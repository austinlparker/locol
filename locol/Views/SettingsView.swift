import SwiftUI

struct CollectorListView: View {
    let collectors: [CollectorInstance]
    @Binding var selectedCollectorId: UUID?
    let onAddCollector: () -> Void
    let onRemoveCollector: (UUID) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedCollectorId) {
                ForEach(collectors) { collector in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(collector.name)
                            .font(.headline)
                        Text("Version: \(collector.version)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .tag(collector.id)
                }
            }
            .listStyle(.sidebar)
            
            Divider()
            
            // Bottom toolbar
            HStack {
                Button(action: onAddCollector) {
                    Label("Add Collector", systemImage: "plus")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .keyboardShortcut("n", modifiers: .command)
                .help("Add Collector")
                
                Button(action: {
                    if let id = selectedCollectorId {
                        onRemoveCollector(id)
                        selectedCollectorId = nil
                    }
                }) {
                    Label("Remove Collector", systemImage: "minus")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .keyboardShortcut(.delete, modifiers: [])
                .help("Remove Selected Collector")
                .disabled(selectedCollectorId == nil)
                
                Spacer()
            }
            .padding(6)
            .background(.bar)
        }
        .frame(width: 220)
    }
}

struct CollectorStatusView: View {
    let collector: CollectorInstance
    let onStartStop: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status indicator and basic info
            HStack(alignment: .center, spacing: 16) {
                Label(
                    collector.isRunning ? "Running" : "Stopped",
                    systemImage: collector.isRunning ? "circle.fill" : "circle"
                )
                .foregroundStyle(collector.isRunning ? .green : .secondary)
                
                Divider()
                    .frame(height: 20)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(collector.name)
                        .font(.headline)
                    Text("Version \(collector.version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(collector.isRunning ? "Stop" : "Start", action: onStartStop)
                    .tint(collector.isRunning ? .red : .green)
            }
            
            // Additional details
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Local Path")
                        .foregroundStyle(.secondary)
                    Text(collector.localPath)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
                
                if !collector.commandLineFlags.isEmpty {
                    GridRow {
                        Text("Flags")
                            .foregroundStyle(.secondary)
                        Text(collector.commandLineFlags)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                
                if collector.isRunning {
                    GridRow {
                        Text("PID")
                            .foregroundStyle(.secondary)
                        Text("\(collector.pid ?? 0)")
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    
                    GridRow {
                        Text("Uptime")
                            .foregroundStyle(.secondary)
                        Text(formatUptime(since: collector.startTime))
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func formatUptime(since date: Date?) -> String {
        guard let date = date else { return "N/A" }
        let interval = Date().timeIntervalSince(date)
        
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60
        
        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
        } else {
            return String(format: "%dm %02ds", minutes, seconds)
        }
    }
}

struct CollectorDetailView: View {
    let collector: CollectorInstance
    let manager: CollectorManager
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Status section
                CollectorStatusView(
                    collector: collector,
                    onStartStop: {
                        if collector.isRunning {
                            manager.stopCollector(withId: collector.id)
                        } else {
                            manager.startCollector(withId: collector.id)
                        }
                    }
                )
                
                // Action buttons
                HStack(spacing: 8) {
                    Button("Edit Config") {
                        openWindow(id: "ConfigEditorWindow", value: collector.id)
                    }
                    
                    Button("View Logs") {
                        openWindow(id: "LogViewerWindow", value: collector.id)
                    }
                }
                
                Divider()
                
                // Command line arguments section
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
                    .accessibilityLabel("Command line arguments for collector")
                }
                
                if collector.isRunning {
                    Divider()
                    
                    // Metrics section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Metrics")
                            .font(.headline)
                        
                        MetricsView(metricsManager: manager.getMetricsManager(forCollectorId: collector.id))
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .background(Color(NSColor.controlBackgroundColor))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        HStack(spacing: 0) {
            CollectorListView(
                collectors: manager.collectors,
                selectedCollectorId: $selectedCollectorId,
                onAddCollector: { showingAddCollector = true },
                onRemoveCollector: { id in
                    manager.removeCollector(withId: id)
                }
            )
            
            Divider()
            
            if let collectorId = selectedCollectorId,
               let collector = manager.collectors.first(where: { $0.id == collectorId }) {
                CollectorDetailView(collector: collector, manager: manager)
            } else {
                ContentUnavailableView("No Collector Selected", 
                    systemImage: "square.dashed",
                    description: Text("Select a collector to view its details")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingAddCollector) {
            AddCollectorSheet(
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
