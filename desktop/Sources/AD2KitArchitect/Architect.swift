import AppKit
import Foundation

enum BriefStyle: String, CaseIterable, Identifiable {
    case popPunk, indie, metal, soul, hybrid
    var id: Self { self }
    var name: String {
        switch self {
        case .popPunk: "Pop punk"
        case .indie: "Indie"
        case .metal: "Metal"
        case .soul: "Soul"
        case .hybrid: "Hybrid"
        }
    }
    var matchingTerms: [String] {
        switch self {
        case .popPunk: ["Rock", "Heavy", "Studio Pop", "United"]
        case .indie: ["Vintage", "Studio", "Jazz"]
        case .metal: ["Metal", "Heavy", "Prog"]
        case .soul: ["Soul", "Funk", "Vintage", "Hip Hop"]
        case .hybrid: ["Reel", "Hip Hop", "Session", "Studio"]
        }
    }
}

enum SongPart: String, CaseIterable, Identifiable {
    case verse, preChorus, chorus, bridge, wholeSong
    var id: Self { self }
    var name: String {
        switch self {
        case .verse: "Verse"
        case .preChorus: "Pre-chorus"
        case .chorus: "Chorus"
        case .bridge: "Bridge"
        case .wholeSong: "Whole song"
        }
    }
}

struct Direction {
    let title: String
    let summary: String
    let source: String
    let reference: String
    let kitFeel: [String]
    let mixMoves: [String]

    static let empty = Direction(
        title: "Scan an AD2 library to begin",
        summary: "The generator will use the packs installed on this Mac.",
        source: "No source pack selected", reference: "No reference preset selected",
        kitFeel: ["—"], mixMoves: ["—"]
    )
}

@MainActor
final class Architect: ObservableObject {
    @Published var style: BriefStyle = .popPunk
    @Published var songPart: SongPart = .chorus
    @Published var tempo = 155
    @Published var character = 1
    @Published var referencePreset = ""
    @Published var seed = 427
    @Published private(set) var direction = Direction.empty
    @Published private(set) var didCopy = false

    func generate(using library: AD2Library, preserveSeed: Bool = false) {
        guard !library.adPaks.isEmpty else {
            direction = .empty
            return
        }
        if !preserveSeed { seed = Int.random(in: 100...999) }
        var generator = SeededGenerator(seed: UInt64(seed) &+ UInt64(tempo * 17) &+ UInt64(style.rawValue.hashValue.magnitude))
        let matchingPacks = library.adPaks.filter { pack in
            style.matchingTerms.contains { pack.name.localizedCaseInsensitiveContains($0) }
        }
        let pool = matchingPacks.isEmpty ? library.adPaks : matchingPacks
        let source = pool[Int(generator.next() % UInt64(pool.count))]
        let characterNotes = ["Keep the processing nearly invisible.", "Use processing to focus the idea.", "Let the mix be assertive and unmistakable."]
        let mix = mixOptions(style: style, character: character, songPart: songPart)
        direction = Direction(
            title: "\(style.name) • \(songPart.name)",
            summary: "\(tempo) BPM. \(characterNotes[character])",
            source: "Start in \(source.name) — choose a factory preset that already has the right room and cymbal character.",
            reference: referencePreset.isEmpty ? "Build fresh, then save the result as a new AD2 User Preset." : "A/B against your ‘\(referencePreset)’ user preset.",
            kitFeel: kitOptions(style: style, songPart: songPart, generator: &generator),
            mixMoves: mix
        )
    }

    func copyBuildSheet() {
        let text = """
        AD2 Kit Architect — \(direction.title)
        \(direction.summary)

        START WITH
        \(direction.source)
        \(direction.reference)

        KIT FEEL
        \(direction.kitFeel.map { "• \($0)" }.joined(separator: "\n"))

        MIX MOVES
        \(direction.mixMoves.map { "• \($0)" }.joined(separator: "\n"))
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        didCopy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { self.didCopy = false }
    }

    private func kitOptions(style: BriefStyle, songPart: SongPart, generator: inout SeededGenerator) -> [String] {
        let roles = [
            "Kick: \(choose(["short and focused", "rounded with clear beater", "deep but controlled"], using: &generator))",
            "Snare: \(choose(["crack with a compact tail", "body-first with restrained brightness", "forward without choking the room"], using: &generator))",
            "Cymbals: \(choose(["leave space above guitars", "keep the top smooth", "use a single brighter crash for the lift"], using: &generator))",
        ]
        switch style {
        case .metal: return [roles[0], "Snare: dense center with decisive attack", "Toms: tune for separation during fast fills"]
        case .soul: return ["Kick: soft front edge and low-mid warmth", "Snare: relaxed transient, enough decay to breathe", "Room: audible in the spaces, not on every hit"]
        case .indie: return ["Kick: rounded and not over-hyped", "Snare: woody center with changing velocity", "Cymbals: dry and slightly imperfect"]
        case .hybrid: return [roles[0], roles[1], "Flexi: add one designed accent, then stop"]
        case .popPunk:
            return songPart == .chorus ? ["Kick: focused low end and a slight beater lift", "Snare: bright crack, trimmed sustain", "Cymbals: wide but tucked under the vocal"] : roles
        }
    }

    private func mixOptions(style: BriefStyle, character: Int, songPart: SongPart) -> [String] {
        let room = songPart == .chorus ? "Bring the room up only until the chorus opens." : "Keep room low enough to preserve the vocal’s space."
        let processing = ["Use minimal bus compression; keep velocity alive.", "Use parallel compression as a support layer, not the whole kit.", "Drive the parallel bus, then blend it in quietly."][character]
        switch style {
        case .metal: return ["High-pass non-kick elements with purpose.", processing, "Gate the room for size without washing the grid."]
        case .soul: return ["Favor tape and gentle shaping over hard compression.", room, "Let the snare tail complete the groove."]
        case .indie: return ["Start with close mics and add room reluctantly.", processing, "Avoid perfect left-right symmetry."]
        case .hybrid: return ["Keep the dry kit stable.", "Use one Delerb as the character layer.", processing]
        case .popPunk: return [room, processing, "Protect the kick’s low-end lane against bass guitar."]
        }
    }

    private func choose(_ values: [String], using generator: inout SeededGenerator) -> String {
        values[Int(generator.next() % UInt64(values.count))]
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
