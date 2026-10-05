import Foundation

/// What is running in D4Mac's Wine prefix.
public enum SessionState: Equatable, Sendable {
    case stopped
    /// Battle.net (and Wine) run, the game does not.
    case battleNet
    case game
}

/// Starts and stops Battle.net and the game.
public final class Launcher: @unchecked Sendable {
    public let paths: Paths
    public private(set) var currentLog: URL?

    /// Battle.net's product code for Diablo IV.
    static let diabloProductCode = "Fen"

    public init(paths: Paths = Paths()) { self.paths = paths }

    /// Settings Battle.net was last started with. The game inherits Battle.net's
    /// environment, so new settings only apply after Battle.net restarts.
    var sessionFile: URL { paths.root.appendingPathComponent("session.json") }

    /// Opens Battle.net. With `playDiablo`, Battle.net also starts Diablo IV.
    /// If Battle.net already runs with other settings, it is restarted first.
    @discardableResult
    public func start(playDiablo: Bool, options: LaunchOptions = LaunchOptions()) async throws -> URL {
        guard Files.exists(paths.battleNetLauncher) else { throw StepError("Battle.net is not installed.") }
        var startsBattleNet = true
        switch await state() {
        case .game:
            throw StepError("Diablo IV is already running. Stop it first to change settings.")
        case .battleNet where runningOptions() != options:
            await stop()
        case .battleNet:
            startsBattleNet = false  // same settings: just ask the open Battle.net
        case .stopped:
            break
        }

        try FileManager.default.createDirectory(at: paths.logs, withIntermediateDirectories: true)
        let log = paths.logs.appendingPathComponent("wine-\(Self.timestamp()).log")
        var args = [paths.battleNetLauncher.path]
        if playDiablo { args.append("--exec=launch \(Self.diabloProductCode)") }
        _ = try Shell.spawn(paths.wineBinary.path, args,
                            environment: WineEnvironment.make(paths, options: options),
                            currentDirectory: paths.battleNetLauncher.deletingLastPathComponent(),
                            logFile: log)
        if startsBattleNet {
            try JSONEncoder().encode(options).write(to: sessionFile)
        }
        currentLog = log
        return log
    }

    /// Ends every Windows program in the prefix and waits until Wine has exited.
    public func stop() async {
        _ = try? await Shell.run(paths.wineserverBinary.path, ["-k"], environment: WineEnvironment.make(paths))
        for _ in 0..<50 where await state() != .stopped {
            try? await Task.sleep(for: .milliseconds(200))
        }
        try? FileManager.default.removeItem(at: sessionFile)
    }

    public func state() async -> SessionState {
        let (_, text) = (try? await Shell.output("/bin/ps", ["-Ao", "command"])) ?? (1, "")
        return Self.parseState(processList: text, paths: paths)
    }

    /// Reads `ps -Ao command` output. Our wineserver runs from our runtime folder; Wine
    /// shows it as `…/wine/lib/wine/../../bin/wineserver`, so compare resolved paths.
    static func parseState(processList: String, paths: Paths) -> SessionState {
        let wineserver = paths.wineserverBinary.standardizedFileURL.path
        let lines = processList.split(separator: "\n").map(String.init)
        let ours = lines.contains { line in
            line.hasPrefix("/") && URL(fileURLWithPath: line.trimmingCharacters(in: .whitespaces))
                .standardizedFileURL.path == wineserver
        }
        guard ours else { return .stopped }
        let gameRuns = lines.contains { $0.contains("\\Diablo IV\\Diablo IV.exe") || $0.hasPrefix("Diablo IV.exe") }
        return gameRuns ? .game : .battleNet
    }

    func runningOptions() -> LaunchOptions? {
        guard let data = try? Data(contentsOf: sessionFile) else { return nil }
        return try? JSONDecoder().decode(LaunchOptions.self, from: data)
    }

    static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }
}
