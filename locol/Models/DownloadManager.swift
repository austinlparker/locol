import Foundation
import os

@Observable
final class DownloadManager: NSObject, URLSessionDownloadDelegate {
    var downloadProgress: Double = 0.0
    var downloadStatus: String = ""
    
    private var destinationBinaryPath: String?
    private let fileManager: CollectorFileManager
    
    private let progressContinuation: AsyncStream<Double>.Continuation
    private let statusContinuation: AsyncStream<String>.Continuation
    
    let progressPublisher: AsyncStream<Double>
    let statusPublisher: AsyncStream<String>
    
    init(fileManager: CollectorFileManager) {
        self.fileManager = fileManager
        
        // Create async streams for progress and status
        var progressContinuation: AsyncStream<Double>.Continuation!
        var statusContinuation: AsyncStream<String>.Continuation!
        
        self.progressPublisher = AsyncStream { continuation in
            progressContinuation = continuation
        }
        self.statusPublisher = AsyncStream { continuation in
            statusContinuation = continuation
        }
        
        self.progressContinuation = progressContinuation
        self.statusContinuation = statusContinuation
        
        super.init()
    }
    
    func downloadAsset(releaseAsset: ReleaseAsset, name: String, version: String, binaryPath: String, configPath: String, completion: @escaping (Result<(String, String), Error>) -> Void) {
        guard let url = URL(string: releaseAsset.browserDownloadURL) else {
            let error = NSError(domain: "DownloadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid download URL"])
            completion(.failure(error))
            return
        }
        
        downloadStatus = "Downloading \(releaseAsset.name)..."
        statusContinuation.yield("Downloading \(releaseAsset.name)...")
        self.destinationBinaryPath = binaryPath
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let downloadTask = session.downloadTask(with: url) { [weak self] tempLocalURL, _, error in
            guard let self = self else { return }
            if let error = error {
                self.handleError(error)
                Task { @MainActor in
                    self.downloadStatus = "Download failed: \(error.localizedDescription)"
                    self.statusContinuation.yield("Download failed: \(error.localizedDescription)")
                    completion(.failure(error))
                }
                return
            }
            
            guard let tempLocalURL = tempLocalURL else {
                let error = NSError(domain: "DownloadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No file URL received"])
                Logger.app.error("No file URL received.")
                Task { @MainActor in
                    self.downloadStatus = "No file URL received."
                    self.statusContinuation.yield("No file URL received.")
                    completion(.failure(error))
                }
                return
            }
            
            do {
                Task { @MainActor in
                    self.downloadStatus = "Extracting \(releaseAsset.name)..."
                    self.statusContinuation.yield("Extracting \(releaseAsset.name)...")
                }
                
                guard let destinationPath = self.destinationBinaryPath else {
                    throw NSError(domain: "DownloadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Destination path not set"])
                }
                
                let binaryPath = try self.fileManager.handleDownloadedAsset(
                    tempLocalURL: tempLocalURL,
                    assetName: releaseAsset.name,
                    destinationPath: destinationPath
                )
                
                Task { @MainActor in
                    self.downloadStatus = "Download and installation complete."
                    self.statusContinuation.yield("Download and installation complete.")
                    completion(.success((binaryPath, configPath)))
                }
            } catch {
                self.handleError(error)
                Task { @MainActor in
                    self.downloadStatus = "Error during extraction: \(error.localizedDescription)"
                    self.statusContinuation.yield("Error during extraction: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
        
        downloadTask.resume()
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        Task { @MainActor in
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            self.downloadProgress = progress
            self.progressContinuation.yield(progress)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        Task { @MainActor in
            self.downloadStatus = "Download complete. Processing..."
            self.statusContinuation.yield("Download complete. Processing...")
        }
    }
    
    private func handleError(_ error: Error) {
        Logger.app.error("Download failed: \(error.localizedDescription)")
    }
    
    deinit {
        progressContinuation.finish()
        statusContinuation.finish()
    }
} 
