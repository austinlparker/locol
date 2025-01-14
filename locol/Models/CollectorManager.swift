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
    @Published var downloadProgress: Double = 0.0
    @Published var downloadStatus: String = ""
    
    private var runningProcesses: [UUID: Process] = [:]
    private var metricsManagers: [UUID: MetricsManager] = [:]
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
    
    func addCollector(name: String, version: String, release: Release, asset: ReleaseAsset) {
        isDownloading = true
        
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
            case .failure(let error):
                AppLogger.shared.error("Failed to download collector: \(error.localizedDescription)")
                // TODO: Show error to user
            }
            
            self.isDownloading = false
        }
    }
    
    func removeCollector(withId id: UUID) {
        guard let collector = appState.getCollector(withId: id) else { return }
        stopCollector(withId: id)
        metricsManagers.removeValue(forKey: id)
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
            var updatedCollector = collector
            updatedCollector.isRunning = true
            appState.updateCollector(updatedCollector)
            // Create metrics manager when collector starts
            _ = getMetricsManager(forCollectorId: id)
        } catch {
            AppLogger.shared.error("Failed to start collector: \(error.localizedDescription)")
            // TODO: Show error to user
        }
    }
    
    func stopCollector(withId id: UUID) {
        guard let collector = appState.getCollector(withId: id) else { return }
        
        processManager.stopCollector(collector)
        var updatedCollector = collector
        updatedCollector.isRunning = false
        appState.updateCollector(updatedCollector)
        metricsManagers.removeValue(forKey: id)
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
        releaseManager.getCollectorReleases(repo: repo, forceRefresh: forceRefresh, completion: completion)
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
        guard let collector = appState.getCollector(withId: id) else { return }
        
        do {
            try fileManager.applyTemplate(named: templateName, to: collector.configPath)
        } catch {
            AppLogger.shared.error("Failed to apply config template: \(error.localizedDescription)")
            // TODO: Show error to user
        }
    }
    
    func getMetricsManager(forCollectorId id: UUID) -> MetricsManager {
        if let manager = metricsManagers[id] {
            return manager
        }
        let manager = MetricsManager()
        metricsManagers[id] = manager
        return manager
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
