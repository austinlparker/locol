import Foundation
import Observation
import Yams
import GRDBQuery

@MainActor
@Observable
final class AppContainer {
    let storage: TelemetryStorage
    let collectorStore: CollectorStore
    let settings: OTLPReceiverSettings
    let server: OTLPServer
    let viewer: TelemetryViewer
    let collectorManager: CollectorManager
    let componentDatabase: ComponentDatabase
    let collectorsViewModel: CollectorsViewModel

    // Pipeline Designer state hoisted for Inspector-driven editing
    var pipelineConfig: CollectorConfiguration = CollectorConfiguration(version: "v0.135.0")
    var selectedPipeline: PipelineConfiguration? = nil
    var selectedPipelineComponent: ComponentInstance? = nil

    /// Provides database context for GRDBQuery @Query property wrappers
    var databaseContext: DatabaseContext? {
        componentDatabase.databaseContext
    }
    
    init() {
        self.storage = TelemetryStorage()
        self.settings = OTLPReceiverSettings()
        self.collectorStore = CollectorStore()
        self.server = OTLPServer(storage: storage, settings: settings)
        self.viewer = TelemetryViewer(storage: storage)
        self.collectorManager = CollectorManager(settings: settings, storage: storage, collectorStore: collectorStore)
        self.componentDatabase = ComponentDatabase()
        self.collectorsViewModel = CollectorsViewModel(store: collectorStore)
    }

    // MARK: - Pipeline Loading
    func loadCollectorConfiguration(forCollectorId id: UUID) async {
        // Prefer DB-typed config; fall back to default version if no config yet
        if let (versionId, config) = try? await collectorStore.getCurrentConfig(id) {
            _ = versionId // currently unused; keep in case we show revision
            await MainActor.run {
                self.pipelineConfig = config
                self.selectedPipeline = config.pipelines.first
            }
            return
        }
        // Fall back: use record to determine version
        if let record = try? await collectorStore.getCollector(id) {
            await MainActor.run {
                self.pipelineConfig = CollectorConfiguration(version: record.version)
                self.selectedPipeline = self.pipelineConfig.pipelines.first
            }
        }
    }
}
