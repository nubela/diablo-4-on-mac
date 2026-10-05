import Foundation

/// Starts and stops Battle.net and the game.
public final class Launcher: @unchecked Sendable {
    public let paths: Paths
    public private(set) var currentLog: URL?

    /// Battle.net's product code for Diablo IV.
    static let diabloProductCode = "Fen"

    public init(paths: Paths = Paths()) { self.paths = paths }

    /// Opens Battle.net. With `playDiablo`, Battle.net also starts Diablo IV.
    @discardableResult
    public func start(playDiablo: Bool, options: LaunchOptions = LaunchOptions()) throws -> URL {
        guard Files.exists(paths.battleNetLauncher) else { throw StepError("Battle.net is not installed.") }
        try FileManager.default.createDirectory(at: paths.logs, withIntermediateDirectories: true)
        let log = paths.logs.appendingPathComponent("wine-\(Self.timestamp()).log")
        var args = [paths.battleNetLauncher.path]
        if playDiablo { args.append("--exec=launch \(Self.diabloProductCode)") }
        _ = try Shell.spawn(paths.wineBinary.path, args,
                            environment: WineEnvironment.make(paths, options: options),
                            currentDirectory: paths.battleNetLauncher.deletingLastPathComponent(),
                            logFile: log)
        currentLog = log
        return log
    }

    /// Ends every Windows program in the prefix.
    public func stop() async {
        _ = try? await Shell.run(paths.wineserverBinary.path, ["-k"], environment: WineEnvironment.make(paths))
    }

    /// True while any Windows program in the prefix runs.
    public func isRunning() async -> Bool {
        // Our wineserver runs from our own runtime folder, so its path identifies it.
        let (_, text) = (try? await Shell.output("/bin/ps", ["-Ao", "command"])) ?? (1, "")
        return text.contains(paths.wineserverBinary.path)
    }

    static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }
}
