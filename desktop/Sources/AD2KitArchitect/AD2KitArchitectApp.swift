import SwiftUI

@main
struct AD2KitArchitectApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 790, idealWidth: 960, minHeight: 700, idealHeight: 790)
        }
        .windowResizability(.contentMinSize)
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            PresetStudioView()
                .tabItem { Label("Logic Preset Studio", systemImage: "square.stack.3d.up.fill") }
            KitMutatorView()
                .tabItem { Label("AD2 Kit Mutator", systemImage: "drum.fill") }
        }
        .tint(Color.coral)
    }
}

struct PresetStudioView: View {
    @StateObject private var library = LogicPresetLibrary()
    @StateObject private var generator = LogicPresetGenerator()

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    libraryCard
                    blendCard
                    randomCard
                    statusCard
                    footer
                }
                .padding(30)
                .frame(maxWidth: 920, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { library.scan() }
        .onChange(of: library.allPresets) { generator.syncPresets(library.allPresets) }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 31, weight: .medium))
                .foregroundStyle(Color.coral)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 6) {
                Text("AD2 PRESET STUDIO")
                    .sectionLabel()
                Text("Make new Logic presets from yours.")
                    .font(.system(size: 34, weight: .regular, design: .serif))
                Text("Blend existing AD2 Logic presets, or generate a fresh multi-preset hybrid every time.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                Button { library.scan() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                    .buttonStyle(.bordered)
                    .tint(Color.coral)
                Button("Open generated folder") { library.openGeneratedFolder() }
                    .buttonStyle(.link)
                    .font(.caption)
            }
        }
    }

    private var libraryCard: some View {
        GroupBox {
            HStack(alignment: .center, spacing: 24) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("LOGIC AD2 PRESETS").sectionLabel()
                    Text("\(library.sourcePresets.count) source preset\(library.sourcePresets.count == 1 ? "" : "s") ready to combine")
                        .font(.title3.weight(.medium))
                    Text(library.logicPresetFolder.path(percentEncoded: false))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Divider().frame(height: 48)
                VStack(alignment: .trailing, spacing: 5) {
                    Text("GENERATED").sectionLabel()
                    Text("\(library.generatedPresets.count)")
                        .font(.system(size: 30, weight: .medium, design: .rounded))
                    Text("kept separate — never overwritten")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(5)
        } label: { EmptyView() }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private var blendCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 17) {
                    sectionHeading(number: "01", title: "Blend mix settings onto a base kit", subtitle: "The base supplies the complete AD2 kit. Add as many influences as you like to blend the AD2 parameters that Logic exposes—levels, pans, pitch, and filters.")
                if library.allPresets.isEmpty {
                    emptyPresetMessage
                } else {
                    HStack(alignment: .bottom, spacing: 15) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("BASE PRESET").sectionLabel()
                            Picker("Base preset", selection: $generator.basePresetURL) {
                                ForEach(library.allPresets) { preset in
                                    Text(preset.displayName).tag(Optional(preset.id))
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(minWidth: 265, alignment: .leading)
                            .onChange(of: generator.basePresetURL) { generator.removeBaseFromInfluences() }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("INFLUENCE STRENGTH").sectionLabel()
                                Spacer()
                                Text("\(Int(generator.blendAmount * 100))%")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $generator.blendAmount, in: 0...1)
                                .tint(Color.coral)
                                .frame(minWidth: 180)
                            HStack { Text("mostly base"); Spacer(); Text("strong blend") }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            Task {
                                await generator.createManualPreset(in: library)
                                if case .success = generator.status { library.scan() }
                            }
                        } label: {
                            creationButtonLabel("Create blend")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.coral)
                        .disabled(generator.isCreating || generator.influenceURLs.isEmpty)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("ADD INFLUENCE PRESETS").sectionLabel()
                            Spacer()
                            Button("Clear") { generator.influenceURLs.removeAll() }
                                .buttonStyle(.link)
                                .font(.caption)
                        }
                        PresetGrid(presets: library.allPresets, selected: generator.influenceURLs, disabled: generator.basePresetURL) { preset in
                            generator.toggleInfluence(preset.id)
                        }
                    }
                }
            }
            .padding(5)
        } label: { EmptyView() }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private var randomCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 17) {
                    sectionHeading(number: "02", title: "Generate an unexpected mix hybrid", subtitle: "Choose a source pool. Each click chooses a fresh base kit, 1–3 other mix influences, and a new blend amount—so it will not repeat the same recipe.")
                if library.allPresets.isEmpty {
                    emptyPresetMessage
                } else {
                    HStack(alignment: .bottom, spacing: 15) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("RANDOM POOL").sectionLabel()
                            Text("\(generator.randomPoolURLs.count) preset\(generator.randomPoolURLs.count == 1 ? "" : "s") available")
                                .font(.callout.weight(.medium))
                        }
                        Spacer()
                        Button("Use all") { generator.randomPoolURLs = Set(library.allPresets.map(\.id)) }
                            .buttonStyle(.bordered)
                        Button {
                            Task {
                                await generator.createRandomPreset(in: library)
                                if case .success = generator.status { library.scan() }
                            }
                        } label: {
                            creationButtonLabel("Generate new hybrid")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.coral)
                        .disabled(generator.isCreating || generator.randomPoolURLs.count < 2)
                    }

                    PresetGrid(presets: library.allPresets, selected: generator.randomPoolURLs) { preset in
                        generator.toggleRandomPool(preset.id)
                    }
                }
            }
            .padding(5)
        } label: { EmptyView() }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    @ViewBuilder
    private var statusCard: some View {
        switch generator.status {
        case .idle:
            if let recipe = generator.lastRecipe { recipeCard(recipe) }
        case .working(let message):
            Label(message, systemImage: "gearshape.2")
                .statusLine(color: .secondary)
                .padding(.horizontal, 12)
        case .success(let message):
            VStack(alignment: .leading, spacing: 10) {
                Label(message, systemImage: "checkmark.circle.fill").statusLine(color: .green)
                if let recipe = generator.lastRecipe { recipeCard(recipe) }
            }
            .padding(14)
            .background(Color.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
        case .failure(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .statusLine(color: .red)
                .padding(14)
                .background(Color.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
        }
    }

    private func recipeCard(_ recipe: BlendRecipe) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LAST RECIPE").sectionLabel()
            Text("Base: \(recipe.baseName)  +  \(recipe.influenceNames.joined(separator: " · "))")
                .font(.caption)
                        Text("\(Int(recipe.strength * 100))% influence strength  •  auto-named \(recipe.outputName).aupreset")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 7))
    }

    private func sectionHeading(number: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number).sectionLabel()
                .frame(width: 18, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title3.weight(.medium))
                Text(subtitle).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var emptyPresetMessage: some View {
        Text("No Logic AD2 presets were found. Add .aupreset files to your Logic AD2 preset folder, then click Refresh.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
    }

    @ViewBuilder
    private func creationButtonLabel(_ title: String) -> some View {
        if generator.isCreating { ProgressView().controlSize(.small) }
        else { Label(title, systemImage: "sparkles") }
    }

    private var footer: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "lock.fill").foregroundStyle(Color.coral)
            Text("Uses Logic’s standard Audio Unit state interface. The AD2 plug-in loads and serializes the final preset; this app only blends parameters that AD2 publishes to Logic. Kit-piece choices stay with the base because this app never reads or alters AD2’s private state block.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 2)
    }
}

private struct PresetGrid: View {
    let presets: [LogicPreset]
    let selected: Set<URL>
    var disabled: URL? = nil
    let toggle: (LogicPreset) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 8)], spacing: 8) {
            ForEach(presets) { preset in
                let isDisabled = preset.id == disabled
                Button {
                    if !isDisabled { toggle(preset) }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: selected.contains(preset.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selected.contains(preset.id) ? Color.coral : .secondary)
                        Text(preset.displayName)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 0)
                    }
                    .font(.caption)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 8)
                    .background(selected.contains(preset.id) ? Color.coral.opacity(0.13) : .white.opacity(0.035), in: RoundedRectangle(cornerRadius: 6))
                    .overlay { RoundedRectangle(cornerRadius: 6).stroke(selected.contains(preset.id) ? Color.coral.opacity(0.5) : .white.opacity(0.08)) }
                    .opacity(isDisabled ? 0.35 : 1)
                }
                .buttonStyle(.plain)
                .help(isDisabled ? "This is the selected base preset" : preset.location)
            }
        }
    }
}
