import SwiftUI
import UniformTypeIdentifiers

struct PipelineDesignerView: View {
    let collectorId: UUID?
    @Environment(AppContainer.self) private var container
    // Versions are loaded asynchronously from the container's ComponentDatabase actor
    @State private var availableVersions: [ComponentVersion] = []
    // Component drawer (bottom) state
    @State private var showComponentDrawer: Bool = true
    @State private var drawerHeight: CGFloat = 260
    private let minDrawerHeight: CGFloat = 160
    private let maxDrawerHeight: CGFloat = 480
    @State private var drawerStartHeight: CGFloat = 260
    @State private var componentDefinitions: [ComponentDefinition] = []
    @State private var componentSearchText: String = ""
    @State private var selectedComponentType: ComponentType? = nil
    // (no old drag state needed)
    
    init(collectorId: UUID? = nil) {
        self.collectorId = collectorId
    }
    
    // Collector details are loaded via store in AppContainer; we don't rely on AppState here.
    
    var body: some View {
        HSplitView {
            // Left sidebar: Pipeline structure
            pipelineStructure
                .frame(minWidth: 200, idealWidth: 260, maxWidth: 320)
                .clipped()
            
            // Center: Visual pipeline editor
            pipelineCanvas
                .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            // Details/config are edited in the Inspector panel (right sidebar of the app)
        }
        .navigationTitle("Pipeline Designer")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Add Pipeline") {
                    addNewPipeline()
                }

                Button(showComponentDrawer ? "Hide Components" : "Show Components") {
                    showComponentDrawer.toggle()
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
        // Bottom component drawer that doesn't compete with the Inspector width
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showComponentDrawer {
                bottomDrawer
            }
        }
        .task {
            await loadCollectorConfiguration()
            await loadAvailableVersions()
            await loadComponentDefinitions()
        }
        .onChange(of: container.pipelineConfig.version) { _, _ in
            Task { await loadComponentDefinitions() }
        }
    }
    
    // MARK: - Pipeline Structure Sidebar
    
    private var pipelineStructure: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Configuration")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Menu {
                    ForEach(availableVersions) { version in
                        Button(version.displayName) {
                            container.pipelineConfig.version = version.version
                        }
                    }
                } label: {
                    Text(container.pipelineConfig.version)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            
            Divider()
            
            // Pipeline and component tree
            List(selection: Binding(
                get: { container.selectedPipeline },
                set: { container.selectedPipeline = $0 }
            )) {
                // Pipelines section
                Section("Service Pipelines") {
                    ForEach(container.pipelineConfig.pipelines) { pipeline in
                        PipelineRowView(
                            pipeline: pipeline,
                            selectedComponent: Binding(
                                get: { container.selectedPipelineComponent },
                                set: { container.selectedPipelineComponent = $0 }
                            )
                        )
                        .tag(pipeline)
                    }
                    .onDelete(perform: deletePipelines)
                }
                
                // Components sections
                if !container.pipelineConfig.receivers.isEmpty {
                    Section("Receivers") {
                        ForEach(container.pipelineConfig.receivers) { receiver in
                            ComponentRowView(component: receiver, selectedComponent: Binding(
                                get: { container.selectedPipelineComponent },
                                set: { container.selectedPipelineComponent = $0 }
                            ))
                        }
                        .onDelete { indices in
                            deleteComponents(at: indices, from: \.receivers)
                        }
                    }
                }
                
                if !container.pipelineConfig.processors.isEmpty {
                    Section("Processors") {
                        ForEach(container.pipelineConfig.processors) { processor in
                            ComponentRowView(component: processor, selectedComponent: Binding(
                                get: { container.selectedPipelineComponent },
                                set: { container.selectedPipelineComponent = $0 }
                            ))
                        }
                        .onDelete { indices in
                            deleteComponents(at: indices, from: \.processors)
                        }
                    }
                }
                
                if !container.pipelineConfig.exporters.isEmpty {
                    Section("Exporters") {
                        ForEach(container.pipelineConfig.exporters) { exporter in
                            ComponentRowView(component: exporter, selectedComponent: Binding(
                                get: { container.selectedPipelineComponent },
                                set: { container.selectedPipelineComponent = $0 }
                            ))
                        }
                        .onDelete { indices in
                            deleteComponents(at: indices, from: \.exporters)
                        }
                    }
                }
                
                if !container.pipelineConfig.extensions.isEmpty {
                    Section("Extensions") {
                        ForEach(container.pipelineConfig.extensions) { extensionComponent in
                            ComponentRowView(component: extensionComponent, selectedComponent: Binding(
                                get: { container.selectedPipelineComponent },
                                set: { container.selectedPipelineComponent = $0 }
                            ))
                        }
                        .onDelete { indices in
                            deleteComponents(at: indices, from: \.extensions)
                        }
                    }
                }
                
                if !container.pipelineConfig.connectors.isEmpty {
                    Section("Connectors") {
                        ForEach(container.pipelineConfig.connectors) { connector in
                            ComponentRowView(component: connector, selectedComponent: Binding(
                                get: { container.selectedPipelineComponent },
                                set: { container.selectedPipelineComponent = $0 }
                            ))
                        }
                        .onDelete { indices in
                            deleteComponents(at: indices, from: \.connectors)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
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
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        StatusIndicator(
                            text: "\(pipeline.receivers.count) receivers",
                            color: .blue,
                            isValid: !pipeline.receivers.isEmpty
                        )
                        
                        StatusIndicator(
                            text: "\(pipeline.processors.count) processors",
                            color: .orange,
                            isValid: true // Processors are optional
                        )
                        
                        StatusIndicator(
                            text: "\(pipeline.exporters.count) exporters", 
                            color: .green,
                            isValid: !pipeline.exporters.isEmpty
                        )
                        
                        Circle()
                            .fill(pipeline.isValid ? .green : .red)
                            .frame(width: 8, height: 8)
                    }
                    .font(.caption)
                } else {
                    Text("Select a pipeline to edit")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
            }
            .padding()
            
            Divider()
            
            // Canvas content
            if let pipeline = container.selectedPipeline {
                PipelineCanvasView(
                    pipeline: binding(for: pipeline),
                    definitions: componentDefinitions,
                    onComponentSelected: { component in
                        container.selectedPipelineComponent = component
                    },
                    createInstance: { definition in
                        createInstance(for: definition)
                    }
                )
            } else {
                ContentUnavailableView {
                    Label("No Pipeline Selected", systemImage: "flowchart")
                } description: {
                    Text("Select a pipeline from the sidebar or create a new one to start building your configuration.")
                } actions: {
                    Button("Create Pipeline") {
                        addNewPipeline()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    // MARK: - Component Drawer

    private var filteredDefinitions: [ComponentDefinition] {
        var defs = componentDefinitions
        if let t = selectedComponentType { defs = defs.filter { $0.type == t } }
        if !componentSearchText.isEmpty {
            let q = componentSearchText
            defs = defs.filter { $0.name.localizedCaseInsensitiveContains(q) ||
                ($0.description?.localizedCaseInsensitiveContains(q) == true) ||
                $0.module.localizedCaseInsensitiveContains(q)
            }
        }
        return defs
    }

    private var componentDrawer: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Components")
                        .font(.headline)
                    Spacer()
                    Menu {
                        ForEach(availableVersions) { v in
                            Button(v.displayName) { container.pipelineConfig.version = v.version }
                        }
                    } label: {
                        Text(container.pipelineConfig.version)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Search
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search", text: $componentSearchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)

                // Type filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        FilterChip(title: "All", isSelected: selectedComponentType == nil, color: Color.secondary) {
                            selectedComponentType = nil
                        }
                        ForEach(ComponentType.allCases, id: \.self) { type in
                            let count = componentDefinitions.filter { $0.type == type }.count
                            if count > 0 {
                                FilterChip(
                                    title: type.displayName,
                                    isSelected: selectedComponentType == type,
                                    color: type.color
                                ) { selectedComponentType = (selectedComponentType == type ? nil : type) }
                            }
                        }
                    }
                }
            }
            .padding()

            Divider()

            if filteredDefinitions.isEmpty {
                ContentUnavailableView {
                    Label("No Components", systemImage: "puzzlepiece")
                } description: {
                    Text("Adjust search or filters.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredDefinitions) { def in
                            DraggableComponentCard(definition: def)
                                .onDrag {
                                    NSItemProvider(object: NSString(string: "component-definition:\(def.id)"))
                                }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Color(.underPageBackgroundColor))
    }

    private var bottomDrawer: some View {
        VStack(spacing: 0) {
            // Grabber and resize handle
            ZStack {
                Color.clear.frame(height: 10)
                Capsule()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 48, height: 4)
                    .padding(.vertical, 6)
            }
            .frame(maxWidth: .infinity)
            .background(Color(.windowBackgroundColor).opacity(0.6))
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        let proposed = drawerStartHeight - value.translation.height
                        drawerHeight = min(max(proposed, minDrawerHeight), maxDrawerHeight)
                    }
                    .onEnded { _ in
                        drawerStartHeight = drawerHeight
                    }
            )

            Divider()
            componentDrawer
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: drawerHeight)
        .background(Color(.underPageBackgroundColor))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: -2)
    }

    // MARK: - Component Inspector
    
    private var componentInspector: some View {
        VStack(alignment: .leading, spacing: 0) {
            EmptyView() // moved to app Inspector
        }
    }
    
    // MARK: - Helper Views
    
    private func binding(for pipeline: PipelineConfiguration) -> Binding<PipelineConfiguration> {
        guard let index = container.pipelineConfig.pipelines.firstIndex(of: pipeline) else {
            fatalError("Pipeline not found in configuration")
        }
        
        return Binding(
            get: { container.pipelineConfig.pipelines[index] },
            set: { container.pipelineConfig.pipelines[index] = $0 }
        )
    }
    
    private func binding(for component: ComponentInstance) -> Binding<ComponentInstance> {
        // Find the component in all arrays and return a binding to it
        if let index = container.pipelineConfig.receivers.firstIndex(of: component) {
            return Binding(
                get: { container.pipelineConfig.receivers[index] },
                set: { container.pipelineConfig.receivers[index] = $0 }
            )
        } else if let index = container.pipelineConfig.processors.firstIndex(of: component) {
            return Binding(
                get: { container.pipelineConfig.processors[index] },
                set: { container.pipelineConfig.processors[index] = $0 }
            )
        } else if let index = container.pipelineConfig.exporters.firstIndex(of: component) {
            return Binding(
                get: { container.pipelineConfig.exporters[index] },
                set: { container.pipelineConfig.exporters[index] = $0 }
            )
        } else if let index = container.pipelineConfig.extensions.firstIndex(of: component) {
            return Binding(
                get: { container.pipelineConfig.extensions[index] },
                set: { container.pipelineConfig.extensions[index] = $0 }
            )
        } else if let index = container.pipelineConfig.connectors.firstIndex(of: component) {
            return Binding(
                get: { container.pipelineConfig.connectors[index] },
                set: { container.pipelineConfig.connectors[index] = $0 }
            )
        }
        
        fatalError("Component not found in configuration")
    }
    
    // MARK: - Actions
    
    private func addNewPipeline() {
        let pipelineName = generateUniquePipelineName()
        let newPipeline = PipelineConfiguration(name: pipelineName)
        container.pipelineConfig.pipelines.append(newPipeline)
        container.selectedPipeline = newPipeline
    }
    
    private func generateUniquePipelineName() -> String {
        let baseNames = ["traces", "metrics", "logs"]
        
        for baseName in baseNames {
            if !container.pipelineConfig.pipelines.contains(where: { $0.name == baseName }) {
                return baseName
            }
        }
        
        // Generate numbered pipeline
        var counter = 1
        while container.pipelineConfig.pipelines.contains(where: { $0.name == "pipeline\(counter)" }) {
            counter += 1
        }
        return "pipeline\(counter)"
    }
    
    private func deletePipelines(at indices: IndexSet) {
        container.pipelineConfig.pipelines.remove(atOffsets: indices)
        if let selected = container.selectedPipeline,
           !container.pipelineConfig.pipelines.contains(selected) {
            container.selectedPipeline = container.pipelineConfig.pipelines.first
        }
    }
    
    private func deleteComponents(at indices: IndexSet, from keyPath: WritableKeyPath<CollectorConfiguration, [ComponentInstance]>) {
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
            print("Export failed: \(error)")
        }
    }
    
    private func saveToCollector() async {
        guard let collectorId else { return }
        do {
            let versionId = try await container.collectorStore.saveConfigVersion(collectorId, config: container.pipelineConfig, autosave: false)
            try await container.collectorStore.setCurrentConfig(collectorId, versionId: versionId)
        } catch {
            print("Failed to save config to store: \(error)")
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
                        print("Import failed: \(error)")
                    }
                }
            } catch {
                // TODO: Show error alert
                print("Import failed: \(error)")
            }
        }
    }
    
    // MARK: - Configuration Loading
    
    private func loadCollectorConfiguration() async {
        guard let collectorId else { return }
        await container.loadCollectorConfiguration(forCollectorId: collectorId)
    }

    private func loadAvailableVersions() async {
        let versions = await container.componentDatabase.availableVersions()
        await MainActor.run {
            self.availableVersions = versions
            if container.pipelineConfig.version.isEmpty, let first = versions.first?.version {
                container.pipelineConfig.version = first
            }
        }
    }

    private func loadComponentDefinitions() async {
        let version = container.pipelineConfig.version
        guard !version.isEmpty else { return }
        let defs = await container.componentDatabase.components(for: version)
        await MainActor.run {
            self.componentDefinitions = defs
        }
    }

    private func createInstance(for definition: ComponentDefinition) -> ComponentInstance {
        // Generate a unique instance name across all top-level components
        let existingNames: Set<String> = Set(container.pipelineConfig.allComponents.map { $0.instanceName })
        let base = definition.name
        var candidate = base
        if existingNames.contains(candidate) {
            // Try random slug for suffix; fall back to numeric if needed
            var attempts = 0
            while attempts < 10 {
                let slug = randomSlug()
                let c = "\(base)/\(slug)"
                if !existingNames.contains(c) { candidate = c; break }
                attempts += 1
            }
            if attempts >= 10 {
                var i = 2
                while existingNames.contains(candidate) {
                    candidate = "\(base)/\(i)"
                    i += 1
                }
            }
        }
        var instance = ComponentInstance(definition: definition, instanceName: candidate)
        // Seed minimal-valid config if there is an anyOf/oneOf constraint and none of the keys are present
        if let group = definition.constraints.first(where: { $0.kind == "anyOf" || $0.kind == "oneOf" }) {
            let hasAny = group.keys.contains(where: { k in instance.configuration[k] != nil })
            if !hasAny, let firstKey = group.keys.first {
                instance.configuration[firstKey] = .map([:])
            }
        }
        // Ensure it exists in top-level components for YAML export
        switch definition.type {
        case .receiver:
            if !container.pipelineConfig.receivers.contains(where: { $0.instanceName == instance.instanceName }) {
                container.pipelineConfig.receivers.append(instance)
            }
        case .processor:
            if !container.pipelineConfig.processors.contains(where: { $0.instanceName == instance.instanceName }) {
                container.pipelineConfig.processors.append(instance)
            }
        case .exporter:
            if !container.pipelineConfig.exporters.contains(where: { $0.instanceName == instance.instanceName }) {
                container.pipelineConfig.exporters.append(instance)
            }
        case .extension:
            if !container.pipelineConfig.extensions.contains(where: { $0.instanceName == instance.instanceName }) {
                container.pipelineConfig.extensions.append(instance)
            }
        case .connector:
            if !container.pipelineConfig.connectors.contains(where: { $0.instanceName == instance.instanceName }) {
                container.pipelineConfig.connectors.append(instance)
            }
        }
        return instance
    }

    private func randomSlug() -> String {
        // Culture ship–style playful slugs; all lowercase, kebab-case
        func pick<T>(_ a: [T]) -> T { a.randomElement()! }
        
        let concepts = [
            "subtlety","gravitas","patience","restraint","perspective","tact","nuance","decorum","serenity","focus","finesse","composure","charisma","mercy","parsimony","style","grace"
        ]
        let intensifiers = ["very","extremely","rather","somewhat","marginally","barely","mostly","distinctly","excessively","insufficiently"]
        let modifiers = ["little","considerable","unexpected","questionable","diminished","augmented","measured","applied","weaponized","unreasonable","faint","noticeable","casual"]
        let codas = ["indeed","perhaps","really","honestly","allegedly","apparently","as-requested"]
        let verbs = ["testing","overthinking","improvising","insinuating","negotiating","procrastinating","iterating","refactoring","pontificating","handwaving","guessing","suboptimizing","celebrating"]
        let polite = ["we","i","one","the-committee"]
        let aims = ["aim-to-please","try-harder","do-our-best","mean-well","clean-up-later","regret-this"]
        let classics = [
            "so-much-for-subtlety","just-testing","killing-time","very-little-gravitas-indeed","frank-exchange-of-views","hand-me-the-gun","youll-thank-me-later","just-read-the-docs","absolutely-not-my-fault"
        ]
        
        enum Pattern: CaseIterable { case classic, soMuchFor, intensifier, gerund, polite }
        let pattern = Pattern.allCases.randomElement()!
        let slug: String
        switch pattern {
        case .classic:
            slug = pick(classics)
        case .soMuchFor:
            slug = "so-much-for-" + pick(concepts)
        case .intensifier:
            slug = [pick(intensifiers), pick(modifiers), pick(concepts), pick(codas)].joined(separator: "-")
        case .gerund:
            slug = "just-" + pick(verbs)
        case .polite:
            slug = pick(polite) + "-" + pick(aims)
        }
        return slug.replacingOccurrences(of: "--", with: "-")
    }
}

// MARK: - Supporting Views

struct PipelineRowView: View {
    let pipeline: PipelineConfiguration
    @Binding var selectedComponent: ComponentInstance?
    
    var body: some View {
        DisclosureGroup {
            // Pipeline components
            if !pipeline.receivers.isEmpty {
                Label("Receivers", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ForEach(pipeline.receivers) { receiver in
                    ComponentRowView(component: receiver, selectedComponent: $selectedComponent)
                        .padding(.leading)
                }
            }
            
            if !pipeline.processors.isEmpty {
                Label("Processors", systemImage: "gearshape")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ForEach(pipeline.processors) { processor in
                    ComponentRowView(component: processor, selectedComponent: $selectedComponent)
                        .padding(.leading)
                }
            }
            
            if !pipeline.exporters.isEmpty {
                Label("Exporters", systemImage: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ForEach(pipeline.exporters) { exporter in
                    ComponentRowView(component: exporter, selectedComponent: $selectedComponent)
                        .padding(.leading)
                }
            }
        } label: {
            HStack {
                Circle()
                    .fill(pipeline.isValid ? .green : .red)
                    .frame(width: 8, height: 8)
                
                Text(pipeline.name)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(pipeline.receivers.count + pipeline.processors.count + pipeline.exporters.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ComponentRowView: View {
    let component: ComponentInstance
    @Binding var selectedComponent: ComponentInstance?
    
    var body: some View {
        HStack {
            Circle()
                .fill(component.definition.type.color)
                .frame(width: 6, height: 6)
            
            Text(component.displayName)
                .font(.body)
            
            Spacer()
            
            if !component.configuration.isEmpty {
                Button {
                    // Make the cog actionable: select and focus this component
                    selectedComponent = component
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
            selectedComponent = component
        }
        .background(
            selectedComponent?.id == component.id ? 
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

// MARK: - Drawer Card

private struct DraggableComponentCard: View {
    let definition: ComponentDefinition
    @State private var hovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Circle().fill(definition.type.color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(definition.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(definition.type.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(hovered ? definition.type.color : .clear, lineWidth: 1)
                )
        )
        .onHover { hovered = $0 }
    }
}

// MARK: - Small UI Helpers

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? color.opacity(0.2) : Color(.controlBackgroundColor))
                        .stroke(
                            isSelected ? color : Color(.separatorColor),
                            lineWidth: isSelected ? 1.5 : 0.5
                        )
                )
                .foregroundColor(isSelected ? color : .primary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PipelineDesignerView()
        .frame(width: 1200, height: 800)
}
