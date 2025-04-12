import Foundation
import Combine
import Subprocess
import os
import AppKit

// A cleaner implementation that properly handles actor isolation
@MainActor
class CollectorManager: ObservableObject {
    static let shared = CollectorManager()
    
    // Published properties for UI updates
    @Published private(set) var isDownloading: Bool = false
    @Published private(set) var isLoadingReleases: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadStatus: String = ""
    @Published private(set) var activeCollector: CollectorInstance? = nil
    @Published private(set) var isProcessingOperation: Bool = false
    
    // Core services
    private let metricsManager = MetricsManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    let fileManager: CollectorFileManager
    let releaseManager: ReleaseManager
    let downloadManager: DownloadManager
    let appState: AppState
    let processManager: ProcessManager
    
    // Logger for error handling
    private let logger = Logger.app
    
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
        
        // Register for application termination notification
        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in
                Task {
                    await self?.cleanupOnTermination()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Accessors
    
    var availableReleases: [Release] {
        releaseManager.availableReleases
    }
    
    var collectors: [CollectorInstance] {
        appState.collectors
    }
    
    // MARK: - Collector Management
    
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
                
                DispatchQueue.main.async {
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
                                self.downloadStatus = "Getting component information..."
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
                                await MainActor.run {
                                    self.handleError(error, context: "Failed to get collector components")
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
            }
        } catch {
            DispatchQueue.main.async {
                self.handleError(error, context: "Failed to create collector directory")
                self.isDownloading = false
                self.downloadProgress = 0.0
                self.downloadStatus = ""
            }
        }
    }
    
    func removeCollector(withId id: UUID) {
        guard let collector = appState.getCollector(withId: id) else { return }
        
        DispatchQueue.main.async {
            // If this is the active collector, stop it first
            if self.activeCollector?.id == id {
                self.stopCollector(withId: id)
            }
            
            self.appState.removeCollector(withId: id)
            
            do {
                try self.fileManager.deleteCollector(name: collector.name)
            } catch {
                self.handleError(error, context: "Failed to delete collector")
            }
        }
    }
    
    func startCollector(withId id: UUID) {
        guard let collector = appState.getCollector(withId: id) else { return }
        
        // Show processing status
        DispatchQueue.main.async {
            self.isProcessingOperation = true
        }
        
        // Use Task for async operation
        Task {
            do {
                // Start collector with async/await
                try await processManager.startCollector(collector)
                
                // Update UI on main thread
                await MainActor.run {
                    // Update collector state
                    var updatedCollector = collector
                    updatedCollector.isRunning = true
                    updatedCollector.pid = Int(processManager.getActiveProcess()?.pid ?? 0)
                    updatedCollector.startTime = Date()
                    appState.updateCollector(updatedCollector)
                    activeCollector = updatedCollector
                    isProcessingOperation = false
                    
                    // Start metrics manager after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.metricsManager.startScraping()
                    }
                }
            } catch {
                await MainActor.run {
                    self.handleError(error, context: "Failed to start collector")
                    self.isProcessingOperation = false
                }
            }
        }
    }
    
    func stopCollector(withId id: UUID) {
        guard let collector = appState.getCollector(withId: id) else { return }
        
        // Show processing status
        DispatchQueue.main.async {
            self.isProcessingOperation = true
        }
        
        // Use Task for async operation
        Task {
            // Stop metrics manager first
            await MainActor.run {
                metricsManager.stopScraping()
            }
            
            do {
                // Then stop the collector
                try await processManager.stopCollector()
                
                // Update UI on main thread
                await MainActor.run {
                    // Update collector state
                    var updatedCollector = collector
                    updatedCollector.isRunning = false
                    updatedCollector.pid = nil
                    updatedCollector.startTime = nil
                    appState.updateCollector(updatedCollector)
                    activeCollector = nil
                    isProcessingOperation = false
                }
            } catch ProcessError.notRunning {
                // If the process isn't running, just update the state
                await MainActor.run {
                    var updatedCollector = collector
                    updatedCollector.isRunning = false
                    updatedCollector.pid = nil
                    updatedCollector.startTime = nil
                    appState.updateCollector(updatedCollector)
                    activeCollector = nil
                    isProcessingOperation = false
                }
            } catch {
                await MainActor.run {
                    self.handleError(error, context: "Failed to stop collector")
                    self.isProcessingOperation = false
                }
            }
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
            DispatchQueue.main.async {
                self.handleError(error, context: "Failed to write config")
            }
        }
    }
    
    func updateCollectorFlags(withId id: UUID, flags: String) {
        guard let collector = appState.getCollector(withId: id) else { return }
        
        DispatchQueue.main.async {
            var updatedCollector = collector
            updatedCollector.commandLineFlags = flags
            self.appState.updateCollector(updatedCollector)
        }
    }
    
    func getCollectorReleases(repo: String, forceRefresh: Bool = false, completion: @escaping () -> Void = {}) {
        DispatchQueue.main.async {
            self.isLoadingReleases = true
        }
        
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
            DispatchQueue.main.async {
                self.handleError(error, context: "Failed to list config templates")
            }
            return []
        }
    }
    
    func applyConfigTemplate(named templateName: String, toCollectorWithId id: UUID) {
        guard let collector = collectors.first(where: { $0.id == id }) else { return }
        
        do {
            try fileManager.applyConfigTemplate(named: templateName, to: collector.configPath)
        } catch {
            DispatchQueue.main.async {
                self.handleError(error, context: "Failed to apply template")
            }
        }
    }
    
    func getMetricsManager() -> MetricsManager {
        return metricsManager
    }
    
    func refreshCollectorComponents(withId id: UUID) async throws {
        guard let collector = appState.getCollector(withId: id) else { return }
        
        let components = try await processManager.getCollectorComponents(collector)
        
        await MainActor.run {
            var updatedCollector = collector
            updatedCollector.components = components
            appState.updateCollector(updatedCollector)
        }
    }
    
    // MARK: - Private Functions
    
    // Centralized cleanup method that uses async/await
    private func cleanupOnTermination() async {
        logger.info("Application terminating, stopping all collectors")
        
        // Copy collectors to avoid potential mutation during iteration
        let collectorsToStop = collectors.filter { $0.isRunning }
        
        // Stop all running collectors
        for collector in collectorsToStop {
            do {
                try await processManager.stopCollector()
                logger.info("Successfully stopped collector: \(collector.name)")
            } catch {
                logger.error("Failed to stop collector \(collector.name): \(error.localizedDescription)")
            }
        }
        
        logger.info("All collectors cleanup complete")
    }
    
    // Update error logging to use system logger
    private func handleError(_ error: Error, context: String) {
        logger.error("\(context): \(error.localizedDescription)")
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