import Foundation

public struct LaunchOptions: Sendable, Equatable {
    /// Show Apple's Metal performance HUD (FPS, GPU time) in the game.
    public var metalHUD = false
    /// Write detailed Wine logs (slower; use only for debugging).
    public var debugLog = false

    public init(metalHUD: Bool = false, debugLog: Bool = false) {
        self.metalHUD = metalHUD
        self.debugLog = debugLog
    }
}

/// Builds the environment for every Wine command.
public enum WineEnvironment {
    public static func make(
        _ paths: Paths,
        options: LaunchOptions = LaunchOptions(),
        base: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        var env = base
        env["WINEPREFIX"] = paths.prefix.path
        // Fast thread sync using macOS kernel primitives (CrossOver-based Wine).
        env["WINEMSYNC"] = "1"
        // Rosetta 2 tells the game the CPU has AVX. Diablo IV needs it.
        env["ROSETTA_ADVERTISE_AVX"] = "1"
        // Where Wine finds Apple's D3DMetal bridge library.
        env["CX_APPLEGPTK_LIBD3DSHARED_PATH"] = paths.libd3dshared.path
        // Libraries the Wine engine loads at run time.
        env["DYLD_FALLBACK_LIBRARY_PATH"] = [
            paths.frameworks.path,
            paths.frameworks.appendingPathComponent("GStreamer.framework/Libraries").path,
            paths.d3dmetalExternal.path,
            "/usr/lib",
        ].joined(separator: ":")
        env["GST_PLUGIN_SYSTEM_PATH"] = paths.frameworks
            .appendingPathComponent("GStreamer.framework/Libraries/gstreamer-1.0").path
        // Stop Wine from adding Windows shortcuts to the macOS menus and Desktop.
        env["WINEDLLOVERRIDES"] = "winemenubuilder.exe=d"
        env["WINEDEBUG"] = options.debugLog ? "err+all,warn+module,+loaddll,+seh" : "-all"
        if options.metalHUD { env["MTL_HUD_ENABLED"] = "1" }
        return env
    }
}
