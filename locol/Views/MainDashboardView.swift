import SwiftUI
import Foundation
import Observation

// Import models
typealias Collector = CollectorInstance

enum NavigationDestination: Hashable {
    case collector(CollectorInstance)
    case dataGenerator
    case dataExplorer
    
    static func == (lhs: NavigationDestination, rhs: NavigationDestination) -> Bool {
        switch (lhs, rhs) {
        case (.collector(let c1), .collector(let c2)):
            return c1.id == c2.id
        case (.dataGenerator, .dataGenerator):
            return true
        case (.dataExplorer, .dataExplorer):
            return true
        default:
            return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .collector(let collector):
            hasher.combine("collector")
            hasher.combine(collector.id)
        case .dataGenerator:
            hasher.combine("dataGenerator")
        case .dataExplorer:
            hasher.combine("dataExplorer")
        }
    }
}

@Observable
final class DashboardViewModel {
    let appState: AppState
    let dataGeneratorManager: DataGeneratorManager
    
    var navigationPath = NavigationPath()
    var selectedDestination: NavigationDestination?
    var isShowingError = false
    var error: Error?
    var isShowingAddCollector = false
    var newCollectorName = ""
    var selectedRelease: Release?
    
    init(appState: AppState, dataGeneratorManager: DataGeneratorManager) {
        self.appState = appState
        self.dataGeneratorManager = dataGeneratorManager
    }
}

struct MainDashboardView: View {
    let appState: AppState
    let dataGeneratorManager: DataGeneratorManager
    let terminationHandler: AppTerminationHandler
    @State private var viewModel: DashboardViewModel
    
    init(appState: AppState, dataGeneratorManager: DataGeneratorManager, terminationHandler: AppTerminationHandler) {
        self.appState = appState
        self.dataGeneratorManager = dataGeneratorManager
        self.terminationHandler = terminationHandler
        self._viewModel = State(initialValue: DashboardViewModel(appState: appState, dataGeneratorManager: dataGeneratorManager))
    }
    
    var body: some View {
        NavigationSplitView {
            SidebarContent(viewModel: viewModel)
        } detail: {
            DetailContent(viewModel: viewModel)
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.isShowingError },
            set: { viewModel.isShowingError = $0 }
        ), presenting: viewModel.error) { _ in
            Button("OK") {}
        } message: { error in
            Text(error.localizedDescription)
        }
        .sheet(isPresented: Binding(
            get: { viewModel.isShowingAddCollector },
            set: { viewModel.isShowingAddCollector = $0 }
        )) {
            AddCollectorSheet(
                appState: appState,
                name: Binding(
                    get: { viewModel.newCollectorName },
                    set: { viewModel.newCollectorName = $0 }
                ),
                selectedRelease: Binding(
                    get: { viewModel.selectedRelease },
                    set: { viewModel.selectedRelease = $0 }
                )
            )
        }
    }
}

private struct SidebarContent: View {
    @State var viewModel: DashboardViewModel
    
    var body: some View {
        List(selection: Binding(
            get: { viewModel.selectedDestination },
            set: { viewModel.selectedDestination = $0 }
        )) {
            CollectorSection(
                collectors: viewModel.appState.collectors,
                appState: viewModel.appState,
                selectedDestination: Binding(
                    get: { viewModel.selectedDestination },
                    set: { viewModel.selectedDestination = $0 }
                )
            )
            
            ToolsSection(selectedDestination: Binding(
                get: { viewModel.selectedDestination },
                set: { viewModel.selectedDestination = $0 }
            ))
        }
        .navigationTitle("Locol")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { viewModel.isShowingAddCollector = true }) {
                    Label("Add Collector", systemImage: "plus")
                }
            }
        }
    }
}

private struct CollectorSection: View {
    let collectors: [CollectorInstance]
    let appState: AppState
    @Binding var selectedDestination: NavigationDestination?
    
    var body: some View {
        Section("Collectors") {
            ForEach(collectors) { collector in
                NavigationLink(value: NavigationDestination.collector(collector)) {
                    CollectorRowView(collector: collector, appState: appState)
                }
            }
        }
    }
}

private struct ToolsSection: View {
    @Binding var selectedDestination: NavigationDestination?
    
    var body: some View {
        Section("Tools") {
            NavigationLink(value: NavigationDestination.dataGenerator) {
                Label("Data Generator", systemImage: "waveform.path")
            }
            NavigationLink(value: NavigationDestination.dataExplorer) {
                Label("Data Explorer", systemImage: "magnifyingglass.circle")
            }
        }
    }
}

private struct DetailContent: View {
    @State var viewModel: DashboardViewModel
    
    var body: some View {
        if let selectedDestination = viewModel.selectedDestination {
            switch selectedDestination {
            case .collector(let collector):
                CollectorDetailView(collector: collector, appState: viewModel.appState)
            case .dataGenerator:
                DataGeneratorView()
            case .dataExplorer:
                DataExplorerView(dataExplorer: DataExplorer.shared)
            }
        } else {
            Text("Select an item from the sidebar")
                .foregroundStyle(.secondary)
        }
    }
}

struct CollectorRowView: View {
    let collector: CollectorInstance
    let appState: AppState
    
    var body: some View {
        Label {
            VStack(alignment: .leading) {
                Text(collector.name)
                Text(collector.version)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: appState.runningCollector?.id == collector.id ? "circle.fill" : "circle")
                .foregroundStyle(appState.runningCollector?.id == collector.id ? .green : .red)
        }
    }
}

private struct CollectorDetailView: View {
    let collector: Collector
    let appState: AppState
    @State private var selectedTab = "metrics"
    @State private var isShowingDeleteAlert = false
    
    var isRunning: Bool {
        appState.runningCollector?.id == collector.id
    }
    
    var body: some View {
        NavigationStack {
            Group {
                switch selectedTab {
                case "metrics":
                    if isRunning {
                        ContentUnavailableView {
                            Label("Metrics Coming Soon", systemImage: "chart.line.downtrend.xyaxis")
                        }
                    } else {
                        ContentUnavailableView {
                            Label("Collector Not Running", systemImage: "chart.line.downtrend.xyaxis")
                        } description: {
                            Text("Start the collector to view metrics")
                        }
                        .accessibilityLabel("Collector status: not running")
                    }
                case "logs":
                    LogViewer(collector: collector)
                        .padding()
                case "config":
                    ConfigEditorView(appState: appState, collectorId: collector.id)
                case "components":
                    ComponentsView(collector: collector)
                case "settings":
                    Form {
                        Section("Feature Gates") {
                            FeatureGatesView(collector: collector, appState: appState)
                        }
                        
                        Section("Danger Zone") {
                            Button(role: .destructive) {
                                isShowingDeleteAlert = true
                            } label: {
                                Label("Delete Collector", systemImage: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .formStyle(.grouped)
                    .padding()
                default:
                    EmptyView()
                }
            }
            .navigationTitle(collector.name)
            .toolbar {
                // Leading toolbar group for navigation
                ToolbarItemGroup(placement: .navigation) {
                    Button {
                        selectedTab = "metrics"
                    } label: {
                        Image(systemName: "chart.xyaxis.line")
                    }
                    .help("View Metrics")
                    .buttonStyle(.borderless)
                    .foregroundStyle(selectedTab == "metrics" ? .primary : .secondary)
                    
                    Button {
                        selectedTab = "logs"
                    } label: {
                        Image(systemName: "text.alignleft")
                    }
                    .help("View Logs")
                    .buttonStyle(.borderless)
                    .foregroundStyle(selectedTab == "logs" ? .primary : .secondary)
                    
                    Button {
                        selectedTab = "config"
                    } label: {
                        Image(systemName: "doc.text")
                    }
                    .help("Edit Configuration")
                    .buttonStyle(.borderless)
                    .foregroundStyle(selectedTab == "config" ? .primary : .secondary)
                    
                    Button {
                        selectedTab = "components"
                    } label: {
                        Image(systemName: "square.3.layers.3d")
                    }
                    .help("View Components")
                    .buttonStyle(.borderless)
                    .foregroundStyle(selectedTab == "components" ? .primary : .secondary)
                    
                    Button {
                        selectedTab = "settings"
                    } label: {
                        Image(systemName: "gear")
                    }
                    .help("Settings")
                    .buttonStyle(.borderless)
                    .foregroundStyle(selectedTab == "settings" ? .primary : .secondary)
                }
                
                // Primary action for start/stop
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            if isRunning {
                                appState.stopCollector(withId: collector.id)
                            } else {
                                await appState.startCollector(withId: collector.id)
                            }
                        }
                    } label: {
                        Image(systemName: isRunning ? "stop.circle.fill" : "play.circle.fill")
                            .foregroundStyle(isRunning ? .red : .green)
                    }
                    .help(isRunning ? "Stop Collector" : "Start Collector")
                }
                
                // Status indicator
                ToolbarItem(placement: .automatic) {
                    if isRunning {
                        Text("Running")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
        }
        .alert("Delete Collector", isPresented: $isShowingDeleteAlert) {
            Button("Delete", role: .destructive) {
                appState.removeCollector(withId: collector.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \(collector.name)? This action cannot be undone.")
        }
    }
}
