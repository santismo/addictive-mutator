@preconcurrency import AudioToolbox
import Foundation

@MainActor
final class LogicPresetGenerator: ObservableObject {
    @Published var basePresetURL: URL?
    @Published var influencePresetURL: URL?
    @Published var blendAmount: Double = 0.5
    @Published var outputName = "AD2 Blend"
    @Published private(set) var isCreating = false
    @Published private(set) var status: Status = .idle

    enum Status: Equatable {
        case idle
        case working(String)
        case success(String)
        case failure(String)
    }

    private let ad2Description = AudioComponentDescription(
        componentType: 1635085685,
        componentSubType: 2017543218,
        componentManufacturer: 2020372033,
        componentFlags: 0,
        componentFlagsMask: 0
    )

    func syncPresets(_ presets: [LogicPreset]) {
        guard !presets.isEmpty else {
            basePresetURL = nil
            influencePresetURL = nil
            return
        }
        if !presets.contains(where: { $0.id == basePresetURL }) {
            basePresetURL = presets.first?.id
        }
        if !presets.contains(where: { $0.id == influencePresetURL }) {
            influencePresetURL = presets.dropFirst().first?.id ?? presets.first?.id
        }
    }

    func createPreset(in library: AD2Library) async {
        guard let baseURL = basePresetURL, let influenceURL = influencePresetURL else {
            status = .failure("Choose a base and an influence preset first.")
            return
        }
        let cleanName = cleanedOutputName(outputName)
        guard !cleanName.isEmpty else {
            status = .failure("Give the new Logic preset a name.")
            return
        }
        let destination = library.generatedLogicPresetFolder.appending(path: "\(cleanName).aupreset")
        guard !FileManager.default.fileExists(atPath: destination.path(percentEncoded: false)) else {
            status = .failure("A Logic preset named ‘\(cleanName)’ already exists. Choose a new name.")
            return
        }

        isCreating = true
        status = .working("Opening the installed Addictive Drums 2 Audio Unit…")
        defer { isCreating = false }

        do {
            let baseState = try propertyListState(at: baseURL)
            let influenceState = try propertyListState(at: influenceURL)
            let unit = try await instantiateAD2()

            status = .working("Reading the base preset’s exposed parameters…")
            unit.fullState = baseState
            let baseValues = parameterValues(in: unit)
            guard !baseValues.isEmpty else {
                throw GeneratorError.noAutomatableParameters
            }

            status = .working("Reading the influence preset’s exposed parameters…")
            unit.fullState = influenceState
            let influenceValues = parameterValues(in: unit)

            status = .working("Blending \(baseValues.count) public Audio Unit parameters…")
            unit.fullState = baseState
            for parameter in unit.parameterTree?.allParameters ?? [] {
                guard let base = baseValues[parameter.address], let influence = influenceValues[parameter.address] else { continue }
                let blended = base + Float(blendAmount) * (influence - base)
                parameter.value = min(parameter.maxValue, max(parameter.minValue, blended))
            }

            guard var outputState = unit.fullState else {
                throw GeneratorError.missingSerializedState
            }
            outputState["name"] = cleanName
            let data = try PropertyListSerialization.data(fromPropertyList: outputState, format: .xml, options: 0)
            try FileManager.default.createDirectory(at: library.generatedLogicPresetFolder, withIntermediateDirectories: true)
            try data.write(to: destination, options: .withoutOverwriting)
            status = .success("Created ‘\(cleanName)’ in your ‘generated presets’ Logic folder.")
        } catch {
            status = .failure(error.localizedDescription)
        }
    }

    private func instantiateAD2() async throws -> AUAudioUnit {
        let box: AudioUnitBox = try await withCheckedThrowingContinuation { continuation in
            AUAudioUnit.instantiate(with: ad2Description, options: []) { unit, error in
                if let unit {
                    continuation.resume(returning: AudioUnitBox(unit))
                } else {
                    continuation.resume(throwing: error ?? GeneratorError.unavailableAudioUnit)
                }
            }
        }
        return box.unit
    }

    private func propertyListState(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dictionary = object as? [String: Any] else { throw GeneratorError.invalidLogicPreset(url.lastPathComponent) }
        let expected = ["manufacturer", "subtype", "type", "data"]
        guard expected.allSatisfy({ dictionary[$0] != nil }) else { throw GeneratorError.invalidLogicPreset(url.lastPathComponent) }
        return dictionary
    }

    private func parameterValues(in unit: AUAudioUnit) -> [AUParameterAddress: AUValue] {
        Dictionary(uniqueKeysWithValues: (unit.parameterTree?.allParameters ?? []).map { ($0.address, $0.value) })
    }

    private func cleanedOutputName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
    }

    private enum GeneratorError: LocalizedError {
        case unavailableAudioUnit
        case invalidLogicPreset(String)
        case noAutomatableParameters
        case missingSerializedState

        var errorDescription: String? {
            switch self {
            case .unavailableAudioUnit:
                "The Addictive Drums 2 Audio Unit could not be opened. Confirm AD2 is authorized, then try again."
            case .invalidLogicPreset(let name):
                "‘\(name)’ is not a valid Logic Audio Unit preset for this generator."
            case .noAutomatableParameters:
                "AD2 did not expose any parameters to the host, so no safe blend could be made."
            case .missingSerializedState:
                "AD2 did not return a preset state to save."
            }
        }
    }
}

private final class AudioUnitBox: @unchecked Sendable {
    let unit: AUAudioUnit
    init(_ unit: AUAudioUnit) { self.unit = unit }
}
