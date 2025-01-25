import SwiftUI
import Foundation
import Observation

// Import models
typealias Collector = CollectorInstance

enum NavigationDestination: Hashable {
    case collector(CollectorInstance)
    case dataGenerator
    case settings
    case metrics
    
    static func == (lhs: NavigationDestination, rhs: NavigationDestination) -> Bool {
        switch (lhs, rhs) {
        case (.collector(let c1), .collector(let c2)):
            return c1.id == c2.id
        case (.dataGenerator, .dataGenerator),
             (.settings, .settings),
             (.metrics, .metrics):
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
        case .settings:
            hasher.combine("settings")
        case .metrics:
            hasher.combine("metrics")
        }
    }
}

@Observable
final class DashboardViewModel {
    var selectedNavigation: NavigationDestination?
}

struct MainDashboardView: View {
    let collectorManager: CollectorManager
    let dataGeneratorManager: DataGeneratorManager
    let terminationHandler: AppTerminationHandler
    
    @State private var selectedDestination: NavigationDestination?
    @State private var isShowingError = false
    @State private var error: Error?
    @State private var isShowingAddCollector = false
    @State private var newCollectorName = ""
    @State private var selectedRelease: Release?
    
    var body: some View {
        NavigationSplitView {
            SidebarContent(
                collectorManager: collectorManager,
                selectedDestination: $selectedDestination,
                onAddCollector: { isShowingAddCollector = true }
            )
        } detail: {
            DetailContent(
                selectedDestination: selectedDestination,
                collectorManager: collectorManager,
                dataGeneratorManager: dataGeneratorManager
            )
        }
        .alert("Error", isPresented: $isShowingError, presenting: error) { _ in
            Button("OK") {}
        } message: { error in
            Text(error.localizedDescription)
        }
        .sheet(isPresented: $isShowingAddCollector) {
            AddCollectorView(
                isPresented: $isShowingAddCollector,
                manager: collectorManager,
                name: $newCollectorName,
                selectedRelease: $selectedRelease
            )
        }
    }
}

private struct SidebarContent: View {
    let collectorManager: CollectorManager
    @Binding var selectedDestination: NavigationDestination?
    let onAddCollector: () -> Void
    
    var body: some View {
        List(selection: $selectedDestination) {
            CollectorSection(
                collectors: collectorManager.collectors,
                selectedDestination: $selectedDestination
            )
            
            ToolsSection(selectedDestination: $selectedDestination)
        }
        .navigationTitle("Locol")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onAddCollector) {
                    Label("Add Collector", systemImage: "plus")
                }
            }
        }
    }
}

private struct CollectorSection: View {
    let collectors: [CollectorInstance]
    @Binding var selectedDestination: NavigationDestination?
    
    var body: some View {
        Section("Collectors") {
            ForEach(collectors) { collector in
                NavigationLink(value: NavigationDestination.collector(collector)) {
                    CollectorRowView(collector: collector)
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
            
            NavigationLink(value: NavigationDestination.metrics) {
                Label("Metrics", systemImage: "chart.xyaxis.line")
            }
            
            NavigationLink(value: NavigationDestination.settings) {
                Label("Settings", systemImage: "gear")
            }
        }
    }
}

private struct DetailContent: View {
    let selectedDestination: NavigationDestination?
    let collectorManager: CollectorManager
    let dataGeneratorManager: DataGeneratorManager
    
    var body: some View {
        if let selectedDestination {
            switch selectedDestination {
            case .collector(let collector):
                CollectorDetailView(collector: collector, collectorManager: collectorManager)
            case .dataGenerator:
                DataGeneratorView()
            case .settings:
                SettingsView(collectorManager: collectorManager)
            case .metrics:
                MetricsView()
            }
        } else {
            Text("Select an item from the sidebar")
                .foregroundStyle(.secondary)
        }
    }
}

struct CollectorRowView: View {
    let collector: CollectorInstance
    
    var body: some View {
        Label {
            VStack(alignment: .leading) {
                Text(collector.name)
                Text(collector.version)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: collector.isRunning ? "circle.fill" : "circle")
                .foregroundStyle(collector.isRunning ? .green : .red)
        }
    }
}

private struct CollectorDetailView: View {
    let collector: Collector
    let collectorManager: CollectorManager
    
    var body: some View {
        TabView {
            MetricsLogView(collector: collector, manager: collectorManager)
                .tabItem {
                    Label("Metrics & Logs", systemImage: "chart.line.uptrend.xyaxis")
                }
            
            ConfigEditorView(manager: collectorManager, collectorId: collector.id)
                .tabItem {
                    Label("Configuration", systemImage: "text.alignleft")
                }
        }
        .navigationTitle(collector.name)
        .toolbar {
            ToolbarItem {
                Button(collector.isRunning ? "Stop" : "Start") {
                    if collector.isRunning {
                        collectorManager.stopCollector(withId: collector.id)
                    } else {
                        collectorManager.startCollector(withId: collector.id)
                    }
                }
            }
        }
    }
}

// Preview
#Preview {
    let collectorManager = CollectorManager()
    let dataGeneratorManager = DataGeneratorManager()
    let terminationHandler = AppTerminationHandler()
    
    return MainDashboardView(
        collectorManager: collectorManager,
        dataGeneratorManager: dataGeneratorManager,
        terminationHandler: terminationHandler
    )
} 
