import Foundation
import os
import Observation
import Subprocess

@Observable
final class AppState {
    var isDownloading: Bool = false
    var isLoadingReleases: Bool = false
    var downloadProgress: Double = 0.0
    var downloadStatus: String = ""
    var error: Error? = nil
    var isShowingError: Bool = false
    private(set) var runningCollector: CollectorInstance? = nil
    private(set) var collectors: [CollectorInstance]
    let dataExplorer: DataExplorer
    
    private let stateKey = "SavedCollectors"
    private let logger = Logger.app
    private let fileManager: CollectorFileManager
    private let releaseManager: ReleaseManager
    private let downloadManager: DownloadManager
    private let processManager: ProcessManager
    let metricsManager: MetricsManager
    
    init(
        fileManager: CollectorFileManager = CollectorFileManager(),
        releaseManager: ReleaseManager = ReleaseManager(),
        metricsManager: MetricsManager = MetricsManager(),
        processManager: ProcessManager? = nil
    ) {
        self.fileManager = fileManager
        self.releaseManager = releaseManager
        self.metricsManager = metricsManager
        self.downloadManager = DownloadManager(fileManager: fileManager)
        self.processManager = processManager ?? ProcessManager(fileManager: fileManager)
        self.dataExplorer = DataExplorer.shared
        
        // Load saved collectors
        if let data = UserDefaults.standard.data(forKey: stateKey) {
            do {
                self.collectors = try JSONDecoder().decode([CollectorInstance].self, from: data)
            } catch {
                logger.error("Failed to decode collectors: \(error)")
                UserDefaults.standard.removeObject(forKey: stateKey)
                self.collectors = []
            }
        } else {
            self.collectors = []
        }
        
        // Reset running state for all collectors on startup
        self.runningCollector = nil
        for i in 0..<collectors.count {
            collectors[i].isRunning = false
            collectors[i].pid = nil
            collectors[i].startTime = nil
        }
        
        // Set up download bindings
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
    
    func addCollector(_ collector: CollectorInstance) {
        Task {
            do {
                // Load components first
                let components = try await processManager.getCollectorComponents(collector)
                
                // Create new collector instance with components
                var updatedCollector = collector
                updatedCollector.components = components
                
                // Add to collectors array
                collectors.append(updatedCollector)
                
                // Save state
                try await saveState()
            } catch {
                handleError(error, context: "Failed to add collector")
            }
        }
    }
    
    func removeCollector(withId id: UUID) {
        guard let collector = getCollector(withId: id) else { return }
        
        // If this is the running collector, stop it first
        if runningCollector?.id == id {
            stopCollector(withId: id)
        }
        
        collectors.removeAll { $0.id == id }
        
        Task {
            do {
                try await saveState()
                try fileManager.deleteCollector(name: collector.name)
            } catch {
                handleError(error, context: "Failed to delete collector")
            }
        }
    }
    
    func updateCollector(_ collector: CollectorInstance) {
        if let index = collectors.firstIndex(where: { $0.id == collector.id }) {
            collectors[index] = collector
            Task {
                do {
                    try await saveState()
                } catch {
                    handleError(error, context: "Failed to save collector state")
                }
            }
        }
    }
    
    func getCollector(withId id: UUID) -> CollectorInstance? {
        collectors.first { $0.id == id }
    }
    
    func startCollector(withId id: UUID) async {
        guard runningCollector == nil else { return }
        guard let collector = collectors.first(where: { $0.id == id }) else { return }
        
        do {
            // Load components first
            let components = try await processManager.getCollectorComponents(collector)
            
            // Create new collector instance with components
            var updatedCollector = collector
            updatedCollector.components = components
            
            // Start the collector
            try processManager.startCollector(updatedCollector)
            
            // Update collector state
            updatedCollector.isRunning = true
            updatedCollector.pid = Int(processManager.activeCollector?.process.pid ?? 0)
            updatedCollector.startTime = Date()
            updateCollector(updatedCollector)
            runningCollector = updatedCollector
            
            // Start metrics scraping
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                self.metricsManager.startScraping()
            }
        } catch {
            handleError(error, context: "Failed to start collector")
        }
    }
    
    func stopCollector(withId id: UUID) {
        guard let collector = getCollector(withId: id) else { return }
        
        metricsManager.stopScraping()
        
        do {
            try processManager.stopCollector()
            
            var updatedCollector = collector
            updatedCollector.isRunning = false
            updatedCollector.pid = nil
            updatedCollector.startTime = nil
            updateCollector(updatedCollector)
            runningCollector = nil
        } catch ProcessError.notRunning {
            var updatedCollector = collector
            updatedCollector.isRunning = false
            updatedCollector.pid = nil
            updatedCollector.startTime = nil
            updateCollector(updatedCollector)
            runningCollector = nil
        } catch {
            handleError(error, context: "Failed to stop collector")
        }
    }
    
    func updateCollectorConfig(withId id: UUID, config: String) {
        guard let collector = getCollector(withId: id) else { return }
        
        do {
            try fileManager.writeConfig(config, to: collector.configPath)
        } catch {
            handleError(error, context: "Failed to write config")
        }
    }
    
    func getCollectorReleases(repo: String, forceRefresh: Bool = false) {
        Task { @MainActor in
            isLoadingReleases = true
            do {
                try await releaseManager.getCollectorReleases(repo: repo, forceRefresh: forceRefresh)
            } catch {
                handleError(error, context: "Failed to get collector releases")
            }
            isLoadingReleases = false
        }
    }
    
    private func saveState() async throws {
        do {
            let data = try JSONEncoder().encode(collectors)
            UserDefaults.standard.set(data, forKey: stateKey)
        } catch {
            handleError(error, context: "Failed to save state")
            throw error
        }
    }
    
    private func handleError(_ error: Error, context: String) {
        logger.error("\(context): \(error.localizedDescription)")
        self.error = error
        isShowingError = true
    }
} 
