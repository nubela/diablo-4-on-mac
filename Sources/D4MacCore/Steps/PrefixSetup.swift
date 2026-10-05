import Foundation

/// Creates the Windows environment ("prefix") that Battle.net and the game run in.
public struct PrefixSetup: SetupStep {
    public let id = "prefix"
    public let title = "Create Windows environment"
    public let summary = "A fresh Wine prefix set to Windows 10"

    public init() {}

    public func isDone(_ context: SetupContext) -> Bool {
        Files.exists(context.paths.marker("prefix"))
    }

    public func run(_ context: SetupContext, progress: @escaping ProgressHandler) async throws {
        let p = context.paths
        guard Files.exists(p.wineBinary) else { throw StepError("Install Wine first.") }
        let env = WineEnvironment.make(p)
        let log: @Sendable (String) -> Void = { progress(StepProgress($0)) }

        progress(StepProgress("Creating Windows environment (first run takes a minute)…", fraction: 0.1))
        try await Shell.check(p.wineBinary.path, ["wineboot", "--init"], environment: env, onLine: log)

        progress(StepProgress("Setting Windows version to Windows 10…", fraction: 0.7))
        try await Shell.check(p.wineBinary.path, ["winecfg", "-v", "win10"], environment: env, onLine: log)

        try await Shell.check(p.wineserverBinary.path, ["-w"], environment: env)
        try Files.writeMarker(p.marker("prefix"))
        progress(StepProgress("Windows environment is ready.", fraction: 1))
    }
}
