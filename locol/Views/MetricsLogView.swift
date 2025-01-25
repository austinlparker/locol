import SwiftUI

struct MetricsLogView: View {
    let collector: CollectorInstance
    let manager: CollectorManager
    let metricsManager: MetricsManager
    @State private var selectedTab = 0
    @State private var showError = false
    @State private var errorMessage: String?
    
    init(collector: CollectorInstance, manager: CollectorManager, metricsManager: MetricsManager = .shared) {
        self.collector = collector
        self.manager = manager
        self.metricsManager = metricsManager
    }
    
    private var metricsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if collector.isRunning {
                MetricsView(viewModel: MetricsViewModel(manager: metricsManager))
            } else {
                ContentUnavailableView {
                    Label("Collector Not Running", systemImage: "chart.line.downtrend.xyaxis")
                } description: {
                    Text("Start the collector to view metrics")
                }
                .accessibilityLabel("Collector status: not running")
            }
        }
        .padding()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            CollectorStatusView(
                collector: collector,
                onStartStop: handleCollectorAction
            )
            .padding()
            
            TabView(selection: $selectedTab) {
                metricsView
                    .tabItem {
                        Label("Metrics", systemImage: "chart.xyaxis.line")
                    }
                    .tag(0)
                
                LogViewer(collector: collector)
                    .padding()
                    .tabItem {
                        Label("Logs", systemImage: "text.alignleft")
                    }
                    .tag(1)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .alert("Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }
    
    private func handleCollectorAction() {
        if collector.isRunning {
            manager.stopCollector(withId: collector.id)
        } else {
            manager.startCollector(withId: collector.id)
        }
    }
} 