import SwiftUI
import UniformTypeIdentifiers
import GRDBQuery
import os

struct PipelineDesignerView: View {
    let collectorId: UUID?
    @Environment(AppContainer.self) private var container
    @Environment(\.databaseContext) private var databaseContext

    // CollectorComponent data via GRDBQuery - automatically reactive
    @Query(ComponentsRequest()) private var allComponents: [CollectorComponent]
    @Query(DocumentRequest()) private var document: Document?

    // (no old drag state needed)
    
    init(collectorId: UUID? = nil) {
        self.collectorId = collectorId
    }
    
    // Collector details are loaded via store in AppContainer; we don't rely on AppState here.
    
    var body: some View {
        // Visual pipeline editor - full width
        pipelineCanvas
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Pipeline Designer")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Add Pipeline") {
                    addNewPipeline()
                }
            }
            
            ToolbarItemGroup(placement: .secondaryAction) {
                if collectorId != nil {
                    Button("Save") {
                        Task { await saveToCollector() }
                    }
                    .keyboardShortcut("s", modifiers: .command)
                }
                
                Button("Export YAML") {
                    exportConfiguration()
                }
                
                Button("Import YAML") {
                    importConfiguration()
                }
            }
        }
        .task {
            await loadCollectorConfiguration()
        }
    }
    
    // MARK: - Pipeline Canvas
    
    private var pipelineCanvas: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Canvas header
            HStack {
                if let pipeline = container.selectedPipeline {
                    Text("Pipeline: \(pipeline.name)")
                        .font(.headline)
                    
                } else {
                    Text("Select a pipeline to edit")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
            }
            .padding()
            
            Divider()
            
            // Canvas content - All pipelines with grid background
            GeometryReader { geometry in
                ZStack {
                    // Grid background for entire designer
                    gridBackground

                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 60) {
                            ForEach(container.pipelineConfig.pipelines) { pipeline in
                                PipelineView(
                                    pipeline: pipeline,
                                    definitions: allComponents,
                                    onComponentSelected: { component in
                                        container.selectedPipelineComponent = component
                                    },
                                    createInstance: { component in
                                        createInstance(for: component)
                                    },
                                    isSelected: container.selectedPipeline?.id == pipeline.id,
                                    onTap: {
                                        container.selectedPipeline = pipeline
                                    },
                                    onNameChanged: { newName in
                                        updatePipelineName(pipeline, newName: newName)
                                    },
                                    onComponentAdded: { component, pipeline in
                                        addComponentToPipeline(component, pipeline: pipeline)
                                    }
                                )
                                .frame(maxWidth: .infinity)
                            }

                            // Add new pipeline button
                            Button(action: addNewPipeline) {
                                VStack(spacing: 16) {
                                    Image(systemName: "plus.circle")
                                        .font(.title)
                                    Text("Add Pipeline")
                                        .font(.headline)
                                }
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 120)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 40)
                        }
                        .padding(.vertical, 40)
                    }
                }
            }

        }
    }

    // MARK: - Helper Views

    private func createInstance(for component: CollectorComponent) -> ComponentInstance {
        ComponentInstance(component: component, name: component.name)
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

    // MARK: - Actions

    private func addNewPipeline() {
        let pipelineName = generateUniquePipelineName()
        let newPipeline = PipelineConfiguration(name: pipelineName)
        container.pipelineConfig.pipelines.append(newPipeline)
        container.selectedPipeline = newPipeline
    }

    private func generateUniquePipelineName() -> String {
        let baseName = "new_pipeline"

        // Check if base name is available
        if !container.pipelineConfig.pipelines.contains(where: { $0.name == baseName }) {
            return baseName
        }

        // Generate numbered pipeline
        var counter = 2
        while container.pipelineConfig.pipelines.contains(where: { $0.name == "\(baseName)_\(counter)" }) {
            counter += 1
        }
        return "\(baseName)_\(counter)"
    }

    private func updatePipelineName(_ pipeline: PipelineConfiguration, newName: String) {
        guard let index = container.pipelineConfig.pipelines.firstIndex(where: { $0.id == pipeline.id }) else {
            return
        }
        container.pipelineConfig.pipelines[index].name = newName
    }

    private func deletePipelines(at indices: IndexSet) {
        container.pipelineConfig.pipelines.remove(atOffsets: indices)
        if let selected = container.selectedPipeline,
           !container.pipelineConfig.pipelines.contains(selected) {
            container.selectedPipeline = container.pipelineConfig.pipelines.first
        }
    }

    private func deleteCollectorComponents(at indices: IndexSet, from keyPath: WritableKeyPath<CollectorConfiguration, [ComponentInstance]>) {
        container.pipelineConfig[keyPath: keyPath].remove(atOffsets: indices)
    }

    private func updateCollectorComponent(_ component: ComponentInstance) {
        // Update the component in the appropriate array
        if let index = container.pipelineConfig.receivers.firstIndex(where: { $0.id == component.id }) {
            container.pipelineConfig.receivers[index] = component
        } else if let index = container.pipelineConfig.processors.firstIndex(where: { $0.id == component.id }) {
            container.pipelineConfig.processors[index] = component
        } else if let index = container.pipelineConfig.exporters.firstIndex(where: { $0.id == component.id }) {
            container.pipelineConfig.exporters[index] = component
        } else if let index = container.pipelineConfig.extensions.firstIndex(where: { $0.id == component.id }) {
            container.pipelineConfig.extensions[index] = component
        } else if let index = container.pipelineConfig.connectors.firstIndex(where: { $0.id == component.id }) {
            container.pipelineConfig.connectors[index] = component
        }

        // Also update in pipelines if needed
        for (pipelineIndex, pipeline) in container.pipelineConfig.pipelines.enumerated() {
            var updatedPipeline = pipeline
            var needsUpdate = false

            if let receiverIndex = updatedPipeline.receivers.firstIndex(where: { $0.id == component.id }) {
                updatedPipeline.receivers[receiverIndex] = component
                needsUpdate = true
            }
            if let processorIndex = updatedPipeline.processors.firstIndex(where: { $0.id == component.id }) {
                updatedPipeline.processors[processorIndex] = component
                needsUpdate = true
            }
            if let exporterIndex = updatedPipeline.exporters.firstIndex(where: { $0.id == component.id }) {
                updatedPipeline.exporters[exporterIndex] = component
                needsUpdate = true
            }

            if needsUpdate {
                container.pipelineConfig.pipelines[pipelineIndex] = updatedPipeline
            }
        }
    }

    private func exportConfiguration() {
        do {
            let yaml = try ConfigSerializer.generateYAML(from: container.pipelineConfig)

            let panel = NSSavePanel()
            panel.allowedContentTypes = [.yaml]
            panel.nameFieldStringValue = "collector-config.yaml"

            if panel.runModal() == .OK, let url = panel.url {
                try yaml.write(to: url, atomically: true, encoding: .utf8)
            }
        } catch {
            // TODO: Show error alert
            Logger.ui.debug("Export failed: \(error)")
        }
    }

    private func saveToCollector() async {
        guard let collectorId else { return }
        do {
            let versionId = try await container.collectorStore.saveConfigVersion(collectorId, config: container.pipelineConfig, autosave: false)
            try await container.collectorStore.setCurrentConfig(collectorId, versionId: versionId)
        } catch {
            Logger.ui.debug("Failed to save config to store: \(error)")
        }
    }

    private func importConfiguration() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.yaml]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let yaml = try String(contentsOf: url, encoding: .utf8)
                Task {
                    do {
                        let parsedConfig = try await ConfigSerializer.parseYAML(yaml, version: container.pipelineConfig.version)
                        await MainActor.run {
                            container.pipelineConfig = parsedConfig
                            container.selectedPipeline = parsedConfig.pipelines.first
                            container.selectedPipelineComponent = nil
                        }
                    } catch {
                        Logger.ui.debug("Import failed: \(error)")
                    }
                }
            } catch {
                // TODO: Show error alert
                Logger.ui.debug("Import failed: \(error)")
            }
        }
    }

    // MARK: - Configuration Loading

    private func loadCollectorConfiguration() async {
        guard let collectorId else { return }
        await container.loadCollectorConfiguration(forCollectorId: collectorId)
    }

    // MARK: - Drag and Drop Support

    private func handleDrop(providers: [NSItemProvider], pipeline: PipelineConfiguration) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: "public.text", options: nil) { (item, error) in
            if let data = item as? Data,
               let payload = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.processDropPayload(payload, pipeline: pipeline)
                }
            }
        }

        return true
    }

    private func handleStageSpecificDrop(providers: [NSItemProvider], pipeline: PipelineConfiguration, targetType: ComponentType) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: "public.text", options: nil) { (item, error) in
            if let data = item as? Data,
               let payload = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.processDropPayload(payload, pipeline: pipeline, targetType: targetType)
                }
            }
        }

        return true
    }

    private func processDropPayload(_ payload: String, pipeline: PipelineConfiguration, targetType: ComponentType? = nil) {
        if payload.hasPrefix("component-definition:"),
           let idStr = payload.split(separator: ":").last,
           let id = Int(idStr),
           let definition = allComponents.first(where: { $0.id == id }) {

            // If targetType is specified, only allow matching component types
            if let targetType = targetType, definition.type != targetType {
                return
            }

            let instance = createInstance(for: definition)
            addComponentToPipeline(instance, pipeline: pipeline)
        }
    }

    private func addComponentToPipeline(_ component: ComponentInstance, pipeline: PipelineConfiguration) {
        guard let index = container.pipelineConfig.pipelines.firstIndex(where: { $0.id == pipeline.id }) else {
            return
        }

        switch component.component.type {
        case .receiver:
            if !container.pipelineConfig.pipelines[index].receivers.contains(where: { $0.id == component.id }) {
                container.pipelineConfig.pipelines[index].receivers.append(component)
            }
        case .processor:
            if !container.pipelineConfig.pipelines[index].processors.contains(where: { $0.id == component.id }) {
                container.pipelineConfig.pipelines[index].processors.append(component)
            }
        case .exporter:
            if !container.pipelineConfig.pipelines[index].exporters.contains(where: { $0.id == component.id }) {
                container.pipelineConfig.pipelines[index].exporters.append(component)
            }
        default:
            break // Extensions and connectors don't go in pipelines
        }
    }
}

// MARK: - Pipeline View

struct PipelineView: View {
    let pipeline: PipelineConfiguration
    let definitions: [CollectorComponent]
    let onComponentSelected: (ComponentInstance) -> Void
    let createInstance: (CollectorComponent) -> ComponentInstance
    let isSelected: Bool
    let onTap: () -> Void
    let onNameChanged: (String) -> Void
    let onComponentAdded: (ComponentInstance, PipelineConfiguration) -> Void

    @State private var isEditingName = false
    @State private var editingName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Pipeline title
            HStack {
                if isEditingName {
                    TextField("Pipeline name", text: $editingName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            finishEditing()
                        }
                        .onExitCommand {
                            cancelEditing()
                        }
                } else {
                    Text(pipeline.name.isEmpty ? "Untitled Pipeline" : pipeline.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .onTapGesture {
                            startEditing()
                        }
                }
                Spacer()
            }
            .padding(.horizontal, 20)

            // Pipeline flow - horizontal components
            HStack(spacing: 40) {
                // Receivers
                pipelineStage(
                    title: "Receivers",
                    components: pipeline.receivers,
                    color: .blue,
                    systemImage: "antenna.radiowaves.left.and.right",
                    dropTypes: [.receiver]
                )

                if !pipeline.receivers.isEmpty || !pipeline.processors.isEmpty || !pipeline.exporters.isEmpty {
                    flowArrow
                }

                // Processors
                pipelineStage(
                    title: "Processors",
                    components: pipeline.processors,
                    color: .orange,
                    systemImage: "gearshape.2",
                    dropTypes: [.processor]
                )

                if !pipeline.processors.isEmpty || !pipeline.exporters.isEmpty {
                    flowArrow
                }

                // Exporters
                pipelineStage(
                    title: "Exporters",
                    components: pipeline.exporters,
                    color: .green,
                    systemImage: "arrow.up.right",
                    dropTypes: [.exporter]
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 30)
        }
        .onTapGesture(perform: onTap)
        .onDrop(of: [.text], isTargeted: nil) { providers in
            handleDrop(providers: providers, pipeline: pipeline)
        }
    }

    private func startEditing() {
        editingName = pipeline.name
        isEditingName = true
    }

    private func finishEditing() {
        let trimmedName = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            onNameChanged(trimmedName)
        }
        isEditingName = false
    }

    private func cancelEditing() {
        editingName = pipeline.name
        isEditingName = false
    }

    private func pipelineStage(
        title: String,
        components: [ComponentInstance],
        color: Color,
        systemImage: String,
        dropTypes: [ComponentType]
    ) -> some View {
        VStack(spacing: 12) {
            // Stage header
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
                Spacer()
                if !components.isEmpty {
                    Text("\\(components.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if components.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.title2)
                        .foregroundColor(color.opacity(0.6))

                    Text("Drop \\(title.lowercased()) here")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 160, height: 80)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5]))
                        .background(color.opacity(0.05))
                )
                .cornerRadius(8)
            } else {
                // Components
                VStack(spacing: 8) {
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
                .frame(width: 160)
            }
        }
        .onDrop(of: [.text], isTargeted: nil) { providers in
            handleStageSpecificDrop(providers: providers, pipeline: pipeline, targetType: dropTypes.first ?? .receiver)
        }
    }

    private var flowArrow: some View {
        Image(systemName: "arrow.right")
            .font(.title2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
    }

    private func removeComponentFromPipeline(_ component: ComponentInstance) {
        // TODO: Implement component removal through observable callbacks
        // For now, this is disabled as pipeline is read-only
    }

    // MARK: - Drag and Drop Support

    private func handleDrop(providers: [NSItemProvider], pipeline: PipelineConfiguration) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: "public.text", options: nil) { (item, error) in
            if let data = item as? Data,
               let payload = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.processDropPayload(payload, pipeline: pipeline)
                }
            }
        }

        return true
    }

    private func handleStageSpecificDrop(providers: [NSItemProvider], pipeline: PipelineConfiguration, targetType: ComponentType) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: "public.text", options: nil) { (item, error) in
            if let data = item as? Data,
               let payload = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.processDropPayload(payload, pipeline: pipeline, targetType: targetType)
                }
            }
        }

        return true
    }

    private func processDropPayload(_ payload: String, pipeline: PipelineConfiguration, targetType: ComponentType? = nil) {
        if payload.hasPrefix("component-definition:") {
            if let idStr = payload.split(separator: ":").last {
                if let id = Int(idStr) {
                    if let definition = definitions.first(where: { $0.id == id }) {
                        // If targetType is specified, only allow matching component types
                        if let targetType = targetType {
                            if definition.type != targetType {
                                return
                            }
                        }

                        let instance = createInstance(definition)
                        onComponentAdded(instance, pipeline)
                    }
                }
            }
        }
    }



}

struct CollectorComponentRowView: View {
    let component: ComponentInstance
    @Binding var selectedCollectorComponent: ComponentInstance?

    var body: some View {
        HStack {
            Circle()
                .fill(component.component.type.color)
                .frame(width: 6, height: 6)

            Text(component.name)
                .font(.body)
            
            Spacer()
            
            if !component.configuration.isEmpty {
                Button {
                    // Make the cog actionable: select and focus this component
                    selectedCollectorComponent = component
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Open configuration for this component")
                .accessibilityLabel("Open configuration")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedCollectorComponent = component
        }
        .background(
            selectedCollectorComponent?.id == component.id ? 
            Color.accentColor.opacity(0.2) : Color.clear
        )
        .cornerRadius(4)
    }
}

struct StatusIndicator: View {
    let text: String
    let color: Color
    let isValid: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isValid ? color : .red)
                .frame(width: 6, height: 6)
            
            Text(text)
                .foregroundStyle(isValid ? color : .red)
        }
    }
}

// MARK: - Extensions

extension UTType {
    static var yaml: UTType {
        UTType(filenameExtension: "yaml") ?? .plainText
    }
}


#Preview {
    PipelineDesignerView()
        .frame(width: 1200, height: 800)
}
