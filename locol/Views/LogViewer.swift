import SwiftUI

struct LogViewer: View {
    let collector: CollectorInstance
    @ObservedObject var logger = CollectorLogger.shared
    
    var body: some View {
        VStack {
            HStack {
                Text("Logs for \(collector.name)")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    logger.clearLogs()
                }
            }
            .padding()
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading) {
                        ForEach(logger.logs.filter { $0.message.contains("[\(collector.name)]") }, id: \.id) { log in
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
                .onChange(of: logger.logs.count) { _ in
                    if let lastLog = logger.logs.last {
                        proxy.scrollTo(lastLog.id, anchor: .bottom)
                    }
                }
            }
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