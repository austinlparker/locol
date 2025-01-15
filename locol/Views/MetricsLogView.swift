import SwiftUI

struct MetricsLogView: View {
    let collector: CollectorInstance
    let manager: CollectorManager
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Status section at the top
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
            .padding()
            
            // Tabs below status
            TabView(selection: $selectedTab) {
                // Metrics tab
                VStack(alignment: .leading, spacing: 16) {
                    if collector.isRunning {
                        MetricsView(metricsManager: manager.getMetricsManager(forCollectorId: collector.id))
                    } else {
                        ContentUnavailableView {
                            Label("Collector Not Running", systemImage: "chart.line.downtrend.xyaxis")
                        } description: {
                            Text("Start the collector to view metrics")
                        }
                    }
                }
                .padding()
                .tabItem {
                    Label("Metrics", systemImage: "chart.xyaxis.line")
                }
                .tag(0)
                
                // Logs tab
                VStack(alignment: .leading, spacing: 16) {
                    LogViewer(collector: collector)
                }
                .padding()
                .tabItem {
                    Label("Logs", systemImage: "text.alignleft")
                }
                .tag(1)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
} 