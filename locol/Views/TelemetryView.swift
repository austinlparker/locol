import SwiftUI

struct TelemetryView: View {
    let collectorManager: CollectorManager?
    let viewer: TelemetryViewer
    
    init(collectorManager: CollectorManager, viewer: TelemetryViewer) {
        self.collectorManager = collectorManager
        self.viewer = viewer
    }
    
    init(collectorName: String, viewer: TelemetryViewer) {
        self.collectorManager = nil
        self.viewer = viewer
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Simplified toolbar for SQL mode only
            sqlModeToolbar
            
            // SQL Query View
            SQLQueryView(collectorName: viewer.selectedCollector, viewer: viewer)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Telemetry")
        .task {
            // Set initial collector selection
            if let collectorManager = collectorManager {
                let runningCollector = collectorManager.collectors.first(where: { $0.isRunning })?.name
                let firstCollector = collectorManager.collectors.first?.name
                viewer.selectedCollector = runningCollector ?? firstCollector ?? "all"
            }
        }
    }
    
    private var sqlModeToolbar: some View {
        HStack {
            // Collector selection (only show when collectorManager is available)
            if collectorManager != nil {
                Menu {
                    Button("All Collectors") {
                        viewer.selectedCollector = "all"
                    }
                    
                    if !viewer.collectorStats.isEmpty {
                        Divider()
                        ForEach(viewer.collectorStats, id: \.collectorName) { stat in
                            Button(stat.collectorName) {
                                viewer.selectedCollector = stat.collectorName
                            }
                        }
                    }
                } label: {
                    Label("Collector: \(viewer.selectedCollector)", systemImage: "server.rack")
                }
            }
            
            Spacer()
            
            // Refresh button
            Button("Refresh Stats", action: {
                Task {
                    await viewer.refreshCollectorStats()
                }
            })
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.background.secondary)
    }
}
