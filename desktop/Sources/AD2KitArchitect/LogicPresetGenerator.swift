@preconcurrency import AudioToolbox
import Foundation

struct BlendRecipe: Equatable {
    let baseName: String
    let influenceNames: [String]
    let strength: Double
    let outputName: String
}

@MainActor
final class LogicPresetGenerator: ObservableObject {
    @Published var basePresetURL: URL?
    @Published var influenceURLs = Set<URL>()
    @Published var randomPoolURLs = Set<URL>()
    @Published var blendAmount: Double = 0.5
    @Published private(set) var isCreating = false
    @Published private(set) var status: Status = .idle
    @Published private(set) var lastRecipe: BlendRecipe?

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
        let ids = Set(presets.map(\.id))
        if !ids.contains(basePresetURL ?? URL(fileURLWithPath: "/")) { basePresetURL = presets.first?.id }
        influenceURLs = influenceURLs.intersection(ids)
        randomPoolURLs = randomPoolURLs.intersection(ids)
        if randomPoolURLs.isEmpty { randomPoolURLs = ids }
        if let base = basePresetURL { influenceURLs.remove(base) }
    }

    func toggleInfluence(_ id: URL) {
        if influenceURLs.contains(id) { influenceURLs.remove(id) }
        else if id != basePresetURL { influenceURLs.insert(id) }
    }

    func toggleRandomPool(_ id: URL) {
        if randomPoolURLs.contains(id) { randomPoolURLs.remove(id) }
        else { randomPoolURLs.insert(id) }
    }

    func removeBaseFromInfluences() {
        if let basePresetURL { influenceURLs.remove(basePresetURL) }
    }

    func createManualPreset(in library: LogicPresetLibrary) async {
        guard let base = basePresetURL else {
            status = .failure("Choose a base preset first.")
            return
        }
        let influences = influenceURLs.filter { $0 != base }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard !influences.isEmpty else {
            status = .failure("Choose at least one influence preset.")
            return
        }
        await createPreset(
            base: base,
            influences: influences,
            strength: blendAmount,
            outputName: nextOutputName(base: base, influences: influences, kind: "blend", in: library),
            in: library
        )
    }

    func createRandomPreset(in library: LogicPresetLibrary) async {
        let pool = Array(randomPoolURLs)
        guard pool.count >= 2 else {
            status = .failure("Choose at least two presets for the random pool.")
            return
        }
        let recipe = freshRandomRecipe(from: pool)
        await createPreset(
            base: recipe.base,
            influences: recipe.influences,
            strength: recipe.strength,
            outputName: nextOutputName(base: recipe.base, influences: recipe.influences, kind: "hybrid", in: library),
            in: library
        )
    }

    private func createPreset(base baseURL: URL, influences influenceURLs: [URL], strength: Double, outputName: String, in library: LogicPresetLibrary) async {
        let destination = library.generatedLogicPresetFolder.appending(path: "\(outputName).aupreset")
        guard !FileManager.default.fileExists(atPath: destination.path(percentEncoded: false)) else {
            status = .failure("‘\(outputName)’ already exists. Try again to make a new variation.")
            return
        }
        isCreating = true
        status = .working("Opening Addictive Drums 2 through Logic’s Audio Unit interface…")
        defer { isCreating = false }
        do {
            let baseState = try propertyListState(at: baseURL)
            let influenceStates = try influenceURLs.map(propertyListState(at:))
            let unit = try await instantiateAD2()

            status = .working("Reading \(influenceURLs.count + 1) presets and their published parameters…")
            unit.fullState = baseState
            let baseValues = parameterValues(in: unit)
            guard !baseValues.isEmpty else { throw GeneratorError.noAutomatableParameters }

            var influenceValues: [[AUParameterAddress: AUValue]] = []
            for state in influenceStates {
                unit.fullState = state
                influenceValues.append(parameterValues(in: unit))
            }

            status = .working("Creating a new hybrid through Addictive Drums 2…")
            unit.fullState = baseState
            for parameter in unit.parameterTree?.allParameters ?? [] {
                guard let baseValue = baseValues[parameter.address] else { continue }
                let values = influenceValues.compactMap { $0[parameter.address] }
                guard !values.isEmpty else { continue }
                let average = values.reduce(0, +) / Float(values.count)
                let blended = baseValue + Float(strength) * (average - baseValue)
                parameter.value = min(parameter.maxValue, max(parameter.minValue, blended))
            }

            guard var outputState = unit.fullState else { throw GeneratorError.missingSerializedState }
            outputState["name"] = outputName
            let outputData = try PropertyListSerialization.data(fromPropertyList: outputState, format: .xml, options: 0)
            try FileManager.default.createDirectory(at: library.generatedLogicPresetFolder, withIntermediateDirectories: true)
            try outputData.write(to: destination, options: .withoutOverwriting)

            let baseName = baseURL.deletingPathExtension().lastPathComponent
            let influenceNames = influenceURLs.map { $0.deletingPathExtension().lastPathComponent }
            lastRecipe = BlendRecipe(baseName: baseName, influenceNames: influenceNames, strength: strength, outputName: outputName)
            status = .success("Created ‘\(outputName)’ in your generated presets folder.")
        } catch {
            status = .failure(error.localizedDescription)
        }
    }

    private func instantiateAD2() async throws -> AUAudioUnit {
        let box: AudioUnitBox = try await withCheckedThrowingContinuation { continuation in
            AUAudioUnit.instantiate(with: ad2Description, options: []) { unit, error in
                if let unit { continuation.resume(returning: AudioUnitBox(unit)) }
                else { continuation.resume(throwing: error ?? GeneratorError.unavailableAudioUnit) }
            }
        }
        return box.unit
    }

    private func propertyListState(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let state = object as? [String: Any] else { throw GeneratorError.invalidLogicPreset(url.lastPathComponent) }
        guard matchesAD2Component(state) else { throw GeneratorError.invalidLogicPreset(url.lastPathComponent) }
        return state
    }

    private func matchesAD2Component(_ state: [String: Any]) -> Bool {
        let type = (state["type"] as? NSNumber)?.uint32Value
        let subtype = (state["subtype"] as? NSNumber)?.uint32Value
        let maker = (state["manufacturer"] as? NSNumber)?.uint32Value
        return type == ad2Description.componentType && subtype == ad2Description.componentSubType && maker == ad2Description.componentManufacturer && state["data"] != nil
    }

    private func parameterValues(in unit: AUAudioUnit) -> [AUParameterAddress: AUValue] {
        Dictionary(uniqueKeysWithValues: (unit.parameterTree?.allParameters ?? []).map { ($0.address, $0.value) })
    }

    private func nextOutputName(base: URL, influences: [URL], kind: String, in library: LogicPresetLibrary) -> String {
        let sourceNames = [base] + influences
        let combinedNames = sourceNames.map { compactName($0.deletingPathExtension().lastPathComponent) }
        let core = combinedNames.joined(separator: " + ")
        let maximumCoreLength = 78
        let trimmedCore = core.count > maximumCoreLength ? String(core.prefix(maximumCoreLength)).trimmingCharacters(in: .whitespaces) + "…" : core
        let preferred = "\(trimmedCore) — \(kind)"
        let existing = (try? FileManager.default.contentsOfDirectory(at: library.generatedLogicPresetFolder, includingPropertiesForKeys: nil)) ?? []
        let names = Set(existing.map { $0.deletingPathExtension().lastPathComponent })
        if !names.contains(preferred) { return preferred }
        for number in 2...9999 {
            let variation = "\(preferred) \(number)"
            if !names.contains(variation) { return variation }
        }
        return "\(preferred) \(UUID().uuidString.prefix(8))"
    }

    private func freshRandomRecipe(from pool: [URL]) -> RandomRecipe {
        let previousSignature = lastRecipe.map { "\($0.baseName)|\($0.influenceNames.sorted().joined(separator: "|"))|\(Int($0.strength * 100))" }
        var fallback: RandomRecipe?
        for _ in 0..<24 {
            let shuffled = pool.shuffled()
            let influenceCount = Int.random(in: 1...min(3, shuffled.count - 1))
            let recipe = RandomRecipe(
                base: shuffled[0],
                influences: Array(shuffled[1...influenceCount]),
                strength: Double.random(in: 0.32...0.88)
            )
            fallback = recipe
            if recipe.signature != previousSignature { return recipe }
        }
        return fallback!
    }

    private func compactName(_ value: String) -> String {
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
            case .unavailableAudioUnit: "The Addictive Drums 2 Audio Unit could not be opened. Confirm AD2 is authorized, then try again."
            case .invalidLogicPreset(let name): "‘\(name)’ is not an Addictive Drums 2 Logic preset."
            case .noAutomatableParameters: "AD2 did not publish any parameters to the host, so a safe blend could not be made."
            case .missingSerializedState: "AD2 did not return a preset state to save."
            }
        }
    }
}

private struct RandomRecipe {
    let base: URL
    let influences: [URL]
    let strength: Double

    var signature: String {
        let baseName = base.deletingPathExtension().lastPathComponent
        let influenceNames = influences.map { $0.deletingPathExtension().lastPathComponent }.sorted().joined(separator: "|")
        return "\(baseName)|\(influenceNames)|\(Int(strength * 100))"
    }
}

private final class AudioUnitBox: @unchecked Sendable {
    let unit: AUAudioUnit
    init(_ unit: AUAudioUnit) { self.unit = unit }
}
