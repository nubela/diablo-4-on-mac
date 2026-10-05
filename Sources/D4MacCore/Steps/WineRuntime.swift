import Foundation

/// Downloads the Wine engine and the libraries it needs.
public struct WineRuntime: SetupStep {
    public let id = "wine"
    public let title = "Download Wine"
    public let summary = "Open-source Wine 10 engine (MSync, D3DMetal support) and its libraries"

    public init() {}

    public func isDone(_ context: SetupContext) -> Bool {
        let p = context.paths
        return Files.exists(p.marker("wine")) && Files.exists(p.wineBinary)
            && Files.exists(p.frameworks.appendingPathComponent("libfreetype.6.dylib"))
    }

    public func run(_ context: SetupContext, progress: @escaping ProgressHandler) async throws {
        let p = context.paths
        try p.ensureBaseFolders()

        let engineArchive = try await Downloader.fetch(Pins.wine, into: p.downloads) {
            progress(StepProgress("Downloading Wine engine…", fraction: $0 * 0.45))
        }
        let libsArchive = try await Downloader.fetch(Pins.libraries, into: p.downloads) {
            progress(StepProgress("Downloading libraries…", fraction: 0.45 + $0 * 0.4))
        }

        progress(StepProgress("Unpacking Wine…", fraction: 0.88))
        let engineTmp = try Files.scratch(p, "engine")
        try await Files.extract(engineArchive, to: engineTmp)
        try Files.replace(p.wine, with: engineTmp.appendingPathComponent("wswine.bundle"))

        progress(StepProgress("Unpacking libraries…", fraction: 0.94))
        let libsTmp = try Files.scratch(p, "libraries")
        let frameworks = "\(Pins.librariesTopFolder)/Contents/Frameworks"
        // Skip the renderer folder: it holds Apple's D3DMetal, which we take only from
        // the user's own Game Porting Toolkit download.
        try await Files.extract(libsArchive, to: libsTmp, members: [frameworks],
                                excluding: ["\(frameworks)/renderer", "\(frameworks)/renderer/*"])
        try Files.replace(p.frameworks, with: libsTmp.appendingPathComponent(frameworks))

        try? Files.fm.removeItem(at: engineTmp)
        try? Files.fm.removeItem(at: libsTmp)
        try Files.writeMarker(p.marker("wine"), Pins.wine.fileName)
        progress(StepProgress("Wine is installed.", fraction: 1))
    }
}
