import Foundation
import os
import Observation

@Observable
class DownloadManager: NSObject, URLSessionDownloadDelegate {
    var downloadProgress: Double = 0.0
    var downloadStatus: String = ""
    
    private var destinationBinaryPath: String?
    private let fileManager: CollectorFileManager
    
    init(fileManager: CollectorFileManager) {
        self.fileManager = fileManager
    }
    
    func downloadAsset(releaseAsset: ReleaseAsset, name: String, version: String, binaryPath: String, configPath: String) async throws -> (String, String) {
        guard let url = URL(string: releaseAsset.browserDownloadURL) else {
            throw NSError(domain: "DownloadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid download URL"])
        }
        
        await MainActor.run {
            downloadStatus = "Downloading \(releaseAsset.name)..."
        }
        self.destinationBinaryPath = binaryPath
        
        return try await withCheckedThrowingContinuation { continuation in
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            let downloadTask = session.downloadTask(with: url) { [weak self] tempLocalURL, _, error in
                guard let self = self else {
                    continuation.resume(throwing: NSError(domain: "DownloadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Download manager deallocated"]))
                    return
                }
                if let error = error {
                    self.handleError(error)
                    Task { @MainActor in
                        self.downloadStatus = "Download failed: \(error.localizedDescription)"
                    }
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let tempLocalURL = tempLocalURL else {
                    let error = NSError(domain: "DownloadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No file URL received"])
                    Logger.app.error("No file URL received.")
                    Task { @MainActor in
                        self.downloadStatus = "No file URL received."
                    }
                    continuation.resume(throwing: error)
                    return
                }
                
                do {
                    Task { @MainActor in
                        self.downloadStatus = "Extracting \(releaseAsset.name)..."
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
                    }
                    continuation.resume(returning: (binaryPath, configPath))
                } catch {
                    self.handleError(error)
                    Task { @MainActor in
                        self.downloadStatus = "Error during extraction: \(error.localizedDescription)"
                    }
                    continuation.resume(throwing: error)
                }
            }
            
            downloadTask.resume()
        }
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        Task { @MainActor in
            self.downloadProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        Task { @MainActor in
            self.downloadStatus = "Download complete. Processing..."
        }
    }
    
    private func handleError(_ error: Error) {
        Logger.app.error("Download failed: \(error.localizedDescription)")
    }
} 
