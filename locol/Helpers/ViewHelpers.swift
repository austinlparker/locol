import SwiftUI

// MARK: - Shared Components

struct StatBox: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Helper Extensions

extension Dictionary where Key == String, Value == String {
    func formattedLabels() -> String {
        map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
    }
} 