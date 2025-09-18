import SwiftUI

struct LogExplorerView: View {
  @Bindable var viewer: TelemetryViewer
  @State private var selectedLogID: UUID?
  @State private var searchText: String = ""

  private var filteredLogs: [LogEntry] {
    guard !searchText.isEmpty else { return viewer.logEntries }
    return viewer.logEntries.filter { entry in
      let haystack = [
        entry.serviceName,
        entry.body,
        entry.traceId,
        entry.spanId
      ]
        .compactMap { $0?.lowercased() }
        .joined(separator: " ")
      return haystack.contains(searchText.lowercased())
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      controlBar
      Divider()
      content
    }
    .task {
      if viewer.logEntries.isEmpty {
        await viewer.refreshLogs()
      }
    }
    .onChange(of: viewer.logSeverity) { _, _ in
      Task { await viewer.refreshLogs() }
    }
    .onChange(of: viewer.logEntries) { _, newEntries in
      guard !newEntries.isEmpty else {
        selectedLogID = nil
        return
      }
      if let selectedLogID,
         newEntries.contains(where: { $0.id == selectedLogID }) {
        return
      }
      selectedLogID = newEntries.first?.id
    }
    .onChange(of: searchText) { _, _ in
      if let selectedLogID,
         filteredLogs.contains(where: { $0.id == selectedLogID }) {
        return
      }
      selectedLogID = filteredLogs.first?.id
    }
  }

  private var controlBar: some View {
    HStack(spacing: 12) {
      Label("Logs", systemImage: "text.justify.left")
        .font(.headline)

      Picker("Severity", selection: $viewer.logSeverity) {
        ForEach(LogSeverityFilter.allCases) { filter in
          Text(filter.title).tag(filter)
        }
      }
      .pickerStyle(.segmented)
      .frame(width: 260)
      .labelsHidden()

      TextField("Search", text: $searchText)
        .textFieldStyle(.roundedBorder)
        .frame(maxWidth: 220)

      Spacer()

      Button {
        Task { await viewer.refreshLogs() }
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
    if viewer.isLoadingLogs && viewer.logEntries.isEmpty {
      ProgressView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if let error = viewer.logsError {
      LogEmptyStateView(
        systemImage: "exclamationmark.triangle",
        title: "Unable to load logs",
        message: error.localizedDescription,
        retryTitle: "Retry"
      ) {
        Task { await viewer.refreshLogs() }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if filteredLogs.isEmpty {
      LogEmptyStateView(
        systemImage: "doc.text.magnifyingglass",
        title: "No logs",
        message: "No log entries match the current filters"
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      HStack(spacing: 0) {
        logList
          .frame(minWidth: 320)
        Divider()
        logDetail
      }
    }
  }

  private var logList: some View {
    List(selection: $selectedLogID) {
      ForEach(filteredLogs) { entry in
        LogRowView(entry: entry)
          .tag(entry.id)
      }
    }
    .listStyle(.plain)
  }

  @ViewBuilder
  private var logDetail: some View {
    if let entry = selectedLog ?? filteredLogs.first {
      logDetailView(entry)
    } else {
      LogEmptyStateView(
        systemImage: "target",
        title: "Select a log",
        message: "Choose a log entry to see details"
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func logDetailView(_ entry: LogEntry) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .firstTextBaseline) {
          Text(entry.severityDisplay)
            .font(.title3)
            .fontWeight(.semibold)
            .foregroundStyle(severityColor(for: entry))
          Spacer()
          Text(entry.formattedTimestamp)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        if let body = entry.body, !body.isEmpty {
          Text(body)
            .font(.body)
            .textSelection(.enabled)
        }

        VStack(alignment: .leading, spacing: 4) {
          if let service = entry.serviceName {
            LabeledContent("Service") { Text(service) }
          }
          if let trace = entry.traceId, !trace.isEmpty {
            LabeledContent("Trace ID") { Text(trace).textSelection(.enabled) }
          }
          if let span = entry.spanId, !span.isEmpty {
            LabeledContent("Span ID") { Text(span).textSelection(.enabled) }
          }
        }
        .font(.subheadline)

        if !entry.attributes.isEmpty {
          VStack(alignment: .leading, spacing: 4) {
            Text("Attributes")
              .font(.subheadline)
              .fontWeight(.semibold)
            ForEach(entry.attributes.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
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
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func severityColor(for entry: LogEntry) -> Color {
    guard let number = entry.severityNumber else { return .primary }
    if number >= LogSeverityNumber.error.rawValue {
      return .red
    }
    if number >= LogSeverityNumber.warn.rawValue {
      return .orange
    }
    return .primary
  }
}

private struct LogEmptyStateView: View {
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

private struct LogRowView: View {
  let entry: LogEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(entry.severityDisplay)
          .font(.subheadline)
          .fontWeight(.medium)
        Spacer()
        Text(entry.formattedTimestamp)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        if let service = entry.serviceName {
          Text(service)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        if let body = entry.body {
          Text(body)
            .font(.caption)
            .lineLimit(2)
        }
      }
    }
    .padding(.vertical, 6)
    .contentShape(Rectangle())
  }
}

private extension LogExplorerView {
  var selectedLog: LogEntry? {
    guard let id = selectedLogID else { return nil }
    return filteredLogs.first(where: { $0.id == id })
  }
}
