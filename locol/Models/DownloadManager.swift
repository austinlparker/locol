import Foundation
import os

class DownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var downloadProgress: Double = 0.0
    @Published var downloadStatus: String = ""
    
    private var destinationBinaryPath: String?
    private let fileManager: CollectorFileManager
    
    init(fileManager: CollectorFileManager) {
        self.fileManager = fileManager
    }
    
    func downloadAsset(releaseAsset: ReleaseAsset, name: String, version: String, binaryPath: String, configPath: String, completion: @escaping (Result<(String, String), Error>) -> Void) {
        guard let url = URL(string: releaseAsset.browserDownloadURL) else {
            let error = NSError(domain: "DownloadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid download URL"])
            completion(.failure(error))
            return
        }
        
        downloadStatus = "Downloading \(releaseAsset.name)..."
        self.destinationBinaryPath = binaryPath
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let downloadTask = session.downloadTask(with: url) { [weak self] tempLocalURL, _, error in
            guard let self = self else { return }
            if let error = error {
                self.handleError(error)
                DispatchQueue.main.async {
                    self.downloadStatus = "Download failed: \(error.localizedDescription)"
                    completion(.failure(error))
                }
                return
            }
            
            guard let tempLocalURL = tempLocalURL else {
                let error = NSError(domain: "DownloadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No file URL received"])
                Logger.app.error("No file URL received.")
                DispatchQueue.main.async {
                    self.downloadStatus = "No file URL received."
                    completion(.failure(error))
                }
                return
            }
            
            do {
                DispatchQueue.main.async {
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
                
                DispatchQueue.main.async {
                    self.downloadStatus = "Download and installation complete."
                    completion(.success((binaryPath, configPath)))
                }
            } catch {
                self.handleError(error)
                DispatchQueue.main.async {
                    self.downloadStatus = "Error during extraction: \(error.localizedDescription)"
                    completion(.failure(error))
                }
            }
        }
        
        downloadTask.resume()
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        DispatchQueue.main.async {
            self.downloadProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        DispatchQueue.main.async {
            self.downloadStatus = "Download complete. Processing..."
        }
    }
    
    private func handleError(_ error: Error) {
        Logger.app.error("Download failed: \(error.localizedDescription)")
    }
} 
