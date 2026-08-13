import AppKit
import ApplicationServices
import Foundation

enum KitMutationTarget: String, CaseIterable, Identifiable {
    case kickNext, snareNext, hihatNext, tom1Next, tom2Next, tom3Next, tom4Next, crash1Next, crash2Next, rideNext, flexi1Next, flexi2Next

    var id: String { rawValue }
    var name: String {
        switch self {
        case .kickNext: "Kick — next"
        case .snareNext: "Snare — next"
        case .hihatNext: "Hi-hat — next"
        case .tom1Next: "Tom 1 — next"
        case .tom2Next: "Tom 2 — next"
        case .tom3Next: "Tom 3 — next"
        case .tom4Next: "Tom 4 — next"
        case .crash1Next: "Crash 1 — next"
        case .crash2Next: "Crash 2 — next"
        case .rideNext: "Ride — next"
        case .flexi1Next: "Flexi 1 — next"
        case .flexi2Next: "Flexi 2 — next"
        }
    }
}

enum SaveTarget: String, CaseIterable, Identifiable {
    case savePreset, presetName, confirmSave
    var id: String { rawValue }
    var name: String {
        switch self {
        case .savePreset: "Save button"
        case .presetName: "Name field"
        case .confirmSave: "Final Save"
        }
    }
}

private struct ScreenPoint: Codable, Equatable {
    let x: Double
    let y: Double
    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
    init(_ point: CGPoint) { x = point.x; y = point.y }
}

private struct CalibrationProfile: Codable {
    var points: [String: ScreenPoint] = [:]
}

struct MutationRecipe {
    let seed: Int
    let changes: [(KitMutationTarget, Int)]
    var summary: String {
        let parts = changes.map { "\($0.0.name) ×\($0.1)" }.joined(separator: "  •  ")
        return "Seed \(seed): \(parts)"
    }
}

@MainActor
final class AD2KitMutator: ObservableObject {
    enum Status: Equatable {
        case idle
        case working(String)
        case success(String)
        case failure(String)
    }

    @Published private(set) var accessibilityGranted = false
    private var profile = CalibrationProfile()
    @Published var mutationDepth = 4
    @Published var presetName = "AD2 Hybrid 001"
    @Published private(set) var isRunning = false
    @Published private(set) var status: Status = .idle
    @Published private(set) var lastRecipe: MutationRecipe?

    private let profileKey = "AD2KitMutator.calibration.v1"
    private let ad2BundleIdentifier = "com.xlnaudio.addictivedrums2"
    private let automationDelay: UInt64 = 170_000_000

    init() {
        if let data = UserDefaults.standard.data(forKey: profileKey), let loaded = try? JSONDecoder().decode(CalibrationProfile.self, from: data) {
            profile = loaded
        }
        presetName = nextPresetName()
        refreshPermission()
    }

    var capturedTargets: [KitMutationTarget] { KitMutationTarget.allCases.filter { isCaptured($0) } }
    var readyToMutate: Bool { accessibilityGranted && !isRunning && capturedTargets.count >= 2 }
    var readyToSave: Bool { accessibilityGranted && !isRunning && SaveTarget.allCases.allSatisfy { isCaptured($0) } && !presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func refreshPermission() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    func requestAccessibility() {
        if let settings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(settings)
        }
        status = .working("Approve this app in macOS Accessibility settings, then return here and click Check again.")
    }

    func isCaptured(_ target: KitMutationTarget) -> Bool { profile.points[target.rawValue] != nil }
    func isCaptured(_ target: SaveTarget) -> Bool { profile.points[target.rawValue] != nil }

    func clear(_ target: KitMutationTarget) {
        profile.points.removeValue(forKey: target.rawValue)
        storeProfile()
    }

    func clearAll() {
        profile.points.removeAll()
        storeProfile()
    }

    func capture(_ target: KitMutationTarget) { beginCapture(key: target.rawValue, label: target.name) }
    func capture(_ target: SaveTarget) { beginCapture(key: target.rawValue, label: target.name) }

    func mutateKit() async {
        guard readyToMutate else {
            status = .failure("Enable Accessibility and capture at least two Kit-page next arrows first.")
            return
        }
        let targets = Array(capturedTargets.shuffled().prefix(min(mutationDepth, capturedTargets.count)))
        let seed = Int.random(in: 1000...9999)
        var generator = SeededGenerator(seed: UInt64(seed))
        let recipe = MutationRecipe(seed: seed, changes: targets.map { ($0, Int(generator.next() % 6) + 1) })
        await run(recipe: recipe)
    }

    func saveCurrentKit() async {
        guard readyToSave else {
            status = .failure("Capture the three AD2 Save Preset controls and give the preset a name first.")
            return
        }
        guard await bringAD2Forward() else { return }
        isRunning = true
        defer { isRunning = false }
        status = .working("Opening AD2’s Save Preset dialog…")
        click(point(for: .savePreset))
        try? await Task.sleep(nanoseconds: 650_000_000)
        status = .working("Naming the AD2 User Preset…")
        click(point(for: .presetName))
        try? await Task.sleep(nanoseconds: 120_000_000)
        selectAllAndType(cleanedPresetName)
        try? await Task.sleep(nanoseconds: 200_000_000)
        status = .working("Asking AD2 to save the generated kit…")
        click(point(for: .confirmSave))
        try? await Task.sleep(nanoseconds: 500_000_000)
        status = .success("AD2 saved ‘\(cleanedPresetName)’ as its own User Preset.")
        presetName = nextPresetName()
    }

    private var cleanedPresetName: String {
        presetName.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
    }

    private func run(recipe: MutationRecipe) async {
        guard await bringAD2Forward() else { return }
        isRunning = true
        defer { isRunning = false }
        status = .working("Mutating \(recipe.changes.count) Kit-page slots in Addictive Drums 2…")
        for (target, clicks) in recipe.changes {
            guard let point = point(for: target) else { continue }
            for _ in 0..<clicks {
                click(point)
                try? await Task.sleep(nanoseconds: automationDelay)
            }
        }
        lastRecipe = recipe
        presetName = "AD2 Hybrid \(recipe.seed)"
        status = .success("New AD2 kit generated. Audition it, then use the Save step below to create the real User Preset.")
    }

    private func bringAD2Forward() async -> Bool {
        guard accessibilityGranted else {
            status = .failure("Accessibility permission is required before any automation can run.")
            return false
        }
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == ad2BundleIdentifier }) else {
            status = .failure("Open standalone Addictive Drums 2, switch to the Kit page, then try again.")
            return false
        }
        app.activate(options: [])
        try? await Task.sleep(nanoseconds: 700_000_000)
        return true
    }

    private func beginCapture(key: String, label: String) {
        guard !isRunning else { return }
        status = .working("Move the pointer over ‘\(label)’ in AD2. Capturing its location in 4 seconds…")
        NSApp.hide(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self else { return }
            guard let location = CGEvent(source: nil)?.location else {
                self.status = .failure("macOS could not read the pointer location. Enable Accessibility and try again.")
                NSApp.activate(ignoringOtherApps: true)
                return
            }
            self.profile.points[key] = ScreenPoint(location)
            self.storeProfile()
            self.status = .success("Captured ‘\(label)’. Keep AD2 at this UI scale for automation.")
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func point(for target: KitMutationTarget) -> CGPoint? { profile.points[target.rawValue]?.cgPoint }
    private func point(for target: SaveTarget) -> CGPoint? { profile.points[target.rawValue]?.cgPoint }

    private func click(_ point: CGPoint?) {
        guard let point else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private func selectAllAndType(_ text: String) {
        let source = CGEventSource(stateID: .hidSystemState)
        let selectDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
        selectDown?.flags = .maskCommand
        let selectUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        selectUp?.flags = .maskCommand
        selectDown?.post(tap: .cghidEventTap)
        selectUp?.post(tap: .cghidEventTap)
        let utf16 = Array(text.utf16)
        let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
        down?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        up?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private func storeProfile() {
        if let data = try? JSONEncoder().encode(profile) { UserDefaults.standard.set(data, forKey: profileKey) }
    }

    private func nextPresetName() -> String {
        "AD2 Hybrid \(Int.random(in: 1000...9999))"
    }
}

private struct SeededGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
