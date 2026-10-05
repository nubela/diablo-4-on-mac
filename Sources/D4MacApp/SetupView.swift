import AppKit
import D4MacCore
import SwiftUI
import UniformTypeIdentifiers

struct SetupView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Set up Diablo IV").font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.gold)
                Text("Each step runs on its own. You only need to act on the D3DMetal and Battle.net steps.")
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(Setup.steps.enumerated()), id: \.offset) { index, step in
                        StepRow(number: index + 1, step: step)
                    }
                }
            }

            HStack {
                if model.isReady {
                    Button("Done") { model.showSetup = false }
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button(model.isWorking ? "Working…" : "Run setup") {
                        Task { await model.runSetup() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.isWorking)
                }
                Spacer()
                Button("Open data folder") { NSWorkspace.shared.open(model.paths.root) }
                    .buttonStyle(.link)
            }
        }
        .padding(28)
    }
}

struct StepRow: View {
    @Environment(AppModel.self) private var model
    let number: Int
    let step: any SetupStep

    private var state: StepState { model.states[step.id] ?? .waiting }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            icon.frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 6) {
                Text("\(number). \(step.title)").font(.headline)
                Text(step.summary).font(.subheadline).foregroundStyle(.secondary)
                detail
            }
            Spacer()
            if case .failed = state {
                Button("Retry") { Task { await model.run(step); model.refresh() } }
                    .disabled(model.isWorking)
            }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder private var icon: some View {
        switch state {
        case .done: Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(.green)
        case .failed: Image(systemName: "exclamationmark.triangle.fill").font(.title2).foregroundStyle(.orange)
        case .running: ProgressView().controlSize(.small)
        case .waiting: Image(systemName: "circle").font(.title2).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var detail: some View {
        switch state {
        case .running(let progress):
            if let fraction = progress.fraction {
                ProgressView(value: fraction).tint(Theme.accent)
            }
            Text(progress.message).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(2)
        case .failed(let message):
            Text(message).font(.caption.monospaced()).foregroundStyle(.orange).textSelection(.enabled)
        default:
            EmptyView()
        }
        if step.id == "d3dmetal", state != .done { GPTKPicker() }
    }
}

/// Shows the user exactly what to download and lets them pick the file.
struct GPTKPicker: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let source = model.d3dmetalSource {
                Label(source.path, systemImage: source.pathExtension == "dmg" ? "opticaldiscdrive" : "folder")
                    .font(.caption).foregroundStyle(Theme.gold).lineLimit(1).truncationMode(.middle)
                Text("Found on this Mac. Run setup to use it, or choose another.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("1. Sign in with a free Apple ID and download “Game Porting Toolkit 3”.\n2. Choose the .dmg here.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("Open Apple download page") { NSWorkspace.shared.open(D3DMetalImport.appleDownloadPage) }
                Button("Choose .dmg or folder…") { choose() }
            }
            .controlSize(.small)
        }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "dmg") ?? .diskImage]
        panel.canChooseDirectories = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        if panel.runModal() == .OK { model.d3dmetalSource = panel.url }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 22).padding(.vertical, 10)
            .background(Theme.accent.opacity(configuration.isPressed ? 0.7 : 1), in: Capsule())
            .foregroundStyle(.white)
    }
}
