import Foundation

/// Copies Apple's D3DMetal (DirectX 12 → Metal) into the Wine engine. The source is either
/// Apple's Game Porting Toolkit .dmg or a D3DMetal folder already on this Mac.
/// D3DMetal is Apple's code: D4Mac never downloads or ships it.
public struct D3DMetalImport: SetupStep {
    public let id = "d3dmetal"
    public let title = "Import D3DMetal"
    public let summary = "Apple's DirectX 12 → Metal layer, from a copy on this Mac or the Game Porting Toolkit"

    public static let appleDownloadPage =
        URL(string: "https://developer.apple.com/download/all/?q=game%20porting%20toolkit")!

    /// Only the game needs D3DMetal; Battle.net can be set up without it.
    public let blocksLaterSteps = false

    public init() {}

    public func isDone(_ context: SetupContext) -> Bool {
        Files.exists(context.paths.marker("d3dmetal")) && Files.exists(context.paths.libd3dshared)
    }

    public func run(_ context: SetupContext, progress: @escaping ProgressHandler) async throws {
        let p = context.paths
        guard Files.exists(p.wineBinary) else { throw StepError("Install Wine first.") }
        guard let source = context.d3dmetalSource ?? Self.findSource(p) else {
            throw StepError("Choose the Game Porting Toolkit .dmg you downloaded from Apple.")
        }

        var mounts: [URL] = []
        defer { for m in mounts.reversed() { Self.detachSync(m) } }

        if source.pathExtension != "dmg" {
            guard let redist = Self.findRedist(in: source) ?? (Self.isRedist(source) ? source : nil) else {
                throw StepError("No D3DMetal files (external/libd3dshared.dylib) in \(source.path).")
            }
            try install(redist, from: source, paths: p, progress: progress)
            return
        }
        let image = source

        progress(StepProgress("Opening \(image.lastPathComponent)…", fraction: 0.1))
        let outer = try await Self.attach(image, paths: p)
        mounts.append(outer)

        // Recent toolkits keep the files in a second .dmg inside the first one.
        var redist = Self.findRedist(in: outer)
        if redist == nil {
            for inner in Self.find(in: outer, maxDepth: 2, where: { $0.pathExtension == "dmg" }) {
                progress(StepProgress("Opening \(inner.lastPathComponent)…", fraction: 0.3))
                let mount = try await Self.attach(inner, paths: p)
                mounts.append(mount)
                redist = Self.findRedist(in: mount)
                if redist != nil { break }
            }
        }
        guard let redist else {
            throw StepError("No D3DMetal files (redist/lib) found in \(image.lastPathComponent).")
        }
        try install(redist, from: image, paths: p, progress: progress)
    }

    /// Copies a D3DMetal folder (`external/` + `wine/`) into the engine's `lib/` folder.
    /// The layout must match exactly: `wine/x86_64-unix/*.so` are relative symlinks
    /// to `../../external/libd3dshared.dylib`.
    private func install(_ redist: URL, from source: URL, paths p: Paths,
                         progress: ProgressHandler) throws {
        progress(StepProgress("Copying D3DMetal from \(source.lastPathComponent)…", fraction: 0.6))
        try Files.overlay(redist.appendingPathComponent("external"), onto: p.d3dmetalExternal)
        for arch in ["x86_64-windows", "x86_64-unix"] {
            let folder = redist.appendingPathComponent("wine/\(arch)")
            if Files.exists(folder) {
                try Files.overlay(folder, onto: p.wineLib.appendingPathComponent(arch))
            }
        }
        guard Files.exists(p.libd3dshared) else { throw StepError("libd3dshared.dylib is missing in \(source.path).") }
        // Keep our own spare copy, so reinstalling Wine never needs the original source again.
        if redist.standardizedFileURL != p.d3dmetalBackup.standardizedFileURL {
            try? Files.fm.removeItem(at: p.d3dmetalBackup)
            try Files.fm.createDirectory(at: p.d3dmetalBackup.deletingLastPathComponent(),
                                         withIntermediateDirectories: true)
            try Files.fm.copyItem(at: redist, to: p.d3dmetalBackup)
        }
        try Files.writeMarker(p.marker("d3dmetal"), source.path)
        progress(StepProgress("D3DMetal is installed.", fraction: 1))
    }

    /// Best source found on this Mac: D4Mac's own spare copy, else a GPTK .dmg in ~/Downloads,
    /// else a D3DMetal folder another app put on this Mac.
    public static func findSource(_ paths: Paths) -> URL? {
        if isRedist(paths.d3dmetalBackup) { return paths.d3dmetalBackup }
        return findImageInDownloads() ?? Paths.existingD3DMetalFolders.first(where: isRedist)
    }

    /// The newest Game Porting Toolkit .dmg in ~/Downloads, if any.
    public static func findImageInDownloads() -> URL? {
        let downloads = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        let items = (try? FileManager.default.contentsOfDirectory(
            at: downloads, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return items
            .filter { $0.pathExtension == "dmg" && $0.lastPathComponent.lowercased().contains("porting") }
            .max { modified($0) < modified($1) }
    }

    private static func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    /// A folder with Apple's D3DMetal layout: `external/libd3dshared.dylib` and `wine/`.
    static func isRedist(_ folder: URL) -> Bool {
        Files.exists(folder.appendingPathComponent("external/libd3dshared.dylib"))
            && Files.exists(folder.appendingPathComponent("wine"))
    }

    static func findRedist(in volume: URL) -> URL? {
        find(in: volume, maxDepth: 3, where: isRedist).first
    }

    static func find(in root: URL, maxDepth: Int, where match: (URL) -> Bool) -> [URL] {
        guard maxDepth >= 0,
              let items = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        else { return [] }
        var found = items.filter(match)
        for item in items where item.hasDirectoryPath || (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
            found += find(in: item, maxDepth: maxDepth - 1, where: match)
        }
        return found
    }

    static func attach(_ image: URL, paths: Paths) async throws -> URL {
        let mount = paths.tmp.appendingPathComponent("gptk-\(UUID().uuidString.prefix(8))")
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        try await Shell.check("/usr/bin/hdiutil", ["attach", "-nobrowse", "-readonly", "-noverify",
                                                   "-mountpoint", mount.path, image.path])
        return mount
    }

    static func detachSync(_ mount: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["detach", "-force", mount.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        try? FileManager.default.removeItem(at: mount)
    }
}
