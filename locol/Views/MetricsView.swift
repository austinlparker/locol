import SwiftUI
import Charts
import os

struct MetricsView: View {
    @StateObject private var viewModel = MetricsViewModel()
    @State private var selectedRateInterval: RateInterval = .oneMinute
    private let logger = Logger(subsystem: "io.aparker.locol", category: "MetricsView")
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 500))
            ], spacing: 16) {
                // Regular metrics section
                if !viewModel.groupedMetrics.regular.isEmpty {
                    Section {
                        ForEach(viewModel.groupedMetrics.regular, id: \.name) { name, series in
                            CounterCard(name: name, series: series)
                        }
                    } header: {
                        Text("Counters")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }
                }

                // Gauges
                if !viewModel.groupedMetrics.gauges.isEmpty {
                    Section {
                        ForEach(viewModel.groupedMetrics.gauges, id: \.0) { key, metrics in
                            GaugeCard(metrics: metrics)
                        }
                    } header: {
                        Text("Gauges")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }
                }
                
                // Histograms section
                if !viewModel.groupedMetrics.histograms.isEmpty {
                    Section {
                        ForEach(viewModel.groupedMetrics.histograms, id: \.0) { key, metrics in
                            if let lastMetric = metrics.last,
                               let histogram = lastMetric.histogram {
                                HistogramCard(metric: lastMetric, histogram: histogram)
                                    .gridCellColumns(2)
                            }
                        }
                    } header: {
                        Text("Histograms")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Metrics")
        .toolbar {
            ToolbarItem {
                Button(action: {
                    viewModel.startScraping()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
            
            ToolbarItem {
                Picker("Rate Interval", selection: $selectedRateInterval) {
                    ForEach(RateInterval.allCases, id: \.self) { interval in
                        Text(interval.description).tag(interval)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
    }
}

enum RateInterval: String, CaseIterable {
    case oneMinute = "1m"
    case fiveMinutes = "5m"
    case fifteenMinutes = "15m"
    
    var description: String {
        rawValue
    }
    
    var seconds: TimeInterval {
        switch self {
        case .oneMinute:
            return 60
        case .fiveMinutes:
            return 300
        case .fifteenMinutes:
            return 900
        }
    }
} 
