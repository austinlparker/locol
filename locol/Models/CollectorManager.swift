//
//  CollectorManager.swift
//  locol
//
//  Created by Austin Parker on 1/12/25.
//

import Foundation
import Combine

class CollectorManager: ObservableObject {
    @Published private(set) var isDownloading: Bool = false
    @Published private(set) var isLoadingReleases: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadStatus: String = ""
    @Published private(set) var activeCollector: CollectorInstance? = nil
    
    private var metricsManager = MetricsManager.shared
    private var cancellables = Set<AnyCancellable>()
    
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
        
        // Set up bindings
        downloadManager.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }
        .store(in: &cancellables)
        
        downloadManager.$downloadProgress
            .assign(to: &$downloadProgress)
        
        downloadManager.$downloadStatus
            .assign(to: &$downloadStatus)
            
        processManager.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }
        .store(in: &cancellables)
    }
    
    var availableReleases: [Release] {
        releaseManager.availableReleases
    }
    
    var collectors: [CollectorInstance] {
        appState.collectors
    }
    
    private func createCollectorDirectory(name: String, version: String) throws -> (binaryPath: String, configPath: String) {
        let collectorDir = fileManager.baseDirectory.appendingPathComponent("collectors").appendingPathComponent(name)
        let binPath = collectorDir.appendingPathComponent("bin")
        let configPath = collectorDir.appendingPathComponent("config.yaml")
        
        do {
            try FileManager.default.createDirectory(at: binPath, withIntermediateDirectories: true)
            AppLogger.shared.debug("Created directory at \(binPath.path)")
            return (binPath.path, configPath.path)
        } catch {
            AppLogger.shared.error("Failed to create directory at \(binPath.path): \(error.localizedDescription)")
            throw error
        }
    }
    
    func addCollector(name: String, version: String, release: Release, asset: ReleaseAsset) {
        isDownloading = true
        downloadStatus = "Creating collector directory..."
        downloadProgress = 0.0
        
        // Create the directory first
        do {
            _ = try createCollectorDirectory(name: name, version: version)
        } catch {
            AppLogger.shared.error("Failed to create collector directory: \(error.localizedDescription)")
            isDownloading = false
            downloadProgress = 0.0
            downloadStatus = ""
            return
        }
        
        // Then download the asset
        downloadStatus = "Downloading collector binary..."
        downloadManager.downloadAsset(releaseAsset: asset, name: name, version: version) { [weak self] result in
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
                        AppLogger.shared.error("Failed to get collector components: \(error.localizedDescription)")
                        await MainActor.run {
                            self.isDownloading = false
                            self.downloadProgress = 0.0
                            self.downloadStatus = ""
                        }
                    }
                }
            case .failure(let error):
                AppLogger.shared.error("Failed to download collector: \(error.localizedDescription)")
                // Clean up the directory on failure
                try? self.fileManager.deleteCollector(name: name)
                self.isDownloading = false
                self.downloadProgress = 0.0
                self.downloadStatus = ""
            }
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
            AppLogger.shared.error("Failed to delete collector: \(error.localizedDescription)")
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
            if let process = processManager.getActiveProcess() {
                updatedCollector.pid = Int(process.processIdentifier)
            }
            updatedCollector.startTime = Date()
            appState.updateCollector(updatedCollector)
            activeCollector = updatedCollector
            
            // Start metrics manager
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // Give the collector time to start up before scraping metrics
                self.metricsManager.startScraping()
            }
        } catch {
            AppLogger.shared.error("Failed to start collector: \(error.localizedDescription)")
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
            AppLogger.shared.error("Failed to stop collector: \(error.localizedDescription)")
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
            AppLogger.shared.error("Failed to write config: \(error.localizedDescription)")
            // TODO: Show error to user
        }
    }
    
    func updateCollectorFlags(withId id: UUID, flags: String) {
        guard let collector = appState.getCollector(withId: id) else { return }
        var updatedCollector = collector
        updatedCollector.commandLineFlags = flags
        appState.updateCollector(updatedCollector)
    }
    
    func getCollectorReleases(repo: String, forceRefresh: Bool = false, completion: @escaping () -> Void = {}) {
        isLoadingReleases = true
        releaseManager.getCollectorReleases(repo: repo, forceRefresh: forceRefresh) { [weak self] in
            DispatchQueue.main.async {
                self?.isLoadingReleases = false
                completion()
            }
        }
    }
    
    func listConfigTemplates() -> [URL] {
        do {
            return try fileManager.listConfigTemplates()
        } catch {
            AppLogger.shared.error("Failed to list config templates: \(error.localizedDescription)")
            return []
        }
    }
    
    func applyConfigTemplate(named templateName: String, toCollectorWithId id: UUID) {
        guard let collector = collectors.first(where: { $0.id == id }) else { return }
        
        do {
            try fileManager.applyConfigTemplate(named: templateName, to: collector.configPath)
        } catch {
            AppLogger.shared.error("Failed to apply template: \(error.localizedDescription)")
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
