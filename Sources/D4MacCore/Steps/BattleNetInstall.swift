import Foundation

/// Runs Blizzard's official Battle.net installer inside the prefix.
public struct BattleNetInstall: SetupStep {
    public let id = "battlenet"
    public let title = "Install Battle.net"
    public let summary = "Blizzard's official installer. Sign in with your own account."

    public init() {}

    public func isDone(_ context: SetupContext) -> Bool {
        Files.exists(context.paths.battleNetLauncher)
    }

    public func run(_ context: SetupContext, progress: @escaping ProgressHandler) async throws {
        let p = context.paths
        guard Files.exists(p.marker("prefix")) else { throw StepError("Create the Windows environment first.") }

        let installer = try await Downloader.fetch(Pins.battleNetInstaller, into: p.downloads,
                                                   fileName: "Battle.net-Setup.exe") {
            progress(StepProgress("Downloading Battle.net installer…", fraction: $0 * 0.3))
        }
        progress(StepProgress("Running the installer. Follow its window; close Battle.net when it opens.",
                              fraction: 0.35))
        let env = WineEnvironment.make(p)
        // The installer starts Battle.net when done and does not exit on its own.
        // Wait until the launcher exists, then stop Wine.
        let process = try Shell.spawn(p.wineBinary.path, [installer.path], environment: env,
                                      logFile: p.logs.appendingPathComponent("battlenet-install.log"))
        while !Files.exists(p.battleNetLauncher) {
            if !process.isRunning, !Files.exists(p.battleNetLauncher) {
                try await Task.sleep(for: .seconds(3))
                if !Files.exists(p.battleNetLauncher) { break }
            }
            try await Task.sleep(for: .seconds(2))
        }
        guard Files.exists(p.battleNetLauncher) else {
            throw StepError("The Battle.net installer closed before it finished. See logs/battlenet-install.log.")
        }
        progress(StepProgress("Battle.net is installed.", fraction: 1))
    }
}
