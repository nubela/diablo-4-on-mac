import AppKit
import SwiftUI

@main
struct D4MacApp: App {
    @State private var model = AppModel()

    init() {
        // Built with SwiftPM, so tell macOS this is a normal app with a Dock icon.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup("D4Mac") {
            RootView()
                .environment(model)
                .frame(minWidth: 760, minHeight: 560)
                .onAppear { NSApplication.shared.activate(ignoringOtherApps: true) }
        }
        .windowStyle(.hiddenTitleBar)
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if model.showSetup || !model.isReady {
                SetupView()
            } else {
                PlayView()
            }
        }
        .preferredColorScheme(.dark)
    }
}

enum Theme {
    static let accent = Color(red: 0.78, green: 0.16, blue: 0.12)
    static let gold = Color(red: 0.86, green: 0.70, blue: 0.42)
    static let background = LinearGradient(
        colors: [Color(red: 0.10, green: 0.03, blue: 0.03), Color(red: 0.03, green: 0.02, blue: 0.02)],
        startPoint: .top, endPoint: .bottom)
    static let card = Color.white.opacity(0.05)
}
