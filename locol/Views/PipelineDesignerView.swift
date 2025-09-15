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

    // Component configuration modal state
    @State private var componentToEdit: ComponentInstance? = nil
    
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
        .sheet(item: $componentToEdit) { component in
            ComponentConfigurationModal(
                component: component,
                onSave: { updatedComponent in
                    updateComponent(updatedComponent)
                    componentToEdit = nil
                },
                onCancel: {
                    componentToEdit = nil
                }
            )
        }
    }
    
    // MARK: - Pipeline Canvas
    
    private var pipelineCanvas: some View {
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
                                        componentToEdit = component
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

    private func updateComponent(_ component: ComponentInstance) {
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

// MARK: - Component Configuration Modal

struct ComponentConfigurationModal: View {
    let component: ComponentInstance
    let onSave: (ComponentInstance) -> Void
    let onCancel: () -> Void

    @Environment(AppContainer.self) private var container

    @State private var componentName: String
    @State private var configurationValues: [String: ConfigValue] = [:]
    @State private var configStructure: ConfigSection?
    @State private var isLoading = true

    init(component: ComponentInstance, onSave: @escaping (ComponentInstance) -> Void, onCancel: @escaping () -> Void) {
        self.component = component
        self.onSave = onSave
        self.onCancel = onCancel
        self._componentName = State(initialValue: component.name)
    }

    private var dynamicWidth: CGFloat {
        let depth = configStructure?.maxDepth() ?? 1
        let baseWidth: CGFloat = 500
        return min(800, baseWidth + CGFloat(depth * 50))
    }

    private var dynamicHeight: CGFloat {
        let fieldCount = configStructure?.getAllFields().count ?? 0
        let depth = configStructure?.maxDepth() ?? 1
        let baseHeight: CGFloat = 400
        let heightPerField: CGFloat = 50
        let depthBonus: CGFloat = CGFloat(depth * 30)
        return min(700, max(400, baseHeight + CGFloat(fieldCount) * heightPerField + depthBonus))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                // Header info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: iconForComponentType(component.component.type))
                            .foregroundColor(component.component.type.color)
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(component.component.name)
                                .font(.headline)
                            Text(component.component.type.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }

                    if let description = component.component.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)

                // Component name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Instance Name")
                        .font(.headline)
                    TextField("Component name", text: $componentName)
                        .textFieldStyle(.roundedBorder)
                }

                // Configuration
                VStack(alignment: .leading, spacing: 8) {
                    Text("Configuration")
                        .font(.headline)

                    if isLoading {
                        ProgressView("Loading fields...")
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if configStructure == nil || (configStructure?.fields.isEmpty == true && configStructure?.subsections.isEmpty == true) {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No configuration fields available")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("This component doesn't have any configurable fields.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let configStructure = configStructure {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ConfigSectionView(
                                    section: configStructure,
                                    configurationValues: $configurationValues,
                                    isRoot: true
                                )
                            }
                            .padding(12)
                        }
                        .frame(minHeight: 150, maxHeight: .infinity)
                        .background(Color(.controlBackgroundColor).opacity(0.3))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.separatorColor).opacity(0.5), lineWidth: 1)
                        )
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Configure Component")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveConfiguration()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(width: dynamicWidth, height: dynamicHeight)
        .onAppear {
            loadFieldsAndConfiguration()
        }
    }

    private func loadFieldsAndConfiguration() {
        isLoading = true

        // Build hierarchical configuration structure
        configStructure = container.componentDatabase.buildConfigStructure(for: component.component)

        // Start with existing configuration values - no conversion needed!
        configurationValues = component.configuration

        // Set default values for fields that don't have current values
        let allFields = configStructure?.getAllFields() ?? []
        for field in allFields {
            if configurationValues[field.name] == nil {
                if let defaultValue = field.defaultValue {
                    // Parse the default value JSON to ConfigValue
                    configurationValues[field.name] = ConfigValue.from(any: defaultValue)
                } else {
                    // Set appropriate default based on field type
                    switch field.kind.lowercased() {
                    case "bool":
                        configurationValues[field.name] = .bool(false)
                    case "int", "int64":
                        configurationValues[field.name] = .int(0)
                    case "float64":
                        configurationValues[field.name] = .double(0.0)
                    case "duration":
                        configurationValues[field.name] = .duration(0)
                    default:
                        configurationValues[field.name] = .string("")
                    }
                }
            }
        }

        isLoading = false
    }

    private func saveConfiguration() {
        // Since we're working directly with ConfigValue, just use the current values
        // Filter out any null/empty values for cleaner config
        var newConfiguration: [String: ConfigValue] = [:]

        for (key, value) in configurationValues {
            switch value {
            case .string(let str) where !str.isEmpty:
                newConfiguration[key] = value
            case .int(_), .bool(_), .double(_), .duration(_), .stringArray(_), .array(_), .stringMap(_), .map(_):
                newConfiguration[key] = value
            case .null:
                // Skip null values
                break
            default:
                // Skip empty strings
                break
            }
        }

        // Create updated component by copying and updating
        var updatedComponent = component
        updatedComponent.name = componentName
        updatedComponent.configuration = newConfiguration

        onSave(updatedComponent)
    }

    private func iconForComponentType(_ type: ComponentType) -> String {
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

    private static func configValueToString(_ value: ConfigValue) -> String {
        switch value {
        case .string(let str):
            return str
        case .int(let int):
            return String(int)
        case .bool(let bool):
            return String(bool)
        case .double(let double):
            return String(double)
        case .duration(let duration):
            return "\(duration)"
        case .stringArray(let array):
            return "[" + array.map { "\"\($0)\"" }.joined(separator: ", ") + "]"
        case .array(let array):
            return "[" + array.map { Self.configValueToString($0) }.joined(separator: ", ") + "]"
        case .stringMap(let map):
            return "{" + map.map { "\($0.key): \"\($0.value)\"" }.joined(separator: ", ") + "}"
        case .map(let map):
            return "{" + map.map { "\($0.key): \(Self.configValueToString($0.value))" }.joined(separator: ", ") + "}"
        case .null:
            return "null"
        }
    }
}

// MARK: - Config Field View

struct ConfigFieldView: View {
    let field: Field
    @Binding var value: ConfigValue

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Field header
            HStack {
                HStack(spacing: 4) {
                    Text(field.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if field.isRequired {
                        Text("*")
                            .foregroundColor(.red)
                            .font(.headline)
                    }

                    // Help tooltip for description
                    if let description = field.description, !description.isEmpty {
                        Image(systemName: "questionmark.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .help(description)
                    }
                }

                Spacer()

                if !field.kind.isEmpty {
                    Text(field.kind)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(4)
                }
            }

            // Field control based on type using enum
            switch field.controlType {
            case .textField:
                TextField(field.defaultValue ?? "Enter \(field.name)", text: Binding(
                    get: {
                        if case .string(let str) = value { return str }
                        return ""
                    },
                    set: { value = .string($0) }
                ))
                .textFieldStyle(.roundedBorder)

            case .numberField:
                TextField(field.defaultValue ?? "0", text: Binding(
                    get: {
                        switch value {
                        case .int(let int): return String(int)
                        case .double(let double): return String(double)
                        default: return ""
                        }
                    },
                    set: {
                        if field.kind.lowercased().contains("float") || field.kind.lowercased().contains("double") {
                            value = .double(Double($0) ?? 0.0)
                        } else {
                            value = .int(Int($0) ?? 0)
                        }
                    }
                ))
                .textFieldStyle(.roundedBorder)

            case .toggle:
                Toggle(isOn: Binding(
                    get: {
                        if case .bool(let bool) = value { return bool }
                        return false
                    },
                    set: { newValue in
                        value = .bool(newValue)
                    }
                )) {
                    EmptyView()
                }

            default:
                // Fallback to text field for unsupported types
                TextField(field.defaultValue ?? "Enter \(field.name)", text: Binding(
                    get: {
                        if case .string(let str) = value { return str }
                        return ""
                    },
                    set: { value = .string($0) }
                ))
                .textFieldStyle(.roundedBorder)
            }

            // Unit display
            if let unit = field.unit, !unit.isEmpty {
                Text("Unit: \(unit)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(field.isRequired && value.isEmpty ? Color.red.opacity(0.3) : Color(.separatorColor), lineWidth: 1)
        )
    }
}

// MARK: - Extensions

extension UTType {
    static var yaml: UTType {
        UTType(filenameExtension: "yaml") ?? .plainText
    }
}

// MARK: - Config Section View

struct ConfigSectionView: View {
    @ObservedObject var section: ConfigSection
    @Binding var configurationValues: [String: ConfigValue]
    let isRoot: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Section header with collapse toggle (skip for root section)
            if !isRoot {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        section.isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: section.isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .animation(.easeInOut(duration: 0.2), value: section.isExpanded)

                        Text(section.name.capitalized)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Spacer()

                        if !section.fields.isEmpty {
                            Text("\(section.fields.count)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.separatorColor).opacity(0.3))
                                .clipShape(Capsule())
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }

            if section.isExpanded {
                VStack(spacing: 8) {
                    // Direct fields in this section
                    ForEach(section.fields) { field in
                        ConfigFieldView(
                            field: field,
                            value: Binding(
                                get: { configurationValues[field.name] ?? .string("") },
                                set: { configurationValues[field.name] = $0 }
                            )
                        )
                        .padding(.leading, isRoot ? 0 : 12)
                    }

                    // Subsections
                    ForEach(Array(section.subsections.keys.sorted()), id: \.self) { key in
                        if let subsection = section.subsections[key] {
                            ConfigSectionView(
                                section: subsection,
                                configurationValues: $configurationValues,
                                isRoot: false
                            )
                            .padding(.leading, isRoot ? 0 : 8)
                        }
                    }
                }
                .clipped()
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95, anchor: .topLeading).combined(with: .opacity),
                    removal: .scale(scale: 0.95, anchor: .topLeading).combined(with: .opacity)
                ))
            }
        }
    }
}

#Preview {
    PipelineDesignerView()
        .frame(width: 1200, height: 800)
}
