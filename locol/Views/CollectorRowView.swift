import SwiftUI

/// A row view for displaying collector information in the sidebar, similar to Console's device/process rows
struct CollectorRowView: View {
    let collector: CollectorInstance
    let isRunning: Bool
    let isProcessing: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator with glass effect
            statusIndicator
            
            // Collector info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(collector.name)
                        .font(.system(.body, design: .default, weight: .medium))
                        .lineLimit(1)
                    
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 12, height: 12)
                    }
                }
                
                Text(collector.version)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
    
    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
            .shadow(color: statusColor.opacity(0.3), radius: 2, x: 0, y: 1)
    }
    
    private var statusColor: Color {
        if isProcessing {
            return .orange
        } else if isRunning {
            return .green
        } else {
            return .secondary.opacity(0.6)
        }
    }
}

#Preview {
    VStack(spacing: 4) {
        CollectorRowView(
                collector: CollectorInstance(
                    id: UUID(),
                    name: "otelcol-contrib",
                    version: "0.89.0",
                    binaryPath: "/tmp/collector",
                    configPath: "/tmp/config.yaml"
                ),
                isRunning: true,
                isProcessing: false
            )
        
        CollectorRowView(
                collector: CollectorInstance(
                    id: UUID(),
                    name: "otelcol-core",
                    version: "0.88.0",
                    binaryPath: "/tmp/collector2",
                    configPath: "/tmp/config2.yaml"
                ),
                isRunning: false,
                isProcessing: true
            )
        
        CollectorRowView(
                collector: CollectorInstance(
                    id: UUID(),
                    name: "custom-collector",
                    version: "1.0.0",
                    binaryPath: "/tmp/collector3",
                    configPath: "/tmp/config3.yaml"
                ),
                isRunning: false,
                isProcessing: false
            )
    }
    .frame(width: 220)
    .background(.background.secondary)
}
