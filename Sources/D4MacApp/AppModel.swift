import D4MacCore
import Foundation
import Observation

enum StepState: Equatable {
    case waiting
    case running(StepProgress)
    case done
    case failed(String)

    static func == (a: StepState, b: StepState) -> Bool {
        switch (a, b) {
        case (.waiting, .waiting), (.done, .done): return true
        case let (.running(x), .running(y)): return x.message == y.message && x.fraction == y.fraction
        case let (.failed(x), .failed(y)): return x == y
        default: return false
        }
    }
}

@MainActor @Observable
final class AppModel {
    let paths = Paths()
    let launcher: Launcher
    var states: [String: StepState] = [:]
    var d3dmetalSource: URL? = D3DMetalImport.findSource()
    var isWorking = false
    var options = LaunchOptions()
    var isGameRunning = false
    var logText = ""
    var showSetup = false

    init() {
        launcher = Launcher(paths: paths)
        refresh()
        showSetup = !isReady
        Task { await pollLoop() }
    }

    var context: SetupContext { SetupContext(paths: paths, d3dmetalSource: d3dmetalSource) }
    var isReady: Bool { Setup.steps.allSatisfy { states[$0.id] == .done } }

    func refresh() {
        let ctx = context
        for step in Setup.steps {
            if case .running = states[step.id] { continue }
            if case .failed = states[step.id], !step.isDone(ctx) { continue }
            states[step.id] = step.isDone(ctx) ? .done : .waiting
        }
    }

    /// Runs every step that is not done yet, in order. Stops at the first failure that blocks later steps.
    func runSetup() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false; refresh() }
        for step in Setup.steps where !step.isDone(context) {
            if await !run(step), step.blocksLaterSteps { return }
        }
    }

    @discardableResult
    func run(_ step: any SetupStep) async -> Bool {
        states[step.id] = .running(StepProgress("Starting…"))
        let ctx = context
        do {
            try await step.run(ctx) { progress in
                Task { @MainActor in self.states[step.id] = .running(progress) }
            }
            states[step.id] = .done
            return true
        } catch {
            states[step.id] = .failed(error.localizedDescription)
            return false
        }
    }

    func play() { start(playDiablo: true) }
    func openBattleNet() { start(playDiablo: false) }

    private func start(playDiablo: Bool) {
        do {
            try launcher.start(playDiablo: playDiablo, options: options)
            isGameRunning = true
        } catch {
            logText = "Could not start: \(error.localizedDescription)"
        }
    }

    func stop() async {
        await launcher.stop()
        isGameRunning = false
    }

    /// Updates "running" state and the log tail every 2 seconds.
    private func pollLoop() async {
        while true {
            try? await Task.sleep(for: .seconds(2))
            isGameRunning = await launcher.isRunning()
            if let log = launcher.currentLog, let data = try? Data(contentsOf: log) {
                logText = String(decoding: data.suffix(16_000), as: UTF8.self)
            }
        }
    }
}
