import Foundation

class DownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var downloadProgress: Double = 0.0
    @Published var downloadStatus: String = ""
    
    private let fileManager: CollectorFileManager
    private var completionHandler: ((Result<String, Error>) -> Void)?
    private var destinationBinaryPath: String?
    
    init(fileManager: CollectorFileManager) {
        self.fileManager = fileManager
        super.init()
    }
    
    func downloadAsset(releaseAsset: ReleaseAsset, name: String, version: String, completion: @escaping (Result<(String, String), Error>) -> Void) {
        let urlString = releaseAsset.browserDownloadURL
        guard let url = URL(string: urlString) else {
            let error = NSError(domain: "DownloadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(urlString)"])
            completion(.failure(error))
            return
        }

        downloadStatus = "Downloading \(releaseAsset.name)..."
        
        do {
            let paths = try fileManager.createCollectorDirectory(name: name, version: version)
            self.destinationBinaryPath = paths.binaryPath
            
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            let downloadTask = session.downloadTask(with: url) { [weak self] tempLocalURL, _, error in
                guard let self = self else { return }
                if let error = error {
                    AppLogger.shared.error("Download failed: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.downloadStatus = "Download failed: \(error.localizedDescription)"
                        completion(.failure(error))
                    }
                    return
                }

                guard let tempLocalURL = tempLocalURL else {
                    let error = NSError(domain: "DownloadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No file URL received"])
                    AppLogger.shared.error("No file URL received.")
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
                        completion(.success((binaryPath, paths.configPath)))
                    }
                } catch {
                    AppLogger.shared.error("Error during extraction or moving: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.downloadStatus = "Error during extraction: \(error.localizedDescription)"
                        completion(.failure(error))
                    }
                }
            }

            downloadTask.resume()
        } catch {
            AppLogger.shared.error("Failed to create directory: \(error.localizedDescription)")
            downloadStatus = "Failed to create directory."
            completion(.failure(error))
        }
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
} 