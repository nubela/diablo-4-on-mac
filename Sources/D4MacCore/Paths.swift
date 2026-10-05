import Foundation

/// Every file location D4Mac uses, in one place.
public struct Paths: Sendable {
    public let root: URL

    public init(root: URL = Paths.defaultRoot) {
        self.root = root
    }

    /// `~/Library/Application Support/D4Mac`, or `$D4MAC_DATA_ROOT` (for testing).
    public static var defaultRoot: URL {
        if let custom = ProcessInfo.processInfo.environment["D4MAC_DATA_ROOT"], !custom.isEmpty {
            return URL(fileURLWithPath: custom, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/D4Mac", isDirectory: true)
    }

    // Runtime (Wine engine + libraries + renderers)
    public var runtime: URL { root.appendingPathComponent("runtime", isDirectory: true) }
    public var wine: URL { runtime.appendingPathComponent("wine", isDirectory: true) }
    public var wineBinary: URL { wine.appendingPathComponent("bin/wine") }
    public var wineserverBinary: URL { wine.appendingPathComponent("bin/wineserver") }
    public var wineLib: URL { wine.appendingPathComponent("lib/wine", isDirectory: true) }
    public var frameworks: URL { runtime.appendingPathComponent("Frameworks", isDirectory: true) }
    /// Must be `lib/external` next to `lib/wine`: D3DMetal's Unix-side symlinks point at
    /// `../../external/libd3dshared.dylib`.
    public var d3dmetalExternal: URL { wine.appendingPathComponent("lib/external", isDirectory: true) }
    public var libd3dshared: URL { d3dmetalExternal.appendingPathComponent("libd3dshared.dylib") }
    /// Spare copy of the imported D3DMetal (`external/` + `wine/`), outside the Wine folder.
    public var d3dmetalBackup: URL { runtime.appendingPathComponent("d3dmetal", isDirectory: true) }

    // Windows side
    public var prefix: URL { root.appendingPathComponent("prefix", isDirectory: true) }
    public var programFilesX86: URL { prefix.appendingPathComponent("drive_c/Program Files (x86)", isDirectory: true) }
    public var gameFolder: URL { programFilesX86.appendingPathComponent("Diablo IV", isDirectory: true) }
    public var gameExe: URL { gameFolder.appendingPathComponent("Diablo IV.exe") }
    public var battleNetLauncher: URL { programFilesX86.appendingPathComponent("Battle.net/Battle.net Launcher.exe") }

    // Housekeeping
    public var downloads: URL { root.appendingPathComponent("downloads", isDirectory: true) }
    public var logs: URL { root.appendingPathComponent("logs", isDirectory: true) }
    public var tmp: URL { root.appendingPathComponent("tmp", isDirectory: true) }

    /// Marker files record which parts are installed. Overlay markers live inside the
    /// Wine folder, so reinstalling Wine also resets the overlays put on top of it.
    public func marker(_ name: String) -> URL {
        switch name {
        case "wine": return runtime.appendingPathComponent(".installed-wine")
        case "prefix": return prefix.appendingPathComponent(".d4mac-ready")
        default: return wine.appendingPathComponent(".installed-\(name)")
        }
    }

    /// Existing Diablo IV installs (Battle.net version) from GameToMac, if any.
    public static var existingGameFolders: [URL] {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Game Library/Games")
        return ["diablo4-battlenet"].map {
            base.appendingPathComponent("\($0)/prefix/drive_c/Program Files (x86)/Diablo IV", isDirectory: true)
        }
    }

    /// D3DMetal folders other apps already put on this Mac (Apple's files, same layout as
    /// the Game Porting Toolkit's `redist/lib`).
    public static var existingD3DMetalFolders: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            "Library/Application Support/Game Library/Games/diablo4-battlenet/deps/Frameworks/renderer/d3dmetal",
            "Library/Application Support/Game Library/Games/diablo4/deps/Frameworks/renderer/d3dmetal",
        ].map { home.appendingPathComponent($0, isDirectory: true) }
    }

    public func ensureBaseFolders() throws {
        for dir in [root, runtime, downloads, logs, tmp] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}
