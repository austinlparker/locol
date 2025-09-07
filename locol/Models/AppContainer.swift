import Foundation
import Observation

@MainActor
@Observable
final class AppContainer {
    let storage: TelemetryStorage
    let settings: OTLPReceiverSettings
    let server: OTLPServer
    let viewer: TelemetryViewer
    let snippetManager: ConfigSnippetManager
    let collectorManager: CollectorManager
    
    init() {
        self.storage = TelemetryStorage()
        self.settings = OTLPReceiverSettings()
        self.server = OTLPServer(storage: storage, settings: settings)
        self.viewer = TelemetryViewer(storage: storage)
        self.snippetManager = ConfigSnippetManager(settings: settings)
        self.collectorManager = CollectorManager(settings: settings, storage: storage)
    }
}
