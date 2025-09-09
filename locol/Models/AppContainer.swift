import Foundation
import Observation
import Yams

@MainActor
@Observable
final class AppContainer {
    let storage: TelemetryStorage
    let settings: OTLPReceiverSettings
    let server: OTLPServer
    let viewer: TelemetryViewer
    let snippetManager: ConfigSnippetManager
    let collectorManager: CollectorManager
    let componentDatabase: ComponentDatabase
    
    // Pipeline Designer state hoisted for Inspector-driven editing
    var pipelineConfig: CollectorConfiguration = CollectorConfiguration(version: "v0.135.0")
    var selectedPipeline: PipelineConfiguration? = nil
    var selectedPipelineComponent: ComponentInstance? = nil
    
    init() {
        self.storage = TelemetryStorage()
        self.settings = OTLPReceiverSettings()
        self.server = OTLPServer(storage: storage, settings: settings)
        self.viewer = TelemetryViewer(storage: storage)
        self.snippetManager = ConfigSnippetManager(settings: settings)
        self.collectorManager = CollectorManager(settings: settings, storage: storage)
        self.componentDatabase = ComponentDatabase()
    }

    // MARK: - Pipeline Loading
    func loadCollectorConfiguration(for collector: CollectorInstance) async {
        do {
            let configPath = collector.configPath
            let yamlContent = try String(contentsOfFile: configPath, encoding: .utf8)
            do {
                let loadedConfig = try await ConfigSerializer.parseYAML(yamlContent, version: collector.version)
                self.pipelineConfig = loadedConfig
                self.selectedPipeline = loadedConfig.pipelines.first
            } catch {
                // Fall back to default configuration with collector's version
                self.pipelineConfig = CollectorConfiguration(version: collector.version)
                self.selectedPipeline = self.pipelineConfig.pipelines.first
            }
        } catch {
            // Fall back to default configuration with collector's version
            self.pipelineConfig = CollectorConfiguration(version: collector.version)
            self.selectedPipeline = self.pipelineConfig.pipelines.first
        }
    }
}
