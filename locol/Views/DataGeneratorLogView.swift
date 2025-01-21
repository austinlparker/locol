import SwiftUI

struct DataGeneratorLogView: View {
    @ObservedObject var logger = DataGeneratorLogger.shared
    @State private var shouldAutoScroll = true
    
    var body: some View {
        VStack {
            HStack {
                Text("Generator Logs")
                    .font(.headline)
                Spacer()
                Toggle("Auto-scroll", isOn: $shouldAutoScroll)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                Button("Clear") {
                    logger.clearLogs()
                }
            }
            .padding()
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading) {
                        ForEach(logger.logs, id: \.id) { log in
                            HStack(alignment: .top, spacing: 8) {
                                Text(formatDate(log.timestamp))
                                    .font(.custom("Menlo", size: 12))
                                    .foregroundColor(.gray)
                                    .frame(width: 100, alignment: .leading)
                                
                                Text(log.message)
                                    .font(.custom("Menlo", size: 12))
                                    .foregroundColor(logColor(for: log.level))
                            }
                            .textSelection(.enabled)
                            .id(log.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: logger.logs) { oldValue, newValue in
                    if shouldAutoScroll {
                        scrollToBottom(proxy: proxy)
                    }
                }
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastLog = logger.logs.last {
            proxy.scrollTo(lastLog.id, anchor: .bottom)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
    
    private func logColor(for level: LogLevel) -> Color {
        switch level {
        case .debug:
            return .gray
        case .info:
            return .primary
        case .error:
            return .red
        }
    }
} 