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
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status indicator and basic info
            HStack(alignment: .center, spacing: 16) {
                Circle()
                    .fill(collector.isRunning ? .green : .red)
                    .frame(width: 8, height: 8)
                
                Text(collector.isRunning ? "Running" : "Stopped")
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button(collector.isRunning ? "Stop" : "Start", action: onStartStop)
                    .tint(collector.isRunning ? .red : .green)
            }
            
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("PID")
                        .foregroundStyle(.secondary)
                    if let pid = collector.pid {
                        Text(String(format: "%d", pid))
                            .font(.system(.body, design: .monospaced))
                    } else {
                        Text("N/A")
                            .foregroundStyle(.secondary)
                    }
                }
                
                GridRow {
                    Text("Config Path")
                        .foregroundStyle(.secondary)
                    Text(collector.configPath)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
                
                GridRow {
                    Text("Uptime")
                        .foregroundStyle(.secondary)
                    Text(formatUptime(since: collector.startTime))
                        .font(.system(.body, design: .monospaced))
                        .id(currentTime)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
    
    private func formatUptime(since date: Date?) -> String {
        guard let date = date else { return "N/A" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 3
        
        return formatter.string(from: date, to: currentTime) ?? "N/A"
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
                    
                    Button("View Metrics & Logs") {
                        openWindow(id: "MetricsLogViewerWindow", value: collector.id)
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
