import SwiftUI

// MARK: - Navigation Model
enum SidebarItem: Hashable {
    case collector(UUID)
    case otlpReceiver
    case telemetryViewer
    case dataGenerator

    var id: String {
        switch self {
        case .collector(let id): return "collector-\(id.uuidString)"
        case .otlpReceiver: return "otlp-receiver"
        case .telemetryViewer: return "telemetry-viewer"
        case .dataGenerator: return "data-generator"
        }
    }

    var title: String {
        switch self {
        case .collector: return "Collector"
        case .otlpReceiver: return "OTLP Receiver"
        case .telemetryViewer: return "Telemetry Viewer"
        case .dataGenerator: return "Data Generator"
        }
    }

    var iconName: String {
        switch self {
        case .collector: return "server.rack"
        case .otlpReceiver: return "antenna.radiowaves.left.and.right"
        case .telemetryViewer: return "chart.line.uptrend.xyaxis"
        case .dataGenerator: return "waveform.path.ecg"
        }
    }
}

struct MainAppView: View {
    @Environment(AppContainer.self) private var container
    @State private var selectedItem: SidebarItem? = nil
    @State private var showInspector = true
    @State private var showAddCollectorSheet = false
    @State private var newCollectorName: String = ""
    @State private var selectedRelease: Release? = nil
    @State private var hasFetchedReleases: Bool = false
    @Environment(\.openWindow) private var openWindow
        
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedItem)
        } detail: {
            DetailView(item: selectedItem)
                .inspector(isPresented: $showInspector) {
                    InspectorView(item: selectedItem)
                        .inspectorColumnWidth(min: 180, ideal: 280, max: 360)
                        .databaseContext(container.databaseContext!)
                }
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button(action: { showAddCollectorSheet = true }) {
                            Label("Add Collector", systemImage: "plus")
                        }
                        .help("Add Collector")
                        
                        Button(action: { showInspector.toggle() }) {
                            Label("Inspector", systemImage: "sidebar.right")
                        }
                    }
                }
        }
        .navigationSplitViewStyle(.automatic)
        .sheet(isPresented: $showAddCollectorSheet) {
            AddCollectorSheet(
                manager: container.collectorManager,
                name: $newCollectorName,
                selectedRelease: $selectedRelease
            )
            .frame(minWidth: 500, minHeight: 400)
        }
        .onAppear {
            // Load releases when the app first appears
            if !hasFetchedReleases {
                Task {
                    await container.collectorManager.getCollectorReleases(repo: "opentelemetry-collector-releases")
                }
                hasFetchedReleases = true
            }
            
            // Select first collector by default (store-backed list)
            if selectedItem == nil && !container.collectorsViewModel.items.isEmpty {
                selectedItem = .collector(container.collectorsViewModel.items.first!.id)
            }
        }
    }
}
