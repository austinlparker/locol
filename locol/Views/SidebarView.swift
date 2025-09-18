import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    @Environment(AppContainer.self) private var container
    @State private var serverRunning = false
    private let selectedRowColor = Color.accentColor.opacity(0.15)
    
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
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selection = .collector(summary.id)
                        }
                        .listRowBackground(highlight(for: .collector(summary.id)))
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

            Section {
                Label("Telemetry Viewer", systemImage: "chart.line.uptrend.xyaxis")
                    .tag(SidebarItem.telemetryViewer)
                    .badge(container.viewer.collectorStats.reduce(0) { $0 + $1.spanCount + $1.metricCount + $1.logCount } > 0 ? "Data" : nil)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selection = .telemetryViewer
                    }
                    .listRowBackground(highlight(for: .telemetryViewer))

                Label("OTLP Receiver", systemImage: "antenna.radiowaves.left.and.right")
                    .tag(SidebarItem.otlpReceiver)
                    .badge(serverRunning ? "Active" : nil)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selection = .otlpReceiver
                    }
                    .listRowBackground(highlight(for: .otlpReceiver))

                Label("Data Generator", systemImage: "waveform.path.ecg")
                    .tag(SidebarItem.dataGenerator)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selection = .dataGenerator
                    }
                    .listRowBackground(highlight(for: .dataGenerator))
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

    private func highlight(for item: SidebarItem) -> Color {
        isSelected(item) ? selectedRowColor : Color.clear
    }

    private func isSelected(_ item: SidebarItem) -> Bool {
        guard let selection else { return false }
        switch (item, selection) {
        case let (.collector(lhs), .collector(rhs)):
            return lhs == rhs
        case (.telemetryViewer, .telemetryViewer),
             (.otlpReceiver, .otlpReceiver),
             (.dataGenerator, .dataGenerator):
            return true
        default:
            return false
        }
    }
}
