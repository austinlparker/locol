import SwiftUI
import UniformTypeIdentifiers
import GRDBQuery
import os
import Observation

struct PipelineDesignerView: View {
    let collectorId: UUID?
    @Environment(AppContainer.self) private var container

    // CollectorComponent data via GRDBQuery - automatically reactive
    @Query(ComponentsRequest()) private var allComponents: [CollectorComponent]

    // Component configuration modal state
    @State private var componentToEdit: ComponentInstance? = nil

    // Autosave state
    @State private var autosaveTask: Task<Void, Never>? = nil
    @State private var hasUnsavedChanges = false
    @State private var isSaving = false
    @State private var saveStatus: SaveStatus = .none

    enum SaveStatus: Equatable {
        case none
        case saving
        case saved
        case error(String)
    }
    
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
                    // Save status indicator
                    saveStatusView

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
                
                Button("Debug & Clean") {
                    debugCurrentState()
                    cleanupPipelineReferences()
                    scheduleAutosave()
                }
            }
        }
        .task {
            await loadCollectorConfiguration()
            normalizeAllComponents()
            // Clean up any inconsistent references after loading
            cleanupPipelineReferences()
        }
        .onDisappear {
            Task {
                await performFinalSaveIfNeeded()
                cancelAutosaveTimer()
            }
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

    // MARK: - Save Status View

    private var saveStatusView: some View {
        HStack(spacing: 4) {
            switch saveStatus {
            case .none:
                if hasUnsavedChanges {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundColor(.orange)
                    Text("Unsaved")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    EmptyView()
                }
            case .saving:
                Image(systemName: "circle.dotted")
                    .font(.system(size: 8))
                    .foregroundColor(.blue)
                Text("Saving...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            case .saved:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.green)
                Text("Saved")
                    .font(.caption)
                    .foregroundColor(.secondary)
            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.red)
                Text("Error")
                    .font(.caption)
                    .foregroundColor(.red)
                    .help(message)
            }
        }
    }

    // MARK: - Pipeline Canvas
    
    private var pipelineCanvas: some View {
        GeometryReader { _ in
            ZStack {
                gridBackground

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 60) {
                        ForEach(container.pipelineConfig.pipelines) { pipeline in
                            PipelineView(
                                pipeline: pipeline,
                                definitions: allComponents,
                                resolveComponent: resolveComponentInstance,
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
                                },
                                onComponentRemoved: { component, pipeline in
                                    removeComponentFromPipeline(component, pipeline: pipeline)
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
        let existingNames = Set(container.pipelineConfig.allComponents.map { $0.name })
        let uniqueName = normalizedInstanceName(
            for: component,
            requestedAlias: nil,
            existingNames: existingNames
        )
        return ComponentInstance(component: component, name: uniqueName)
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

    // MARK: - Configuration Cleanup
    
    private func debugCurrentState() {
        Logger.ui.debug("=== CURRENT CONFIGURATION STATE ===")
        Logger.ui.debug("Global receivers: \(container.pipelineConfig.receivers.map { $0.name }.joined(separator: ", "))")
        Logger.ui.debug("Global processors: \(container.pipelineConfig.processors.map { $0.name }.joined(separator: ", "))")
        Logger.ui.debug("Global exporters: \(container.pipelineConfig.exporters.map { $0.name }.joined(separator: ", "))")
        
        for (index, pipeline) in container.pipelineConfig.pipelines.enumerated() {
            Logger.ui.debug("Pipeline '\(pipeline.name)' receivers: \(pipeline.receivers.map { $0.name }.joined(separator: ", "))")
            Logger.ui.debug("Pipeline '\(pipeline.name)' processors: \(pipeline.processors.map { $0.name }.joined(separator: ", "))")
            Logger.ui.debug("Pipeline '\(pipeline.name)' exporters: \(pipeline.exporters.map { $0.name }.joined(separator: ", "))")
        }
        Logger.ui.debug("=== END STATE ===")
    }

    private func cleanupPipelineReferences() {
        Logger.ui.debug("Cleaning up pipeline references...")

        normalizeAllComponents()
        deduplicateGlobalComponents()

        let globalReceiverNames = Set(container.pipelineConfig.receivers.map { $0.name })
        let globalProcessorNames = Set(container.pipelineConfig.processors.map { $0.name })
        let globalExporterNames = Set(container.pipelineConfig.exporters.map { $0.name })
        
        Logger.ui.debug("Global exporters: \(Array(globalExporterNames).joined(separator: ", "))")
        
        for (pipelineIndex, pipeline) in container.pipelineConfig.pipelines.enumerated() {
            var needsUpdate = false
            var updatedPipeline = pipeline
            
            // Clean up receiver references
            let validReceivers = updatedPipeline.receivers.filter { component in
                let isValid = globalReceiverNames.contains(component.name)
                if !isValid {
                    Logger.ui.debug("Removing invalid receiver reference '\(component.name)' from pipeline '\(pipeline.name)'")
                }
                return isValid
            }
            if validReceivers.count != updatedPipeline.receivers.count {
                updatedPipeline.receivers = validReceivers
                needsUpdate = true
            }
            
            // Clean up processor references
            let validProcessors = updatedPipeline.processors.filter { component in
                let isValid = globalProcessorNames.contains(component.name)
                if !isValid {
                    Logger.ui.debug("Removing invalid processor reference '\(component.name)' from pipeline '\(pipeline.name)'")
                }
                return isValid
            }
            if validProcessors.count != updatedPipeline.processors.count {
                updatedPipeline.processors = validProcessors
                needsUpdate = true
            }
            
            // Clean up exporter references
            let validExporters = updatedPipeline.exporters.filter { component in
                let isValid = globalExporterNames.contains(component.name)
                if !isValid {
                    Logger.ui.debug("Removing invalid exporter reference '\(component.name)' from pipeline '\(pipeline.name)'")
                }
                return isValid
            }
            if validExporters.count != updatedPipeline.exporters.count {
                updatedPipeline.exporters = validExporters
                needsUpdate = true
            }
            
            if needsUpdate {
                container.pipelineConfig.pipelines[pipelineIndex] = updatedPipeline
                Logger.ui.debug("Updated pipeline '\(pipeline.name)' references")
            }
        }
    }

    // MARK: - Actions

    private func addNewPipeline() {
        let pipelineName = generateUniquePipelineName()
        let newPipeline = PipelineConfiguration(name: pipelineName)
        container.pipelineConfig.pipelines.append(newPipeline)
        container.selectedPipeline = newPipeline
        scheduleAutosave()
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
        scheduleAutosave()
    }

    private func deletePipelines(at indices: IndexSet) {
        container.pipelineConfig.pipelines.remove(atOffsets: indices)
        if let selected = container.selectedPipeline,
           !container.pipelineConfig.pipelines.contains(selected) {
            container.selectedPipeline = container.pipelineConfig.pipelines.first
        }
        scheduleAutosave()
    }

    private func deleteCollectorComponents(at indices: IndexSet, from keyPath: WritableKeyPath<CollectorConfiguration, [ComponentInstance]>) {
        container.pipelineConfig[keyPath: keyPath].remove(atOffsets: indices)
    }

    private func updateComponent(_ component: ComponentInstance) {
        // Update the component in the global arrays
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

        // Also update in all pipelines where this component is used
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
        scheduleAutosave()
    }

    private func exportConfiguration() {
        do {
            Logger.ui.debug("Exporting configuration: receivers=\(container.pipelineConfig.receivers.count), processors=\(container.pipelineConfig.processors.count), exporters=\(container.pipelineConfig.exporters.count)")
            let yaml = try ConfigSerializer.generateYAML(from: container.pipelineConfig)
            Logger.ui.debug("Generated YAML successfully")

            let panel = NSSavePanel()
            panel.allowedContentTypes = [.yaml]
            panel.nameFieldStringValue = "collector-config.yaml"

            if panel.runModal() == .OK, let url = panel.url {
                try yaml.write(to: url, atomically: true, encoding: .utf8)
                Logger.ui.debug("YAML exported successfully to: \(url)")
            }
        } catch {
            // TODO: Show error alert
            Logger.ui.error("Export failed: \(error)")
        }
    }

    private func saveToCollector() async {
        guard let collectorId else { return }
        do {
            withAnimation(.easeInOut(duration: 0.2)) {
                saveStatus = .saving
            }
            
            // Clean up any invalid pipeline references first
            cleanupPipelineReferences()
            
            let versionId = try await container.collectorStore.saveConfigVersion(collectorId, config: container.pipelineConfig, autosave: false)
            try await container.collectorStore.setCurrentConfig(collectorId, versionId: versionId)
            hasUnsavedChanges = false
            withAnimation(.easeInOut(duration: 0.2)) {
                saveStatus = .saved
            }

            // Clear saved status after a brief display
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if case .saved = saveStatus {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        saveStatus = .none
                    }
                }
            }
        } catch {
            Logger.ui.debug("Failed to save config to store: \(error)")
            withAnimation(.easeInOut(duration: 0.2)) {
                saveStatus = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Autosave Implementation

    private func scheduleAutosave() {
        guard collectorId != nil else { return }
        // Cancel any pending task
        autosaveTask?.cancel()
        hasUnsavedChanges = true
        // Debounce for ~2 seconds
        autosaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await performAutosave()
        }
    }

    private func performAutosave() async {
        guard let collectorId, hasUnsavedChanges, !isSaving else { return }

        isSaving = true
        withAnimation(.easeInOut(duration: 0.2)) {
            saveStatus = .saving
        }

        do {
            // Debug current state before cleanup
            debugCurrentState()
            
            // Clean up any invalid pipeline references first
            cleanupPipelineReferences()
            
            // Validate configuration before saving
            let yaml = try ConfigSerializer.generateYAML(from: container.pipelineConfig)
            Logger.ui.debug("Generated YAML for validation: \n\(yaml)")

            let versionId = try await container.collectorStore.saveConfigVersion(collectorId, config: container.pipelineConfig, autosave: true)
            try await container.collectorStore.setCurrentConfig(collectorId, versionId: versionId)
            hasUnsavedChanges = false
            withAnimation(.easeInOut(duration: 0.2)) {
                saveStatus = .saved
            }
            Logger.ui.debug("Autosaved configuration successfully")

            // Clear saved status after a brief display
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if case .saved = saveStatus {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        saveStatus = .none
                    }
                }
            }
        } catch {
            Logger.ui.error("Failed to autosave config: \(error)")
            Logger.ui.debug("Current config state: receivers=\(container.pipelineConfig.receivers.count), processors=\(container.pipelineConfig.processors.count), exporters=\(container.pipelineConfig.exporters.count)")
            Logger.ui.debug("Pipeline count: \(container.pipelineConfig.pipelines.count)")
            
            withAnimation(.easeInOut(duration: 0.2)) {
                saveStatus = .error("Autosave failed: \(error.localizedDescription)")
            }

            // Clear error status after longer display
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if case .error = saveStatus {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        saveStatus = .none
                    }
                }
            }
        }

        isSaving = false
    }

    private func cancelAutosaveTimer() {
        autosaveTask?.cancel()
        autosaveTask = nil
    }

    private func performFinalSaveIfNeeded() async {
        if hasUnsavedChanges && !isSaving {
            await performAutosave()
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
                            scheduleAutosave()
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

        Logger.ui.debug("Designer drop (pipeline area) initiated for pipeline=\(pipeline.name)")
        provider.loadItem(forTypeIdentifier: "public.text", options: nil) { (item, _) in
            if let payload = extractDropPayload(item) {
                Logger.ui.debug("Designer drop payload: \(payload, privacy: .public)")
                DispatchQueue.main.async {
                    self.processDropPayload(payload, pipeline: pipeline)
                }
            } else {
                Logger.ui.error("Designer drop missing payload for pipeline=\(pipeline.name)")
            }
        }

        return true
    }

    private func handleStageSpecificDrop(providers: [NSItemProvider], pipeline: PipelineConfiguration, targetType: ComponentType) -> Bool {
        guard let provider = providers.first else { return false }

        Logger.ui.debug("Designer stage drop initiated for pipeline=\(pipeline.name) stage=\(targetType.rawValue)")
        provider.loadItem(forTypeIdentifier: "public.text", options: nil) { (item, _) in
            if let payload = extractDropPayload(item) {
                Logger.ui.debug("Designer stage drop payload: \(payload, privacy: .public)")
                DispatchQueue.main.async {
                    self.processDropPayload(payload, pipeline: pipeline, targetType: targetType)
                }
            } else {
                Logger.ui.error("Designer stage drop missing payload for pipeline=\(pipeline.name) stage=\(targetType.rawValue)")
            }
        }

        return true
    }

    private func processDropPayload(_ payload: String, pipeline: PipelineConfiguration, targetType: ComponentType? = nil) {
        let trimmedPayload = payload.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existingComponent = componentInstance(from: trimmedPayload) {
            Logger.ui.debug("Designer drop resolved existing instance name=\(existingComponent.name) id=\(existingComponent.id.uuidString, privacy: .public)")
            if let targetType, existingComponent.component.type != targetType {
                Logger.ui.debug("Designer drop rejected existing instance type mismatch: expected=\(targetType.rawValue) actual=\(existingComponent.component.type.rawValue)")
                return
            }
            addComponentToPipeline(existingComponent, pipeline: pipeline)
            return
        }

        if let definition = componentDefinition(from: trimmedPayload) {
            Logger.ui.debug("Designer drop resolved definition id=\(definition.id) name=\(definition.name)")
            if let targetType, definition.type != targetType {
                Logger.ui.debug("Designer drop rejected definition type mismatch: expected=\(targetType.rawValue) actual=\(definition.type.rawValue)")
                return
            }

            let instance = createInstance(for: definition)
            addComponentToPipeline(instance, pipeline: pipeline)
        } else {
            Logger.ui.error("Designer drop payload unrecognized: \(trimmedPayload, privacy: .public)")
        }
    }

    private func componentInstance(from payload: String) -> ComponentInstance? {
        guard let value = payloadValue(from: payload, expectedPrefix: "component-instance"),
              let uuid = UUID(uuidString: value) else {
            Logger.ui.debug("Designer drop payload is not component-instance: \(payload, privacy: .public)")
            return nil
        }

        if let globalMatch = container.pipelineConfig.allComponents.first(where: { $0.id == uuid }) {
            return globalMatch
        }

        for pipeline in container.pipelineConfig.pipelines {
            let stageComponents = pipeline.receivers + pipeline.processors + pipeline.exporters
            if let match = stageComponents.first(where: { $0.id == uuid }) {
                Logger.ui.debug("Designer drop located instance in pipeline '\(pipeline.name)' id=\(uuid.uuidString, privacy: .public)")
                let registered = registerComponentIfNeeded(match)
                return registered
            }
        }

        Logger.ui.error("Designer drop could not find instance uuid=\(uuid.uuidString, privacy: .public)")
        return nil
    }

    private func componentDefinition(from payload: String) -> CollectorComponent? {
        guard let value = payloadValue(from: payload, expectedPrefix: "component-definition"),
              let id = Int(value) else {
            Logger.ui.debug("Designer drop payload is not component-definition: \(payload, privacy: .public)")
            return nil
        }

        let resolved = allComponents.first(where: { $0.id == id })
        if resolved == nil {
            Logger.ui.error("Designer drop could not find definition id=\(id)")
        }
        return resolved
    }

    private func addComponentToPipeline(_ component: ComponentInstance, pipeline: PipelineConfiguration) {
        let normalized = registerComponentIfNeeded(component)
        attachComponentToPipeline(normalized, pipeline: pipeline)
    }

    private func registerComponentIfNeeded(_ component: ComponentInstance) -> ComponentInstance {
        var normalized = component
        normalized.configuration = normalizedConfiguration(for: component)
        let componentId = component.id
        switch component.component.type {
        case .receiver:
            if let index = container.pipelineConfig.receivers.firstIndex(where: { $0.id == componentId }) {
                container.pipelineConfig.receivers[index] = normalized
                normalizePipelineReferences(for: normalized)
                return normalized
            }
            Logger.ui.debug("Registering new receiver '\(component.name)'")
            container.pipelineConfig.receivers.append(normalized)
        case .processor:
            if let index = container.pipelineConfig.processors.firstIndex(where: { $0.id == componentId }) {
                container.pipelineConfig.processors[index] = normalized
                normalizePipelineReferences(for: normalized)
                return normalized
            }
            Logger.ui.debug("Registering new processor '\(component.name)'")
            container.pipelineConfig.processors.append(normalized)
        case .exporter:
            if let index = container.pipelineConfig.exporters.firstIndex(where: { $0.id == componentId }) {
                container.pipelineConfig.exporters[index] = normalized
                normalizePipelineReferences(for: normalized)
                return normalized
            }
            Logger.ui.debug("Registering new exporter '\(component.name)'")
            container.pipelineConfig.exporters.append(normalized)
        case .extension:
            if let index = container.pipelineConfig.extensions.firstIndex(where: { $0.id == componentId }) {
                container.pipelineConfig.extensions[index] = normalized
                normalizePipelineReferences(for: normalized)
                return normalized
            }
            Logger.ui.debug("Registering new extension '\(component.name)'")
            container.pipelineConfig.extensions.append(normalized)
        case .connector:
            if let index = container.pipelineConfig.connectors.firstIndex(where: { $0.id == componentId }) {
                container.pipelineConfig.connectors[index] = normalized
                normalizePipelineReferences(for: normalized)
                return normalized
            }
            Logger.ui.debug("Registering new connector '\(component.name)'")
            container.pipelineConfig.connectors.append(normalized)
        }
        normalizePipelineReferences(for: normalized)
        return normalized
    }

    private func attachComponentToPipeline(_ component: ComponentInstance, pipeline: PipelineConfiguration) {
        guard let index = container.pipelineConfig.pipelines.firstIndex(where: { $0.id == pipeline.id }) else {
            Logger.ui.error("Could not find pipeline with id \(pipeline.id)")
            return
        }

        Logger.ui.debug("Attaching component '\(component.name)' of type \(component.component.type.rawValue) to pipeline '\(pipeline.name)'")

        var didAttach = false

        switch component.component.type {
        case .receiver:
            if !container.pipelineConfig.pipelines[index].receivers.contains(where: { $0.id == component.id }) {
                container.pipelineConfig.pipelines[index].receivers.append(component)
                Logger.ui.debug("Attached '\(component.name)' to pipeline '\(pipeline.name)' receivers")
                didAttach = true
            }
        case .processor:
            if !container.pipelineConfig.pipelines[index].processors.contains(where: { $0.id == component.id }) {
                container.pipelineConfig.pipelines[index].processors.append(component)
                Logger.ui.debug("Attached '\(component.name)' to pipeline '\(pipeline.name)' processors")
                didAttach = true
            }
        case .exporter:
            if !container.pipelineConfig.pipelines[index].exporters.contains(where: { $0.id == component.id }) {
                container.pipelineConfig.pipelines[index].exporters.append(component)
                Logger.ui.debug("Attached '\(component.name)' to pipeline '\(pipeline.name)' exporters")
                didAttach = true
            }
        case .extension, .connector:
            Logger.ui.debug("Component type \(component.component.type.rawValue) is not part of pipeline stages")
        }

        if didAttach {
            scheduleAutosave()
        }
    }

    private func resolveComponentInstance(_ id: UUID) -> ComponentInstance? {
        if let globalMatch = container.pipelineConfig.allComponents.first(where: { $0.id == id }) {
            return globalMatch
        }

        for pipeline in container.pipelineConfig.pipelines {
            let stageComponents = pipeline.receivers + pipeline.processors + pipeline.exporters
            if let match = stageComponents.first(where: { $0.id == id }) {
                Logger.ui.debug("resolveComponentInstance: found instance in pipeline \(pipeline.name) id=\(id.uuidString, privacy: .public)")
                let registered = registerComponentIfNeeded(match)
                return registered
            }
        }

        Logger.ui.error("resolveComponentInstance: unable to find instance id=\(id.uuidString, privacy: .public)")
        return nil
    }

    private func deduplicateGlobalComponents() {
        func unique(_ components: [ComponentInstance]) -> [ComponentInstance] {
            var seen = Set<UUID>()
            return components.filter { component in
                let inserted = seen.insert(component.id).inserted
                if !inserted {
                    Logger.ui.debug("Removing duplicate component entry name=\(component.name) id=\(component.id.uuidString, privacy: .public)")
                }
                return inserted
            }
        }

        container.pipelineConfig.receivers = unique(container.pipelineConfig.receivers)
        container.pipelineConfig.processors = unique(container.pipelineConfig.processors)
        container.pipelineConfig.exporters = unique(container.pipelineConfig.exporters)
        container.pipelineConfig.extensions = unique(container.pipelineConfig.extensions)
        container.pipelineConfig.connectors = unique(container.pipelineConfig.connectors)

        // Drop connectors when they are not referenced. We currently do not expose connector editing,
        // and lingering defaults like "count" pollute generated YAML.
        if container.pipelineConfig.connectors.isEmpty == false {
            Logger.ui.debug("Clearing unused connectors from configuration")
            container.pipelineConfig.connectors.removeAll()
        }
    }

    private func normalizeAllComponents() {
        container.pipelineConfig.receivers = container.pipelineConfig.receivers.map(normalizedComponent)
        container.pipelineConfig.processors = container.pipelineConfig.processors.map(normalizedComponent)
        container.pipelineConfig.exporters = container.pipelineConfig.exporters.map(normalizedComponent)
        container.pipelineConfig.extensions = container.pipelineConfig.extensions.map(normalizedComponent)
        container.pipelineConfig.connectors = container.pipelineConfig.connectors.map(normalizedComponent)
    }

    private func normalizedComponent(_ component: ComponentInstance) -> ComponentInstance {
        var copy = component
        copy.configuration = normalizedConfiguration(for: component)
        return copy
    }

    private func normalizedConfiguration(for component: ComponentInstance) -> [String: ConfigValue] {
        let fields = container.componentDatabase.getFields(for: component.component)
        var idToCanonical: [Int: String] = [:]
        for field in fields {
            let path = field.getFullPath(database: container.componentDatabase)
            let canonical = path.isEmpty ? field.name : path
            idToCanonical[field.id] = canonical
        }

        var nameToField: [String: Field] = [:]
        for field in fields {
            nameToField[field.name] = field
        }

        var normalized: [String: ConfigValue] = [:]
        for (key, value) in component.configuration {
            if let field = nameToField[key], let canonical = idToCanonical[field.id] {
                normalized[canonical] = value
            } else if let field = fields.first(where: { idToCanonical[$0.id] == key }), let canonical = idToCanonical[field.id] {
                normalized[canonical] = value
            } else {
                normalized[key] = value
            }
        }
        return normalized
    }

    private func normalizePipelineReferences(for component: ComponentInstance) {
        for index in container.pipelineConfig.pipelines.indices {
            switch component.component.type {
            case .receiver:
                if let receiverIndex = container.pipelineConfig.pipelines[index].receivers.firstIndex(where: { $0.id == component.id }) {
                    container.pipelineConfig.pipelines[index].receivers[receiverIndex] = component
                }
            case .processor:
                if let processorIndex = container.pipelineConfig.pipelines[index].processors.firstIndex(where: { $0.id == component.id }) {
                    container.pipelineConfig.pipelines[index].processors[processorIndex] = component
                }
            case .exporter:
                if let exporterIndex = container.pipelineConfig.pipelines[index].exporters.firstIndex(where: { $0.id == component.id }) {
                    container.pipelineConfig.pipelines[index].exporters[exporterIndex] = component
                }
            case .extension, .connector:
                break
            }
        }
    }

    private func removeComponentFromPipeline(_ component: ComponentInstance, pipeline: PipelineConfiguration) {
        guard let pipelineIndex = container.pipelineConfig.pipelines.firstIndex(where: { $0.id == pipeline.id }) else {
            Logger.ui.error("Could not find pipeline with id \(pipeline.id)")
            return
        }

        Logger.ui.debug("Removing component '\(component.name)' of type \(component.component.type.rawValue) from pipeline '\(pipeline.name)'")

        // Remove from the specific pipeline
        switch component.component.type {
        case .receiver:
            container.pipelineConfig.pipelines[pipelineIndex].receivers.removeAll { $0.id == component.id }
            Logger.ui.debug("Removed '\(component.name)' from pipeline '\(pipeline.name)' receivers")
        case .processor:
            container.pipelineConfig.pipelines[pipelineIndex].processors.removeAll { $0.id == component.id }
            Logger.ui.debug("Removed '\(component.name)' from pipeline '\(pipeline.name)' processors")
        case .exporter:
            container.pipelineConfig.pipelines[pipelineIndex].exporters.removeAll { $0.id == component.id }
            Logger.ui.debug("Removed '\(component.name)' from pipeline '\(pipeline.name)' exporters")
        default:
            break // Extensions and connectors don't go in pipelines
        }

        // Check if this component is still used in any other pipelines
        let isUsedElsewhere = container.pipelineConfig.pipelines.contains { otherPipeline in
            otherPipeline.id != pipeline.id && (
                otherPipeline.receivers.contains { $0.id == component.id } ||
                otherPipeline.processors.contains { $0.id == component.id } ||
                otherPipeline.exporters.contains { $0.id == component.id }
            )
        }

        // If the component is not used in any other pipelines, remove it from the global arrays
        if !isUsedElsewhere {
            switch component.component.type {
            case .receiver:
                container.pipelineConfig.receivers.removeAll { $0.id == component.id }
                Logger.ui.debug("Removed '\(component.name)' from global receivers (not used elsewhere)")
            case .processor:
                container.pipelineConfig.processors.removeAll { $0.id == component.id }
                Logger.ui.debug("Removed '\(component.name)' from global processors (not used elsewhere)")
            case .exporter:
                container.pipelineConfig.exporters.removeAll { $0.id == component.id }
                Logger.ui.debug("Removed '\(component.name)' from global exporters (not used elsewhere)")
            case .extension:
                container.pipelineConfig.extensions.removeAll { $0.id == component.id }
                Logger.ui.debug("Removed '\(component.name)' from global extensions")
            case .connector:
                container.pipelineConfig.connectors.removeAll { $0.id == component.id }
                Logger.ui.debug("Removed '\(component.name)' from global connectors")
            }
        } else {
            Logger.ui.debug("Keeping '\(component.name)' in global arrays (still used in other pipelines)")
        }

        // Log current state for debugging
        Logger.ui.debug("Current global exporters: \(container.pipelineConfig.exporters.map { $0.name }.joined(separator: ", "))")
        Logger.ui.debug("Current pipeline '\(pipeline.name)' exporters: \(container.pipelineConfig.pipelines[pipelineIndex].exporters.map { $0.name }.joined(separator: ", "))")

        scheduleAutosave()
    }
}

// MARK: - Pipeline View

struct PipelineView: View {
    let pipeline: PipelineConfiguration
    let definitions: [CollectorComponent]
    let resolveComponent: (UUID) -> ComponentInstance?
    let onComponentSelected: (ComponentInstance) -> Void
    let createInstance: (CollectorComponent) -> ComponentInstance
    let isSelected: Bool
    let onTap: () -> Void
    let onNameChanged: (String) -> Void
    let onComponentAdded: (ComponentInstance, PipelineConfiguration) -> Void
    let onComponentRemoved: (ComponentInstance, PipelineConfiguration) -> Void

    @State private var isEditingName = false
    @State private var editingName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Pipeline title
            HStack {
                if isEditingName {
                    TextField("Pipeline name", text: $editingName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { finishEditing() }
                        .onExitCommand { cancelEditing() }
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
                    Text("\(components.count)")
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

                    Text("Drop \(title.lowercased()) here")
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
                            },
                            draggableId: component.id
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
        Logger.ui.debug("Removing component '\(component.name)' from pipeline '\(pipeline.name)'")
        // Propagate intent to parent; parent owns the source of truth and will mutate AppContainer (Observable)
        onComponentRemoved(component, pipeline)
    }

    // MARK: - Drag and Drop Support

    private func handleDrop(providers: [NSItemProvider], pipeline: PipelineConfiguration) -> Bool {
        guard let provider = providers.first else { return false }

        Logger.ui.debug("PipelineView drop initiated for pipeline=\(pipeline.name)")
        provider.loadItem(forTypeIdentifier: "public.text", options: nil) { (item, _) in
            if let payload = extractDropPayload(item) {
                Logger.ui.debug("PipelineView drop payload: \(payload, privacy: .public)")
                DispatchQueue.main.async {
                    self.processDropPayload(payload, pipeline: pipeline)
                }
            } else {
                Logger.ui.error("PipelineView drop missing payload for pipeline=\(pipeline.name)")
            }
        }

        return true
    }

    private func handleStageSpecificDrop(providers: [NSItemProvider], pipeline: PipelineConfiguration, targetType: ComponentType) -> Bool {
        guard let provider = providers.first else { return false }

        Logger.ui.debug("PipelineView stage drop initiated for pipeline=\(pipeline.name) stage=\(targetType.rawValue)")
        provider.loadItem(forTypeIdentifier: "public.text", options: nil) { (item, _) in
            if let payload = extractDropPayload(item) {
                Logger.ui.debug("PipelineView stage drop payload: \(payload, privacy: .public)")
                DispatchQueue.main.async {
                    self.processDropPayload(payload, pipeline: pipeline, targetType: targetType)
                }
            } else {
                Logger.ui.error("PipelineView stage drop missing payload for pipeline=\(pipeline.name) stage=\(targetType.rawValue)")
            }
        }

        return true
    }

    private func processDropPayload(_ payload: String, pipeline: PipelineConfiguration, targetType: ComponentType? = nil) {
        let trimmedPayload = payload.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existingComponent = componentInstance(from: trimmedPayload) {
            Logger.ui.debug("PipelineView drop resolved existing instance name=\(existingComponent.name) id=\(existingComponent.id.uuidString, privacy: .public)")
            if let targetType, existingComponent.component.type != targetType {
                Logger.ui.debug("PipelineView drop rejected instance type mismatch expected=\(targetType.rawValue) actual=\(existingComponent.component.type.rawValue)")
                return
            }
            onComponentAdded(existingComponent, pipeline)
            return
        }

        guard let definition = componentDefinition(from: trimmedPayload) else {
            Logger.ui.error("PipelineView drop payload unrecognized: \(trimmedPayload, privacy: .public)")
            return
        }

        if let targetType, definition.type != targetType {
            Logger.ui.debug("PipelineView drop rejected definition type mismatch expected=\(targetType.rawValue) actual=\(definition.type.rawValue)")
            return
        }

        let instance = createInstance(definition)
        onComponentAdded(instance, pipeline)
    }

    private func componentInstance(from payload: String) -> ComponentInstance? {
        guard let value = payloadValue(from: payload, expectedPrefix: "component-instance"),
              let uuid = UUID(uuidString: value) else {
            return nil
        }
        if let resolved = resolveComponent(uuid) {
            Logger.ui.debug("PipelineView resolved instance uuid=\(uuid.uuidString, privacy: .public) name=\(resolved.name)")
            return resolved
        } else {
            Logger.ui.error("PipelineView could not resolve instance uuid=\(uuid.uuidString, privacy: .public)")
            return nil
        }
    }

    private func componentDefinition(from payload: String) -> CollectorComponent? {
        guard let value = payloadValue(from: payload, expectedPrefix: "component-definition"),
              let id = Int(value) else {
            return nil
        }

        return definitions.first(where: { $0.id == id })
    }

}

struct CollectorComponentRowView: View {
    let component: ComponentInstance
    @Binding var selectedCollectorComponent: ComponentInstance?

    var body: some View {
        let payload = "component-instance:\(component.id.uuidString)"
        Logger.ui.debug("Inspector drag prepared for instance: \(payload, privacy: .public)")

        return HStack {
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
        .onDrag {
            Logger.ui.debug("Inspector drag started for payload: \(payload, privacy: .public)")
            return NSItemProvider(object: payload as NSString)
        }
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

// MARK: - Config Form Model (modern data flow)

@Observable
final class ConfigFormModel {
    private(set) var values: [String: ConfigValue]

    init(values: [String: ConfigValue] = [:]) {
        self.values = values
    }

    func value(for fullPath: String) -> ConfigValue {
        values[fullPath] ?? .string("")
    }

    func setValue(_ value: ConfigValue, for fullPath: String) {
        values[fullPath] = value
    }

    // Convenience helpers
    func string(for fullPath: String) -> String {
        if case .string(let s) = value(for: fullPath) { return s }
        return ""
    }

    func setString(_ s: String, for fullPath: String) {
        setValue(.string(s), for: fullPath)
    }

    func bool(for fullPath: String) -> Bool {
        if case .bool(let b) = value(for: fullPath) { return b }
        return false
    }

    func setBool(_ b: Bool, for fullPath: String) {
        setValue(.bool(b), for: fullPath)
    }

    func numberString(for fullPath: String) -> String {
        switch value(for: fullPath) {
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        default: return ""
        }
    }

    func setNumberString(_ text: String, kind: String, for fullPath: String) {
        let lower = kind.lowercased()
        if lower.contains("float") || lower.contains("double") {
            setValue(.double(Double(text) ?? 0.0), for: fullPath)
        } else {
            setValue(.int(Int(text) ?? 0), for: fullPath)
        }
    }
}

// MARK: - Config Section View (modernized)

struct ConfigSectionView: View {
    @ObservedObject var section: ConfigSection
    let isRoot: Bool
    let componentDatabase: ComponentDatabase
    @Environment(ConfigFormModel.self) private var form

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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
                        let fullPath = field.getFullPath(database: componentDatabase)
                        ModernConfigFieldView(field: field, fullPath: fullPath)
                            .padding(.leading, isRoot ? 0 : 12)
                    }

                    // Subsections
                    ForEach(Array(section.subsections.keys.sorted()), id: \.self) { key in
                        if let subsection = section.subsections[key] {
                            ConfigSectionView(
                                section: subsection,
                                isRoot: false,
                                componentDatabase: componentDatabase
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

struct ModernConfigFieldView: View {
    let field: Field
    let fullPath: String
    @Environment(ConfigFormModel.self) private var form

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
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

            // Control
            switch field.controlType {
            case .textField:
                TextField(field.defaultValue ?? "Enter \(field.name)",
                          text: .init(
                            get: { form.string(for: fullPath) },
                            set: { form.setString($0, for: fullPath) }
                          ))
                .textFieldStyle(.roundedBorder)

            case .numberField:
                TextField(field.defaultValue ?? "0",
                          text: .init(
                            get: { form.numberString(for: fullPath) },
                            set: { form.setNumberString($0, kind: field.kind, for: fullPath) }
                          ))
                .textFieldStyle(.roundedBorder)

            case .toggle:
                Toggle(isOn: .init(
                    get: { form.bool(for: fullPath) },
                    set: { form.setBool($0, for: fullPath) }
                )) { EmptyView() }
                
            case .arrayEditor:
                ArrayEditorView(
                    values: .init(
                        get: {
                            switch form.value(for: fullPath) {
                            case .stringArray(let arr):
                                return arr
                            case .array(let arr):
                                // Convert generic array to string array for editing
                                return arr.compactMap { value in
                                    switch value {
                                    case .string(let str): return str
                                    case .int(let int): return String(int)
                                    case .double(let double): return String(double)
                                    case .bool(let bool): return String(bool)
                                    default: return nil
                                    }
                                }
                            default:
                                return []
                            }
                        },
                        set: { newValues in
                            // Determine the appropriate ConfigValue type based on field kind
                            if field.kind.lowercased() == "array" {
                                // For generic arrays, convert strings back to appropriate types
                                let configValues = newValues.map { ConfigValue.string($0) }
                                form.setValue(.array(configValues), for: fullPath)
                            } else {
                                // For string arrays, keep as strings
                                form.setValue(.stringArray(newValues), for: fullPath)
                            }
                        }
                    )
                )
                
            case .mapEditor:
                MapEditorView(
                    pairs: .init(
                        get: {
                            if case .stringMap(let dict) = form.value(for: fullPath) { return dict }
                            return [:]
                        },
                        set: { form.setValue(.stringMap($0), for: fullPath) }
                    )
                )

            default:
                TextField(field.defaultValue ?? "Enter \(field.name)",
                          text: .init(
                            get: { form.string(for: fullPath) },
                            set: { form.setString($0, for: fullPath) }
                          ))
                .textFieldStyle(.roundedBorder)
            }

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
                .stroke(field.isRequired && form.value(for: fullPath).isEmpty ? Color.red.opacity(0.3) : Color(.separatorColor), lineWidth: 1)
        )
    }
}

struct ArrayEditorView: View {
    @State private var newItem: String = ""
    @Binding var values: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(values.indices, id: \.self) { index in
                HStack {
                    TextField("Item", text: Binding(
                        get: { values[index] },
                        set: { values[index] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)

                    Button(role: .destructive) {
                        values.remove(at: index)
                    } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                }
            }
            HStack {
                TextField("Add item", text: $newItem)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    let trimmed = newItem.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    values.append(trimmed)
                    newItem = ""
                }
            }
        }
    }
}

struct MapEditorView: View {
    @State private var newKey: String = ""
    @State private var newValue: String = ""
    @Binding var pairs: [String: String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(pairs.keys.sorted(), id: \.self) { key in
                HStack {
                    TextField("Key", text: Binding(
                        get: { key },
                        set: { newKey in
                            // Renaming key: move value to new key
                            let value = pairs.removeValue(forKey: key) ?? ""
                            if !newKey.isEmpty { pairs[newKey] = value }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 120)

                    Text("=")
                        .foregroundStyle(.secondary)

                    TextField("Value", text: Binding(
                        get: { pairs[key] ?? "" },
                        set: { pairs[key] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)

                    Button(role: .destructive) {
                        pairs.removeValue(forKey: key)
                    } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                }
            }
            HStack {
                TextField("New key", text: $newKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 120)
                Text("=")
                    .foregroundStyle(.secondary)
                TextField("New value", text: $newValue)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    let k = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    let v = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !k.isEmpty else { return }
                    pairs[k] = v
                    newKey = ""
                    newValue = ""
                }
            }
        }
    }
}

// MARK: - Extensions

extension UTType {
    static var yaml: UTType {
        UTType(filenameExtension: "yaml") ?? .plainText
    }
}

// MARK: - Component Configuration Modal

struct ComponentConfigurationModal: View {
    let component: ComponentInstance
    let onSave: (ComponentInstance) -> Void
    let onCancel: () -> Void

    @Environment(AppContainer.self) private var container

    @State private var alias: String
    @State private var configurationValues: [String: ConfigValue] = [:]
    @State private var formModel = ConfigFormModel()
    @State private var configStructure: ConfigSection?
    @State private var isLoading = true

    init(component: ComponentInstance, onSave: @escaping (ComponentInstance) -> Void, onCancel: @escaping () -> Void) {
        self.component = component
        self.onSave = onSave
        self.onCancel = onCancel

        let initialAlias = aliasFromInstanceName(component)
        self._alias = State(initialValue: initialAlias)
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

    private var baseName: String {
        component.component.name
    }

    private var fullNamePreview: String {
        let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return baseName }

        if trimmed.hasPrefix(baseName + "/") {
            return trimmed
        }

        return "\(baseName)/\(trimmed)"
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
                    TextField("Optional name", text: $alias)
                        .textFieldStyle(.roundedBorder)
                    Text("Full identifier: \(fullNamePreview)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                                    isRoot: true,
                                    componentDatabase: container.componentDatabase
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
        .environment(formModel)
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
        formModel = ConfigFormModel(values: configurationValues)

        // Set default values for fields that don't have current values
        let allFields = configStructure?.getAllFields() ?? []
        for field in allFields {
            let fullPath = field.getFullPath(database: container.componentDatabase)
            if configurationValues[fullPath] == nil {
                if let defaultValue = field.defaultValue {
                    // Parse the default value JSON to ConfigValue
                    configurationValues[fullPath] = ConfigValue.from(any: defaultValue)
                } else {
                    // Set appropriate default based on field type
                    switch field.kind.lowercased() {
                    case "bool":
                        configurationValues[fullPath] = .bool(false)
                    case "int", "int64":
                        configurationValues[fullPath] = .int(0)
                    case "float64":
                        configurationValues[fullPath] = .double(0.0)
                    case "duration":
                        configurationValues[fullPath] = .duration(0)
                    case "[]string", "slice", "stringarray":
                        configurationValues[fullPath] = .stringArray([])
                    case "array":
                        configurationValues[fullPath] = .array([])
                    case "map", "stringmap":
                        configurationValues[fullPath] = .stringMap([:])
                    default:
                        configurationValues[fullPath] = .string("")
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

        for (key, value) in formModel.values {
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

        let existingNames = Set(
            container.pipelineConfig.allComponents
                .filter { $0.id != component.id }
                .map { $0.name }
        )
        let uniqueName = normalizedInstanceName(
            for: component.component,
            requestedAlias: alias,
            existingNames: existingNames
        )

        updatedComponent.name = uniqueName
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

// MARK: - Instance Naming Helpers

fileprivate func aliasFromInstanceName(_ instance: ComponentInstance) -> String {
    let baseName = instance.component.name
    let fullName = instance.name

    guard fullName != baseName else { return "" }

    if fullName.hasPrefix(baseName + "/") {
        let suffix = fullName.dropFirst(baseName.count + 1)
        return String(suffix)
    }

    return fullName
}

fileprivate func normalizedInstanceName(
    for component: CollectorComponent,
    requestedAlias: String?,
    existingNames: Set<String>
) -> String {
    let baseName = component.name
    var alias = requestedAlias?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    if alias.hasPrefix(baseName + "/") {
        alias = String(alias.dropFirst(baseName.count + 1))
    }

    if alias.first == "/" {
        alias = String(alias.dropFirst())
    }

    var candidate = alias.isEmpty ? baseName : "\(baseName)/\(alias)"
    if !existingNames.contains(candidate) {
        return candidate
    }

    var counter = 1
    while true {
        let suffix: String
        if alias.isEmpty {
            suffix = "\(baseName)/\(counter)"
        } else {
            suffix = "\(baseName)/\(alias)-\(counter)"
        }

        if !existingNames.contains(suffix) {
            return suffix
        }

        counter += 1
    }
}

private func extractDropPayload(_ item: NSSecureCoding?) -> String? {
    if let data = item as? Data {
        return String(data: data, encoding: .utf8)
    }
    if let string = item as? String {
        return string
    }
    if let string = item as? NSString {
        return string as String
    }
    return nil
}

fileprivate func payloadValue(from payload: String, expectedPrefix: String) -> String? {
    let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let prefixRange = trimmed.range(of: expectedPrefix + ":") else {
        Logger.ui.debug("payloadValue: payload '\(payload, privacy: .public)' does not contain prefix \(expectedPrefix)")
        return nil
    }
    let valueStart = prefixRange.upperBound
    let value = trimmed[valueStart...].trimmingCharacters(in: .whitespacesAndNewlines)
    Logger.ui.debug("payloadValue extracted value='\(value, privacy: .public)' for prefix=\(expectedPrefix)")
    return value.isEmpty ? nil : value
}

#Preview {
    PipelineDesignerView()
        .frame(width: 1200, height: 800)
}
