import SwiftUI

struct MainAppView: View {
    @ObservedObject var collectorManager: CollectorManager
    @ObservedObject var dataGeneratorManager: DataGeneratorManager
    @State private var selectedNavigation: NavigationItem? = .collectors
    @State private var selectedCollector: CollectorInstance? = nil
    @State private var showAddCollectorSheet = false
    @State private var newCollectorName: String = ""
    @State private var selectedRelease: Release? = nil
    @State private var hasFetchedReleases: Bool = false
    @Environment(\.openWindow) private var openWindow
    
    // Navigation items for the sidebar
    enum NavigationItem: Hashable {
        case collectors
        case dataSender
        case collector(UUID)
        
        var id: String {
            switch self {
            case .collectors: return "collectors"
            case .dataSender: return "dataSender"
            case .collector(let id): return "collector-\(id.uuidString)"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar content
            sidebarContent
        } detail: {
            // Detail content
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            // Load releases when the app first appears
            if !hasFetchedReleases {
                collectorManager.getCollectorReleases(repo: "opentelemetry-collector-releases")
                hasFetchedReleases = true
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
            // Main navigation items
            Section("Navigation") {
                NavigationLink(value: NavigationItem.collectors) {
                    Label("Collectors", systemImage: "antenna.radiowaves.left.and.right")
                }
                
                NavigationLink(value: NavigationItem.dataSender) {
                    Label("Data Generator", systemImage: "paperplane")
                }
            }
            
            // List of collectors
            if !collectorManager.collectors.isEmpty {
                Section {
                    ForEach(collectorManager.collectors) { collector in
                        NavigationLink(value: NavigationItem.collector(collector.id)) {
                            CollectorRowView(
                                collector: collector,
                                isRunning: collectorManager.isCollectorRunning(withId: collector.id),
                                isProcessing: collectorManager.isProcessingOperation && collectorManager.activeCollector?.id == collector.id
                            )
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
                            
                            Button("Remove") {
                                collectorManager.removeCollector(withId: collector.id)
                                if case .collector(let id) = selectedNavigation, id == collector.id {
                                    selectedNavigation = .collectors
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Collectors")
                        Spacer()
                        Button(action: { showAddCollectorSheet = true }) {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            } else {
                Section("Collectors") {
                    VStack(spacing: 12) {
                        Text("No collectors configured")
                            .foregroundStyle(.secondary)
                        
                        Button("Add Collector") {
                            showAddCollectorSheet = true
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 220, idealWidth: 250)
        .toolbar {
            ToolbarItem {
                Button(action: { showAddCollectorSheet = true }) {
                    Label("Add Collector", systemImage: "plus")
                }
            }
        }
    }
    
    // MARK: - Detail View
    @ViewBuilder
    private var detailContent: some View {
        switch selectedNavigation {
        case .collectors:
            // Show collector list overview
            CollectorsOverviewView(
                collectorManager: collectorManager,
                onAddCollector: { showAddCollectorSheet = true }
            )
            
        case .dataSender:
            // Show data generator view
            DataGeneratorView(manager: dataGeneratorManager)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case .collector(let collectorId):
            // Show collector details
            if let collector = collectorManager.collectors.first(where: { $0.id == collectorId }) {
                CollectorTabView(collector: collector, manager: collectorManager)
                    .id(collector.id) // Force view refresh when collector changes
            } else {
                // Collector not found
                ContentUnavailableView("Collector Not Found",
                    systemImage: "exclamationmark.triangle",
                    description: Text("The selected collector could not be found.")
                )
            }
            
        case nil:
            // Default view when nothing is selected
            ContentUnavailableView("Select an Item",
                systemImage: "sidebar.left",
                description: Text("Choose an item from the sidebar")
            )
        }
    }
}

// MARK: - Helper Views

struct CollectorRowView: View {
    let collector: CollectorInstance
    let isRunning: Bool
    let isProcessing: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(collector.name)
                    .font(.headline)
                
                Text(collector.version)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isProcessing {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 20, height: 20)
            } else if isRunning {
                Text("Running")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Text("Stopped")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CollectorsOverviewView: View {
    @ObservedObject var collectorManager: CollectorManager
    let onAddCollector: () -> Void
    
    var body: some View {
        VStack {
            if collectorManager.collectors.isEmpty {
                ContentUnavailableView {
                    Label("No Collectors", systemImage: "antenna.radiowaves.left.and.right.slash")
                } description: {
                    Text("Add a collector to get started collecting telemetry data")
                } actions: {
                    Button("Add Collector") {
                        onAddCollector()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), alignment: .top)], spacing: 16) {
                        ForEach(collectorManager.collectors) { collector in
                            CollectorCard(
                                collector: collector,
                                isRunning: collectorManager.isCollectorRunning(withId: collector.id),
                                onStartStop: {
                                    if collector.isRunning {
                                        collectorManager.stopCollector(withId: collector.id)
                                    } else {
                                        collectorManager.startCollector(withId: collector.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CollectorCard: View {
    let collector: CollectorInstance
    let isRunning: Bool
    let onStartStop: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(collector.name)
                        .font(.headline)
                    
                    Text(collector.version)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: onStartStop) {
                    Label(isRunning ? "Stop" : "Start", systemImage: isRunning ? "stop.circle" : "play.circle")
                }
                .buttonStyle(.borderedProminent)
                .tint(isRunning ? .red : .green)
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label {
                        Text("Status:")
                    } icon: {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(isRunning ? .green : .gray)
                            .font(.system(size: 10))
                    }
                    
                    if let pid = collector.pid, isRunning {
                        Label("PID: \(pid)", systemImage: "number")
                            .font(.caption)
                    }
                    
                    if let startTime = collector.startTime, isRunning {
                        Label("Started: \(startTime.formatted(date: .abbreviated, time: .shortened))", systemImage: "clock")
                            .font(.caption)
                    }
                }
                
                Spacer()
                
                if let componentCount = getComponentCount(collector: collector) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Components:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 8) {
                            ComponentCountBadge(count: componentCount.receivers, color: .blue, label: "R")
                            ComponentCountBadge(count: componentCount.processors, color: .green, label: "P")
                            ComponentCountBadge(count: componentCount.exporters, color: .purple, label: "E")
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
    
    private struct ComponentCount {
        let receivers: Int
        let processors: Int
        let exporters: Int
    }
    
    private func getComponentCount(collector: CollectorInstance) -> ComponentCount? {
        guard let components = collector.components else { return nil }
        
        return ComponentCount(
            receivers: components.receivers?.count ?? 0,
            processors: components.processors?.count ?? 0,
            exporters: components.exporters?.count ?? 0
        )
    }
}

struct ComponentCountBadge: View {
    let count: Int
    let color: Color
    let label: String
    
    var body: some View {
        Text("\(count) \(label)")
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .cornerRadius(4)
    }
}

struct CollectorTabView: View {
    let collector: CollectorInstance
    let manager: CollectorManager
    
    var body: some View {
        TabView {
            ConfigEditorView(manager: manager, collectorId: collector.id)
                .tabItem {
                    Label("Configuration", systemImage: "doc.text")
                }
            
            FeatureGatesView(collector: collector, manager: manager)
                .padding()
                .tabItem {
                    Label("Feature Gates", systemImage: "switch.2")
                }
                
            ComponentsView(collector: collector)
                .padding()
                .tabItem {
                    Label("Components", systemImage: "cube.box")
                }
                
            MetricsView()
                .environmentObject(manager.getMetricsManager())
                .padding()
                .tabItem {
                    Label("Metrics", systemImage: "chart.bar")
                }
                
            LogViewer(collector: collector)
                .padding()
                .tabItem {
                    Label("Logs", systemImage: "text.line.last.and.arrowtriangle.forward")
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ComponentsView: View {
    let collector: CollectorInstance
    @State private var isRefreshing = false
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Components")
                    .font(.title)
                    .bold()
                
                Spacer()
                
                if isRefreshing {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Refreshing...")
                            .font(.caption)
                    }
                } else {
                    Button(action: refreshComponents) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
                
            if let components = collector.components {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if let receivers = components.receivers, !receivers.isEmpty {
                            ComponentSection(
                                title: "Receivers",
                                components: receivers,
                                version: collector.version,
                                color: .blue
                            )
                        }
                        
                        if let processors = components.processors, !processors.isEmpty {
                            ComponentSection(
                                title: "Processors",
                                components: processors,
                                version: collector.version,
                                color: .green
                            )
                        }
                        
                        if let exporters = components.exporters, !exporters.isEmpty {
                            ComponentSection(
                                title: "Exporters",
                                components: exporters,
                                version: collector.version,
                                color: .purple
                            )
                        }
                        
                        if let extensions = components.extensions, !extensions.isEmpty {
                            ComponentSection(
                                title: "Extensions",
                                components: extensions,
                                version: collector.version,
                                color: .orange
                            )
                        }
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("No Components", systemImage: "square.stack.3d.up.slash")
                } description: {
                    Text("Component information not available")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    private func refreshComponents() {
        isRefreshing = true
        
        Task {
            do {
                try await CollectorManager.shared.refreshCollectorComponents(withId: collector.id)
                await MainActor.run {
                    isRefreshing = false
                }
            } catch {
                await MainActor.run {
                    isRefreshing = false
                    // You could show an error alert or message here
                }
            }
        }
    }
}

#Preview {
    MainAppView(
        collectorManager: CollectorManager(),
        dataGeneratorManager: DataGeneratorManager.shared
    )
}