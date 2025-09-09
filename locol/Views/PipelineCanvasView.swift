import SwiftUI

struct PipelineCanvasView: View {
    @Binding var pipeline: PipelineConfiguration
    let definitions: [ComponentDefinition]
    let onComponentSelected: (ComponentInstance) -> Void
    // Creates a new instance for a definition, ensuring it's added to top-level config
    let createInstance: (ComponentDefinition) -> ComponentInstance
    
    private let componentSpacing: CGFloat = 120
    private let componentSize = CGSize(width: 100, height: 80)
    
    var body: some View {
        GeometryReader { geo in
            ScrollView([.horizontal, .vertical]) {
                ZStack {
                    // Grid background
                    gridBackground
                    
                    // Pipeline flow
                    pipelineFlow
                }
                // Match the visible area without forcing extra width/height
                .frame(minWidth: geo.size.width, minHeight: geo.size.height)
                .background(Color(.controlBackgroundColor).opacity(0.3))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .onDrop(of: [.text], delegate: PipelineDropDelegate(
            pipeline: $pipeline,
            definitions: definitions,
            createInstance: createInstance
        ))
    }
    
    // MARK: - Grid Background
    
    private var gridBackground: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 20
            
            context.stroke(
                Path { path in
                    // Vertical lines
                    for x in stride(from: 0, through: size.width, by: gridSize) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    
                    // Horizontal lines
                    for y in stride(from: 0, through: size.height, by: gridSize) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                },
                with: .color(.secondary.opacity(0.1)),
                lineWidth: 0.5
            )
        }
    }
    
    // MARK: - Pipeline Flow
    
    private var pipelineFlow: some View {
        VStack(spacing: 40) {
            // Title
            Text("Pipeline: \(pipeline.name)")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 40)
            
            VStack(spacing: 40) {
                // Receivers row
                if !pipeline.receivers.isEmpty {
                    pipelineStage(
                        title: "Receivers",
                        components: pipeline.receivers,
                        color: .blue,
                        systemImage: "antenna.radiowaves.left.and.right"
                    )
                } else {
                    emptyStage(
                        title: "Receivers",
                        color: .blue,
                        systemImage: "antenna.radiowaves.left.and.right",
                        dropTypes: [.receiver]
                    )
                }
                
                // Flow arrow
                if !pipeline.receivers.isEmpty || !pipeline.processors.isEmpty || !pipeline.exporters.isEmpty {
                    flowArrow
                }
                
                // Processors row (optional)
                if !pipeline.processors.isEmpty {
                    pipelineStage(
                        title: "Processors",
                        components: pipeline.processors,
                        color: .orange,
                        systemImage: "gearshape.2"
                    )
                    
                    // Flow arrow
                    flowArrow
                } else if !pipeline.receivers.isEmpty || !pipeline.exporters.isEmpty {
                    emptyStage(
                        title: "Processors (Optional)",
                        color: .orange,
                        systemImage: "gearshape.2",
                        dropTypes: [.processor]
                    )
                    
                    // Flow arrow  
                    flowArrow
                }
                
                // Exporters row
                if !pipeline.exporters.isEmpty {
                    pipelineStage(
                        title: "Exporters",
                        components: pipeline.exporters,
                        color: .green,
                        systemImage: "arrow.up.right"
                    )
                } else {
                    emptyStage(
                        title: "Exporters",
                        color: .green,
                        systemImage: "arrow.up.right",
                        dropTypes: [.exporter]
                    )
                }
            }
            
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func pipelineStage(
        title: String,
        components: [ComponentInstance],
        color: Color,
        systemImage: String
    ) -> some View {
        VStack(spacing: 16) {
            // Stage header
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
                Spacer()
                Text("\(components.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 400)
            
            // Components
            HStack(spacing: 16) {
                ForEach(components) { component in
                    ComponentCardView(
                        component: component,
                        onTap: { onComponentSelected(component) },
                        onRemove: {
                            removeComponentFromPipeline(component)
                        }
                    )
                }
            }
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
        .frame(maxWidth: 500)
        .onDrop(of: [.text], delegate: StageDropDelegate(
            pipeline: $pipeline,
            stageType: components.first?.definition.type ?? .receiver,
            definitions: definitions,
            createInstance: createInstance
        ))
    }
    
    private func emptyStage(
        title: String,
        color: Color,
        systemImage: String,
        dropTypes: [ComponentType]
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(color.opacity(0.6))
            
            Text(title)
                .font(.headline)
                .foregroundColor(color.opacity(0.8))
            
            Text("Drop components here")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 200, height: 100)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5]))
                .background(color.opacity(0.05))
        )
        .cornerRadius(12)
        .onDrop(of: [.text], delegate: StageDropDelegate(
            pipeline: $pipeline,
            stageType: dropTypes.first ?? .receiver,
            definitions: definitions,
            createInstance: createInstance
        ))
    }
    
    private var flowArrow: some View {
        Image(systemName: "arrow.down")
            .font(.title2)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
    }
    
    private func removeComponentFromPipeline(_ component: ComponentInstance) {
        pipeline.receivers.removeAll { $0.id == component.id }
        pipeline.processors.removeAll { $0.id == component.id }
        pipeline.exporters.removeAll { $0.id == component.id }
    }
}

// MARK: - Component Card View

struct ComponentCardView: View {
    let component: ComponentInstance
    let onTap: () -> Void
    let onRemove: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Type icon
            Image(systemName: iconForComponent(component.definition.type))
                .font(.title3)
                .foregroundColor(component.definition.type.color)
            
            // Component name
            Text(component.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            // Configuration indicator
            if !component.configuration.isEmpty {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 4, height: 4)
            }
        }
        .frame(width: 80, height: 70)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isHovered ? component.definition.type.color : Color.clear,
                    lineWidth: 2
                )
        )
        .overlay(
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .background(Color.white)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .font(.caption)
            .opacity(isHovered ? 1 : 0)
            .offset(x: 32, y: -32)
        )
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
    }
    
    private func iconForComponent(_ type: ComponentType) -> String {
        switch type {
        case .receiver:
            return "antenna.radiowaves.left.and.right"
        case .processor:
            return "gearshape.2"
        case .exporter:
            return "arrow.up.right"
        case .extension:
            return "puzzlepiece.extension"
        case .connector:
            return "cable.connector"
        }
    }
}

// MARK: - Drop Delegates

struct PipelineDropDelegate: DropDelegate {
    @Binding var pipeline: PipelineConfiguration
    let definitions: [ComponentDefinition]
    let createInstance: (ComponentDefinition) -> ComponentInstance
    
    func performDrop(info: DropInfo) -> Bool {
        // Handle dropping components (from the drawer)
        guard let itemProviders = info.itemProviders(for: [.text]).first else { return false }
        
        itemProviders.loadItem(forTypeIdentifier: "public.text", options: nil) { (item, error) in
            if let data = item as? Data,
               let payload = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    handleDropPayload(payload)
                }
            }
        }
        
        return true
    }
    
    private func handleDropPayload(_ payload: String) {
        if payload.hasPrefix("component-definition:"),
           let idStr = payload.split(separator: ":").last,
           let id = Int(idStr),
           let def = definitions.first(where: { $0.id == id }) {
            let instance = createInstance(def)
            addComponentToPipeline(instance)
        }
    }

    private func addComponentToPipeline(_ component: ComponentInstance) {
        switch component.definition.type {
        case .receiver:
            if !pipeline.receivers.contains(where: { $0.id == component.id }) {
                pipeline.receivers.append(component)
            }
        case .processor:
            if !pipeline.processors.contains(where: { $0.id == component.id }) {
                pipeline.processors.append(component)
            }
        case .exporter:
            if !pipeline.exporters.contains(where: { $0.id == component.id }) {
                pipeline.exporters.append(component)
            }
        default:
            break // Extensions and connectors don't go in pipelines
        }
    }
}

struct StageDropDelegate: DropDelegate {
    @Binding var pipeline: PipelineConfiguration
    let stageType: ComponentType
    let definitions: [ComponentDefinition]
    let createInstance: (ComponentDefinition) -> ComponentInstance
    
    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.text])
    }
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProviders = info.itemProviders(for: [.text]).first else { return false }
        
        itemProviders.loadItem(forTypeIdentifier: "public.text", options: nil) { (item, error) in
            if let data = item as? Data,
               let payload = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    handleDropPayload(payload)
                }
            }
        }
        
        return true
    }

    private func handleDropPayload(_ payload: String) {
        if payload.hasPrefix("component-definition:"),
           let idStr = payload.split(separator: ":").last,
           let id = Int(idStr),
           let def = definitions.first(where: { $0.id == id }) {
            let instance = createInstance(def)
            addIfMatchesStage(instance)
        }
    }

    private func addIfMatchesStage(_ component: ComponentInstance) {
        guard component.definition.type == stageType else { return }
        switch stageType {
        case .receiver:
            if !pipeline.receivers.contains(where: { $0.id == component.id }) {
                pipeline.receivers.append(component)
            }
        case .processor:
            if !pipeline.processors.contains(where: { $0.id == component.id }) {
                pipeline.processors.append(component)
            }
        case .exporter:
            if !pipeline.exporters.contains(where: { $0.id == component.id }) {
                pipeline.exporters.append(component)
            }
        default:
            break
        }
    }
}

#Preview {
    @State var pipeline = PipelineConfiguration(name: "traces")
    let defs: [ComponentDefinition] = []
    
    return PipelineCanvasView(
        pipeline: $pipeline,
        definitions: defs,
        onComponentSelected: { _ in },
        createInstance: { def in ComponentInstance(definition: def, instanceName: def.name) }
    )
    .frame(width: 800, height: 600)
}
