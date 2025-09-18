import SwiftUI
import Charts

struct MetricExplorerView: View {
  @Bindable var viewer: TelemetryViewer

  var body: some View {
    VStack(spacing: 0) {
      controlBar
      Divider()
      content
    }
    .task {
      if viewer.metricCatalog.isEmpty {
        await viewer.refreshMetricCatalog()
      }
    }
    .onChange(of: viewer.selectedMetric) { _, metric in
      guard let metric else { return }
      Task { await viewer.loadMetricSeries(for: metric) }
    }
    .onChange(of: viewer.metricTimeRange) { _, _ in
      guard let metric = viewer.selectedMetric else { return }
      Task { await viewer.loadMetricSeries(for: metric) }
    }
  }

  private var controlBar: some View {
    HStack(spacing: 12) {
      Label("Metrics", systemImage: "chart.line.uptrend.xyaxis")
        .font(.headline)
      Spacer()
      Picker("Range", selection: $viewer.metricTimeRange) {
        ForEach(MetricTimeRange.allCases) { range in
          Text(range.title).tag(range)
        }
      }
      .pickerStyle(.segmented)
      .frame(width: 200)
      Button {
        Task { await viewer.refreshMetricCatalog() }
      } label: {
        Label("Reload", systemImage: "arrow.clockwise")
      }
      .buttonStyle(.bordered)
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
  }

  @ViewBuilder
  private var content: some View {
    if viewer.isLoadingMetricCatalog && viewer.metricCatalog.isEmpty {
      ProgressView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if let error = viewer.metricCatalogError {
      MetricEmptyStateView(
        systemImage: "exclamationmark.triangle",
        title: "Unable to load metrics",
        message: error.localizedDescription,
        retryTitle: "Retry"
      ) {
        Task { await viewer.refreshMetricCatalog() }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      HStack(spacing: 0) {
        metricList
          .frame(width: 280)
          .background(.background)
        Divider()
        metricDetail
      }
    }
  }

  private var metricList: some View {
    List(selection: $viewer.selectedMetric) {
      ForEach(viewer.metricCatalog, id: \.self) { descriptor in
        MetricDescriptorRow(descriptor: descriptor)
          .tag(descriptor)
      }
    }
    .listStyle(.sidebar)
  }

  @ViewBuilder
  private var metricDetail: some View {
    if let descriptor = viewer.selectedMetric {
      VStack(alignment: .leading, spacing: 0) {
        MetricDetailHeader(descriptor: descriptor, range: viewer.metricTimeRange)
        Divider()
        if viewer.isLoadingMetricSeries {
          ProgressView("Loading series…")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewer.metricSeriesError {
          MetricEmptyStateView(
            systemImage: "exclamationmark.triangle",
            title: "Unable to load series",
            message: error.localizedDescription
          )
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewer.metricSeries.isEmpty {
          MetricEmptyStateView(
            systemImage: "chart.line.uptrend.xyaxis",
            title: "No data",
            message: "This metric does not have recent samples in the selected range"
          )
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          MetricSeriesChart(points: viewer.metricSeries)
            .padding()
          MetricSeriesSummary(points: viewer.metricSeries)
            .padding([.horizontal, .bottom])
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      MetricEmptyStateView(
        systemImage: "target",
        title: "Select a metric",
        message: "Choose a metric to visualize its recent samples"
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}

private struct MetricDescriptorRow: View {
  let descriptor: MetricDescriptor

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(descriptor.metricName)
          .font(.headline)
          .lineLimit(1)
        Spacer()
        if let unit = descriptor.unit {
          Text(unit)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      HStack(spacing: 10) {
        Label(descriptor.type.capitalized, systemImage: "cube")
          .font(.caption)
          .foregroundStyle(.secondary)
        Label("\(descriptor.sampleCount) samples", systemImage: "waveform")
          .font(.caption)
          .foregroundStyle(.tertiary)
        if let timestamp = descriptor.latestTimestamp {
          HStack(spacing: 4) {
            Image(systemName: "clock")
              .font(.caption)
              .foregroundStyle(.tertiary)
            Text(timestamp, style: .time)
              .font(.caption)
              .foregroundStyle(.tertiary)
          }
        }
      }
    }
    .padding(.vertical, 6)
  }
}

private struct MetricDetailHeader: View {
  let descriptor: MetricDescriptor
  let range: MetricTimeRange

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline) {
        Text(descriptor.metricName)
          .font(.title3)
          .fontWeight(.semibold)
        Spacer()
        if let unit = descriptor.unit {
          Text(unit)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
      HStack(spacing: 16) {
        LabeledContent("Type") {
          Text(descriptor.type.capitalized)
        }
        LabeledContent("Samples") {
          Text("\(descriptor.sampleCount)")
        }
        LabeledContent("Services") {
          Text("\(descriptor.serviceCount)")
        }
        LabeledContent("Window") {
          Text(range.title)
        }
      }
      .font(.subheadline)
    }
    .padding()
  }
}

private struct MetricSeriesChart: View {
  let points: [MetricDataPoint]

  var body: some View {
    Chart {
      ForEach(groupedPoints, id: \.service) { series in
        ForEach(series.points) { point in
          LineMark(
            x: .value("Time", point.timestamp),
            y: .value("Value", point.value)
          )
          .foregroundStyle(by: .value("Service", series.service))
          .interpolationMethod(.monotone)
          PointMark(
            x: .value("Time", point.timestamp),
            y: .value("Value", point.value)
          )
          .symbolSize(15)
          .foregroundStyle(by: .value("Service", series.service))
        }
      }
    }
    .chartXAxis {
      AxisMarks(values: .automatic(desiredCount: 4))
    }
    .chartYAxis {
      AxisMarks(position: .leading)
    }
    .chartLegend(.visible)
    .frame(maxWidth: .infinity, maxHeight: 320)
  }

  private var groupedPoints: [(service: String, points: [MetricDataPoint])] {
    let grouped = Dictionary(grouping: points) { point in
      point.serviceName ?? "All"
    }
    return grouped
      .map { key, value in
        (service: key, points: value.sorted { $0.timestamp < $1.timestamp })
      }
      .sorted { lhs, rhs in
        lhs.service < rhs.service
      }
  }
}

private struct MetricSeriesSummary: View {
  let points: [MetricDataPoint]

  var body: some View {
    let values = points.map(\.value)
    let latest = points.max { $0.timestamp < $1.timestamp }
    HStack(spacing: 24) {
      summaryItem(title: "Latest", value: latest?.value)
      summaryItem(title: "Min", value: values.min())
      summaryItem(title: "Max", value: values.max())
      summaryItem(title: "Avg", value: average(of: values))
    }
    .font(.subheadline)
  }

  private func summaryItem(title: String, value: Double?) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .foregroundStyle(.secondary)
      if let value {
        Text(value, format: .number.precision(.fractionLength(2)))
      } else {
        Text("—")
      }
    }
  }

  private func average(of values: [Double]) -> Double? {
    guard !values.isEmpty else { return nil }
    let total = values.reduce(0, +)
    return total / Double(values.count)
  }
}

private struct MetricEmptyStateView: View {
  let systemImage: String
  let title: String
  let message: String
  var retryTitle: String? = nil
  var retry: (() -> Void)? = nil

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.system(size: 40))
        .foregroundStyle(.tertiary)
      Text(title)
        .font(.title3)
        .fontWeight(.semibold)
      Text(message)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      if let retryTitle, let retry {
        Button(retryTitle, action: retry)
      }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
