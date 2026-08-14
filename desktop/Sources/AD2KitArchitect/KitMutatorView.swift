import SwiftUI

struct KitMutatorView: View {
    @ObservedObject var mutator: AD2KitMutator

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    permissionCard
                    calibrationCard
                    generateCard
                    statusCard
                    footer
                }
                .padding(30)
                .frame(maxWidth: 1_300, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { mutator.refreshPermission() }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 5) {
                Image(systemName: "drum.fill")
                    .font(.system(size: 27, weight: .medium))
                Text("AdMu").font(.caption2.bold())
            }
            .foregroundStyle(Color.orangeAccent)
            .frame(width: 52)
            VStack(alignment: .leading, spacing: 6) {
                Text("ADDICTIVE MUTATOR")
                    .sectionLabel()
                Text("Mutate the kit. Keep the groove.")
                    .font(.system(size: 31, weight: .medium, design: .rounded))
                Text("Calibrate the visible Addictive Drums Kit page once, then generate new combinations on demand.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                Text("AD2 KIT PAGE MAP · 18 SLOTS")
                    .font(.caption2.monospaced())
                    .foregroundStyle(Color.orangeAccent)
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
                    Text(mutator.accessibilityGranted ? "The mutator can now operate only when you start a run." : "macOS needs permission before this app can click AD2. Approve Addictive Mutator in System Settings → Privacy & Security → Accessibility.")
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
                    VStack(alignment: .trailing, spacing: 5) {
                        Button("Check again") { mutator.refreshPermission() }
                            .buttonStyle(.bordered)
                        Button("Read pointer") { mutator.readPointerLocation() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }
            .padding(5)
        } label: { EmptyView() }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private var calibrationCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 15) {
                Picker("Automation target", selection: $mutator.automationTarget) {
                    ForEach(AutomationTarget.allCases) { target in
                        Text(target.name).tag(target)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(mutator.isBusy)

                if mutator.automationTarget == .standalone {
                    Toggle("Use Logic Pro mapping for any unmapped standalone controls", isOn: $mutator.useLogicCalibrationForStandalone)
                        .toggleStyle(.switch)
                        .tint(Color.orangeAccent)
                        .disabled(mutator.isBusy)
                    Text("Direct standalone captures always win. With this on, your mapped Logic Kit page is scaled to the standalone AD2 window for any remaining controls; test one arrow first.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                sectionHeading(number: "01", title: "Click-to-capture the hover arrows", subtitle: mutator.automationTarget == .standalone ? "Click Capture, then click the exact AD2 control once; that click is both captured and passed to AD2. Capture a row point first, then its Up and/or Down arrow. These points persist across restarts and follow AD2’s window position and proportional size changes." : "Open and focus the exact AD2 plug-in editor in Logic Pro first. Then capture its row, Up, and Down controls exactly as you did in standalone. Logic calibration is saved independently and can optionally be used as the standalone fallback.")

                kitSlotGrid
                HStack {
                    Text("\(mutator.enabledPreparedPieces.count) included & ready · \(mutator.capturedPieces.count) calibrated · \(mutator.capturedTargets.count) arrows captured")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear all locations", role: .destructive) { mutator.clearAll() }
                        .buttonStyle(.link)
                        .font(.caption)
                }
                if let detail = mutator.lastCaptureDetail {
                    Text(detail)
                        .font(.caption.monospaced())
                        .foregroundStyle(.green)
                }
            }
            .padding(5)
        } label: { EmptyView() }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private var kitSlotGrid: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(spacing: 3) {
                ForEach(Array(KitPiece.kitPageRows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 3) {
                        ForEach(row) { piece in
                            PieceCalibrationCard(piece: piece, mutator: mutator)
                                .frame(width: 182, height: 138)
                        }
                    }
                }
            }
            .padding(3)
        }
        .frame(minHeight: 420)
        .background(Color.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 4))
    }

    private var generateCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 15) {
                sectionHeading(number: "02", title: "Mutate the actual kit", subtitle: mutator.automationTarget == .standalone ? "First load any starting preset in standalone AD2. Every enabled, calibrated Kit piece gets a random captured direction and click count; turn a slot off above to leave it unchanged." : "Keep the intended AD2 editor visible and focused in Logic Pro. Only enabled slots use the points calibrated for that exact Logic window; disabled slots are skipped.")
                HStack(alignment: .bottom, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("INCLUDED KIT PIECES").sectionLabel()
                        Text("This run will mutate \(mutator.enabledPreparedPieces.count) enabled, calibrated piece\(mutator.enabledPreparedPieces.count == 1 ? "" : "s").")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Picker("Pointer", selection: $mutator.pointerMode) {
                            ForEach(PointerMode.allCases) { mode in
                                Text(mode.name).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 260)
                        HStack(spacing: 9) {
                            Text("CLICK INTERVAL").sectionLabel()
                            Slider(value: $mutator.clickIntervalMilliseconds, in: 30...600, step: 5)
                            Text(mutator.clickIntervalLabel)
                                .font(.caption.monospaced())
                                .frame(width: 48, alignment: .trailing)
                        }
                        .frame(maxWidth: 260)
                        Text("Saved as your default for future runs. Lower can be faster; raise it if AD2 drops a click.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
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
            Text("Enabled, calibrated pieces run in the same physical order as the AD2 Kit page: Cym 1–6, Tom 1–4, Ride 1–2, Kick, Snare, Hi-hat, Flexi 1–3. Each arrow gets one burst. Your include switches, click interval, and captures persist; recapture only after a real AD2 layout change.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 2)
    }
}

private struct PieceCalibrationCard: View {
    let piece: KitPiece
    @ObservedObject var mutator: AD2KitMutator

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 6) {
                Text(piece.name.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.88))
                Spacer(minLength: 0)
                Image(systemName: mutator.isPieceReady(piece) ? "checkmark.circle.fill" : "circle")
                    .font(.caption2)
                    .foregroundStyle(mutator.isPieceReady(piece) ? Color.orangeAccent : .white.opacity(0.35))
            }
            .frame(maxWidth: .infinity)

            Toggle("Include \(piece.name)", isOn: Binding(
                get: { mutator.isPieceEnabled(piece) },
                set: { mutator.setPieceEnabled(piece, enabled: $0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
            .tint(Color.orangeAccent)
            .help(mutator.isPieceEnabled(piece) ? "\(piece.name) will be randomized when it is calibrated" : "\(piece.name) will be skipped")
            .disabled(mutator.isBusy)
            .frame(maxWidth: .infinity, alignment: .trailing)

            Spacer(minLength: 3)

            HStack(alignment: .center, spacing: 10) {
                rowCapture
                Divider().overlay(Color.line).frame(height: 45)
                VStack(spacing: 5) {
                    arrowCapture(.up)
                    arrowCapture(.down)
                }
            }

            Spacer(minLength: 1)
            Text(pieceStatus)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.48))
        }
        .padding(11)
        .opacity(mutator.isPieceEnabled(piece) ? 1 : 0.48)
        .background(Color.kitSlot, in: RoundedRectangle(cornerRadius: 3))
        .overlay { RoundedRectangle(cornerRadius: 3).stroke(Color.line, lineWidth: 1) }
    }

    private var rowCapture: some View {
        Button {
            mutator.captureHover(for: piece)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: "cursorarrow.rays")
                    .font(.caption)
                Text(mutator.isHoverCaptured(piece) ? "ROW ✓" : "ROW")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.6)
            }
            .foregroundStyle(mutator.isHoverCaptured(piece) ? Color.orangeAccent : .white.opacity(0.8))
            .frame(width: 53, height: 45)
            .background(.white.opacity(mutator.isHoverCaptured(piece) ? 0.10 : 0.045), in: RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
        .help("Capture the point that reveals \(piece.name)'s arrows")
        .disabled(mutator.isBusy)
    }

    private func arrowCapture(_ arrow: KitArrow) -> some View {
        let target = KitMutationTarget(piece: piece, arrow: arrow)
        return HStack(spacing: 4) {
            Button {
                mutator.capture(target)
            } label: {
                Image(systemName: arrow.symbol)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(mutator.isCaptured(target) ? Color.orangeAccent : .white.opacity(0.8))
                    .frame(width: 24, height: 18)
                    .background(.white.opacity(mutator.isCaptured(target) ? 0.10 : 0.045), in: RoundedRectangle(cornerRadius: 2))
            }
            .buttonStyle(.plain)
            .help("Capture \(piece.name)'s \(arrow.name) arrow")
            .disabled(mutator.isBusy)

            Button {
                Task { await mutator.test(target) }
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 20, height: 18)
                    .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 2))
            }
            .buttonStyle(.plain)
            .help("Test \(piece.name)'s \(arrow.name) arrow")
            .disabled(!mutator.isHoverCaptured(piece) || !mutator.isCaptured(target) || mutator.isBusy)
        }
    }

    private var pieceStatus: String {
        let row = mutator.isHoverCaptured(piece) ? "ROW" : "—"
        let up = mutator.isCaptured(KitMutationTarget(piece: piece, arrow: .up)) ? "↑" : "·"
        let down = mutator.isCaptured(KitMutationTarget(piece: piece, arrow: .down)) ? "↓" : "·"
        return "\(row)  \(up) \(down)"
    }
}
