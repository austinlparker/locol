import SwiftUI

struct DetailView: View {
    let item: SidebarItem?
    @Environment(AppContainer.self) private var container
    
    var body: some View {
        Group {
            switch item {
            case .collector(let id):
                CollectorDetailView(collectorId: id)
                
            case .otlpReceiver:
                if #available(macOS 15.0, *) {
                    OTLPReceiverView(server: container.server, settings: container.settings, viewer: container.viewer)
                } else {
                    ContentUnavailableView {
                        Label("Unavailable", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text("OTLP Receiver requires macOS 15.0 or newer.")
                    }
                }
                
            case .telemetryViewer:
                TelemetryView(collectorManager: container.collectorManager, viewer: container.viewer)
                
            case .dataGenerator:
                DataGeneratorView()
                
            case .sqlQuery:
                SQLQueryView(collectorName: container.viewer.selectedCollector, viewer: container.viewer)
                
            case nil:
                ContentUnavailableView(
                    "Select an Item",
                    systemImage: "sidebar.left",
                    description: Text("Choose a collector or tool from the sidebar to get started")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CollectorDetailView: View {
    let collectorId: UUID
    @Environment(AppContainer.self) private var container
    @State private var record: CollectorRecord? = nil
    
    var body: some View {
        PipelineDesignerView(collectorId: collectorId)
            .navigationTitle(record?.name ?? "Collector")
            .navigationSubtitle(record?.version ?? "")
            .task {
                if record == nil {
                    record = try? await container.collectorStore.getCollector(collectorId)
                }
            }
    }
}
