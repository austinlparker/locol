import SwiftUI

struct TraceExplorerView: View {
  private enum TraceListLimit: Int, CaseIterable, Identifiable {
    case twentyFive = 25
    case fifty = 50
    case oneHundred = 100

    var id: Int { rawValue }

    var title: String {
      switch self {
      case .twentyFive: return "25"
      case .fifty: return "50"
      case .oneHundred: return "100"
      }
    }
  }

  @Bindable var viewer: TelemetryViewer
  @State private var selectedLimit: TraceListLimit = .fifty
  @State private var selectedSpanId: String?
  private let relativeFormatter = RelativeDateTimeFormatter()

  var body: some View {
    VStack(spacing: 0) {
      controlBar
      Divider()
      content
    }
    .task {
      if viewer.traceSummaries.isEmpty {
        await viewer.refreshTraceSummaries(limit: selectedLimit.rawValue)
      }
    }
    .onChange(of: selectedLimit) { _, newValue in
      Task { await viewer.refreshTraceSummaries(limit: newValue.rawValue) }
    }
    .onChange(of: viewer.selectedTraceId) { _, _ in
      selectedSpanId = nil
    }
  }

  private var controlBar: some View {
    HStack(spacing: 12) {
      Label("Traces", systemImage: "chart.bar.doc.horizontal")
        .font(.headline)
      Spacer()
      Picker("Limit", selection: $selectedLimit) {
        ForEach(TraceListLimit.allCases) { limit in
          Text(limit.title).tag(limit)
        }
      }
      .pickerStyle(.segmented)
      .frame(width: 200)
      Button {
        Task { await viewer.refreshTraceSummaries(limit: selectedLimit.rawValue) }
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
    if viewer.isLoadingTraceSummaries && viewer.traceSummaries.isEmpty {
      ProgressView()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    } else if let error = viewer.traceSummariesError {
      TraceEmptyStateView(
        systemImage: "exclamationmark.triangle",
        title: "Unable to load traces",
        message: error.localizedDescription,
        retryTitle: "Retry"
      ) {
        Task { await viewer.refreshTraceSummaries(limit: selectedLimit.rawValue) }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      HStack(spacing: 0) {
        traceList
          .frame(width: 300)
          .background(.background)
        Divider()
        traceDetail
      }
    }
  }

  private var traceList: some View {
    List(selection: $viewer.selectedTraceId) {
      ForEach(viewer.traceSummaries) { summary in
        TraceSummaryRow(summary: summary, relativeFormatter: relativeFormatter)
          .tag(summary.traceId)
      }
    }
    .listStyle(.sidebar)
    .onChange(of: viewer.selectedTraceId) { _, newValue in
      guard let id = newValue else { return }
      Task { await viewer.loadTraceDetail(traceId: id) }
    }
  }

  @ViewBuilder
  private var traceDetail: some View {
    if let traceId = viewer.selectedTraceId,
       let summary = viewer.traceSummaries.first(where: { $0.traceId == traceId }) {
      VStack(spacing: 0) {
        TraceSummaryHeader(summary: summary)
        Divider()
        if viewer.isLoadingTraceDetail {
          ProgressView("Loading trace…")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewer.traceDetailError {
          TraceEmptyStateView(
            systemImage: "exclamationmark.triangle",
            title: "Unable to load spans",
            message: error.localizedDescription
          )
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewer.traceSpans.isEmpty {
          TraceEmptyStateView(
            systemImage: "cloud.sun",
            title: "No spans",
            message: "This trace does not contain any spans to render"
          )
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          TraceWaterfallView(spans: viewer.traceSpans, selectedSpanId: $selectedSpanId)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      TraceEmptyStateView(
        systemImage: "target",
        title: "Select a trace",
        message: "Choose a trace from the list to inspect its spans"
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}

private struct TraceSummaryRow: View {
  let summary: TraceSummary
  let relativeFormatter: RelativeDateTimeFormatter

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(summary.rootOperation)
          .font(.headline)
          .lineLimit(1)
        Spacer()
        Text(summary.durationMilliseconds, format: .number.precision(.fractionLength(1)))
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .overlay(alignment: .trailing) {
            Text("ms")
              .font(.caption2)
              .foregroundStyle(.tertiary)
              .padding(.leading, 2)
          }
      }
      HStack(spacing: 8) {
        if let service = summary.serviceName {
          Label(service, systemImage: "rectangle.stack")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Label(relativeFormatter.localizedString(for: summary.startTime, relativeTo: Date()), systemImage: "clock")
          .font(.caption)
          .foregroundStyle(.tertiary)
        Label("\(summary.spanCount) spans", systemImage: "square.stack.3d.up")
          .font(.caption)
          .foregroundStyle(.tertiary)
        if summary.hasErrors {
          Label("errors", systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.red)
        }
      }
    }
    .padding(.vertical, 6)
  }
}

private struct TraceSummaryHeader: View {
  let summary: TraceSummary

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline) {
        Text(summary.rootOperation)
          .font(.title3)
          .fontWeight(.semibold)
        Spacer()
        Text(summary.durationMilliseconds, format: .number.precision(.fractionLength(2)))
          .font(.headline)
        Text("ms")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      HStack(spacing: 16) {
        if let service = summary.serviceName {
          LabeledContent("Service") {
            Text(service)
              .font(.body)
          }
        }
        LabeledContent("Spans") {
          Text("\(summary.spanCount)")
        }
        LabeledContent("Errors") {
          Text("\(summary.errorCount)")
            .foregroundStyle(summary.hasErrors ? .red : .secondary)
        }
        LabeledContent("Started") {
          Text(summary.startTime, style: .time)
        }
      }
      .font(.subheadline)
    }
    .padding()
  }
}

private struct TraceWaterfallView: View {
  let spans: [TraceSpanDetail]
  @Binding var selectedSpanId: String?
  @State private var selectedEvent: TraceSpanEvent?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        ForEach(displaySpans) { display in
          TraceSpanRow(
            display: display,
            referenceStart: referenceStart,
            totalDuration: totalDuration,
            selectedSpanId: $selectedSpanId,
            selectedEvent: $selectedEvent
          )
        }
      }
      .padding(.top, 12)
      .padding(.horizontal)
    }
    .background(
      TraceWaterfallBackground()
        .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
        .foregroundStyle(.quaternary)
    )
    .overlay(alignment: .bottom) {
      if selectedEvent != nil || selectedSpanId != nil {
        VStack(spacing: 8) {
          if let event = selectedEvent {
            TraceEventDetailView(event: event)
          }

          if let selectedSpanId,
             let span = spans.first(where: { $0.spanId == selectedSpanId }) {
            TraceSpanDetailView(span: span)
          }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
        .shadow(radius: 12)
      }
    }
    .onChange(of: selectedSpanId) { _, _ in
      selectedEvent = nil
    }
  }

  private var referenceStart: Date {
    spans.map(\.startTime).min() ?? Date()
  }

  private var totalDuration: TimeInterval {
    guard let latest = spans.map(\.endTime).max() else { return 1 }
    let duration = latest.timeIntervalSince(referenceStart)
    return duration > 0 ? duration : 1
  }

  private var displaySpans: [TraceSpanDisplay] {
    let sorted = spans.sorted { lhs, rhs in
      if lhs.startTime == rhs.startTime {
        return lhs.duration > rhs.duration
      }
      return lhs.startTime < rhs.startTime
    }
    let depths = computeDepths(for: sorted)
    return sorted.map { span in
      TraceSpanDisplay(span: span, depth: depths[span.spanId] ?? 0)
    }
  }

  private func computeDepths(for spans: [TraceSpanDetail]) -> [String: Int] {
    var depths: [String: Int] = [:]
    let spanMap = Dictionary(uniqueKeysWithValues: spans.map { ($0.spanId, $0) })
    for span in spans {
      depths[span.spanId] = depth(for: span, spanMap: spanMap, cache: &depths)
    }
    return depths
  }

  private func depth(
    for span: TraceSpanDetail,
    spanMap: [String: TraceSpanDetail],
    cache: inout [String: Int]
  ) -> Int {
    if let cached = cache[span.spanId] {
      return cached
    }
    guard let parentId = span.parentSpanId,
          let parent = spanMap[parentId] else {
      cache[span.spanId] = 0
      return 0
    }
    let parentDepth = depth(for: parent, spanMap: spanMap, cache: &cache)
    let depth = parentDepth + 1
    cache[span.spanId] = depth
    return depth
  }
}

private struct TraceSpanDisplay: Identifiable {
  let span: TraceSpanDetail
  let depth: Int

  var id: String { span.spanId }
}

private struct TraceSpanRow: View {
  let display: TraceSpanDisplay
  let referenceStart: Date
  let totalDuration: TimeInterval
  @Binding var selectedSpanId: String?
  @Binding var selectedEvent: TraceSpanEvent?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline) {
        Text(display.span.operationName)
          .font(.subheadline)
          .fontWeight(.medium)
          .lineLimit(1)
        Spacer()
        Text(display.span.durationMilliseconds, format: .number.precision(.fractionLength(2)))
          .font(.caption)
          .foregroundStyle(.secondary)
        Text("ms")
          .font(.caption2)
          .foregroundStyle(.tertiary)
        if display.span.isError {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.red)
            .font(.caption)
        }
      }
      GeometryReader { geometry in
        let width = geometry.size.width
        let relativeStart = display.span.startTime.timeIntervalSince(referenceStart) / totalDuration
        let relativeDuration = max(display.span.duration / totalDuration, 0.005)
        let xOffset = max(0, CGFloat(relativeStart) * width)
        let barWidth = max(CGFloat(relativeDuration) * width, 2)
        let minX = xOffset
        let maxX = xOffset + barWidth
        let height = geometry.size.height

        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 3)
            .fill(display.span.isError ? Color.red.opacity(0.7) : Color.accentColor.opacity(0.7))
            .frame(width: barWidth, height: 14)
            .overlay(
              RoundedRectangle(cornerRadius: 3)
                .stroke(
                  selectedSpanId == display.span.spanId ? Color.primary : Color.clear,
                  lineWidth: selectedSpanId == display.span.spanId ? 2 : 0
                )
            )
            .offset(x: xOffset)

          ForEach(display.span.events) { event in
            let ratio = displayRatio(for: event.timestamp)
            let globalX = max(0, min(1, ratio)) * width
            let clampedX = min(max(globalX, minX), maxX)
            let isSelected = selectedEvent?.id == event.id

            Circle()
              .fill(isSelected ? Color.orange : Color.white)
              .frame(width: isSelected ? 10 : 8, height: isSelected ? 10 : 8)
              .overlay(
                Circle()
                  .stroke(isSelected ? Color.orange : Color.primary.opacity(0.6), lineWidth: 1)
              )
              .position(x: clampedX, y: height / 2)
              .onTapGesture {
                selectedSpanId = display.span.spanId
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                  selectedEvent = event
                }
              }
              .help(event.name)
          }
        }
      }
      .frame(height: 18)
    }
    .padding(.vertical, 8)
    .padding(.leading, CGFloat(display.depth) * 14)
    .padding(.trailing, 8)
    .background(selectedSpanId == display.span.spanId ? Color.accentColor.opacity(0.12) : Color.clear)
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .contentShape(Rectangle())
    .onTapGesture {
      selectedSpanId = display.span.spanId
      selectedEvent = nil
    }
  }

  private func displayRatio(for timestamp: Date) -> CGFloat {
    let delta = timestamp.timeIntervalSince(referenceStart)
    guard totalDuration > 0 else { return 0 }
    return CGFloat(delta / totalDuration)
  }
}

private struct TraceSpanDetailView: View {
  let span: TraceSpanDetail

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(span.operationName)
          .font(.headline)
        Spacer()
        Text(span.durationMilliseconds, format: .number.precision(.fractionLength(2)))
          .font(.subheadline)
        Text("ms")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      if let service = span.serviceName {
        LabeledContent("Service") {
          Text(service)
        }
      }
      LabeledContent("Start") {
        Text(span.startTime, style: .time)
      }
      LabeledContent("End") {
        Text(span.endTime, style: .time)
      }
      if let statusMessage = span.statusMessage, !statusMessage.isEmpty {
        LabeledContent("Status") {
          Text(statusMessage)
            .foregroundStyle(span.isError ? .red : .secondary)
        }
      }
      if !span.attributes.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Text("Attributes")
            .font(.subheadline)
            .fontWeight(.semibold)
          ForEach(span.attributes.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
            HStack(alignment: .firstTextBaseline) {
              Text(key)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 160, alignment: .leading)
              Text(value)
                .font(.caption)
                .textSelection(.enabled)
            }
          }
        }
      }
      if !span.events.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Text("Events")
            .font(.subheadline)
            .fontWeight(.semibold)
          ForEach(span.events) { event in
            VStack(alignment: .leading, spacing: 4) {
              HStack {
                Text(event.name)
                  .font(.caption)
                  .fontWeight(.medium)
                Spacer()
                Text(event.formattedTimestamp)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
              if !event.attributes.isEmpty {
                ForEach(event.attributes.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                  HStack(alignment: .firstTextBaseline) {
                    Text(key)
                      .font(.caption2)
                      .foregroundStyle(.secondary)
                      .frame(width: 150, alignment: .leading)
                    Text(value)
                      .font(.caption2)
                      .textSelection(.enabled)
                  }
                }
              }
              if event.droppedAttributesCount > 0 {
                Text("Dropped attributes: \(event.droppedAttributesCount)")
                  .font(.caption2)
                  .foregroundStyle(.tertiary)
              }
            }
            .padding(8)
            .background(.background.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 6))
          }
        }
      }
    }
    .padding()
  }
}

private struct TraceEventDetailView: View {
  let event: TraceSpanEvent

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label(event.name, systemImage: "flag.fill")
          .labelStyle(.titleAndIcon)
          .font(.headline)
        Spacer()
        Text(event.formattedTimestamp)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if !event.attributes.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          ForEach(event.attributes.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
            HStack(alignment: .firstTextBaseline) {
              Text(key)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 160, alignment: .leading)
              Text(value)
                .font(.caption)
                .textSelection(.enabled)
            }
          }
        }
      }

      if event.droppedAttributesCount > 0 {
        Text("Dropped attributes: \(event.droppedAttributesCount)")
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
    }
    .padding()
  }
}

private struct TraceWaterfallBackground: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let numberOfLines = 6
    let spacing = rect.width / CGFloat(numberOfLines)
    for index in 0...numberOfLines {
      let x = CGFloat(index) * spacing
      path.move(to: CGPoint(x: x, y: rect.minY))
      path.addLine(to: CGPoint(x: x, y: rect.maxY))
    }
    return path
  }
}

private struct TraceEmptyStateView: View {
  let systemImage: String
  let title: String
  let message: String
  var retryTitle: String? = nil
  var retry: (() -> Void)? = nil

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.system(size: 42))
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
  }
}
