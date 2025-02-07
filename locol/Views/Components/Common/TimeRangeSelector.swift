import SwiftUI

struct TimeRange: Equatable, Hashable {
    let start: Date
    let end: Date
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(start)
        hasher.combine(end)
    }
    
    static func last(_ duration: TimeInterval) -> TimeRange {
        let end = Date()
        let start = end.addingTimeInterval(-duration)
        return TimeRange(start: start, end: end)
    }
    
    static let last15Minutes = last(15 * 60)
    static let last1Hour = last(60 * 60)
    static let last3Hours = last(3 * 60 * 60)
    static let last6Hours = last(6 * 60 * 60)
    static let last12Hours = last(12 * 60 * 60)
    static let last24Hours = last(24 * 60 * 60)
    static let last7Days = last(7 * 24 * 60 * 60)
    static let last30Days = last(30 * 24 * 60 * 60)
}

struct TimeRangeSelector: View {
    @Binding var selectedRange: TimeRange
    @State private var isCustomRange = false
    @State private var customStart = Date()
    @State private var customEnd = Date()
    
    private let predefinedRanges: [(String, TimeRange)] = [
        ("Last 15m", .last15Minutes),
        ("Last 1h", .last1Hour),
        ("Last 3h", .last3Hours),
        ("Last 6h", .last6Hours),
        ("Last 12h", .last12Hours),
        ("Last 24h", .last24Hours),
        ("Last 7d", .last7Days),
        ("Last 30d", .last30Days)
    ]
    
    var body: some View {
        HStack {
            Picker("Time Range", selection: $selectedRange) {
                ForEach(predefinedRanges, id: \.0) { label, range in
                    Text(label)
                        .tag(range)
                }
                Text("Custom")
                    .tag(TimeRange(start: customStart, end: customEnd))
            }
            .pickerStyle(.menu)
            .frame(width: 120)
            
            if isCustomRange {
                DatePicker("Start", selection: $customStart, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .onChange(of: customStart) {
                        selectedRange = TimeRange(start: customStart, end: customEnd)
                    }
                
                Text("to")
                    .foregroundStyle(.secondary)
                
                DatePicker("End", selection: $customEnd, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .onChange(of: customEnd) {
                        selectedRange = TimeRange(start: customStart, end: customEnd)
                    }
            }
        }
        .onChange(of: selectedRange) { range in
            isCustomRange = !predefinedRanges.contains { $0.1 == range }
            if isCustomRange {
                customStart = range.start
                customEnd = range.end
            }
        }
    }
} 