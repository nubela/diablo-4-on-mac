import D4MacCore
import SwiftUI

struct PlayView: View {
    @Environment(AppModel.self) private var model
    @State private var showLog = false

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 6) {
                Text("DIABLO IV")
                    .font(.system(size: 64, weight: .black, design: .serif))
                    .tracking(6)
                    .foregroundStyle(LinearGradient(colors: [Theme.gold, Theme.accent],
                                                    startPoint: .top, endPoint: .bottom))
                    .shadow(color: Theme.accent.opacity(0.6), radius: 24)
                Text(statusText)
                    .font(.callout.smallCaps()).foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                if model.session == .game {
                    Button("Stop") { Task { await model.stop() } }
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("Play") { model.play() }
                        .buttonStyle(PrimaryButtonStyle())
                        .keyboardShortcut(.defaultAction)
                    Button("Open Battle.net") { model.openBattleNet() }
                        .buttonStyle(.bordered)
                    if model.session == .battleNet {
                        Button("Stop") { Task { await model.stop() } }
                            .buttonStyle(.bordered)
                    }
                }
            }
            .padding(.top, 28)

            HStack(spacing: 20) {
                Toggle("Show FPS (Metal HUD)", isOn: $model.options.metalHUD)
                Toggle("Debug log", isOn: $model.options.debugLog)
            }
            .toggleStyle(.checkbox).font(.caption).padding(.top, 18)
            .disabled(model.session == .game)
            if model.session == .battleNet {
                Text("Changed settings restart Battle.net when you press Play.")
                    .font(.caption2).foregroundStyle(.secondary).padding(.top, 6)
            }

            Spacer()

            HStack {
                Button("Setup") { model.showSetup = true }.buttonStyle(.link)
                Spacer()
                Button(showLog ? "Hide log" : "Show log") { showLog.toggle() }.buttonStyle(.link)
            }
            .padding(.horizontal, 24).padding(.bottom, 12)

            if showLog { LogView(text: model.logText).frame(height: 180) }
        }
    }
}

private extension PlayView {
    var statusText: String {
        switch model.session {
        case .stopped: "Ready to play"
        case .battleNet: "Battle.net is open"
        case .game: "Diablo IV is running"
        }
    }
}

struct LogView: View {
    let text: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(text.isEmpty ? "No log yet. Press Play or Open Battle.net." : text)
                    .font(.caption.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(10)
                    .id("end")
            }
            .background(Color.black.opacity(0.5))
            .onChange(of: text) { proxy.scrollTo("end", anchor: .bottom) }
        }
    }
}
