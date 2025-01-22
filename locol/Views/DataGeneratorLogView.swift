import SwiftUI

struct DataGeneratorLogView: View {
    @ObservedObject var logger = DataGeneratorLogger.shared
    @State private var shouldAutoScroll = true
    @State private var lastLogCount = 0
    
    var logs: [LogEntry] {
        Array(logger.logs)
    }
    
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
                        ForEach(logs, id: \.id) { log in
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
                        
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding()
                }
                .onChange(of: logger.logs.count) { _, newCount in
                    if shouldAutoScroll && newCount > lastLogCount {
                        DispatchQueue.main.async {
                            withAnimation {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                    lastLogCount = newCount
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