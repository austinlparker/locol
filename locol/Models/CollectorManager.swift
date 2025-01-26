//
//  CollectorManager.swift
//  locol
//
//  Created by Austin Parker on 1/12/25.
//

import Foundation
import Subprocess
import os
import Observation

@Observable
final class CollectorManager {
    var isDownloading: Bool = false
    var isLoadingReleases: Bool = false
    var downloadProgress: Double = 0.0
    var downloadStatus: String = ""
    var activeCollector: CollectorInstance? = nil
    
    private var metricsManager = MetricsManager.shared
    
    let fileManager: CollectorFileManager
    let releaseManager: ReleaseManager
    let downloadManager: DownloadManager
    let appState: AppState
    let processManager: ProcessManager
    
    init() {
        self.fileManager = CollectorFileManager()
        self.releaseManager = ReleaseManager()
        self.downloadManager = DownloadManager(fileManager: fileManager)
        self.appState = AppState()
        self.processManager = ProcessManager(fileManager: fileManager)
        
        // Reset running state for all collectors on startup
        for collector in appState.collectors where collector.isRunning {
            var updatedCollector = collector
            updatedCollector.isRunning = false
            appState.updateCollector(updatedCollector)
        }
        
        // Set up bindings for download progress and status
        Task { @MainActor in
            for await progress in downloadManager.progressPublisher {
                self.downloadProgress = progress
            }
        }
        
        Task { @MainActor in
            for await status in downloadManager.statusPublisher {
                self.downloadStatus = status
            }
        }
    }
    
    var availableReleases: [Release] {
        releaseManager.availableReleases
    }
    
    var collectors: [CollectorInstance] {
        appState.collectors
    }
    
    func addCollector(name: String, version: String, release: Release, asset: ReleaseAsset) {
        isDownloading = true
        downloadStatus = "Creating collector directory..."
        downloadProgress = 0.0
        
        // Create the directory and copy default config
        do {
            let (binaryPath, configPath) = try fileManager.createCollectorDirectory(name: name, version: version)
            
            // Load and write the default configuration from templates
            guard let templateURL = Bundle.main.url(forResource: "default", withExtension: "yaml", subdirectory: "templates"),
                  let defaultConfig = try? String(contentsOf: templateURL, encoding: .utf8) else {
                throw NSError(domain: "io.aparker.locol", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Could not load default template"
                ])
            }
            
            try defaultConfig.write(to: URL(fileURLWithPath: configPath), atomically: true, encoding: .utf8)
            
            // Then download the asset
            downloadStatus = "Downloading collector binary..."
            downloadManager.downloadAsset(releaseAsset: asset, name: name, version: version, binaryPath: binaryPath, configPath: configPath) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success((let binaryPath, let configPath)):
                    let collector = CollectorInstance(
                        name: name,
                        version: version,
                        binaryPath: binaryPath,
                        configPath: configPath
                    )
                    self.appState.addCollector(collector)
                    
                    // Get component information
                    Task {
                        do {
                            await MainActor.run {
                                self.downloadStatus = "Getting component information..."
                            }
                            let components = try await self.processManager.getCollectorComponents(collector)
                            await MainActor.run {
                                var updatedCollector = collector
                                updatedCollector.components = components
                                self.appState.updateCollector(updatedCollector)
                                self.isDownloading = false
                                self.downloadProgress = 0.0
                                self.downloadStatus = ""
                            }
                        } catch {
                            self.handleError(error, context: "Failed to get collector components")
                            await MainActor.run {
                                self.isDownloading = false
                                self.downloadProgress = 0.0
                                self.downloadStatus = ""
                            }
                        }
                    }
                case .failure(let error):
                    self.handleError(error, context: "Failed to download collector")
                    // Clean up the directory on failure
                    try? self.fileManager.deleteCollector(name: name)
                    self.isDownloading = false
                    self.downloadProgress = 0.0
                    self.downloadStatus = ""
                }
            }
        } catch {
            self.handleError(error, context: "Failed to create collector directory")
            isDownloading = false
            downloadProgress = 0.0
            downloadStatus = ""
            return
        }
    }
    
    func removeCollector(withId id: UUID) {
        guard let collector = appState.getCollector(withId: id) else { return }
        
        // If this is the active collector, stop it first
        if activeCollector?.id == id {
            stopCollector(withId: id)
        }
        
        appState.removeCollector(withId: id)
        
        do {
            try fileManager.deleteCollector(name: collector.name)
        } catch {
            self.handleError(error, context: "Failed to delete collector")
            // TODO: Show error to user
        }
    }
    
    func startCollector(withId id: UUID) {
        guard let collector = appState.getCollector(withId: id) else { return }
        
        do {
            try processManager.startCollector(collector)
            
            // Update collector state
            var updatedCollector = collector
            updatedCollector.isRunning = true
            updatedCollector.pid = Int(processManager.activeCollector?.process.pid ?? 0)
            updatedCollector.startTime = Date()
            appState.updateCollector(updatedCollector)
            activeCollector = updatedCollector
            
            // Start metrics manager
            Task { @MainActor in
                // Give the collector time to start up before scraping metrics
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                self.metricsManager.startScraping()
            }
        } catch {
            self.handleError(error, context: "Failed to start collector")
        }
    }
    
    func stopCollector(withId id: UUID) {
        guard let collector = appState.getCollector(withId: id) else { return }
        
        // Stop metrics manager first
        metricsManager.stopScraping()
        
        // Then stop the collector
        do {
            try processManager.stopCollector()
            
            // Update collector state
            var updatedCollector = collector
            updatedCollector.isRunning = false
            updatedCollector.pid = nil
            updatedCollector.startTime = nil
            appState.updateCollector(updatedCollector)
            activeCollector = nil
        } catch ProcessError.notRunning {
            // If the process isn't running, just update the state
            var updatedCollector = collector
            updatedCollector.isRunning = false
            updatedCollector.pid = nil
            updatedCollector.startTime = nil
            appState.updateCollector(updatedCollector)
            activeCollector = nil
        } catch {
            self.handleError(error, context: "Failed to stop collector")
        }
    }
    
    func isCollectorRunning(withId id: UUID) -> Bool {
        guard let collector = appState.getCollector(withId: id) else { return false }
        return processManager.isRunning(collector)
    }
    
    func updateCollectorConfig(withId id: UUID, config: String) {
        guard let collector = appState.getCollector(withId: id) else { return }
        
        do {
            try fileManager.writeConfig(config, to: collector.configPath)
        } catch {
            self.handleError(error, context: "Failed to write config")
            // TODO: Show error to user
        }
    }
    
    func getCollectorReleases(repo: String, forceRefresh: Bool = false, completion: @escaping () -> Void = {}) {
        isLoadingReleases = true
        releaseManager.getCollectorReleases(repo: repo, forceRefresh: forceRefresh) { [weak self] in
            Task { @MainActor in
                self?.isLoadingReleases = false
                completion()
            }
        }
    }
    
    func listConfigTemplates() -> [URL] {
        do {
            return try fileManager.listConfigTemplates()
        } catch {
            self.handleError(error, context: "Failed to list config templates")
            return []
        }
    }
    
    func applyConfigTemplate(named templateName: String, toCollectorWithId id: UUID) {
        guard let collector = collectors.first(where: { $0.id == id }) else { return }
        
        do {
            try fileManager.applyConfigTemplate(named: templateName, to: collector.configPath)
        } catch {
            self.handleError(error, context: "Failed to apply template")
        }
    }
    
    func getMetricsManager() -> MetricsManager {
        return metricsManager
    }
    
    func refreshCollectorComponents(withId id: UUID) async throws {
        guard let collector = appState.getCollector(withId: id) else { return }
        let components = try await processManager.getCollectorComponents(collector)
        var updatedCollector = collector
        updatedCollector.components = components
        appState.updateCollector(updatedCollector)
    }
    
    // Update error logging to use system logger
    private func handleError(_ error: Error, context: String) {
        Logger.app.error("\(context): \(error.localizedDescription)")
    }
}

// MARK: - Data Models
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
