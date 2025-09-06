import SwiftUI

/// A Console-style toolbar with glass effects for controlling collectors
struct ConsoleToolbar: View {
    let selectedCollector: CollectorInstance?
    let collectorManager: CollectorManager
    let onStartStop: () -> Void
    let onClear: (() -> Void)?
    let onRefresh: () -> Void
    @Binding var searchText: String
    
    private var isCollectorRunning: Bool {
        guard let collector = selectedCollector else { return false }
        return collectorManager.isCollectorRunning(withId: collector.id)
    }
    
    private var isProcessing: Bool {
        guard let collector = selectedCollector else { return false }
        return collectorManager.isProcessingOperation && collectorManager.activeCollector?.id == collector.id
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Start/Stop button group
            buttonGroupContent
            
            Spacer()
            
            // Search and controls
            HStack(spacing: 8) {
                // Refresh button
                Button(action: onRefresh) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                }
                .conditionalGlassButtonStyle()
                
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13))
                    
                    TextField("Search", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                .frame(width: 180)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
    
    @Namespace private var toolbarNamespace
    
    @ViewBuilder
    private var buttonGroupContent: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 4) {
                startStopButton
                
                if let onClear = onClear {
                    Button(action: onClear) {
                        Label("Clear", systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }
                    .conditionalGlassButtonStyle()
                    .disabled(selectedCollector == nil)
                    .conditionalGlassEffect(id: "clear", namespace: toolbarNamespace)
                }
            }
        } else {
            HStack(spacing: 4) {
                startStopButton
                
                if let onClear = onClear {
                    Button(action: onClear) {
                        Label("Clear", systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }
                    .conditionalGlassButtonStyle()
                    .disabled(selectedCollector == nil)
                    .conditionalGlassEffect(id: "clear", namespace: toolbarNamespace)
                }
            }
        }
    }
    
    
    @ViewBuilder
    private var startStopButton: some View {
        if isCollectorRunning {
            Button(action: onStartStop) {
                HStack(spacing: 6) {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 12, weight: .medium))
                    }
                    
                    Text(buttonTitle)
                        .font(.system(size: 13, weight: .medium))
                }
                .frame(minWidth: 60)
            }
            .conditionalGlassProminentButtonStyle()
            .disabled(selectedCollector == nil || isProcessing)
            .conditionalGlassEffect(id: "startStop", namespace: toolbarNamespace)
        } else {
            Button(action: onStartStop) {
                HStack(spacing: 6) {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .medium))
                    }
                    
                    Text(buttonTitle)
                        .font(.system(size: 13, weight: .medium))
                }
                .frame(minWidth: 60)
            }
            .conditionalGlassButtonStyle()
            .disabled(selectedCollector == nil || isProcessing)
            .conditionalGlassEffect(id: "startStop", namespace: toolbarNamespace)
        }
    }
    
    private var buttonTitle: String {
        if isProcessing {
            return isCollectorRunning ? "Stopping" : "Starting"
        } else {
            return isCollectorRunning ? "Stop" : "Start"
        }
    }
}

// MARK: - Availability Helpers

extension View {
    @ViewBuilder
    func conditionalGlassEffect(id: String, namespace: Namespace.ID) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffectID(id, in: namespace)
        } else {
            self
        }
    }
    
    @ViewBuilder
    func conditionalGlassButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(GlassButtonStyle())
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }
    
    @ViewBuilder 
    func conditionalGlassProminentButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(GlassProminentButtonStyle())
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        ConsoleToolbar(
                selectedCollector: CollectorInstance(
                    id: UUID(),
                    name: "otelcol-contrib",
                    version: "0.89.0",
                    binaryPath: "/tmp/collector",
                    configPath: "/tmp/config.yaml"
                ),
                collectorManager: CollectorManager(),
                onStartStop: {},
                onClear: {},
                onRefresh: {},
                searchText: .constant("")
            )
        
        Rectangle()
            .fill(.background.secondary)
            .frame(height: 200)
    }
    .frame(width: 600)
}
