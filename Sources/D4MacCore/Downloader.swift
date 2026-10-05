import CryptoKit
import Foundation

public struct ChecksumError: LocalizedError {
    public let file: String
    public let expected: String
    public let actual: String
    public var errorDescription: String? {
        "Checksum mismatch for \(file).\nExpected \(expected)\nGot      \(actual)"
    }
}

/// Downloads pinned files into the downloads folder and checks their SHA-256.
public enum Downloader {
    /// Returns the local file. Re-uses an earlier download if its checksum still matches.
    public static func fetch(
        _ pin: Pin,
        into folder: URL,
        fileName: String? = nil,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent(fileName ?? pin.fileName)

        if let expected = pin.sha256, FileManager.default.fileExists(atPath: destination.path),
           (try? sha256(of: destination)) == expected {
            progress(1)
            return destination
        }

        let delegate = ProgressDelegate(progress)
        let (temp, response) = try await URLSession.shared.download(from: pin.url, delegate: delegate)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey:
                "Download of \(pin.name) failed: HTTP \(http.statusCode)"])
        }
        if let expected = pin.sha256 {
            let actual = try sha256(of: temp)
            guard actual == expected else {
                try? FileManager.default.removeItem(at: temp)
                throw ChecksumError(file: pin.fileName, expected: expected, actual: actual)
            }
        }
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temp, to: destination)
        progress(1)
        return destination
    }

    /// SHA-256 of a file, read in 4 MB chunks so large files use little memory.
    public static func sha256(of file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 4 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

private final class ProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let onProgress: @Sendable (Double) -> Void
    init(_ onProgress: @escaping @Sendable (Double) -> Void) { self.onProgress = onProgress }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    // Required by the protocol; the async `download(from:)` API hands us the file.
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {}
}
