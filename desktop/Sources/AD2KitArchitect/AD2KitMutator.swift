import AppKit
import ApplicationServices
import Foundation

enum KitPiece: String, CaseIterable, Identifiable {
    // Keep the existing raw values for Cym 1–3 and Ride 1: they are the keys
    // under which the user's earlier captures are already persisted.
    case kick, snare, hihat, tom1, tom2, tom3, tom4
    case crash1, crash2, crash3, crash4, crash5, crash6
    case ride, ride2
    case flexi1, flexi2, flexi3

    var id: String { rawValue }
    var name: String {
        switch self {
        case .kick: "Kick"
        case .snare: "Snare"
        case .hihat: "Hi-hat"
        case .tom1: "Tom 1"
        case .tom2: "Tom 2"
        case .tom3: "Tom 3"
        case .tom4: "Tom 4"
        case .crash1: "Cymbal 1"
        case .crash2: "Cymbal 2"
        case .crash3: "Cymbal 3"
        case .crash4: "Cymbal 4"
        case .crash5: "Cymbal 5"
        case .crash6: "Cymbal 6"
        case .ride: "Ride 1"
        case .ride2: "Ride 2"
        case .flexi1: "Flexi 1"
        case .flexi2: "Flexi 2"
        case .flexi3: "Flexi 3"
        }
    }

    /// Physical Kit-page order: it reduces travel across the editor and makes
    /// every all-pieces run predictable. Existing stored keys stay intact.
    var kitPageOrder: Int {
        switch self {
        case .crash1: 0
        case .crash2: 1
        case .crash3: 2
        case .crash4: 3
        case .crash5: 4
        case .crash6: 5
        case .tom1: 6
        case .tom2: 7
        case .tom3: 8
        case .tom4: 9
        case .ride: 10
        case .ride2: 11
        case .kick: 12
        case .snare: 13
        case .hihat: 14
        case .flexi1: 15
        case .flexi2: 16
        case .flexi3: 17
        }
    }

    static let kitPageRows: [[KitPiece]] = [
        [.crash1, .crash2, .crash3, .crash4, .crash5, .crash6],
        [.tom1, .tom2, .tom3, .tom4, .ride, .ride2],
        [.kick, .snare, .hihat, .flexi1, .flexi2, .flexi3]
    ]
}

enum KitArrow: String, CaseIterable, Identifiable {
    case up, down
    var id: String { rawValue }
    var name: String { rawValue.capitalized }
    var symbol: String { self == .up ? "arrow.up" : "arrow.down" }
}

enum PointerMode: String, CaseIterable, Identifiable {
    case quiet, visible
    var id: String { rawValue }
    var name: String { self == .quiet ? "Quiet" : "Visible" }
}

enum AutomationTarget: String, CaseIterable, Identifiable {
    case standalone, logicPro
    var id: String { rawValue }
    var name: String { self == .standalone ? "AD2 Standalone" : "Logic Pro AD2" }
    var bundleIdentifier: String { self == .standalone ? "com.xlnaudio.addictivedrums2" : "com.apple.logic10" }
}

struct KitMutationTarget: Hashable, Identifiable {
    let piece: KitPiece
    let arrow: KitArrow

    var id: String { "\(piece.rawValue).\(arrow.rawValue)" }
    var name: String { "\(piece.name) — \(arrow.name)" }
}

private struct ScreenPoint: Codable, Equatable {
    let x: Double
    let y: Double
    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
    init(_ point: CGPoint) { x = point.x; y = point.y }
}

private struct CalibratedPoint: Codable, Equatable {
    let screen: ScreenPoint
    /// Offset from the standalone AD2 window's top-left corner. It allows
    /// calibration to survive moving that window anywhere on the display.
    let ad2WindowOffset: ScreenPoint?
    /// The window dimensions at capture time. When AD2 is resized, the offset
    /// is scaled proportionally before the click is sent.
    let ad2WindowSize: ScreenPoint?
}

private struct CalibrationProfile: Codable {
    var points: [String: CalibratedPoint] = [:]
}

private struct LegacyCalibrationProfile: Codable {
    var points: [String: ScreenPoint] = [:]
}

private struct AD2WindowFrame {
    let origin: CGPoint
    let size: CGSize
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
    @Published var pointerMode: PointerMode = .visible
    @Published var clickIntervalMilliseconds: Double {
        didSet {
            UserDefaults.standard.set(clickIntervalMilliseconds, forKey: clickIntervalKey)
        }
    }
    @Published var automationTarget: AutomationTarget = .standalone {
        didSet { loadEnabledPieces() }
    }
    @Published private(set) var enabledPieces: Set<KitPiece> = Set(KitPiece.allCases)
    @Published private(set) var isRunning = false
    @Published private(set) var isCapturing = false
    @Published private(set) var status: Status = .idle
    @Published private(set) var lastRecipe: MutationRecipe?
    @Published private(set) var lastCaptureDetail: String?

    // v5 keeps standalone and Logic calibrations separately, preventing a
    // coordinate captured in one host from ever being used in the other.
    // Earlier formats store a relative point and its calibration window size.
    // point-only formats are migrated, so a normal update does not make the
    // user recapture every control.
    private let profileKey = "AD2KitMutator.calibration.v5"
    private let previousProfileKey = "AD2KitMutator.calibration.v4"
    private let legacyProfileKey = "AD2KitMutator.calibration.v2"
    // The app was renamed from AD2 Kit Architect. Its old preferences domain
    // is checked once on launch so the new app name never strands a user's
    // hard-won click captures.
    private let previousBundleIdentifier = "com.ad2kitarchitect.local"
    private let clickIntervalKey = "AD2KitMutator.clickIntervalMilliseconds.v1"
    // Inclusion is deliberately separate from calibration. Updating the app
    // never rewrites any saved row/arrow coordinates the user already made.
    private let enabledPiecesKey = "AD2KitMutator.enabledPieces.v1"
    private var captureMonitor: Any?

    init() {
        let previousDefaults = UserDefaults(suiteName: previousBundleIdentifier)
        let savedInterval = UserDefaults.standard.object(forKey: clickIntervalKey) as? Double
            ?? previousDefaults?.object(forKey: clickIntervalKey) as? Double
        clickIntervalMilliseconds = min(max(savedInterval ?? 100, 30), 600)
        let hasCurrentProfile = UserDefaults.standard.data(forKey: profileKey) != nil
        if let data = UserDefaults.standard.data(forKey: profileKey) ?? previousDefaults?.data(forKey: profileKey),
           let loaded = try? JSONDecoder().decode(CalibrationProfile.self, from: data) {
            profile = loaded
            if !hasCurrentProfile { storeProfile() }
        } else if let data = UserDefaults.standard.data(forKey: previousProfileKey) ?? previousDefaults?.data(forKey: previousProfileKey),
                  let previous = try? JSONDecoder().decode(CalibrationProfile.self, from: data) {
            automationTarget = .standalone
            let frame = currentTargetWindowFrame()
            profile.points = Dictionary(uniqueKeysWithValues: previous.points.map { key, point in
                (storageKey(key), CalibratedPoint(screen: point.screen, ad2WindowOffset: point.ad2WindowOffset, ad2WindowSize: point.ad2WindowSize ?? frame.map { ScreenPoint(CGPoint(x: $0.size.width, y: $0.size.height)) }))
            }
            )
            storeProfile()
        } else if let data = UserDefaults.standard.data(forKey: legacyProfileKey) ?? previousDefaults?.data(forKey: legacyProfileKey),
                  let legacy = try? JSONDecoder().decode(LegacyCalibrationProfile.self, from: data) {
            automationTarget = .standalone
            let frame = currentTargetWindowFrame()
            profile.points = Dictionary(uniqueKeysWithValues: legacy.points.map { key, point in
                (storageKey(key), CalibratedPoint(
                    screen: point,
                    ad2WindowOffset: frame.map { ScreenPoint(CGPoint(x: point.x - $0.origin.x, y: point.y - $0.origin.y)) },
                    ad2WindowSize: frame.map { ScreenPoint(CGPoint(x: $0.size.width, y: $0.size.height)) }
                ))
            })
            storeProfile()
        }
        loadEnabledPieces()
        refreshPermission()
    }

    var capturedTargets: [KitMutationTarget] {
        KitPiece.allCases.flatMap { piece in
            KitArrow.allCases.map { KitMutationTarget(piece: piece, arrow: $0) }
        }.filter(isCaptured)
    }
    var capturedPieces: [KitPiece] {
        KitPiece.allCases.filter { isHoverCaptured($0) && !capturedArrows(for: $0).isEmpty }
    }
    var enabledPreparedPieces: [KitPiece] { capturedPieces.filter(isPieceEnabled) }
    var readyToMutate: Bool { accessibilityGranted && !isBusy && !enabledPreparedPieces.isEmpty }
    var isBusy: Bool { isRunning || isCapturing }
    var clickIntervalLabel: String { "\(Int(clickIntervalMilliseconds.rounded())) ms" }

    func refreshPermission() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    func requestAccessibility() {
        if let settings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(settings)
        }
        status = .working("Approve this app in macOS Accessibility settings, then return here and click Check again.")
    }

    func readPointerLocation() {
        refreshPermission()
        guard accessibilityGranted else {
            status = .failure("This build does not have Accessibility permission yet. Use Request access, enable Addictive Mutator, then click Check again.")
            return
        }
        guard let point = CGEvent(source: nil)?.location else {
            status = .failure("macOS did not return the current pointer location.")
            return
        }
        status = .success("Pointer read successfully: x \(Int(point.x.rounded())) · y \(Int(point.y.rounded())).")
    }

    func isCaptured(_ target: KitMutationTarget) -> Bool { profile.points[storageKey(target.id)] != nil }

    func isHoverCaptured(_ piece: KitPiece) -> Bool { profile.points[storageKey(hoverKey(for: piece))] != nil }

    func capturedArrows(for piece: KitPiece) -> [KitArrow] {
        KitArrow.allCases.filter { isCaptured(KitMutationTarget(piece: piece, arrow: $0)) }
    }

    func isPieceReady(_ piece: KitPiece) -> Bool {
        isHoverCaptured(piece) && !capturedArrows(for: piece).isEmpty
    }

    func isPieceEnabled(_ piece: KitPiece) -> Bool {
        enabledPieces.contains(piece)
    }

    func setPieceEnabled(_ piece: KitPiece, enabled: Bool) {
        if enabled { enabledPieces.insert(piece) }
        else { enabledPieces.remove(piece) }
        storeEnabledPieces()
    }

    func capturedLocation(_ target: KitMutationTarget) -> String? {
        guard let point = profile.points[storageKey(target.id)]?.screen else { return nil }
        return "x \(Int(point.x.rounded())) · y \(Int(point.y.rounded()))"
    }

    func clear(_ target: KitMutationTarget) {
        profile.points.removeValue(forKey: storageKey(target.id))
        storeProfile()
    }

    func clearHover(for piece: KitPiece) {
        profile.points.removeValue(forKey: storageKey(hoverKey(for: piece)))
        storeProfile()
    }

    func clearAll() {
        profile.points.keys.filter { $0.hasPrefix("\(automationTarget.rawValue).") }.forEach { profile.points.removeValue(forKey: $0) }
        storeProfile()
    }

    func capture(_ target: KitMutationTarget) { beginCapture(key: target.id, label: target.name) }
    func captureHover(for piece: KitPiece) { beginCapture(key: hoverKey(for: piece), label: "\(piece.name) row") }

    /// A safe diagnostic: move the visible cursor to one stored Kit-page
    /// coordinate, pause, then issue one click. This makes a bad calibration
    /// immediately obvious before a multi-slot mutation is attempted.
    func test(_ target: KitMutationTarget) async {
        guard await bringTargetForward() else { return }
        guard let hover = hoverPoint(for: target.piece), let point = point(for: target) else {
            status = .failure("Capture the ‘\(target.piece.name)’ row and its ‘\(target.arrow.name)’ arrow for \(automationTarget.name) before testing.")
            return
        }
        isRunning = true
        defer { isRunning = false }

        status = .working("Hovering ‘\(target.piece.name)’, then moving to its ‘\(target.arrow.name)’ arrow…")
        sendHover(at: hover)
        try? await Task.sleep(nanoseconds: hoverRevealDelay)
        sendHover(at: point)
        try? await Task.sleep(nanoseconds: arrowRevealDelay)
        click(point)
        try? await Task.sleep(nanoseconds: automationDelay)
        status = .success("Clicked ‘\(target.name)’ once. If the piece did not cycle, recapture the row hover point and arrow, then test again.")
    }

    func mutateKit() async {
        guard readyToMutate else {
            status = .failure("Enable Accessibility, then turn on and prepare at least one Kit piece (row hover plus an Up or Down arrow).")
            return
        }
        // The user chooses the pieces with the per-slot Include switches;
        // execution always follows the physical Kit-page route.
        let pieces = enabledPreparedPieces.sorted { $0.kitPageOrder < $1.kitPageOrder }
        await mutate(pieces: pieces)
    }

    private func mutate(pieces: [KitPiece]) async {
        let seed = Int.random(in: 1000...9999)
        var generator = SeededGenerator(seed: UInt64(seed))
        let changes = pieces.compactMap { piece -> (KitMutationTarget, Int)? in
            let arrows = capturedArrows(for: piece)
            guard !arrows.isEmpty else { return nil }
            let arrow = arrows[Int(generator.next() % UInt64(arrows.count))]
            return (KitMutationTarget(piece: piece, arrow: arrow), Int(generator.next() % 4) + 1)
        }
        let recipe = MutationRecipe(seed: seed, changes: changes)
        await run(recipe: recipe)
    }

    /// The menu-bar action is deliberately only for an already-calibrated AD2
    /// editor in Logic. It never reuses the standalone capture points.
    func quickRandomizeLogic() async {
        guard !isBusy else {
            status = .failure("A capture or mutation is already in progress.")
            return
        }
        let previousTarget = automationTarget
        automationTarget = .logicPro
        defer { automationTarget = previousTarget }
        guard !enabledPreparedPieces.isEmpty else {
            status = .failure("The menu-bar action needs at least one enabled, calibrated AD2 piece for Logic Pro. Open the main app to set its Include switch and calibrate it once.")
            return
        }
        await mutateKit()
    }

    private func run(recipe: MutationRecipe) async {
        guard await bringTargetForward() else { return }
        isRunning = true
        defer { isRunning = false }
        status = .working("Mutating \(recipe.changes.count) Kit-page slots in Addictive Drums 2…")
        for (target, clicks) in recipe.changes {
            guard let hover = hoverPoint(for: target.piece), let point = point(for: target) else { continue }
            // Hover once to reveal the arrow, then remain on it for the full
            // burst. There is no need to travel back to the drum row between
            // clicks, which makes a multi-step change much faster.
            sendHover(at: hover)
            try? await Task.sleep(nanoseconds: hoverRevealDelay)
            sendHover(at: point)
            try? await Task.sleep(nanoseconds: arrowRevealDelay)
            for clickIndex in 0..<clicks {
                status = .working("Changing ‘\(target.name)’ — click \(clickIndex + 1) of \(clicks)…")
                click(point)
                try? await Task.sleep(nanoseconds: automationDelay)
            }
        }
        lastRecipe = recipe
        status = .success("New AD2 kit generated. Audition it, then save it through AD2 whenever you want to keep it.")
    }

    private func bringTargetForward() async -> Bool {
        guard accessibilityGranted else {
            status = .failure("Accessibility permission is required before any automation can run.")
            return false
        }
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == automationTarget.bundleIdentifier }) else {
            status = .failure(automationTarget == .standalone ? "Open standalone Addictive Drums 2, switch to the Kit page, then try again." : "Open the target Addictive Drums 2 plug-in editor in Logic Pro, then try again.")
            return false
        }
        app.activate(options: [])
        try? await Task.sleep(nanoseconds: 700_000_000)
        guard currentTargetWindowFrame() != nil else {
            status = .failure(automationTarget == .standalone ? "AD2’s standalone window is not available." : "Focus the desired AD2 plug-in editor window in Logic Pro, then try again.")
            return false
        }
        return true
    }

    private func beginCapture(key: String, label: String) {
        guard !isBusy else { return }
        refreshPermission()
        guard accessibilityGranted else {
            status = .failure("Allow Accessibility for this build first. Capture needs the same permission as mouse control.")
            return
        }
        isCapturing = true
        status = .working("Preparing click capture for ‘\(label)’… wait for the second chime, then click the exact AD2 control once.")
        NSSound.beep()
        NSApp.hide(nil)
        // Do not monitor immediately: without this delay the initial click on
        // this app's Capture button can be mistaken for the AD2 control click.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { [weak self] in
            guard let self, self.isCapturing else { return }
            self.captureMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
                let location = CGEvent(source: nil)?.location
                DispatchQueue.main.async {
                    self?.finishCapture(key: key, label: label, location: location)
                }
            }
            NSSound.beep()
            self.status = .working("Click capture is ready for ‘\(label)’. Click the exact AD2 control once now.")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            guard let self else { return }
            guard self.isCapturing else { return }
            self.stopCaptureMonitor()
            self.isCapturing = false
            self.status = .failure("No click was captured for ‘\(label)’ within 30 seconds. Try Capture again and click the AD2 control once.")
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func finishCapture(key: String, label: String, location: CGPoint?) {
        guard isCapturing else { return }
        stopCaptureMonitor()
        isCapturing = false
        guard let location else {
            status = .failure("macOS could not read that click location. Try Capture again.")
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let windowFrame = currentTargetWindowFrame(containing: location)
        profile.points[storageKey(key)] = CalibratedPoint(
            screen: ScreenPoint(location),
            ad2WindowOffset: windowFrame.map { ScreenPoint(CGPoint(x: location.x - $0.origin.x, y: location.y - $0.origin.y)) },
            ad2WindowSize: windowFrame.map { ScreenPoint(CGPoint(x: $0.size.width, y: $0.size.height)) }
        )
        storeProfile()
        lastCaptureDetail = "Saved ‘\(label)’ at x \(Int(location.x.rounded())) · y \(Int(location.y.rounded()))."
        NSSound.beep()
        status = .success("\(lastCaptureDetail ?? "Capture saved.") It will survive restarts and follow the \(automationTarget.name) window position/size.")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func stopCaptureMonitor() {
        if let captureMonitor { NSEvent.removeMonitor(captureMonitor) }
        captureMonitor = nil
    }

    private func point(for target: KitMutationTarget) -> CGPoint? { resolvedPoint(profile.points[storageKey(target.id)]) }
    private func hoverPoint(for piece: KitPiece) -> CGPoint? { resolvedPoint(profile.points[storageKey(hoverKey(for: piece))]) }
    private func hoverKey(for piece: KitPiece) -> String { "\(piece.rawValue).hover" }
    private func storageKey(_ key: String) -> String { "\(automationTarget.rawValue).\(key)" }

    private var hoverRevealDelay: UInt64 {
        let multiplier = pointerMode == .quiet ? 0.6 : 1.5
        let minimum = pointerMode == .quiet ? 30.0 : 85.0
        let maximum = pointerMode == .quiet ? 110.0 : 300.0
        return millisecondsToNanoseconds(min(max(clickIntervalMilliseconds * multiplier, minimum), maximum))
    }
    private var arrowRevealDelay: UInt64 {
        let multiplier = pointerMode == .quiet ? 0.9 : 2.0
        let minimum = pointerMode == .quiet ? 45.0 : 120.0
        let maximum = pointerMode == .quiet ? 160.0 : 450.0
        return millisecondsToNanoseconds(min(max(clickIntervalMilliseconds * multiplier, minimum), maximum))
    }
    private var automationDelay: UInt64 { millisecondsToNanoseconds(clickIntervalMilliseconds) }

    private func millisecondsToNanoseconds(_ value: Double) -> UInt64 {
        UInt64(max(1, value * 1_000_000))
    }

    private func resolvedPoint(_ stored: CalibratedPoint?) -> CGPoint? {
        guard let stored else { return nil }
        guard let offset = stored.ad2WindowOffset, let frame = currentTargetWindowFrame() else { return stored.screen.cgPoint }
        let xScale = stored.ad2WindowSize.flatMap { $0.x > 0 && frame.size.width > 0 ? frame.size.width / $0.x : nil } ?? 1
        let yScale = stored.ad2WindowSize.flatMap { $0.y > 0 && frame.size.height > 0 ? frame.size.height / $0.y : nil } ?? 1
        return CGPoint(x: frame.origin.x + (offset.x * xScale), y: frame.origin.y + (offset.y * yScale))
    }

    private func currentTargetWindowFrame(containing point: CGPoint? = nil) -> AD2WindowFrame? {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == automationTarget.bundleIdentifier }) else { return nil }
        let applicationElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(applicationElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement],
              !windows.isEmpty else { return nil }
        if let point, let matched = windows.compactMap(windowFrame).first(where: { frame in
            CGRect(origin: frame.origin, size: frame.size).contains(point)
        }) {
            return matched
        }
        if automationTarget == .logicPro {
            var focusedValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(applicationElement, kAXFocusedWindowAttribute as CFString, &focusedValue) == .success,
               let focusedValue {
                return windowFrame(focusedValue as! AXUIElement)
            }
        }
        return windowFrame(windows.first!)
    }

    private func windowFrame(_ window: AXUIElement) -> AD2WindowFrame? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue else { return nil }
        let positionAXValue = positionValue as! AXValue
        let sizeAXValue = sizeValue as! AXValue
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetType(positionAXValue) == .cgPoint,
              AXValueGetValue(positionAXValue, .cgPoint, &position),
              AXValueGetType(sizeAXValue) == .cgSize,
              AXValueGetValue(sizeAXValue, .cgSize, &size) else { return nil }
        return AD2WindowFrame(origin: position, size: size)
    }

    private func click(_ point: CGPoint?) {
        guard let point else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private func sendHover(at point: CGPoint) {
        if pointerMode == .visible {
            CGWarpMouseCursorPosition(point)
            return
        }
        let source = CGEventSource(stateID: .hidSystemState)
        let move = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
        move?.post(tap: .cgSessionEventTap)
    }

    private func storeProfile() {
        if let data = try? JSONEncoder().encode(profile) { UserDefaults.standard.set(data, forKey: profileKey) }
    }

    private func loadEnabledPieces() {
        let allPieces = Set(KitPiece.allCases)
        guard let settings = UserDefaults.standard.dictionary(forKey: enabledPiecesKey) as? [String: [String]],
              let savedIDs = settings[automationTarget.rawValue] else {
            enabledPieces = allPieces
            return
        }
        // Ignore retired/unknown names and use all-on for an old empty entry.
        let savedPieces = Set(savedIDs.compactMap(KitPiece.init(rawValue:)))
        enabledPieces = savedPieces.isEmpty ? allPieces : savedPieces
    }

    private func storeEnabledPieces() {
        var settings = UserDefaults.standard.dictionary(forKey: enabledPiecesKey) as? [String: [String]] ?? [:]
        settings[automationTarget.rawValue] = enabledPieces.map(\.rawValue).sorted()
        UserDefaults.standard.set(settings, forKey: enabledPiecesKey)
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
