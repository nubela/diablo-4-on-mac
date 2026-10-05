import Foundation

/// Re-uses an existing Diablo IV install (from GameToMac) with an APFS clone.
/// A clone shares disk blocks with the original, so it is fast and uses almost no space.
/// The original files are never changed.
public struct GameImport: SetupStep {
    public let id = "game"
    public let title = "Import Diablo IV"
    public let summary = "Clone an existing install (no extra disk), or skip and download in Battle.net"

    public init() {}

    public func isDone(_ context: SetupContext) -> Bool {
        Files.exists(context.paths.gameExe) || Files.exists(context.paths.marker("game-skipped"))
    }

    public func source() -> URL? {
        Paths.existingGameFolders.first { Files.exists($0.appendingPathComponent("Diablo IV.exe")) }
    }

    public func run(_ context: SetupContext, progress: @escaping ProgressHandler) async throws {
        let p = context.paths
        guard Files.exists(p.marker("prefix")) else { throw StepError("Create the Windows environment first.") }
        guard let source = source() else {
            try Files.writeMarker(p.marker("game-skipped"))
            progress(StepProgress("No existing install found. Install Diablo IV from Battle.net.", fraction: 1))
            return
        }

        let partial = p.programFilesX86.appendingPathComponent("Diablo IV.cloning", isDirectory: true)
        try? Files.fm.removeItem(at: partial)
        try Files.fm.createDirectory(at: p.programFilesX86, withIntermediateDirectories: true)

        progress(StepProgress("Cloning \(source.path)… (a few minutes, no extra disk space)"))
        // -c: APFS clone instead of a byte copy. Fails cleanly on non-APFS volumes.
        try await Shell.check("/bin/cp", ["-cR", source.path, partial.path])
        try Files.replace(p.gameFolder, with: partial)
        progress(StepProgress("Diablo IV is imported. Battle.net will verify it on first launch.", fraction: 1))
    }
}
