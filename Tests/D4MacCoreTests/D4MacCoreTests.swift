@testable import D4MacCore
import Foundation
import Testing

final class D4MacCoreTests {
    let root: URL
    var paths: Paths { Paths(root: root) }

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("d4mac-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    @Test func pathsStayUnderRoot() {
        for url in [paths.wineBinary, paths.prefix, paths.gameExe, paths.battleNetLauncher, paths.libd3dshared,
                    paths.marker("wine"), paths.marker("dxmt"), paths.marker("prefix")] {
            #expect(url.path.hasPrefix(root.path), Comment(rawValue: url.path))
        }
        #expect(paths.gameExe.path.hasSuffix("drive_c/Program Files (x86)/Diablo IV/Diablo IV.exe"))
    }

    @Test func overlayMarkersLiveInsideWineFolder() {
        // Reinstalling Wine deletes the wine folder, so overlay markers must reset with it.
        #expect(paths.marker("dxmt").path.hasPrefix(paths.wine.path))
        #expect(paths.marker("d3dmetal").path.hasPrefix(paths.wine.path))
        #expect(!paths.marker("wine").path.hasPrefix(paths.wine.path))
    }

    @Test func findSourcePrefersOwnBackup() throws {
        let backup = paths.d3dmetalBackup
        try FileManager.default.createDirectory(at: backup.appendingPathComponent("external"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: backup.appendingPathComponent("wine"), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: backup.appendingPathComponent("external/libd3dshared.dylib").path, contents: Data())
        #expect(D3DMetalImport.findSource(paths) == backup)
        #expect(!backup.path.hasPrefix(paths.wine.path), "backup must survive a Wine reinstall")
    }

    @Test func sessionStateFromProcessList() {
        // Wine shows its wineserver with an unresolved path.
        let server = paths.wine.path + "/lib/wine/../../bin/wineserver"
        let battleNet = #"C:\Program Files (x86)\Battle.net\Battle.net.exe --exec=launch Fen"#
        let game = #"C:\Program Files (x86)\Diablo IV\Diablo IV.exe -nostreamline -sso -launch -uid fenris"#
        #expect(Launcher.parseState(processList: "/sbin/launchd\n\(battleNet)", paths: paths) == .stopped)
        #expect(Launcher.parseState(processList: "\(server)\n\(battleNet)", paths: paths) == .battleNet)
        #expect(Launcher.parseState(processList: "\(server)\n\(battleNet)\n\(game)", paths: paths) == .game)
        // Another app's Wine does not count as ours.
        #expect(Launcher.parseState(processList: "/Applications/Other.app/wine/bin/wineserver\n\(game)", paths: paths) == .stopped)
    }

    @Test func launchOptionsRoundTrip() throws {
        let options = LaunchOptions(metalHUD: true, debugLog: false)
        let decoded = try JSONDecoder().decode(LaunchOptions.self, from: JSONEncoder().encode(options))
        #expect(decoded == options)
        #expect(decoded != LaunchOptions())
    }

    @Test func d3dmetalSymlinksResolve() {
        // wine/lib/wine/x86_64-unix/d3d12.so -> ../../external/libd3dshared.dylib
        let target = paths.wineLib.appendingPathComponent("x86_64-unix")
            .appendingPathComponent("../../external/libd3dshared.dylib").standardizedFileURL
        #expect(target == paths.libd3dshared.standardizedFileURL)
    }

    @Test func environment() {
        let env = WineEnvironment.make(paths, base: ["HOME": "/Users/x"])
        #expect(env["HOME"] == "/Users/x")
        #expect(env["WINEPREFIX"] == paths.prefix.path)
        #expect(env["WINEMSYNC"] == "1")
        #expect(env["ROSETTA_ADVERTISE_AVX"] == "1")
        #expect(env["CX_APPLEGPTK_LIBD3DSHARED_PATH"] == paths.libd3dshared.path)
        #expect(env["WINEDEBUG"] == "-all")
        #expect(env["MTL_HUD_ENABLED"] == nil)
        #expect(env["DYLD_FALLBACK_LIBRARY_PATH"]!.hasPrefix(paths.frameworks.path + ":"))
    }

    @Test func environmentOptions() {
        let env = WineEnvironment.make(paths, options: LaunchOptions(metalHUD: true, debugLog: true), base: [:])
        #expect(env["MTL_HUD_ENABLED"] == "1")
        #expect(env["WINEDEBUG"] != "-all")
    }

    @Test func sha256OfFile() throws {
        let file = root.appendingPathComponent("abc.txt")
        try Data("abc".utf8).write(to: file)
        #expect(try Downloader.sha256(of: file)
                == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func downloaderReusesFileWithMatchingChecksum() async throws {
        let folder = root.appendingPathComponent("downloads")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("abc".utf8).write(to: folder.appendingPathComponent("abc.txt"))
        // The URL is never contacted because the cached file matches.
        let pin = Pin(name: "test", url: URL(string: "https://invalid.example/abc.txt")!,
                      sha256: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        let url = try await Downloader.fetch(pin, into: folder) { _ in }
        #expect(url.lastPathComponent == "abc.txt")
    }

    @Test func stepsReflectMarkers() throws {
        let ctx = SetupContext(paths: paths)
        #expect(!WineRuntime().isDone(ctx))
        #expect(!DXMTInstall().isDone(ctx))
        #expect(!PrefixSetup().isDone(ctx))

        try FileManager.default.createDirectory(at: paths.wineBinary.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: paths.wineBinary.path, contents: Data())
        try FileManager.default.createDirectory(at: paths.frameworks, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: paths.frameworks.appendingPathComponent("libfreetype.6.dylib").path,
                                       contents: Data())
        try Files.writeMarker(paths.marker("wine"))
        try Files.writeMarker(paths.marker("dxmt"))
        try Files.writeMarker(paths.marker("prefix"))

        #expect(WineRuntime().isDone(ctx))
        #expect(DXMTInstall().isDone(ctx))
        #expect(PrefixSetup().isDone(ctx))
        #expect(!D3DMetalImport().isDone(ctx), "needs libd3dshared.dylib too")
    }

    @Test func overlayReplacesFiles() throws {
        let src = root.appendingPathComponent("src"), dst = root.appendingPathComponent("dst")
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dst, withIntermediateDirectories: true)
        try Data("new".utf8).write(to: src.appendingPathComponent("d3d11.dll"))
        try Data("old".utf8).write(to: dst.appendingPathComponent("d3d11.dll"))
        try Data("keep".utf8).write(to: dst.appendingPathComponent("kernel32.dll"))
        try Files.overlay(src, onto: dst)
        #expect(try String(contentsOf: dst.appendingPathComponent("d3d11.dll"), encoding: .utf8) == "new")
        #expect(try String(contentsOf: dst.appendingPathComponent("kernel32.dll"), encoding: .utf8) == "keep")
    }

    @Test func findRedistInNestedFolders() throws {
        let lib = root.appendingPathComponent("vol/Toolkit/redist/lib")
        try FileManager.default.createDirectory(at: lib.appendingPathComponent("external"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: lib.appendingPathComponent("wine"), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: lib.appendingPathComponent("external/libd3dshared.dylib").path, contents: Data())
        #expect(D3DMetalImport.findRedist(in: root.appendingPathComponent("vol"))?.standardizedFileURL
                == lib.standardizedFileURL)
    }

    @Test func shellCheckReportsFailure() async throws {
        do {
            try await Shell.check("/bin/sh", ["-c", "echo boom; exit 3"])
            Issue.record("expected an error")
        } catch let error as ShellError {
            #expect(error.status == 3)
            #expect(error.tail.contains("boom"))
        }
    }
}
