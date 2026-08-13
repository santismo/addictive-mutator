import AppKit
import SwiftUI

@main
struct AD2KitArchitectApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 840, idealWidth: 980, minHeight: 680, idealHeight: 760)
        }
        .windowResizability(.contentMinSize)
    }
}

struct ContentView: View {
    @StateObject private var library = AD2Library()
    @StateObject private var architect = Architect()
    @StateObject private var logicGenerator = LogicPresetGenerator()

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()
            if library.isScanning {
                ProgressView("Finding your Addictive Drums 2 library…")
                    .controlSize(.large)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        header
                        libraryCard
                        logicBlendCard
                        briefCard
                        directionCard
                        safetyNote
                    }
                    .padding(32)
                    .frame(maxWidth: 900, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            library.scan()
        }
        .onChange(of: library.packs) {
            architect.generate(using: library)
        }
        .onChange(of: library.logicPresets) {
            logicGenerator.syncPresets(library.logicPresets)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                Label("AD2 KIT ARCHITECT", systemImage: "waveform")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.coral)
                    .tracking(1.5)
                Text("Make the next kit feel right.")
                    .font(.system(size: 34, weight: .regular, design: .serif))
                Text("A local, procedural companion for the AD2 content installed on this Mac.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            Spacer()
            Button {
                library.scan()
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .tint(Color.coral)
        }
    }

    private var libraryCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("YOUR AD2 LIBRARY")
                            .sectionLabel()
                        if library.isInstalled {
                            Text("Found on this Mac")
                                .font(.title3.weight(.medium))
                            Text(library.userFolder.path(percentEncoded: false))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Text("Addictive Drums 2 wasn’t found")
                                .font(.title3.weight(.medium))
                            Text("Install AD2 first, then click Rescan.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if library.isInstalled {
                        Button("Open user folder") {
                            library.openUserFolder()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if library.isInstalled {
                    Divider()
                    HStack(spacing: 22) {
                        Stat(value: "\(library.adPaks.count)", label: "ADpaks")
                        Stat(value: "\(library.kitPiecePaks.count)", label: "Kitpiece Paks")
                        Stat(value: "\(library.userPresets.count)", label: "User Presets")
                        Stat(value: "\(library.logicPresets.count)", label: "Logic Presets")
                    }
                    if !library.adPaks.isEmpty {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("AVAILABLE ADPAKS").sectionLabel()
                            FlowLayout(spacing: 7) {
                                ForEach(library.adPaks) { pack in
                                    Text(pack.name)
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 5)
                                        .background(Color.coral.opacity(0.14), in: Capsule())
                                        .foregroundStyle(Color.coralLight)
                                }
                            }
                        }
                    }
                    if !library.userPresets.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("YOUR EXISTING STARTING POINTS").sectionLabel()
                            Picker("Starting point", selection: $architect.referencePreset) {
                                Text("No reference preset").tag("")
                                ForEach(library.userPresets) { preset in
                                    Text(preset.name).tag(preset.name)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            Text("Names only — this app does not inspect or alter AD2 preset files.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(5)
        } label: {
            EmptyView()
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private var logicBlendCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("CREATE A REAL LOGIC PRESET")
                            .sectionLabel()
                        Text("Blend your existing AD2 presets")
                            .font(.title3.weight(.medium))
                        Text("The base supplies the kit and internal AD2 state. The influence contributes every AD2 parameter Logic exposes to the host. New files go to your ‘generated presets’ folder.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.title2)
                        .foregroundStyle(Color.coral)
                }

                if library.logicPresets.isEmpty {
                    Text("No Logic AD2 presets found in ~/Library/Audio/Presets/XLN Audio/Addictive Drums 2.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 16) {
                        presetPicker(title: "BASE", selection: $logicGenerator.basePresetURL)
                        Image(systemName: "arrow.right")
                            .foregroundStyle(Color.coral)
                            .padding(.top, 17)
                        presetPicker(title: "INFLUENCE", selection: $logicGenerator.influencePresetURL)
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text("BLEND").sectionLabel()
                            Spacer()
                            Text("\(Int(logicGenerator.blendAmount * 100))% influence")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $logicGenerator.blendAmount, in: 0...1)
                            .tint(Color.coral)
                        HStack { Text("Keep base"); Spacer(); Text("Use influence") }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(alignment: .bottom, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("NEW LOGIC PRESET NAME").sectionLabel()
                            TextField("Preset name", text: $logicGenerator.outputName)
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 270)
                        }
                        Button {
                            Task {
                                await logicGenerator.createPreset(in: library)
                                if case .success = logicGenerator.status { library.scan() }
                            }
                        } label: {
                            if logicGenerator.isCreating {
                                ProgressView().controlSize(.small)
                            } else {
                                Label("Create .aupreset", systemImage: "square.and.arrow.down")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.coral)
                        .disabled(logicGenerator.isCreating)
                    }

                    switch logicGenerator.status {
                    case .idle: EmptyView()
                    case .working(let message): Label(message, systemImage: "gearshape.2").statusLine(color: .secondary)
                    case .success(let message): Label(message, systemImage: "checkmark.circle.fill").statusLine(color: .green)
                    case .failure(let message): Label(message, systemImage: "exclamationmark.triangle.fill").statusLine(color: .red)
                    }
                }
            }
            .padding(5)
        } label: { EmptyView() }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private func presetPicker(title: String, selection: Binding<URL?>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).sectionLabel()
            Picker(title, selection: selection) {
                ForEach(library.logicPresets) { preset in
                    Text(preset.name).tag(Optional(preset.id))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var briefCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("MAKE A KIT")
                            .sectionLabel()
                        Text("A small, deliberate brief")
                            .font(.title3.weight(.medium))
                    }
                    Spacer()
                    Button {
                        architect.generate(using: library)
                    } label: {
                        Label("Generate direction", systemImage: "sparkles")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.coral)
                    .disabled(!library.isInstalled || library.adPaks.isEmpty)
                }

                Picker("Style", selection: $architect.style) {
                    ForEach(BriefStyle.allCases) { style in
                        Text(style.name).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: architect.style) { architect.generate(using: library) }

                HStack(spacing: 18) {
                    Picker("Song part", selection: $architect.songPart) {
                        ForEach(SongPart.allCases) { part in Text(part.name).tag(part) }
                    }
                    .frame(maxWidth: 210)
                    Picker("Tempo", selection: $architect.tempo) {
                        ForEach([80, 95, 110, 125, 140, 155, 170, 190], id: \.self) { bpm in Text("\(bpm) BPM").tag(bpm) }
                    }
                    .frame(maxWidth: 150)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("CHARACTER").sectionLabel()
                        Picker("Character", selection: $architect.character) {
                            Text("Natural").tag(0)
                            Text("Balanced").tag(1)
                            Text("Produced").tag(2)
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 225)
                    }
                }
            }
            .padding(5)
        } label: { EmptyView() }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private var directionCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("YOUR DIRECTION")
                            .sectionLabel()
                        Text(architect.direction.title)
                            .font(.system(size: 28, weight: .regular, design: .serif))
                        Text(architect.direction.summary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Seed \(architect.seed)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
                }

                Divider()

                HStack(alignment: .top, spacing: 28) {
                    DirectionColumn(title: "START WITH", lines: [architect.direction.source, architect.direction.reference])
                    DirectionColumn(title: "KIT FEEL", lines: architect.direction.kitFeel)
                    DirectionColumn(title: "MIX MOVES", lines: architect.direction.mixMoves)
                }

                HStack {
                    Button("Copy build sheet") {
                        architect.copyBuildSheet()
                    }
                    .buttonStyle(.bordered)
                    Button("New variation") {
                        architect.seed += 1
                        architect.generate(using: library, preserveSeed: true)
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    if architect.didCopy {
                        Label("Copied", systemImage: "checkmark")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding(5)
        } label: { EmptyView() }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private var safetyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.fill").foregroundStyle(Color.coral)
            Text("This version reads only installed-pack and user-preset names. It cannot write an .AD2Preset until XLN publishes or approves a preset-file API or format. The build sheet is designed to be applied and saved in AD2 itself.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(13)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct Stat: View {
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.system(size: 24, weight: .medium, design: .rounded))
            Text(label).sectionLabel()
        }
    }
}

private struct DirectionColumn: View {
    let title: String
    let lines: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).sectionLabel()
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CardGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.content
            .padding(20)
            .background(Color.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 1)
            }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 600
        var position = CGPoint.zero
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if position.x + size.width > width, position.x > 0 {
                position.x = 0
                position.y += rowHeight + spacing
                rowHeight = 0
            }
            position.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: position.y + rowHeight)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var position = bounds.origin
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if position.x + size.width > bounds.maxX, position.x > bounds.minX {
                position.x = bounds.minX
                position.y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: position, proposal: ProposedViewSize(size))
            position.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private extension Text {
    func sectionLabel() -> some View {
        self.font(.system(size: 10, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(Color.coral)
    }
}

private extension Color {
    static let canvas = Color(red: 0.074, green: 0.070, blue: 0.066)
    static let card = Color(red: 0.118, green: 0.112, blue: 0.105)
    static let coral = Color(red: 1.0, green: 0.38, blue: 0.25)
    static let coralLight = Color(red: 1.0, green: 0.60, blue: 0.48)
}

private extension Label where Title == Text, Icon == Image {
    func statusLine(color: Color) -> some View {
        self.font(.caption)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}
