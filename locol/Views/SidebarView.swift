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
                if container.collectorsViewModel.items.isEmpty {
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
                    ForEach(container.collectorsViewModel.items, id: \.id) { summary in
                        Label {
                            HStack {
                                Text(summary.name)
                                Spacer()
                                if summary.isRunning {
                                    Circle()
                                        .fill(.green)
                                        .frame(width: 6, height: 6)
                                }
                            }
                        } icon: {
                            Image(systemName: "server.rack")
                                .foregroundStyle(summary.isRunning ? .green : .primary)
                        }
                        .tag(SidebarItem.collector(summary.id))
                        .contextMenu {
                            Button(summary.isRunning ? "Stop Collector" : "Start Collector") {
                                toggleCollector(summary)
                            }
                            
                            Divider()
                            
                            Button("Delete Collector", role: .destructive) {
                                deleteCollector(summary)
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
    
    private func toggleCollector(_ summary: CollectorSummary) {
        if summary.isRunning {
            container.collectorManager.stopCollector(withId: summary.id)
        } else {
            container.collectorManager.startCollector(withId: summary.id)
        }
    }
    
    private func deleteCollector(_ summary: CollectorSummary) {
        container.collectorManager.removeCollector(withId: summary.id)
        if case .collector(let sel) = selection, sel == summary.id {
            selection = nil
        }
    }
}
