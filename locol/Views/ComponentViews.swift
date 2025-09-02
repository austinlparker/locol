import SwiftUI

struct ComponentSection: View {
    let title: String
    let components: [String]
    let version: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(color)
                
                Spacer()
                
                Text("\(components.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.2))
                    .foregroundStyle(color)
                    .cornerRadius(8)
            }
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), alignment: .leading)], spacing: 8) {
                ForEach(components.sorted(), id: \.self) { component in
                    ComponentListItem(
                        name: component,
                        color: color,
                        version: version
                    )
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct ComponentListItem: View {
    let name: String
    let color: Color
    let version: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: iconForComponent(name))
                    .foregroundStyle(color)
                    .frame(width: 16)
                
                Text(name)
                    .font(.body)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Version: \(version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let description = componentDescription(name) {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.leading, 20)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemFill))
        .cornerRadius(6)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
    
    private func iconForComponent(_ name: String) -> String {
        let lowerName = name.lowercased()
        
        if lowerName.contains("receiver") || lowerName.contains("http") || lowerName.contains("grpc") {
            return "antenna.radiowaves.left.and.right"
        } else if lowerName.contains("processor") || lowerName.contains("batch") || lowerName.contains("memory") {
            return "gearshape"
        } else if lowerName.contains("exporter") || lowerName.contains("logging") || lowerName.contains("debug") {
            return "arrow.up.right"
        } else if lowerName.contains("extension") {
            return "puzzlepiece"
        } else {
            return "cube"
        }
    }
    
    private func componentDescription(_ name: String) -> String? {
        let lowerName = name.lowercased()
        
        switch lowerName {
        case let n where n.contains("otlp"):
            return "OpenTelemetry Protocol component"
        case let n where n.contains("batch"):
            return "Batches telemetry data for efficient processing"
        case let n where n.contains("memory_limiter"):
            return "Prevents memory usage from exceeding configured limits"
        case let n where n.contains("debug"):
            return "Outputs telemetry data to console for debugging"
        case let n where n.contains("logging"):
            return "Exports telemetry data to log files"
        default:
            return nil
        }
    }
}

#Preview {
    ComponentSection(
        title: "Receivers",
        components: ["otlp", "httpcheck", "prometheus"],
        version: "0.91.0",
        color: .blue
    )
    .padding()
}