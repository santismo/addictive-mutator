import SwiftUI

struct KitMutatorView: View {
    @StateObject private var mutator = AD2KitMutator()

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    permissionCard
                    calibrationCard
                    generateCard
                    saveCard
                    statusCard
                    footer
                }
                .padding(30)
                .frame(maxWidth: 920, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { mutator.refreshPermission() }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "drum.fill")
                .font(.system(size: 31, weight: .medium))
                .foregroundStyle(Color.coral)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 6) {
                Text("AD2 KIT MUTATOR")
                    .sectionLabel()
                Text("Generate actual mixed AD2 kits.")
                    .font(.system(size: 34, weight: .regular, design: .serif))
                Text("This beta drives the visible AD2 Kit page, so Addictive Drums itself creates and saves the real preset.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
    }

    private var permissionCard: some View {
        GroupBox {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: mutator.accessibilityGranted ? "checkmark.shield.fill" : "hand.raised.fill")
                    .font(.title2)
                    .foregroundStyle(mutator.accessibilityGranted ? .green : Color.coral)
                VStack(alignment: .leading, spacing: 4) {
                    Text(mutator.accessibilityGranted ? "Accessibility enabled" : "Allow mouse-and-keyboard control")
                        .font(.headline)
                    Text(mutator.accessibilityGranted ? "The mutator can now operate only when you start a run." : "macOS needs permission before this app can click AD2. Approve AD2 Preset Studio in System Settings → Privacy & Security → Accessibility.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if !mutator.accessibilityGranted {
                    Button("Request access") { mutator.requestAccessibility() }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.coral)
                } else {
                    Button("Check again") { mutator.refreshPermission() }
                        .buttonStyle(.bordered)
                }
            }
            .padding(5)
        } label: { EmptyView() }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private var calibrationCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 15) {
                sectionHeading(number: "01", title: "Calibrate your Kit page", subtitle: "Open standalone Addictive Drums 2, go to Kit, and leave the UI scale unchanged. For each sound you want the generator to vary, click Capture, then move your pointer over that slot’s right-facing next arrow. The app captures its location after four seconds—no click is sent during calibration.")

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 9)], spacing: 9) {
                    ForEach(KitMutationTarget.allCases) { target in
                        HStack(spacing: 8) {
                            Image(systemName: mutator.isCaptured(target) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(mutator.isCaptured(target) ? .green : .secondary)
                            Text(target.name).font(.caption)
                            Spacer(minLength: 0)
                            Button(mutator.isCaptured(target) ? "Recapture" : "Capture") {
                                mutator.capture(target)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            Button(role: .destructive) { mutator.clear(target) } label: { Image(systemName: "xmark") }
                                .buttonStyle(.borderless)
                                .controlSize(.mini)
                                .disabled(!mutator.isCaptured(target))
                        }
                        .padding(8)
                        .background(.white.opacity(mutator.isCaptured(target) ? 0.055 : 0.025), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                HStack {
                    Text("\(mutator.capturedTargets.count) slot\(mutator.capturedTargets.count == 1 ? "" : "s") ready")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear all locations", role: .destructive) { mutator.clearAll() }
                        .buttonStyle(.link)
                        .font(.caption)
                }
            }
            .padding(5)
        } label: { EmptyView() }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private var generateCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 15) {
                sectionHeading(number: "02", title: "Mutate the actual kit", subtitle: "First load any starting preset in standalone AD2. The generator advances a random selection of your captured kit-piece menus; AD2 decides from its own installed content, so no missing ADpaks are introduced.")
                HStack(alignment: .bottom, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("MUTATION DEPTH").sectionLabel()
                            Spacer()
                            Text("\(mutator.mutationDepth) slots")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        Stepper(value: $mutator.mutationDepth, in: 1...max(1, mutator.capturedTargets.count)) {
                            Text(mutator.mutationDepth == 1 ? "One new kit piece" : "Several changed kit pieces")
                                .font(.caption)
                        }
                        .frame(minWidth: 260)
                    }
                    Spacer()
                    Button {
                        Task { await mutator.mutateKit() }
                    } label: {
                        runButtonLabel("Mutate kit")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.coral)
                    .disabled(!mutator.readyToMutate)
                }
                if let recipe = mutator.lastRecipe {
                    Text(recipe.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(10)
                        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(5)
        } label: { EmptyView() }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private var saveCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 15) {
                sectionHeading(number: "03", title: "Save through Addictive Drums", subtitle: "Optional. Capture AD2’s visible Save control, the name field in its Save Preset dialog, and its final Save button. The mutator clicks those controls and types a unique name; AD2 writes the genuine .AD2Preset file into its own User folder.")
                HStack(spacing: 10) {
                    ForEach(SaveTarget.allCases) { target in
                        HStack(spacing: 7) {
                            Image(systemName: mutator.isCaptured(target) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(mutator.isCaptured(target) ? .green : .secondary)
                            Text(target.name).font(.caption)
                            Button(mutator.isCaptured(target) ? "Recapture" : "Capture") { mutator.capture(target) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                        .padding(8)
                        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 6))
                    }
                    Spacer()
                }
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PRESET NAME").sectionLabel()
                        TextField("Generated AD2 kit name", text: $mutator.presetName)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 330)
                    }
                    Button {
                        Task { await mutator.saveCurrentKit() }
                    } label: {
                        runButtonLabel("Save real AD2 preset")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.coral)
                    .disabled(!mutator.readyToSave)
                }
            }
            .padding(5)
        } label: { EmptyView() }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    @ViewBuilder
    private var statusCard: some View {
        switch mutator.status {
        case .idle: EmptyView()
        case .working(let message):
            Label(message, systemImage: "gearshape.2").statusLine(color: .secondary)
                .padding(.horizontal, 12)
        case .success(let message):
            Label(message, systemImage: "checkmark.circle.fill").statusLine(color: .green)
                .padding(14)
                .background(Color.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
        case .failure(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill").statusLine(color: .red)
                .padding(14)
                .background(Color.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
        }
    }

    @ViewBuilder
    private func runButtonLabel(_ title: String) -> some View {
        if mutator.isRunning { ProgressView().controlSize(.small) }
        else { Label(title, systemImage: "sparkles") }
    }

    private func sectionHeading(number: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number).sectionLabel().frame(width: 18, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title3.weight(.medium))
                Text(subtitle).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var footer: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.shield.fill").foregroundStyle(Color.coral)
            Text("Automation is coordinate-based and intentionally opt-in. Keep AD2 on the Kit page at the same UI scale used for calibration, keep the pointer away while a run is active, and confirm the resulting kit by ear before saving.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 2)
    }
}
