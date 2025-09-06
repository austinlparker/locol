import SwiftUI

struct MainAppView: View {
    let collectorManager: CollectorManager
    @State private var selectedNavigation: NavigationItem? = nil
    @State private var selectedCollector: CollectorInstance? = nil
    @State private var showAddCollectorSheet = false
    @State private var newCollectorName: String = ""
    @State private var selectedRelease: Release? = nil
    @State private var hasFetchedReleases: Bool = false
    @State private var searchText: String = ""
    @Environment(\.openWindow) private var openWindow
    
    // Navigation items for the sidebar
    enum NavigationItem: Hashable {
        case dataSender
        case otlpReceiver
        case telemetry
        case collector(UUID)
        
        var id: String {
            switch self {
            case .dataSender: return "dataSender"
            case .otlpReceiver: return "otlpReceiver"
            case .telemetry: return "telemetry"
            case .collector(let id): return "collector-\(id.uuidString)"
            }
        }
        
        var title: String {
            switch self {
            case .dataSender: return "Data Generator"
            case .otlpReceiver: return "OTLP Receiver"
            case .telemetry: return "Telemetry"
            case .collector: return "Collector"
            }
        }
        
        var iconName: String {
            switch self {
            case .dataSender: return "paperplane"
            case .otlpReceiver: return "tray.and.arrow.down"
            case .telemetry: return "chart.line.uptrend.xyaxis"
            case .collector: return "antenna.radiowaves.left.and.right"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar content with Console-style layout
            sidebarContent
        } detail: {
            // Detail content with toolbar
            // Main detail content
            detailContent
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        toolbarButtons
                    }
                    
                    ToolbarItem(placement: .principal) {
                        searchField
                    }
                }
        }
        .navigationSplitViewStyle(.balanced)
        .containerBackground(.thickMaterial, for: .window)
        .onAppear {
            // Load releases when the app first appears
            if !hasFetchedReleases {
                Task {
                    await collectorManager.getCollectorReleases(repo: "opentelemetry-collector-releases")
                }
                hasFetchedReleases = true
            }
            
            // Select first collector by default
            if selectedNavigation == nil && !collectorManager.collectors.isEmpty {
                selectedNavigation = .collector(collectorManager.collectors.first!.id)
                selectedCollector = collectorManager.collectors.first
            }
        }
        .onChange(of: selectedNavigation) { _, newValue in
            // Update selected collector when navigation changes
            if case .collector(let collectorId) = newValue {
                selectedCollector = collectorManager.collectors.first { $0.id == collectorId }
            } else {
                selectedCollector = nil
            }
        }
        .sheet(isPresented: $showAddCollectorSheet) {
            AddCollectorSheet(
                manager: collectorManager, 
                name: $newCollectorName,
                selectedRelease: $selectedRelease
            )
            .frame(minWidth: 500, minHeight: 400)
        }
    }
    
    // MARK: - Sidebar View
    private var sidebarContent: some View {
        List(selection: $selectedNavigation) {
            // Collectors section (primary, like Console's devices)
            Section {
                if !collectorManager.collectors.isEmpty {
                    ForEach(filteredCollectors) { collector in
                        NavigationLink(value: NavigationItem.collector(collector.id)) {
                            collectorRowContent(for: collector)
                        }
                        .contextMenu {
                            Button(collector.isRunning ? "Stop" : "Start") {
                                if collector.isRunning {
                                    collectorManager.stopCollector(withId: collector.id)
                                } else {
                                    collectorManager.startCollector(withId: collector.id)
                                }
                            }
                            
                            Divider()
                            
                            Button("Delete", role: .destructive) {
                                collectorManager.removeCollector(withId: collector.id)
                                if case .collector(let id) = selectedNavigation, id == collector.id {
                                    selectedNavigation = nil
                                }
                            }
                        }
                    }
                } else {
                    Button(action: { showAddCollectorSheet = true }) {
                        HStack {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(.secondary)
                            Text("Add Collector")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                HStack {
                    Text("COLLECTORS")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: { showAddCollectorSheet = true }) {
                        Image(systemName: "plus")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
            
            // Tools section (secondary, like Console's categories)
            Section {
                NavigationLink(value: NavigationItem.dataSender) {
                    Label("Data Generator", systemImage: "paperplane")
                        .foregroundStyle(.primary)
                }
                
                NavigationLink(value: NavigationItem.otlpReceiver) {
                    Label("OTLP Receiver", systemImage: "tray.and.arrow.down")
                        .foregroundStyle(.primary)
                }
                
                NavigationLink(value: NavigationItem.telemetry) {
                    Label("Telemetry Viewer", systemImage: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(.primary)
                }
            } header: {
                Text("TOOLS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 240)
        .background(Material.regular)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Helper Properties and Functions
    
    @ViewBuilder
    private var toolbarButtons: some View {
        // Refresh button
        Button(action: handleRefresh) {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
        .conditionalGlassButtonStyle()
        
        // Clear button (only show for collector views)
        if shouldShowClearButton {
            Button(action: handleClear) {
                Label("Clear", systemImage: "trash")
            }
            .conditionalGlassButtonStyle()
            .disabled(selectedCollector == nil)
        }
        
        // Start/Stop button
        Button(action: handleStartStop) {
            HStack(spacing: 6) {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: isCollectorRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 12, weight: .medium))
                }
                
                Text(startStopButtonTitle)
                    .font(.system(size: 13, weight: .medium))
            }
        }
        .conditionalGlassProminentButtonStyle()
        .disabled(selectedCollector == nil || isProcessing)
    }
    
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 13))
            
            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
        }
        .frame(width: 180)
    }
    
    private var shouldShowClearButton: Bool {
        guard let selectedCollector = selectedCollector else { return false }
        return selectedNavigation == .collector(selectedCollector.id)
    }
    
    private var isCollectorRunning: Bool {
        guard let collector = selectedCollector else { return false }
        return collectorManager.isCollectorRunning(withId: collector.id)
    }
    
    private var isProcessing: Bool {
        guard let collector = selectedCollector else { return false }
        return collectorManager.isProcessingOperation && collectorManager.activeCollector?.id == collector.id
    }
    
    private var startStopButtonTitle: String {
        if isProcessing {
            return isCollectorRunning ? "Stopping" : "Starting"
        } else {
            return isCollectorRunning ? "Stop" : "Start"
        }
    }
    
    private func collectorRowContent(for collector: CollectorInstance) -> some View {
        CollectorRowView(
            collector: collector,
            isRunning: collectorManager.isCollectorRunning(withId: collector.id),
            isProcessing: collectorManager.isProcessingOperation && collectorManager.activeCollector?.id == collector.id
        )
    }
    
    private var filteredCollectors: [CollectorInstance] {
        if searchText.isEmpty {
            return collectorManager.collectors
        } else {
            return collectorManager.collectors.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func handleStartStop() {
        guard let collector = selectedCollector else { return }
        
        if collectorManager.isCollectorRunning(withId: collector.id) {
            collectorManager.stopCollector(withId: collector.id)
        } else {
            collectorManager.startCollector(withId: collector.id)
        }
    }
    
    private func handleClear() {
        // Clear collector logs or data
        // This could be implemented based on what clearing means for each collector
    }
    
    private func handleRefresh() {
        // Refresh collector status or data
        // This could trigger a status update or data refresh
    }
    
    // MARK: - Detail View
    @ViewBuilder
    private var detailContent: some View {
        switch selectedNavigation {
        case .dataSender:
            // Show data generator view
            DataGeneratorView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        
        case .otlpReceiver:
            // Show OTLP receiver view
            if #available(macOS 15.0, *) {
                OTLPReceiverView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView {
                    Label("Unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("OTLP Receiver requires macOS 15.0 or newer.")
                }
            }
            
        case .telemetry:
            // Show telemetry data view
            TelemetryView(collectorManager: collectorManager)
            
        case .collector(let collectorId):
            // Show collector details
            if let collector = collectorManager.collectors.first(where: { $0.id == collectorId }) {
                ConfigEditorView(manager: collectorManager, collectorId: collector.id)
                    .id(collector.id) // Force view refresh when collector changes
            } else {
                // Collector not found
                ContentUnavailableView("Collector Not Found",
                    systemImage: "exclamationmark.triangle",
                    description: Text("The selected collector could not be found.")
                )
            }
            
        case .none:
            // Default view when nothing is selected
            if !collectorManager.collectors.isEmpty {
                ContentUnavailableView("Select a Collector",
                    systemImage: "sidebar.left",
                    description: Text("Choose a collector from the sidebar to view its details")
                )
            } else {
                ContentUnavailableView {
                    Label("No Collectors", systemImage: "antenna.radiowaves.left.and.right")
                } description: {
                    Text("Add your first OpenTelemetry collector to get started")
                } actions: {
                    Button("Add Collector") {
                        showAddCollectorSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
