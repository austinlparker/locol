import SwiftUI

struct FlagsView: View {
    let collectorId: UUID
    let manager: CollectorManager
    @Environment(AppContainer.self) private var container
    @State private var flags: String = ""
    @State private var hasChanges = false
    @State private var baselineFlags: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Command Line Flags")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Configure additional command line flags for the collector. Each flag should be separated by spaces.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            
            // Flags Editor
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Flags:")
                        .font(.headline)
                    
                    Spacer()
                    
                    if hasChanges {
                        Button("Reset") {
                            loadFlags()
                            hasChanges = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("Save") {
                            saveFlags()
                            hasChanges = false
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                
                TextField("Enter command line flags (e.g., --log-level=debug --feature-gates=component.UseLocalHostAsDefaultHost)", text: $flags, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 100)
                    .onChange(of: flags) { _, newValue in
                        hasChanges = newValue != baselineFlags
                    }
            }
            
            // Common flags reference
            commonFlagsReference
            
            Spacer()
        }
        .padding()
        .navigationTitle("Flags")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            loadFlags()
        }
    }
    
    private var commonFlagsReference: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Common Flags")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                FlagReferenceRow(flag: "--log-level", description: "Set logging level (debug, info, warn, error)", example: "--log-level=debug")
                FlagReferenceRow(flag: "--config", description: "Path to configuration file", example: "--config=/path/to/config.yaml")
                FlagReferenceRow(flag: "--feature-gates", description: "Enable experimental features", example: "--feature-gates=component.UseLocalHostAsDefaultHost")
                FlagReferenceRow(flag: "--set", description: "Override config values", example: "--set=processors.batch.timeout=2s")
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func loadFlags() {
        Task {
            if let rec = try? await container.collectorStore.getCollector(collectorId) {
                await MainActor.run {
                    self.flags = rec.flags
                    self.baselineFlags = rec.flags
                    self.hasChanges = false
                }
            }
        }
    }
    
    private func saveFlags() {
        manager.updateCollectorFlags(withId: collectorId, flags: flags)
        baselineFlags = flags
        hasChanges = false
    }
}

struct FlagReferenceRow: View {
    let flag: String
    let description: String
    let example: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(flag)
                    .font(.system(.callout, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(example, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Copy example")
            }
            
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(example)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
