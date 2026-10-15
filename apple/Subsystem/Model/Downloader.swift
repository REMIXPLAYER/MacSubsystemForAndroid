// Mac Subsystem for Android - a file download with progress, for the Android image and F-Droid.
// Licensed under the GNU General Public License v3 or later.

import Foundation

final class Downloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private var continuation: CheckedContinuation<URL, Error>?
    private let destination: URL
    private let progress: @Sendable (Double, Int64) -> Void
    private var session: URLSession?

    /// Download `url` to `destination`. `progress` gets (fraction, bytes written).
    static func download(_ url: URL, to destination: URL,
                         progress: @escaping @Sendable (Double, Int64) -> Void) async throws -> URL {
        let downloader = Downloader(destination: destination, progress: progress)
        return try await downloader.run(url)
    }

    private init(destination: URL, progress: @escaping @Sendable (Double, Int64) -> Void) {
        self.destination = destination
        self.progress = progress
    }

    private func run(_ url: URL) async throws -> URL {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
                self.session = session
                session.downloadTask(with: url).resume()
            }
        } onCancel: { [weak self] in
            self?.session?.invalidateAndCancel()
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let fraction = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0
        progress(fraction, totalBytesWritten)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let response = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(response.statusCode) {
            finish(.failure(AndroidImage.ImageError.download("HTTP \(response.statusCode)")))
            return
        }
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
            finish(.success(destination))
        } catch {
            finish(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { finish(.failure(AndroidImage.ImageError.download(error.localizedDescription))) }
    }

    private func finish(_ result: Result<URL, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        session?.finishTasksAndInvalidate()
        continuation.resume(with: result)
    }
}
