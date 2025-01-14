import SwiftUI

struct CollectorListView: View {
    let collectors: [CollectorInstance]
    @Binding var selectedCollectorId: UUID?
    let onAddCollector: () -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Installed Collectors")
                .font(.headline)
                .padding(.bottom)
            
            List(collectors, selection: $selectedCollectorId) { collector in
                VStack(alignment: .leading) {
                    Text(collector.name)
                        .font(.headline)
                    Text("Version: \(collector.version)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            
            Button("Add Collector") {
                onAddCollector()
            }
            .padding(.top)
        }
        .frame(width: 250)
        .padding()
    }
}

struct CollectorDetailView: View {
    let collector: CollectorInstance
    let manager: CollectorManager
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configuration for \(collector.name)")
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Command Line Arguments")
                    .font(.headline)
                
                TextEditor(text: Binding(
                    get: { collector.commandLineFlags },
                    set: { manager.updateCollectorFlags(withId: collector.id, flags: $0) }
                ))
                .font(.system(.body, design: .monospaced))
                .frame(height: 60)
                .padding(4)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(4)
                
                HStack(spacing: 12) {
                    Button(collector.isRunning ? "Stop" : "Start") {
                        if collector.isRunning {
                            manager.stopCollector(withId: collector.id)
                        } else {
                            manager.startCollector(withId: collector.id)
                        }
                    }
                    .tint(collector.isRunning ? .red : .green)
                    
                    Button("Edit Config") {
                        openWindow(id: "ConfigEditorWindow", value: collector.id)
                    }
                    
                    Button("Logs") {
                        openWindow(id: "LogViewerWindow", value: collector.id)
                    }
                    
                    Spacer()
                    
                    Button("Remove") {
                        manager.removeCollector(withId: collector.id)
                    }
                    .tint(.red)
                }
            }
            .padding(.bottom, 8)
            
            if collector.isRunning {
                Text("Metrics")
                    .font(.headline)
                
                MetricsView(metricsManager: manager.getMetricsManager(forCollectorId: collector.id))
                    .frame(maxHeight: .infinity)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct SettingsView: View {
    @ObservedObject var manager: CollectorManager
    @State private var isLoadingReleases: Bool = false
    @State private var hasFetchedReleases: Bool = false
    @State private var selectedCollectorId: UUID? = nil
    @State private var showingAddCollector: Bool = false
    @State private var newCollectorName: String = ""
    @State private var selectedRelease: Release? = nil
    
    var body: some View {
        HStack {
            CollectorListView(
                collectors: manager.collectors,
                selectedCollectorId: $selectedCollectorId,
                onAddCollector: { showingAddCollector = true }
            )
            
            Divider()
            
            if let collectorId = selectedCollectorId,
               let collector = manager.collectors.first(where: { $0.id == collectorId }) {
                CollectorDetailView(collector: collector, manager: manager)
            } else {
                Text("Select a collector to configure")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 800, minHeight: 400)
        .sheet(isPresented: $showingAddCollector) {
            AddCollectorView(
                isPresented: $showingAddCollector,
                manager: manager,
                name: $newCollectorName,
                selectedRelease: $selectedRelease
            )
        }
        .onAppear {
            if !hasFetchedReleases {
                fetchReleases()
                hasFetchedReleases = true
            }
        }
    }
    
    private func fetchReleases(forceRefresh: Bool = false) {
        isLoadingReleases = true
        manager.getCollectorReleases(repo: "opentelemetry-collector-releases", forceRefresh: forceRefresh) {
            isLoadingReleases = false
        }
    }
}
