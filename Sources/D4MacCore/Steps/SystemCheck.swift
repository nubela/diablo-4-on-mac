import Foundation

/// Apple Silicon, macOS 14+, Rosetta 2, and enough free disk space.
public struct SystemCheck: SetupStep {
    public let id = "system"
    public let title = "Check this Mac"
    public let summary = "Apple Silicon, macOS 14 or later, Rosetta 2, 20 GB free"

    static let minimumFreeBytes: Int64 = 20 << 30

    public init() {}

    public func isDone(_ context: SetupContext) -> Bool { problems(context).isEmpty }

    public func run(_ context: SetupContext, progress: @escaping ProgressHandler) async throws {
        if !Self.hasRosetta() {
            progress(StepProgress("Installing Rosetta 2…"))
            try await Shell.check("/usr/sbin/softwareupdate", ["--install-rosetta", "--agree-to-license"]) {
                progress(StepProgress($0))
            }
        }
        let found = problems(context)
        guard found.isEmpty else { throw StepError(found.joined(separator: "\n")) }
        progress(StepProgress("This Mac is ready.", fraction: 1))
    }

    func problems(_ context: SetupContext) -> [String] {
        var found: [String] = []
        if !Self.isAppleSilicon() { found.append("This Mac does not have an Apple Silicon chip.") }
        if ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 14 {
            found.append("macOS 14 Sonoma or later is required.")
        }
        if !Self.hasRosetta() { found.append("Rosetta 2 is not installed.") }
        let free = Self.freeBytes(near: context.paths.root)
        if free < Self.minimumFreeBytes {
            found.append("Only \(free >> 30) GB free disk space; 20 GB or more is needed.")
        }
        return found
    }

    static func isAppleSilicon() -> Bool {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname("hw.optional.arm64", &value, &size, nil, 0) == 0 && value == 1
    }

    /// Rosetta is installed when this file exists.
    static func hasRosetta() -> Bool {
        Files.exists(URL(fileURLWithPath: "/Library/Apple/usr/libexec/oah/libRosettaRuntime"))
    }

    static func freeBytes(near url: URL) -> Int64 {
        var probe = url
        while !Files.exists(probe), probe.path != "/" { probe.deleteLastPathComponent() }
        let values = try? probe.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage ?? 0
    }
}
