import Foundation

public struct StepProgress: Sendable {
    /// 0...1, or nil when the length is unknown.
    public var fraction: Double?
    public var message: String

    public init(_ message: String, fraction: Double? = nil) {
        self.message = message
        self.fraction = fraction
    }
}

public typealias ProgressHandler = @Sendable (StepProgress) -> Void

/// Input the steps need besides paths.
public struct SetupContext: Sendable {
    public var paths: Paths
    /// Apple's Game Porting Toolkit .dmg, or a D3DMetal folder, picked by the user.
    public var d3dmetalSource: URL?

    public init(paths: Paths = Paths(), d3dmetalSource: URL? = nil) {
        self.paths = paths
        self.d3dmetalSource = d3dmetalSource
    }
}

public struct StepError: LocalizedError {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

/// One item in the setup checklist.
public protocol SetupStep: Sendable {
    var id: String { get }
    var title: String { get }
    var summary: String { get }
    func isDone(_ context: SetupContext) -> Bool
    func run(_ context: SetupContext, progress: @escaping ProgressHandler) async throws
    /// When false, later steps still run if this one fails (they do not need it).
    var blocksLaterSteps: Bool { get }
}

public extension SetupStep {
    var blocksLaterSteps: Bool { true }
}

/// All steps, in the order they must run.
public enum Setup {
    public static let steps: [any SetupStep] = [
        SystemCheck(),
        WineRuntime(),
        D3DMetalImport(),
        DXMTInstall(),
        PrefixSetup(),
        GameImport(),
        BattleNetInstall(),
    ]

    public static func isReady(_ context: SetupContext) -> Bool {
        steps.allSatisfy { $0.isDone(context) }
    }
}

/// Small file helpers shared by the steps.
enum Files {
    static let fm = FileManager.default

    static func exists(_ url: URL) -> Bool { fm.fileExists(atPath: url.path) }

    static func writeMarker(_ url: URL, _ text: String = "") throws {
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data((text + "\n").utf8).write(to: url)
    }

    /// A fresh empty folder under the D4Mac tmp folder.
    static func scratch(_ paths: Paths, _ name: String) throws -> URL {
        let dir = paths.tmp.appendingPathComponent(name, isDirectory: true)
        try? fm.removeItem(at: dir)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func extract(_ archive: URL, to folder: URL, members: [String] = [],
                        excluding: [String] = []) async throws {
        let excludes = excluding.flatMap { ["--exclude", $0] }
        try await Shell.check("/usr/bin/tar", excludes + ["-xf", archive.path, "-C", folder.path] + members)
    }

    /// Copies every item in `source` into `destination`, replacing items with the same name.
    /// Used to put renderer DLLs on top of the Wine engine.
    static func overlay(_ source: URL, onto destination: URL) throws {
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        for item in try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil) {
            let target = destination.appendingPathComponent(item.lastPathComponent)
            if exists(target) { try fm.removeItem(at: target) }
            try fm.copyItem(at: item, to: target)
        }
    }

    /// Replaces `destination` with `source` (moved, not copied).
    static func replace(_ destination: URL, with source: URL) throws {
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if exists(destination) { try fm.removeItem(at: destination) }
        try fm.moveItem(at: source, to: destination)
    }
}
