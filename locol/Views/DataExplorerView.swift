import SwiftUI

struct DataExplorerView: View {
    @State private var selectedTab = "metrics"
    @State private var isShowingError = false
    @State private var errorMessage: String?
    let dataExplorer: DataExplorer
    
    var body: some View {
        NavigationStack {
            Group {
                switch selectedTab {
                case "metrics":
                    if dataExplorer.isRunning {
                        ExplorerMetricsTableView(dataExplorer: dataExplorer)
                            .padding()
                    } else {
                        ContentUnavailableView {
                            Label("Server Not Running", systemImage: "chart.line.downtrend.xyaxis")
                        } description: {
                            Text("Start the server to collect telemetry data")
                        }
                    }
                case "logs":
                    if dataExplorer.isRunning {
                        ExplorerLogsTableView(dataExplorer: dataExplorer)
                            .padding()
                    } else {
                        ContentUnavailableView {
                            Label("Server Not Running", systemImage: "text.alignleft")
                        } description: {
                            Text("Start the server to collect telemetry data")
                        }
                    }
                case "traces":
                    if dataExplorer.isRunning {
                        ExplorerTracesTableView(dataExplorer: dataExplorer)
                            .padding()
                    } else {
                        ContentUnavailableView {
                            Label("Server Not Running", systemImage: "point.3.connected.trianglepath.dotted")
                        } description: {
                            Text("Start the server to collect telemetry data")
                        }
                    }
                default:
                    EmptyView()
                }
            }
            .navigationTitle("Data Explorer")
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
                        selectedTab = "traces"
                    } label: {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                    }
                    .help("View Traces")
                    .buttonStyle(.borderless)
                    .foregroundStyle(selectedTab == "traces" ? .primary : .secondary)
                }
                
                // Primary action for start/stop
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            do {
                                if dataExplorer.isRunning {
                                    await dataExplorer.stop()
                                } else {
                                    try await dataExplorer.start()
                                }
                            } catch {
                                errorMessage = error.localizedDescription
                                isShowingError = true
                            }
                        }
                    } label: {
                        Image(systemName: dataExplorer.isRunning ? "stop.circle.fill" : "play.circle.fill")
                            .foregroundStyle(dataExplorer.isRunning ? .red : .green)
                    }
                    .help(dataExplorer.isRunning ? "Stop Server" : "Start Server")
                }
                
                // Status indicator
                ToolbarItem(placement: .automatic) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(dataExplorer.isRunning ? .green : .red)
                            .frame(width: 8, height: 8)
                        if dataExplorer.isRunning {
                            Text("Running")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .alert("Error", isPresented: $isShowingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? dataExplorer.error?.localizedDescription ?? "An unknown error occurred")
        }
    }
}

private struct ExplorerMetricsTableView: View {
    let dataExplorer: DataExplorer
    
    var body: some View {
        Table(dataExplorer.metrics) {
            TableColumn("Name", value: \.name)
            TableColumn("Description", value: \.description_p)
            TableColumn("Unit", value: \.unit)
            TableColumn("Type", value: \.type)
            TableColumn("Time") { metric in
                Text(metric.time.description)
            }
            TableColumn("Value") { metric in
                Text(String(format: "%.2f", metric.value))
            }
            TableColumn("Attributes", value: \.attributes)
        }
    }
}

private struct ExplorerLogsTableView: View {
    let dataExplorer: DataExplorer
    
    var body: some View {
        Table(dataExplorer.logs) {
            TableColumn("Time") { log in
                Text(log.timestamp.description)
            }
            TableColumn("Severity", value: \.severityText)
            TableColumn("Level") { log in
                Text("\(log.severityNumber)")
            }
            TableColumn("Message", value: \.body)
            TableColumn("Attributes", value: \.attributes)
        }
    }
}

private struct ExplorerTracesTableView: View {
    let dataExplorer: DataExplorer
    
    var body: some View {
        Table(dataExplorer.spans) {
            TableColumn("Trace ID", value: \.traceId)
            TableColumn("Span ID", value: \.spanId)
            TableColumn("Parent Span ID", value: \.parentSpanId)
            TableColumn("Name", value: \.name)
            TableColumn("Kind") { span in
                Text("\(span.kind)")
            }
            TableColumn("Start Time") { span in
                Text(span.startTime.description)
            }
            TableColumn("End Time") { span in
                Text(span.endTime.description)
            }
            TableColumn("Attributes", value: \.attributes)
        }
    }
} 