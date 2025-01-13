//
//  CollectorManager.swift
//  locol
//
//  Created by Austin Parker on 1/12/25.
//

import Foundation

struct Release: Decodable, Hashable, Encodable {
    let url: String
    let htmlURL: String
    let assetsURL: String
    let tagName: String
    let name: String?
    let publishedAt: String?
    let author: SimpleUser?
    let assets: [ReleaseAsset]?

    enum CodingKeys: String, CodingKey {
        case url
        case htmlURL = "html_url"
        case assetsURL = "assets_url"
        case tagName = "tag_name"
        case name
        case publishedAt = "published_at"
        case author
        case assets
    }
}

struct SimpleUser: Decodable, Hashable, Encodable {
    let login: String
    let id: Int
    let nodeID: String
    let avatarURL: String
    let url: String
    let htmlURL: String

    enum CodingKeys: String, CodingKey {
        case login
        case id
        case nodeID = "node_id"
        case avatarURL = "avatar_url"
        case url
        case htmlURL = "html_url"
    }
}

struct ReleaseAsset: Decodable, Hashable, Encodable {
    let url: String
    let id: Int
    let name: String
    let contentType: String
    let size: Int
    let downloadCount: Int
    let browserDownloadURL: String

    enum CodingKeys: String, CodingKey {
        case url
        case id
        case name
        case contentType = "content_type"
        case size
        case downloadCount = "download_count"
        case browserDownloadURL = "browser_download_url"
    }
}

class CollectorManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var isRunning: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadStatus: String = ""
    @Published var availableReleases: [Release] = []
    @Published var commandLineFlags: [String: String] = UserDefaults.standard.dictionary(forKey: "CommandLineFlags") as? [String: String] ?? [:]
    
    let collectorPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".locol/bin/")
    let configPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".locol/config/")
    
    private var process: Process?
    private let cacheKeyReleases = "CachedReleases"
    private let cacheKeyTimestamp = "CachedReleasesTimestamp"

    func saveCommandLineFlags(for version: String) {
            UserDefaults.standard.set(commandLineFlags, forKey: "CommandLineFlags")
        AppLogger.shared.info("Saved command line flags for version \(version): \(self.commandLineFlags[version] ?? "")")
        }
    
    func downloadAsset(releaseAsset: ReleaseAsset, versionTag: String) {
        let urlString = releaseAsset.browserDownloadURL
        guard let url = URL(string: urlString) else {
            AppLogger.shared.error("Invalid URL: \(urlString)")
            downloadStatus = "Invalid URL"
            return
        }

        downloadStatus = "Downloading \(releaseAsset.name)..."

        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFileURL = tempDirectory.appendingPathComponent(releaseAsset.name)
        let versionedCollectorPath = collectorPath.appendingPathComponent(versionTag) 
        do {
            if !FileManager.default.fileExists(atPath: versionedCollectorPath.path) {
                try FileManager.default.createDirectory(at: versionedCollectorPath, withIntermediateDirectories: true)
                AppLogger.shared.debug("Created directory at \(versionedCollectorPath.path)")
            }
        } catch {
            AppLogger.shared.error("Failed to create directory: \(error.localizedDescription)")
            downloadStatus = "Failed to create version directory."
            return
        }

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let downloadTask = session.downloadTask(with: url) { [weak self] tempLocalURL, _, error in
            guard let self = self else { return }
            if let error = error {
                AppLogger.shared.error("Download failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.downloadStatus = "Download failed: \(error.localizedDescription)"
                }
                return
            }

            guard let tempLocalURL = tempLocalURL else {
                AppLogger.shared.error("No file URL received.")
                DispatchQueue.main.async {
                    self.downloadStatus = "No file URL received."
                }
                return
            }

            do {
                DispatchQueue.main.async {
                    self.downloadStatus = "Extracting \(releaseAsset.name)..."
                }
                let extractedPath = try self.extractTarGz(at: tempLocalURL)

                let binaryName = releaseAsset.name.components(separatedBy: "_").first ?? ""
                if binaryName.isEmpty {
                    throw NSError(
                        domain: "ExtractionError",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Binary name not found in extracted folder."]
                        )
                }
                let binaryPath = extractedPath.appendingPathComponent(binaryName)

                guard FileManager.default.fileExists(atPath: binaryPath.path) else {
                    throw NSError(
                        domain: "ExtractionError",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Binary \(binaryName) not found in extracted folder."]
                    )
                }

                let destinationBinaryPath = versionedCollectorPath.appendingPathComponent(binaryName)
                if FileManager.default.fileExists(atPath: destinationBinaryPath.path) {
                    try FileManager.default.removeItem(at: destinationBinaryPath)
                }
                try FileManager.default.moveItem(at: binaryPath, to: destinationBinaryPath)

                DispatchQueue.main.async {
                    self.downloadStatus = "Download and installation complete for version \(versionTag)."
                }
            } catch {
                AppLogger.shared.error("Error during extraction or moving: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.downloadStatus = "Error during extraction: \(error.localizedDescription)"
                }
            }
        }

        downloadTask.resume()
    }

    func extractTarGz(at fileURL: URL) throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let outputDirectory = tempDirectory.appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xzvf", fileURL.path, "-C", outputDirectory.path]

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw NSError(domain: "ExtractorError", code: Int(process.terminationStatus), userInfo: nil)
        }

        return outputDirectory
    }

    func getCollectorReleases(repo: String, forceRefresh: Bool = false, completion: @escaping () -> Void = {}) {
        
        if !forceRefresh, let cachedReleases = getCachedReleases() {
            DispatchQueue.main.async {
                self.availableReleases = cachedReleases
                AppLogger.shared.info("Loaded releases from cache.")
                completion()
            }
            return
        }
        
        let urlString = "https://api.github.com/repos/open-telemetry/\(repo)/releases"
        guard let url = URL(string: urlString) else {
            AppLogger.shared.error("Invalid URL: \(urlString)")
            completion()
            return
        }

        AppLogger.shared.debug("Fetching releases from \(urlString)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                AppLogger.shared.error("Error fetching releases: \(error.localizedDescription)")
                completion()
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                AppLogger.shared.error("Invalid response received.")
                completion()
                return
            }

            if httpResponse.statusCode == 403, let resetTime = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Reset") {
                let resetTimestamp = Double(resetTime) ?? 0
                let resetDate = Date(timeIntervalSince1970: resetTimestamp)
                AppLogger.shared.error("Rate limited. Retry after \(resetDate).")
                completion()
                return
            }

            guard let data = data else {
                AppLogger.shared.error("No data received")
                completion()
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let releases = try decoder.decode([Release].self, from: data)

                let filteredReleases = self.filterReleases(releases)
                AppLogger.shared.log("Filtered releases count: \(filteredReleases.count)")
                self.cacheReleases(filteredReleases)

                DispatchQueue.main.async {
                    self.availableReleases = filteredReleases
                    completion()
                }
            } catch {
                AppLogger.shared.error("Failed to decode releases: \(error.localizedDescription)")
                completion()
            }
        }

        task.resume()
    }
    
    private func filterReleases(_ releases: [Release]) -> [Release] {
            return releases.compactMap { release -> Release? in
                guard release.tagName.range(of: #"^v\d+\.\d+\.\d+$"#, options: .regularExpression) != nil else {
                    return nil
                }

                let darwinBinaryAssets = release.assets?.filter { $0.name.contains("darwin") && $0.name.hasSuffix(".tar.gz") } ?? []
                if darwinBinaryAssets.isEmpty {
                    return nil
                }

                return Release(
                    url: release.url,
                    htmlURL: release.htmlURL,
                    assetsURL: release.assetsURL,
                    tagName: release.tagName,
                    name: release.name,
                    publishedAt: release.publishedAt,
                    author: release.author,
                    assets: darwinBinaryAssets
                )
            }
        }
    
    private func cacheReleases(_ releases: [Release]) {
            let timestamp = Date()
            do {
                let encodedReleases = try JSONEncoder().encode(releases)
                UserDefaults.standard.set(encodedReleases, forKey: cacheKeyReleases)
                UserDefaults.standard.set(timestamp, forKey: cacheKeyTimestamp)
                AppLogger.shared.info("Cached releases at \(timestamp).")
            } catch {
                AppLogger.shared.error("Failed to cache releases: \(error.localizedDescription)")
            }
        }
    
    private func getCachedReleases() -> [Release]? {
            guard let timestamp = UserDefaults.standard.object(forKey: cacheKeyTimestamp) as? Date else { return nil }
            guard Date().timeIntervalSince(timestamp) < 3600 else { return nil } // Cache valid for 1 hour
            guard let encodedReleases = UserDefaults.standard.data(forKey: cacheKeyReleases) else { return nil }

            do {
                return try JSONDecoder().decode([Release].self, from: encodedReleases)
            } catch {
                AppLogger.shared.error("Failed to decode cached releases: \(error.localizedDescription)")
                return nil
            }
        }
    
    func invalidateCache() {
            UserDefaults.standard.removeObject(forKey: cacheKeyReleases)
            UserDefaults.standard.removeObject(forKey: cacheKeyTimestamp)
            AppLogger.shared.info("Cache invalidated.")
        }

    func startCollector() {
        guard process == nil else { return }
        let process = Process()
        process.executableURL = collectorPath.appendingPathComponent("otelcol-contrib")
        process.arguments = ["--config", collectorPath.appendingPathComponent("config.yaml").path]
        do {
            try process.run()
            self.process = process
            isRunning = true
        } catch {
            print("Failed to start collector: \(error)")
        }
    }

    func stopCollector() {
        process?.terminate()
        process = nil
        isRunning = false
    }

    func isCollectorRunning() -> Bool {
        // Implement status check logic
        return isRunning
    }

    func writeConfig(_ config: String) {
        let configPath = collectorPath.appendingPathComponent("config.yaml")
        try? config.write(to: configPath, atomically: true, encoding: .utf8)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        DispatchQueue.main.async {
            self.downloadProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        DispatchQueue.main.async {
            self.downloadStatus = "Download complete. Processing..."
        }

        do {
            let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("downloadedFile.tar.gz")
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.moveItem(at: location, to: destinationURL)

            DispatchQueue.main.async {
                self.downloadStatus = "Download moved to \(destinationURL.path)."
            }

            // Optionally extract or process the file
            // let extractedPath = try self.extractTarGz(at: destinationURL)
            // Perform additional actions on extracted files
        } catch {
            DispatchQueue.main.async {
                self.downloadStatus = "Error moving file: \(error.localizedDescription)"
            }
        }
    }
}
