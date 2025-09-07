import SwiftUI

struct ComponentsView: View {
    let collectorId: UUID
    let manager: CollectorManager
    
    private var collector: CollectorInstance? {
        manager.collectors.first { $0.id == collectorId }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let components = collector?.components {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        // Receivers
                        if let receivers = components.receivers, !receivers.isEmpty {
                            ComponentSection(title: "Receivers", components: receivers.map(\.name), version: "", color: .blue)
                        }
                        
                        // Processors
                        if let processors = components.processors, !processors.isEmpty {
                            ComponentSection(title: "Processors", components: processors.map(\.name), version: "", color: .orange)
                        }
                        
                        // Exporters
                        if let exporters = components.exporters, !exporters.isEmpty {
                            ComponentSection(title: "Exporters", components: exporters.map(\.name), version: "", color: .green)
                        }
                        
                        // Extensions
                        if let extensions = components.extensions, !extensions.isEmpty {
                            ComponentSection(title: "Extensions", components: extensions.map(\.name), version: "", color: .purple)
                        }
                        
                        // Connectors
                        if let connectors = components.connectors, !connectors.isEmpty {
                            ComponentSection(title: "Connectors", components: connectors.map(\.name), version: "", color: .pink)
                        }
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView {
                    Label("No Component Information", systemImage: "puzzlepiece")
                } description: {
                    Text("Component information is not available for this collector.")
                } actions: {
                    Button("Refresh Components") {
                        Task {
                            try? await manager.refreshCollectorComponents(withId: collectorId)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Components")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}