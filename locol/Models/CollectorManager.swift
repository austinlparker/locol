import Foundation
import Combine
import Subprocess
import os
import AppKit
import Observation
import Yams

// A cleaner implementation that properly handles actor isolation
@MainActor
@Observable
class CollectorManager {
    static let shared = CollectorManager()
    
    // Properties for UI updates
    private(set) var isDownloading: Bool = false
    private(set) var isLoadingReleases: Bool = false
    var downloadProgress: Double = 0.0
    var downloadStatus: String = ""
    private(set) var activeCollector: CollectorInstance? = nil
    private(set) var isProcessingOperation: Bool = false
    
    // Core services
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
    
    // MARK: - Service Telemetry Injection
    
    private func injectServiceTelemetry(for collector: CollectorInstance) throws -> CollectorInstance {
        // Read the current configuration
        let configURL = URL(fileURLWithPath: collector.configPath)
        let configContent = try String(contentsOf: configURL, encoding: .utf8)
        
        // Parse the YAML configuration
        guard var config = try Yams.load(yaml: configContent) as? [String: Any] else {
            throw NSError(domain: "io.aparker.locol", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to parse collector configuration"
            ])
        }
        
        // Get OTLP receiver settings
        let settings = OTLPReceiverSettings.shared
        
        // Check if OTLP receiver is available (it auto-starts as a singleton)
        if #available(macOS 15.0, *) {
            // Always inject telemetry - the receiver will auto-start if needed
            logger.info("Injecting OTLP telemetry configuration")
        } else {
            logger.info("OTLP receiver not available on this macOS version, skipping telemetry injection")
            return collector
        }
        
        // Create service telemetry configuration
        var serviceTelemetry: [String: Any] = [:]
        
        // Inject traces telemetry if enabled
        if settings.tracesEnabled {
            serviceTelemetry["traces"] = [
                "processors": [
                    [
                        "batch": [
                            "exporter": [
                                "otlp": [
                                    "protocol": "grpc",
                                    "endpoint": settings.grpcEndpoint,
                                    "headers": [
                                        "collector-name": collector.name
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        }
        
        // Inject metrics telemetry if enabled
        if settings.metricsEnabled {
            serviceTelemetry["metrics"] = [
                "level": "detailed",
                "readers": [
                    [
                        "periodic": [
                            "exporter": [
                                "otlp": [
                                    "protocol": "grpc",
                                    "endpoint": settings.grpcEndpoint,
                                    "headers": [
                                        "collector-name": collector.name
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        }
        
        // Inject logs telemetry if enabled
        if settings.logsEnabled {
            serviceTelemetry["logs"] = [
                "processors": [
                    [
                        "batch": [
                            "exporter": [
                                "otlp": [
                                    "protocol": "grpc",
                                    "endpoint": settings.grpcEndpoint,
                                    "headers": [
                                        "collector-name": collector.name
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        }
        
        // Inject the service telemetry into the configuration
        if var service = config["service"] as? [String: Any] {
            service["telemetry"] = serviceTelemetry
            config["service"] = service
        } else {
            config["service"] = [
                "telemetry": serviceTelemetry
            ]
        }
        
        // Write the updated configuration to a temporary file
        let modifiedConfigContent = try Yams.dump(object: config)
        let tempConfigURL = configURL.appendingPathExtension("locol-temp")
        try modifiedConfigContent.write(to: tempConfigURL, atomically: true, encoding: .utf8)
        
        logger.info("Injected service telemetry configuration for collector \(collector.name)")
        
        // Return a new collector instance with the temp config path
        return CollectorInstance(
            id: collector.id,
            name: collector.name,
            version: collector.version,
            binaryPath: collector.binaryPath,
            configPath: tempConfigURL.path,
            commandLineFlags: collector.commandLineFlags,
            isRunning: collector.isRunning,
            pid: collector.pid,
            startTime: collector.startTime,
            components: collector.components
        )
    }
    
    private func cleanupTempConfig(for collector: CollectorInstance) {
        // The temp config path might be the current config path if telemetry was injected
        let configURL = URL(fileURLWithPath: collector.configPath)
        
        // Check if the current config path is a temp file
        if configURL.pathExtension == "locol-temp" {
            try? FileManager.default.removeItem(at: configURL)
            logger.debug("Cleaned up temporary configuration file for collector \(collector.name)")
        } else {
            // Also check for a temp file based on the original path
            let tempConfigURL = configURL.appendingPathExtension("locol-temp")
            if FileManager.default.fileExists(atPath: tempConfigURL.path) {
                try? FileManager.default.removeItem(at: tempConfigURL)
                logger.debug("Cleaned up temporary configuration file for collector \(collector.name)")
            }
        }
    }
    
    // MARK: - Collector Management
    
    func addCollector(name: String, version: String, release: Release, asset: ReleaseAsset) async {
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
            
            // Start monitoring download progress
            let progressTask = Task { [weak self] in
                while !Task.isCancelled {
                    guard let self else { return }
                    await MainActor.run {
                        self.downloadProgress = self.downloadManager.downloadProgress
                        self.downloadStatus = self.downloadManager.downloadStatus
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                }
            }
            
            let (downloadedBinaryPath, downloadedConfigPath) = try await downloadManager.downloadAsset(
                releaseAsset: asset,
                name: name,
                version: version,
                binaryPath: binaryPath,
                configPath: configPath
            )
            
            progressTask.cancel()
            
            let collector = CollectorInstance(
                name: name,
                version: version,
                binaryPath: downloadedBinaryPath,
                configPath: downloadedConfigPath
            )
            appState.addCollector(collector)
            
            // Get component information
            do {
                downloadStatus = "Getting component information..."
                let components = try await processManager.getCollectorComponents(collector)
                
                var updatedCollector = collector
                updatedCollector.components = components
                appState.updateCollector(updatedCollector)
                isDownloading = false
                downloadProgress = 0.0
                downloadStatus = ""
            } catch {
                handleError(error, context: "Failed to get collector components")
                isDownloading = false
                downloadProgress = 0.0
                downloadStatus = ""
            }
        } catch {
            handleError(error, context: "Failed to create collector directory or download collector")
            isDownloading = false
            downloadProgress = 0.0
            downloadStatus = ""
            // Clean up the directory on failure
            try? fileManager.deleteCollector(name: name)
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
            handleError(error, context: "Failed to delete collector")
        }
        
        // Clean up telemetry data for this collector
        if #available(macOS 15.0, *) {
            Task {
                try await TelemetryStorage.shared.clearData(for: collector.name)
                await MainActor.run {
                    logger.info("Removed telemetry data for collector: \(collector.name)")
                }
            }
        }
    }
    
    func startCollector(withId id: UUID) {
        guard let collector = appState.getCollector(withId: id) else { return }
        
        // Show processing status
        isProcessingOperation = true
        
        // Use Task for async operation
        Task {
            do {
                // Inject service telemetry configuration before starting
                let collectorWithTelemetry = try injectServiceTelemetry(for: collector)
                
                // Start collector with async/await
                try await processManager.startCollector(collectorWithTelemetry)
                
                // Update collector state
                var updatedCollector = collector
                updatedCollector.isRunning = true
                updatedCollector.pid = 0  // PID not available with new swift-subprocess API
                updatedCollector.startTime = Date()
                appState.updateCollector(updatedCollector)
                activeCollector = updatedCollector
                isProcessingOperation = false
                
                // Metrics scraping disabled - we now get metrics via OTLP telemetry
                // Task {
                //     try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                //     metricsManager.startScraping()
                // }
            } catch {
                handleError(error, context: "Failed to start collector")
                isProcessingOperation = false
            }
        }
    }
    
    func stopCollector(withId id: UUID) {
        guard let collector = appState.getCollector(withId: id) else { return }
        
        // Show processing status
        isProcessingOperation = true
        
        // Use Task for async operation
        Task {
            // Metrics scraping disabled - no need to stop scraping
            // metricsManager.stopScraping()
            
            do {
                // Then stop the collector
                try await processManager.stopCollector()
                
                // Clean up temporary configuration file if it exists
                cleanupTempConfig(for: collector)
                
                // Update collector state
                var updatedCollector = collector
                updatedCollector.isRunning = false
                updatedCollector.pid = nil
                updatedCollector.startTime = nil
                appState.updateCollector(updatedCollector)
                activeCollector = nil
                isProcessingOperation = false
            } catch ProcessError.notRunning {
                // If the process isn't running, just update the state
                var updatedCollector = collector
                updatedCollector.isRunning = false
                updatedCollector.pid = nil
                updatedCollector.startTime = nil
                appState.updateCollector(updatedCollector)
                activeCollector = nil
                isProcessingOperation = false
            } catch {
                handleError(error, context: "Failed to stop collector")
                isProcessingOperation = false
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
            handleError(error, context: "Failed to write config")
        }
    }
    
    func updateCollectorFlags(withId id: UUID, flags: String) {
        guard let collector = appState.getCollector(withId: id) else { return }
        
        var updatedCollector = collector
        updatedCollector.commandLineFlags = flags
        appState.updateCollector(updatedCollector)
    }
    
    func getCollectorReleases(repo: String, forceRefresh: Bool = false) async {
        isLoadingReleases = true
        
        await releaseManager.getCollectorReleases(repo: repo, forceRefresh: forceRefresh)
        
        isLoadingReleases = false
    }
    
    func listConfigTemplates() -> [URL] {
        do {
            return try fileManager.listConfigTemplates()
        } catch {
            handleError(error, context: "Failed to list config templates")
            return []
        }
    }
    
    func applyConfigTemplate(named templateName: String, toCollectorWithId id: UUID) {
        guard let collector = collectors.first(where: { $0.id == id }) else { return }
        
        do {
            try fileManager.applyConfigTemplate(named: templateName, to: collector.configPath)
        } catch {
            handleError(error, context: "Failed to apply template")
        }
    }
    
    
    func refreshCollectorComponents(withId id: UUID) async throws {
        guard let collector = appState.getCollector(withId: id) else { return }
        
        let components = try await processManager.getCollectorComponents(collector)
        
        var updatedCollector = collector
        updatedCollector.components = components
        appState.updateCollector(updatedCollector)
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
