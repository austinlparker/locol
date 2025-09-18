import Foundation
import Combine
import Subprocess
import os
import Observation
import Yams

// A cleaner implementation that properly handles actor isolation
@MainActor
@Observable
class CollectorManager {
    
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
    let settings: OTLPReceiverSettings
    let storage: TelemetryStorageProtocol
    let processManager: ProcessManager
    let collectorStore: CollectorStore?
    
    // Logger for error handling
    private let logger = Logger.app
    
    init(
        fileManager: CollectorFileManager = CollectorFileManager(),
        releaseManager: ReleaseManager = ReleaseManager(),
        downloadManager: DownloadManager? = nil,
        processManager: ProcessManager? = nil,
        settings: OTLPReceiverSettings = OTLPReceiverSettings(),
        storage: TelemetryStorageProtocol = TelemetryStorage(),
        collectorStore: CollectorStore? = nil
    ) {
        self.fileManager = fileManager
        self.releaseManager = releaseManager
        self.downloadManager = downloadManager ?? DownloadManager(fileManager: fileManager)
        self.processManager = processManager ?? ProcessManager(fileManager: fileManager)
        self.settings = settings
        self.storage = storage
        self.collectorStore = collectorStore
        // Hook process termination to clear state and update store
        self.processManager.onCollectorTerminated = { [weak self] id in
            guard let self else { return }
            Task { @MainActor in
                if self.activeCollector?.id == id {
                    self.activeCollector = nil
                }
                try? await self.collectorStore?.markStopped(id)
            }
        }
        // Application termination cleanup will be handled by the app's lifecycle
    }
    
    // MARK: - Public Accessors
    
    var availableReleases: [Release] {
        releaseManager.availableReleases
    }
    
    // No in-memory collector list; store is source of truth
    
    // MARK: - Service Telemetry Materialization
    private func buildRuntimeCollectorInstance(from record: CollectorRecord, id: UUID) async throws -> CollectorInstance {
        if #available(macOS 15.0, *) {
            logger.info("Materializing OTLP telemetry overlay for \(record.name)")
        }
        guard let (_, origConfig) = try await collectorStore?.getCurrentConfig(id) else {
            throw ProcessError.configurationError("No current configuration for collector \(record.name)")
        }
        var typedConfig = origConfig
        // Runtime validation: ensure OTLP receiver has at least one protocol
        if let idx = typedConfig.receivers.firstIndex(where: { $0.name.split(separator: "/").first == "otlp" }) {
            var inst = typedConfig.receivers[idx]
            let hasProtocols: Bool
            if case let .map(protoMap)? = inst.configuration["protocols"] {
                hasProtocols = !protoMap.isEmpty
            } else {
                hasProtocols = false
            }
            if !hasProtocols {
                let proto: [String: ConfigValue] = [
                    "grpc": .map([:]),
                    "http": .map([:])
                ]
                inst.configuration["protocols"] = .map(proto)
                typedConfig.receivers[idx] = inst
            }
        }
        let overlay = OverlaySettings(
            grpcEndpoint: settings.grpcEndpoint,
            tracesEnabled: settings.tracesEnabled,
            metricsEnabled: settings.metricsEnabled,
            logsEnabled: settings.logsEnabled
        )
        let runtimeYAML = try ConfigSerializer.generateYAML(from: typedConfig, overlayTelemetryFor: record.name, settings: overlay)
        // Write to ~/.locol/collectors/<name>/config.runtime.yaml
        let baseDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".locol/collectors/\(record.name)")
        try FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        let tempConfigURL = baseDir.appendingPathComponent("config.runtime.yaml")
        try runtimeYAML.write(to: tempConfigURL, atomically: true, encoding: .utf8)
        return CollectorInstance(
            id: id,
            name: record.name,
            version: record.version,
            binaryPath: record.binaryPath,
            configPath: tempConfigURL.path,
            commandLineFlags: record.flags,
            isRunning: record.isRunning,
            pid: nil,
            startTime: nil,
            components: nil
        )
    }
    
    private func cleanupTempConfig(for collector: CollectorInstance) {
        let configURL = URL(fileURLWithPath: collector.configPath)
        // Clean up files with ".runtime" extension
        if configURL.pathExtension == "runtime" {
            try? FileManager.default.removeItem(at: configURL)
            logger.debug("Cleaned up runtime configuration for collector \(collector.name)")
        } else {
            let runtimeURL = configURL.appendingPathExtension("runtime")
            if FileManager.default.fileExists(atPath: runtimeURL.path) {
                try? FileManager.default.removeItem(at: runtimeURL)
                logger.debug("Cleaned up runtime configuration for collector \(collector.name)")
            }
        }
    }
    
    // MARK: - Collector Management
    
    func addCollector(name: String, version: String, release: Release, asset: ReleaseAsset) async {
        isDownloading = true
        downloadStatus = "Creating collector directory..."
        downloadProgress = 0.0
        
        // Create the directory and default typed configuration
        do {
            let (binaryPath, configPath) = try fileManager.createCollectorDirectory(name: name, version: version)

            // Create default typed configuration
            let defaultConfig = createDefaultConfiguration(version: version)

            // Generate YAML from typed config and write to file
            do {
                let yamlContent = try ConfigSerializer.generateYAML(from: defaultConfig)
                try yamlContent.write(to: URL(fileURLWithPath: configPath), atomically: true, encoding: .utf8)
                logger.debug("Successfully wrote default configuration to \(configPath)")
            } catch {
                logger.error("Failed to generate YAML from default config: \(error)")
                throw error
            }
            
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
            
            // Persist to store
            if let store = collectorStore {
                Task {
                    do {
                        _ = try await store.createCollector(
                            id: UUID(),
                            name: name,
                            version: version,
                            binaryPath: downloadedBinaryPath,
                            defaultConfig: defaultConfig
                        )
                    } catch {
                        self.logger.error("Failed to persist collector to store: \(error.localizedDescription)")
                    }
                }
            }
            isDownloading = false
            downloadProgress = 0.0
            downloadStatus = ""
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
        // If this is the active collector, stop it first
        if activeCollector?.id == id {
            stopCollector(withId: id)
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                let record = try await self.collectorStore?.getCollector(id)
                if let name = record?.name {
                    try? self.fileManager.deleteCollector(name: name)
                    if #available(macOS 15.0, *) {
                        try await self.storage.clearData(for: name)
                        self.logger.info("Removed telemetry data for collector: \(name)")
                    }
                }
                try await self.collectorStore?.deleteCollector(id)
            } catch {
                self.handleError(error, context: "Failed to remove collector")
            }
        }
    }
    
    func startCollector(withId id: UUID) {
        // Avoid duplicate starts for the same collector
        if processManager.activeCollectorId == id || isProcessingOperation {
            logger.debug("Start requested for already running or processing collector: \(id)")
            return
        }
        // Show processing status
        isProcessingOperation = true
        
        // Use Task for async operation
        Task {
            do {
                guard let record = try await collectorStore?.getCollector(id) else {
                    throw ProcessError.configurationError("Collector not found")
                }
                let collectorWithTelemetry = try await buildRuntimeCollectorInstance(from: record, id: id)
                
                // Start collector with async/await
                try await processManager.startCollector(collectorWithTelemetry)
                
                // Update collector state
                var running = collectorWithTelemetry
                running.isRunning = true
                running.pid = 0
                running.startTime = Date()
                activeCollector = running
                isProcessingOperation = false
                // Persist running state
                if let store = collectorStore {
                    try? await store.markRunning(id, start: running.startTime ?? Date())
                }
                
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
                if let active = activeCollector { cleanupTempConfig(for: active) }
                
                // Update collector state
                activeCollector = nil
                isProcessingOperation = false
                if let store = collectorStore {
                    try? await store.markStopped(id)
                }
            } catch ProcessError.notRunning {
                // If the process isn't running, just update the state
                activeCollector = nil
                isProcessingOperation = false
                if let store = collectorStore {
                    try? await store.markStopped(id)
                }
            } catch {
                handleError(error, context: "Failed to stop collector")
                isProcessingOperation = false
            }
        }
    }
    
    func isCollectorRunning(withId id: UUID) -> Bool {
        return activeCollector?.id == id && processManager.activeCollectorId == id
    }
    
    func updateCollectorConfig(withId id: UUID, config: String) {
        logger.notice("updateCollectorConfig called; prefer saving typed config to CollectorStore")
    }
    
    func updateCollectorFlags(withId id: UUID, flags: String) {
        Task { try? await collectorStore?.updateFlags(id, flags: flags) }
    }
    
    func getCollectorReleases(repo: String, forceRefresh: Bool = false) async {
        isLoadingReleases = true
        
        await releaseManager.getCollectorReleases(repo: repo, forceRefresh: forceRefresh)
        
        isLoadingReleases = false
    }
    
    
    
    func refreshCollectorComponents(withId id: UUID) async throws {
        guard let record = try await collectorStore?.getCollector(id) else { return }
        // Build a minimal instance for calling processManager (config path not used)
        let instance = CollectorInstance(id: id, name: record.name, version: record.version, binaryPath: record.binaryPath, configPath: "")
        _ = try await processManager.getCollectorComponents(instance)
    }
    
    // MARK: - Configuration Creation

    private func createDefaultConfiguration(version: String) -> CollectorConfiguration {
        let database = ComponentDatabase()

        // Look up components from database
        guard let otlpComponent = database.getComponent(name: "otlp", type: .receiver),
              let batchComponent = database.getComponent(name: "batch", type: .processor),
              let debugComponent = database.getComponent(name: "debug", type: .exporter) else {
            logger.error("Failed to find required components in database")
            // Fallback to empty config if components not found
            return CollectorConfiguration(version: version)
        }

        // Create OTLP receiver instance with configuration
        var otlpReceiver = ComponentInstance(component: otlpComponent, name: "otlp")
        otlpReceiver.configuration = [
            "protocols": .map([
                "grpc": .map([
                    "endpoint": .string("localhost:4317")
                ]),
                "http": .map([
                    "endpoint": .string("localhost:4318")
                ])
            ])
        ]

        // Create batch processor instance
        let batchProcessor = ComponentInstance(component: batchComponent, name: "batch")

        // Create debug exporter instance with configuration
        var debugExporter = ComponentInstance(component: debugComponent, name: "debug")
        debugExporter.configuration = [
            "verbosity": .string("detailed")
        ]

        // Create default pipeline
        let defaultPipeline = PipelineConfiguration(
            name: "traces",
            receivers: [otlpReceiver],
            processors: [batchProcessor],
            exporters: [debugExporter]
        )

        var config = CollectorConfiguration(version: version)
        config.receivers = [otlpReceiver]
        config.processors = [batchProcessor]
        config.exporters = [debugExporter]
        config.extensions = []
        config.connectors = []
        config.pipelines = [defaultPipeline]
        return config
    }

    // MARK: - Lifecycle Management

    // Centralized cleanup method that uses async/await
    func cleanupOnTermination() async {
        logger.info("Application terminating, stopping all collectors")
        
        // Stop active collector if present
        if activeCollector != nil {
            do {
                try await processManager.stopCollector()
            } catch {
                logger.error("Failed to stop active collector: \(error.localizedDescription)")
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
