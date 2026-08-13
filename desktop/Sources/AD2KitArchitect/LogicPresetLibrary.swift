import AppKit
import Foundation

struct LogicPreset: Identifiable, Hashable {
    let id: URL
    let name: String
    let location: String
    let isGenerated: Bool

    var displayName: String {
        isGenerated ? "↳ \(name)" : name
    }
}

@MainActor
final class LogicPresetLibrary: ObservableObject {
    @Published private(set) var sourcePresets: [LogicPreset] = []
    @Published private(set) var generatedPresets: [LogicPreset] = []

    private let fileManager = FileManager.default
    var logicPresetFolder: URL {
        fileManager.homeDirectoryForCurrentUser
            .appending(path: "Library/Audio/Presets/XLN Audio/Addictive Drums 2", directoryHint: .isDirectory)
    }
    var generatedLogicPresetFolder: URL {
        logicPresetFolder.appending(path: "generated presets", directoryHint: .isDirectory)
    }
    var allPresets: [LogicPreset] { sourcePresets + generatedPresets }

    func scan() {
        guard fileManager.fileExists(atPath: logicPresetFolder.path(percentEncoded: false)) else {
            sourcePresets = []
            generatedPresets = []
            return
        }
        let generatedPath = generatedLogicPresetFolder.standardizedFileURL.path(percentEncoded: false)
        guard let files = fileManager.enumerator(at: logicPresetFolder, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return }
        var sources: [LogicPreset] = []
        var generated: [LogicPreset] = []
        for case let file as URL in files {
            guard file.pathExtension.caseInsensitiveCompare("aupreset") == .orderedSame else { continue }
            guard file.deletingPathExtension().lastPathComponent != "#default" else { continue }
            let path = file.standardizedFileURL.path(percentEncoded: false)
            let isGenerated = path.hasPrefix(generatedPath + "/")
            let relative = file.deletingLastPathComponent().path(percentEncoded: false)
                .replacingOccurrences(of: logicPresetFolder.path(percentEncoded: false), with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let preset = LogicPreset(
                id: file,
                name: file.deletingPathExtension().lastPathComponent,
                location: relative.isEmpty ? "Logic AD2 presets" : relative,
                isGenerated: isGenerated
            )
            if isGenerated { generated.append(preset) } else { sources.append(preset) }
        }
        sourcePresets = sources.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        generatedPresets = generated.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func openGeneratedFolder() {
        try? fileManager.createDirectory(at: generatedLogicPresetFolder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(generatedLogicPresetFolder)
    }
}
