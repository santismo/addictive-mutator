import AppKit
import Foundation

struct InstalledPack: Identifiable, Hashable {
    enum Kind: String { case adPak = "ADpak", kitPiecePak = "Kitpiece Pak" }
    let id: String
    let name: String
    let kind: Kind
}

struct UserPreset: Identifiable, Hashable {
    let id: URL
    let name: String
}

struct LogicPreset: Identifiable, Hashable {
    let id: URL
    let name: String
}

@MainActor
final class AD2Library: ObservableObject {
    @Published private(set) var isScanning = true
    @Published private(set) var isInstalled = false
    @Published private(set) var userFolder = URL(fileURLWithPath: "/")
    @Published private(set) var packs: [InstalledPack] = []
    @Published private(set) var userPresets: [UserPreset] = []
    @Published private(set) var logicPresets: [LogicPreset] = []

    var adPaks: [InstalledPack] { packs.filter { $0.kind == .adPak } }
    var kitPiecePaks: [InstalledPack] { packs.filter { $0.kind == .kitPiecePak } }

    private let fileManager = FileManager.default
    private var ad2UserRoot: URL {
        fileManager.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/Addictive Drums 2", directoryHint: .isDirectory)
    }
    private let soundDataRoot = URL(fileURLWithPath: "/Library/Application Support/XLN Audio/Addictive Drums 2/Sound Data", isDirectory: true)
    var logicPresetFolder: URL {
        fileManager.homeDirectoryForCurrentUser
            .appending(path: "Library/Audio/Presets/XLN Audio/Addictive Drums 2", directoryHint: .isDirectory)
    }
    var generatedLogicPresetFolder: URL {
        logicPresetFolder.appending(path: "generated presets", directoryHint: .isDirectory)
    }

    func scan() {
        isScanning = true
        let root = ad2UserRoot
        isInstalled = fileManager.fileExists(atPath: root.path(percentEncoded: false))
        userFolder = locateUserPresetFolder(in: root) ?? root
        userPresets = scanUserPresets(at: userFolder)
        logicPresets = scanLogicPresets()
        packs = scanPacks()
        isScanning = false
    }

    func openUserFolder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: userFolder.path(percentEncoded: false))
    }

    private func locateUserPresetFolder(in root: URL) -> URL? {
        guard let children = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return nil }
        if let identifiedFolder = children.first(where: { fileManager.fileExists(atPath: $0.appending(path: "AD2preset.AD2PresetList").path(percentEncoded: false)) }) {
            return identifiedFolder
        }
        return children.first(where: { $0.lastPathComponent.allSatisfy(\.isNumber) })
    }

    private func scanUserPresets(at directory: URL) -> [UserPreset] {
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return [] }
        return files
            .filter { $0.pathExtension.caseInsensitiveCompare("AD2Preset") == .orderedSame }
            .map { UserPreset(id: $0, name: $0.deletingPathExtension().lastPathComponent) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func scanLogicPresets() -> [LogicPreset] {
        guard let files = try? fileManager.contentsOfDirectory(at: logicPresetFolder, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return [] }
        return files
            .filter { $0.pathExtension.caseInsensitiveCompare("aupreset") == .orderedSame }
            .filter { $0.deletingPathExtension().lastPathComponent != "#default" }
            .map { LogicPreset(id: $0, name: $0.deletingPathExtension().lastPathComponent) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func scanPacks() -> [InstalledPack] {
        guard let files = fileManager.enumerator(at: soundDataRoot, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return [] }
        var installed = Set<InstalledPack>()
        for case let file as URL in files {
            guard file.pathExtension.caseInsensitiveCompare("xpak") == .orderedSame else { continue }
            let stem = file.deletingPathExtension().lastPathComponent
            guard !stem.hasPrefix("Preview_"), !stem.hasPrefix("Resources"), !stem.hasPrefix("ADBV") else { continue }
            let code = String(stem.prefix(8))
            if code.hasPrefix("ADAP") {
                installed.insert(InstalledPack(id: code, name: friendlyPackName(from: stem, removing: code), kind: .adPak))
            } else if code.hasPrefix("ADKP") {
                installed.insert(InstalledPack(id: code, name: friendlyPackName(from: stem, removing: code), kind: .kitPiecePak))
            }
        }
        return installed.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func friendlyPackName(from stem: String, removing code: String) -> String {
        let raw = stem
            .replacingOccurrences(of: code, with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "_-"))
            .replacingOccurrences(of: "_", with: " ")
        let specialNames = [
            "Studio Prog": "Studio Progressive",
            "HipHopGospel": "Hip Hop & Gospel",
            "Modern Soul RnB": "Modern Soul & R&B",
            "Sonor Designer Snare": "Sonor Designer Snare",
            "Timbau LP": "Timbau LP",
            "Cajon Valter Standard": "Cajon Valter",
        ]
        return specialNames[raw] ?? raw
    }
}
