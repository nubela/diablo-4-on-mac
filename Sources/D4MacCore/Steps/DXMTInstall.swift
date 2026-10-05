import Foundation

/// Installs DXMT (Direct3D 11 → Metal) for 32-bit programs only, so the Battle.net
/// launcher window can draw. 64-bit programs (the game) keep using D3DMetal.
public struct DXMTInstall: SetupStep {
    public let id = "dxmt"
    public let title = "Download DXMT"
    public let summary = "Open-source Direct3D 11 renderer for the Battle.net launcher"

    public init() {}

    public func isDone(_ context: SetupContext) -> Bool {
        Files.exists(context.paths.marker("dxmt"))
    }

    public func run(_ context: SetupContext, progress: @escaping ProgressHandler) async throws {
        let p = context.paths
        guard Files.exists(p.wineBinary) else { throw StepError("Install Wine first.") }

        let archive = try await Downloader.fetch(Pins.dxmt, into: p.downloads) {
            progress(StepProgress("Downloading DXMT…", fraction: $0 * 0.8))
        }
        progress(StepProgress("Installing DXMT…", fraction: 0.85))
        let tmp = try Files.scratch(p, "dxmt")
        try await Files.extract(archive, to: tmp)
        let top = tmp.appendingPathComponent(Pins.dxmtTopFolder)

        try Files.overlay(top.appendingPathComponent("i386-windows"),
                          onto: p.wineLib.appendingPathComponent("i386-windows"))
        try Files.overlay(top.appendingPathComponent("x86_64-unix"),
                          onto: p.wineLib.appendingPathComponent("x86_64-unix"))

        try? Files.fm.removeItem(at: tmp)
        try Files.writeMarker(p.marker("dxmt"), Pins.dxmt.fileName)
        progress(StepProgress("DXMT is installed.", fraction: 1))
    }
}
