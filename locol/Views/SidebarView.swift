import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    @Environment(AppContainer.self) private var container
    @State private var serverRunning = false
    
    var body: some View {
        ZStack {
            // Background for proper sidebar styling
            Color(NSColor.controlBackgroundColor)
                .ignoresSafeArea()
            
            List(selection: $selection) {
            // COLLECTORS SECTION
            Section {
                if container.collectorManager.collectors.isEmpty {
                    // Empty state
                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundStyle(.tertiary)
                        Text("No collectors")
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                    .font(.caption)
                    .padding(.vertical, 4)
                } else {
                    ForEach(container.collectorManager.collectors) { collector in
                        Label {
                            HStack {
                                Text(collector.name)
                                Spacer()
                                if collector.isRunning {
                                    Circle()
                                        .fill(.green)
                                        .frame(width: 6, height: 6)
                                }
                            }
                        } icon: {
                            Image(systemName: "server.rack")
                                .foregroundStyle(collector.isRunning ? .green : .primary)
                        }
                        .tag(SidebarItem.collector(collector.id))
                        .contextMenu {
                            Button(collector.isRunning ? "Stop Collector" : "Start Collector") {
                                toggleCollector(collector)
                            }
                            
                            Divider()
                            
                            Button("Delete Collector", role: .destructive) {
                                deleteCollector(collector)
                            }
                        }
                    }
                }
            } header: {
                Text("COLLECTORS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            
            // SERVICES SECTION
            Section {
                Label("OTLP Receiver", systemImage: "antenna.radiowaves.left.and.right")
                    .tag(SidebarItem.otlpReceiver)
                    .badge(serverRunning ? "Active" : nil)
                
                Label("Telemetry Viewer", systemImage: "chart.line.uptrend.xyaxis")
                    .tag(SidebarItem.telemetryViewer)
                    .badge(container.viewer.collectorStats.reduce(0) { $0 + $1.spanCount + $1.metricCount + $1.logCount } > 0 ? "Data" : nil)
            } header: {
                Text("SERVICES")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            
            // TOOLS SECTION
            Section {
                Label("Data Generator", systemImage: "waveform.path.ecg")
                    .tag(SidebarItem.dataGenerator)
                
                Label("SQL Query", systemImage: "terminal")
                    .tag(SidebarItem.sqlQuery)
            } header: {
                Text("TOOLS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("locol")
        .task {
            serverRunning = await container.server.isRunning()
        }
    }
    
    // MARK: - Helper Methods
    
    private func toggleCollector(_ collector: CollectorInstance) {
        if collector.isRunning {
            container.collectorManager.stopCollector(withId: collector.id)
        } else {
            container.collectorManager.startCollector(withId: collector.id)
        }
    }
    
    private func deleteCollector(_ collector: CollectorInstance) {
        container.collectorManager.removeCollector(withId: collector.id)
        if case .collector(let id) = selection, id == collector.id {
            selection = nil
        }
    }
}