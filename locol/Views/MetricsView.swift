import SwiftUI
import Charts
import os

struct MetricsView: View {
    @StateObject private var viewModel: MetricsViewModel
    
    init(manager: MetricsManager = .shared) {
        _viewModel = StateObject(wrappedValue: MetricsViewModel(manager: manager))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 400), spacing: 16)], spacing: 16) {
                    ForEach(viewModel.groupedMetrics) { group in
                        switch group {
                        case .counters(let name, let series):
                            CounterCard(name: name, series: series)
                        case .gauge(let metrics):
                            GaugeCard(metrics: metrics)
                        case .histogram(let metric, let histogram):
                            HistogramCard(metric: metric, histogram: histogram)
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    private var toolbar: some View {
        HStack {
            Text("Metrics")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            HStack(spacing: 8) {
                ForEach(TimeRange.allCases) { range in
                    Button(action: {
                        viewModel.selectedTimeRange = range
                    }) {
                        Text(range.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .background {
                        if viewModel.selectedTimeRange == range {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor)
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        }
                    }
                    .foregroundStyle(viewModel.selectedTimeRange == range ? .white : .primary)
                }
            }
            .padding(4)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
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
