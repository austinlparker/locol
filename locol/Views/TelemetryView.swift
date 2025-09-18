import SwiftUI

struct TelemetryView: View {
  private enum ExplorerMode: String, CaseIterable, Identifiable {
    case traces
    case metrics
    case logs
    case sql

    var id: String { rawValue }

    var title: String {
      switch self {
      case .traces: return "Traces"
      case .metrics: return "Metrics"
      case .logs: return "Logs"
      case .sql: return "SQL"
      }
    }

    var systemImage: String {
      switch self {
      case .traces: return "chart.bar.doc.horizontal"
      case .metrics: return "chart.line.uptrend.xyaxis"
      case .logs: return "text.justify.left"
      case .sql: return "terminal"
      }
    }
  }
  
  let collectorManager: CollectorManager?
  @Bindable var viewer: TelemetryViewer
  @State private var mode: ExplorerMode
  @State private var hasInitialized = false
  private let initialCollectorName: String?
  
  init(collectorManager: CollectorManager, viewer: TelemetryViewer) {
    self.collectorManager = collectorManager
    self._viewer = Bindable(viewer)
    self._mode = State(initialValue: .traces)
    self.initialCollectorName = nil
  }
  
  init(collectorName: String, viewer: TelemetryViewer) {
    self.collectorManager = nil
    self._viewer = Bindable(viewer)
    self._mode = State(initialValue: .sql)
    self.initialCollectorName = collectorName
  }
  
  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      content
    }
    .navigationTitle("Telemetry")
    .task { await initializeIfNeeded() }
    .onChange(of: mode) { _, newMode in
      Task { await refreshData(for: newMode, force: true) }
    }
    .onChange(of: viewer.selectedCollector) { _, _ in
      Task { await refreshData(for: mode, force: true) }
    }
  }
  
  private var header: some View {
    HStack(spacing: 12) {
      if collectorManager != nil {
        Menu {
          Button("All Collectors") {
            viewer.selectedCollector = "all"
          }
          if !viewer.collectorStats.isEmpty {
            Divider()
            ForEach(viewer.collectorStats, id: \.collectorName) { stat in
              Button(stat.collectorName) {
                viewer.selectedCollector = stat.collectorName
              }
            }
          }
        } label: {
          Label("Collector: \(collectorDisplayName)", systemImage: "server.rack")
        }
      }
      
      Spacer()
      
      Picker("Mode", selection: $mode) {
        ForEach(ExplorerMode.allCases) { mode in
          Label(mode.title, systemImage: mode.systemImage)
            .tag(mode)
        }
      }
      .pickerStyle(.segmented)
      .frame(maxWidth: 280)
      .labelsHidden()
      
      Spacer(minLength: 12)
      
      Button {
        Task { await refreshData(for: mode, force: true) }
      } label: {
        Label(refreshButtonTitle, systemImage: "arrow.clockwise")
      }
      .buttonStyle(.bordered)
    }
    .padding(.horizontal)
    .padding(.vertical, 10)
    .background(.background.secondary)
  }
  
  @ViewBuilder
  private var content: some View {
    switch mode {
    case .traces:
      TraceExplorerView(viewer: viewer)
    case .metrics:
      MetricExplorerView(viewer: viewer)
    case .logs:
      LogExplorerView(viewer: viewer)
    case .sql:
      SQLQueryView(collectorName: viewer.selectedCollector, viewer: viewer)
    }
  }
  
  private var collectorDisplayName: String {
    viewer.selectedCollector == "all" ? "All" : viewer.selectedCollector
  }
  
  private var refreshButtonTitle: String {
    switch mode {
    case .traces: return "Refresh Traces"
    case .metrics: return "Refresh Metrics"
    case .logs: return "Refresh Logs"
    case .sql: return "Refresh Stats"
    }
  }
  
  private func initializeIfNeeded() async {
    guard !hasInitialized else { return }
    hasInitialized = true
    if let initialCollectorName {
      viewer.selectedCollector = initialCollectorName
    } else if viewer.selectedCollector == "all",
        let first = viewer.collectorStats.first?.collectorName {
      viewer.selectedCollector = first
    }
    await viewer.refreshCollectorStats()
    await refreshData(for: mode, force: true)
  }
  
  private func refreshData(for mode: ExplorerMode, force: Bool) async {
    switch mode {
    case .traces:
      if force || viewer.traceSummaries.isEmpty {
        await viewer.refreshTraceSummaries()
      }
    case .metrics:
      if force || viewer.metricCatalog.isEmpty {
        await viewer.refreshMetricCatalog()
      }
    case .logs:
      if force || viewer.logEntries.isEmpty {
        await viewer.refreshLogs()
      }
    case .sql:
      await viewer.refreshCollectorStats()
    }
  }
}
