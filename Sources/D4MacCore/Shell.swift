import Foundation

public struct ShellError: LocalizedError {
    public let command: String
    public let status: Int32
    public let tail: String

    public var errorDescription: String? {
        "`\(command)` failed with exit code \(status).\n\(tail)"
    }
}

/// The one place D4Mac starts other programs.
public enum Shell {
    /// Runs a program to the end. Each output line goes to `onLine`.
    /// Returns the exit code.
    @discardableResult
    public static func run(
        _ executable: String,
        _ arguments: [String] = [],
        environment: [String: String]? = nil,
        currentDirectory: URL? = nil,
        onLine: (@Sendable (String) -> Void)? = nil
    ) async throws -> Int32 {
        let process = makeProcess(executable, arguments, environment, currentDirectory)
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        let reader = LineReader(onLine: onLine)
        pipe.fileHandleForReading.readabilityHandler = { handle in
            reader.feed(handle.availableData)
        }
        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { p in
                pipe.fileHandleForReading.readabilityHandler = nil
                reader.feed(pipe.fileHandleForReading.readDataToEndOfFile())
                reader.flush()
                continuation.resume(returning: p.terminationStatus)
            }
            do { try process.run() } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }

    /// Like `run`, but throws when the exit code is not 0.
    public static func check(
        _ executable: String,
        _ arguments: [String] = [],
        environment: [String: String]? = nil,
        currentDirectory: URL? = nil,
        onLine: (@Sendable (String) -> Void)? = nil
    ) async throws {
        let tail = TailBuffer()
        let status = try await run(executable, arguments, environment: environment,
                                   currentDirectory: currentDirectory) { line in
            tail.append(line)
            onLine?(line)
        }
        guard status == 0 else {
            let command = ([executable] + arguments).joined(separator: " ")
            throw ShellError(command: command, status: status, tail: tail.text)
        }
    }

    /// Runs a program and returns its output (stdout + stderr) as text.
    public static func output(_ executable: String, _ arguments: [String] = [],
                              environment: [String: String]? = nil) async throws -> (Int32, String) {
        let all = TailBuffer(limit: .max)
        let status = try await run(executable, arguments, environment: environment) { all.append($0) }
        return (status, all.text)
    }

    /// Starts a long-running program and returns at once. Output is appended to `logFile`.
    public static func spawn(
        _ executable: String,
        _ arguments: [String],
        environment: [String: String],
        currentDirectory: URL? = nil,
        logFile: URL
    ) throws -> Process {
        FileManager.default.createFile(atPath: logFile.path, contents: nil)
        let handle = try FileHandle(forWritingTo: logFile)
        handle.seekToEndOfFile()
        let process = makeProcess(executable, arguments, environment, currentDirectory)
        process.standardOutput = handle
        process.standardError = handle
        process.terminationHandler = { _ in try? handle.close() }
        try process.run()
        return process
    }

    private static func makeProcess(_ executable: String, _ arguments: [String],
                                    _ environment: [String: String]?, _ cwd: URL?) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let environment { process.environment = environment }
        if let cwd { process.currentDirectoryURL = cwd }
        return process
    }
}

/// Splits a byte stream into lines.
private final class LineReader: @unchecked Sendable {
    private var buffer = Data()
    private let lock = NSLock()
    private let onLine: (@Sendable (String) -> Void)?

    init(onLine: (@Sendable (String) -> Void)?) { self.onLine = onLine }

    func feed(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }
        buffer.append(data)
        while let index = buffer.firstIndex(where: { $0 == 0x0A || $0 == 0x0D }) {
            let line = String(decoding: buffer[buffer.startIndex..<index], as: UTF8.self)
            buffer.removeSubrange(buffer.startIndex...index)
            if !line.isEmpty { onLine?(line) }
        }
    }

    func flush() {
        lock.lock(); defer { lock.unlock() }
        if !buffer.isEmpty { onLine?(String(decoding: buffer, as: UTF8.self)) }
        buffer.removeAll()
    }
}

/// Keeps the last lines of output, for error messages.
final class TailBuffer: @unchecked Sendable {
    private var lines: [String] = []
    private let lock = NSLock()
    private let limit: Int

    init(limit: Int = 30) { self.limit = limit }

    func append(_ line: String) {
        lock.lock(); defer { lock.unlock() }
        lines.append(line)
        if lines.count > limit { lines.removeFirst(lines.count - limit) }
    }

    var text: String {
        lock.lock(); defer { lock.unlock() }
        return lines.joined(separator: "\n")
    }
}
