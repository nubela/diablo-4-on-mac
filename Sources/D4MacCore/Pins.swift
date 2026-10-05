import Foundation

/// A file we download, fixed to one exact version by its SHA-256.
public struct Pin: Sendable {
    public let name: String
    public let url: URL
    public let sha256: String?
    public var fileName: String { url.lastPathComponent }
}

/// Pinned versions of all downloaded parts. Update here to move to a newer version.
public enum Pins {
    /// Sikarugir's open-source Wine 10 engine (LGPL). Has MSync and D3DMetal support.
    /// The Wine 11 builds (11.0, 11.0_1) fail to start any process on macOS 26.5, so stay on 10.
    public static let wine = Pin(
        name: "Wine 10 (Sikarugir engine)",
        url: URL(string: "https://github.com/Sikarugir-App/Engines/releases/download/v1.0/WS12WineSikarugir10.0_8.tar.xz")!,
        sha256: "2a6bcf2a3bf13cddf825599b6bc1e3659cbf71e1282c6d77141a92f6ac8d4c68")

    /// Sikarugir's wrapper template. We only take its open-source libraries
    /// (FreeType, GnuTLS, SDL, GStreamer, ...). Its Apple D3DMetal copy is skipped.
    public static let libraries = Pin(
        name: "Runtime libraries (Sikarugir template)",
        url: URL(string: "https://github.com/Sikarugir-App/Template/releases/download/v1.0/Template-1.0.21.tar.xz")!,
        sha256: "bbe996e4e4375318485953d0c7818b7b4b0a4dc1f13303bcc584f99f7602f78d")
    public static let librariesTopFolder = "Template-1.0.21.app"

    /// DXMT (MIT): Direct3D 11 on Metal. Used for the 32-bit Battle.net launcher UI.
    public static let dxmt = Pin(
        name: "DXMT v0.72",
        url: URL(string: "https://github.com/3Shain/dxmt/releases/download/v0.72/dxmt-v0.72-builtin.tar.gz")!,
        sha256: "661eae8cc12c5ad900ecf3c76e7bacfda519b3eeb5ed5c44b48875b2373e89fe")
    public static let dxmtTopFolder = "v0.72"

    /// Blizzard's official installer. Not pinned: Blizzard updates it often.
    public static let battleNetInstaller = Pin(
        name: "Battle.net installer",
        url: URL(string: "https://www.battle.net/download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP&version=Live")!,
        sha256: nil)
}
