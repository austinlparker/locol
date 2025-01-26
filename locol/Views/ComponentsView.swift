import SwiftUI

struct ComponentsView: View {
    let collector: CollectorInstance
    
    var body: some View {
        if let components = collector.components {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let receivers = components.receivers {
                        ComponentSection(
                            title: "Receivers",
                            components: receivers.map { CollectorComponent(name: $0.name, module: $0.module) },
                            version: collector.version,
                            color: .blue
                        )
                    }
                    
                    if let processors = components.processors {
                        ComponentSection(
                            title: "Processors",
                            components: processors.map { CollectorComponent(name: $0.name, module: $0.module) },
                            version: collector.version,
                            color: .purple
                        )
                    }
                    
                    if let exporters = components.exporters {
                        ComponentSection(
                            title: "Exporters",
                            components: exporters.map { CollectorComponent(name: $0.name, module: $0.module) },
                            version: collector.version,
                            color: .green
                        )
                    }
                    
                    if let extensions = components.extensions {
                        ComponentSection(
                            title: "Extensions",
                            components: extensions.map { CollectorComponent(name: $0.name, module: $0.module) },
                            version: collector.version,
                            color: .orange
                        )
                    }
                    
                    if let connectors = components.connectors {
                        ComponentSection(
                            title: "Connectors",
                            components: connectors.map { CollectorComponent(name: $0.name, module: $0.module) },
                            version: collector.version,
                            color: .red
                        )
                    }
                }
                .padding()
            }
        } else {
            ContentUnavailableView {
                Label("No Components", systemImage: "cube.box")
            } description: {
                Text("Failed to load components from the collector")
            }
        }
    }
} 