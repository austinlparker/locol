import SwiftUI

struct CollectorListView: View {
    let collectors: [CollectorInstance]
    @Binding var selectedCollectorId: UUID?
    let onAddCollector: () -> Void
    let onRemoveCollector: (UUID) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedCollectorId) {
                ForEach(collectors) { collector in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(collector.name)
                            .font(.headline)
                        Text("Version: \(collector.version)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .tag(collector.id)
                }
            }
            .listStyle(.sidebar)
            
            Divider()
            
            // Bottom toolbar
            HStack {
                Button(action: onAddCollector) {
                    Label("Add Collector", systemImage: "plus")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .keyboardShortcut("n", modifiers: .command)
                .help("Add Collector")
                
                Button(action: {
                    if let id = selectedCollectorId {
                        onRemoveCollector(id)
                        selectedCollectorId = nil
                    }
                }) {
                    Label("Remove Collector", systemImage: "minus")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .keyboardShortcut(.delete, modifiers: [])
                .help("Remove Selected Collector")
                .disabled(selectedCollectorId == nil)
                
                Spacer()
            }
            .padding(6)
            .background(.bar)
        }
        .frame(width: 220)
    }
}

struct CollectorStatusView: View {
    let collector: CollectorInstance
    let onStartStop: () -> Void
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status indicator and basic info
            HStack(alignment: .center, spacing: 16) {
                Circle()
                    .fill(collector.isRunning ? .green : .red)
                    .frame(width: 8, height: 8)
                
                Text(collector.isRunning ? "Running" : "Stopped")
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button(collector.isRunning ? "Stop" : "Start", action: onStartStop)
                    .tint(collector.isRunning ? .red : .green)
            }
            
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("PID")
                        .foregroundStyle(.secondary)
                    if let pid = collector.pid {
                        Text(String(format: "%d", pid))
                            .font(.system(.body, design: .monospaced))
                    } else {
                        Text("N/A")
                            .foregroundStyle(.secondary)
                    }
                }
                
                GridRow {
                    Text("Config Path")
                        .foregroundStyle(.secondary)
                    Text(collector.configPath)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
                
                GridRow {
                    Text("Uptime")
                        .foregroundStyle(.secondary)
                    Text(formatUptime(since: collector.startTime))
                        .font(.system(.body, design: .monospaced))
                        .id(currentTime)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
    
    private func formatUptime(since date: Date?) -> String {
        guard let date = date else { return "N/A" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 3
        
        return formatter.string(from: date, to: currentTime) ?? "N/A"
    }
}

struct FeatureGate: Identifiable, Hashable {
    let id: String
    var isEnabled: Bool
    
    init(flag: String) {
        if flag.hasPrefix("-") {
            self.id = String(flag.dropFirst())
            self.isEnabled = false
        } else {
            self.id = flag.hasPrefix("+") ? String(flag.dropFirst()) : flag
            self.isEnabled = true
        }
    }
    
    var asFlag: String {
        isEnabled ? id : "-\(id)"
    }
    
    static func parseFromHelpText(_ helpText: String) -> [FeatureGate] {
        // Find the line containing the feature-gates flag
        let lines = helpText.split(separator: "\n")
        guard let featureGatesLine = lines.first(where: { $0.contains("--feature-gates") }) else {
            return []
        }
        
        // The default value is everything after "default" until the end of line or next flag
        guard let defaultStart = featureGatesLine.range(of: "default")?.upperBound else {
            return []
        }
        
        // Get the default value and clean it up
        var defaultValue = String(featureGatesLine[defaultStart...])
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "()"))
        
        // If there's another flag after this one, it would start with "--"
        if let nextFlagRange = defaultValue.range(of: "--") {
            defaultValue = String(defaultValue[..<nextFlagRange.lowerBound])
        }
        
        return defaultValue
            .split(separator: ",")
            .map(String.init)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map(FeatureGate.init)
            .sorted { $0.id < $1.id }
    }
    
    static func parse(fromFlags flags: String) -> [FeatureGate] {
        // If flags string is empty or doesn't contain feature gates, return empty array
        guard !flags.isEmpty, flags.contains("--feature-gates=") else {
            return []
        }
        
        let flagsString = flags.replacingOccurrences(of: "--feature-gates=", with: "")
        return flagsString
            .split(separator: ",")
            .map(String.init)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map(FeatureGate.init)
            .sorted { $0.id < $1.id }
    }
    
    static func serialize(gates: [FeatureGate]) -> String {
        gates.map(\.asFlag).joined(separator: ",")
    }
}

struct FeatureGateCategory: Identifiable {
    let id: String
    var gates: [FeatureGate]
    var isExpanded: Bool = false
    
    init(prefix: String, gates: [FeatureGate]) {
        self.id = prefix
        self.gates = gates
        // Start expanded if any gates in the category are modified from default
        self.isExpanded = gates.contains { $0.isEnabled }
    }
}

struct FeatureGatesView: View {
    let collector: CollectorInstance
    let manager: CollectorManager
    @State private var searchText: String = ""
    @State private var gates: [FeatureGate] = []
    @State private var categories: [FeatureGateCategory] = []
    @State private var isLoadingGates: Bool = true
    
    var filteredCategories: [FeatureGateCategory] {
        if searchText.isEmpty {
            return categories
        }
        return categories.compactMap { category in
            let filteredGates = category.gates.filter { gate in
                gate.id.localizedCaseInsensitiveContains(searchText)
            }
            return filteredGates.isEmpty ? nil : FeatureGateCategory(prefix: category.id, gates: filteredGates)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Feature Gates")
                .font(.headline)
            
            SearchField("Search feature gates", text: $searchText)
                .controlSize(.large)
            
            if isLoadingGates {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if gates.isEmpty {
                ContentUnavailableView {
                    Label("No Feature Gates", systemImage: "flag.slash")
                } description: {
                    Text("Failed to load feature gates from the collector")
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredCategories) { category in
                            DisclosureGroup {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(category.gates) { gate in
                                        HStack {
                                            Text(gate.id.replacingOccurrences(of: "\(category.id).", with: ""))
                                                .font(.system(.body, design: .monospaced))
                                                .foregroundStyle(gate.isEnabled ? .primary : .secondary)
                                            
                                            Spacer()
                                            
                                            Toggle("", isOn: binding(for: gate))
                                                .toggleStyle(.switch)
                                                .labelsHidden()
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(category.id)
                                        .font(.headline)
                                    
                                    Text("(\(category.gates.count))")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                    
                                    if category.gates.contains(where: { $0.isEnabled }) {
                                        Image(systemName: "circle.fill")
                                            .foregroundStyle(.blue)
                                            .font(.system(size: 8))
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                .frame(maxHeight: 400)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .task {
            let currentGates = FeatureGate.parse(fromFlags: collector.commandLineFlags)
            if currentGates.isEmpty {
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: collector.binaryPath)
                    process.arguments = ["--help"]
                    
                    let pipe = Pipe()
                    process.standardOutput = pipe
                    try process.run()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let helpText = String(data: data, encoding: .utf8) {
                        gates = FeatureGate.parseFromHelpText(helpText)
                        categories = categorizeGates(gates)
                    }
                } catch {
                    // Handle error silently
                }
            } else {
                gates = currentGates
                categories = categorizeGates(currentGates)
            }
            isLoadingGates = false
        }
    }
    
    private func categorizeGates(_ gates: [FeatureGate]) -> [FeatureGateCategory] {
        var categoryMap: [String: [FeatureGate]] = [:]
        var uncategorized: [FeatureGate] = []
        
        for gate in gates {
            if let dotIndex = gate.id.firstIndex(of: ".") {
                let prefix = String(gate.id[..<dotIndex])
                categoryMap[prefix, default: []].append(gate)
            } else {
                uncategorized.append(gate)
            }
        }
        
        var categories = categoryMap.map { prefix, gates in
            FeatureGateCategory(prefix: prefix, gates: gates.sorted { $0.id < $1.id })
        }
        categories.sort { $0.id < $1.id }
        
        if !uncategorized.isEmpty {
            categories.append(FeatureGateCategory(prefix: "other", gates: uncategorized))
        }
        
        return categories
    }
    
    private func binding(for gate: FeatureGate) -> Binding<Bool> {
        Binding(
            get: { gate.isEnabled },
            set: { newValue in
                if let categoryIndex = categories.firstIndex(where: { $0.gates.contains(gate) }),
                   let gateIndex = categories[categoryIndex].gates.firstIndex(of: gate) {
                    categories[categoryIndex].gates[gateIndex].isEnabled = newValue
                    gates = categories.flatMap(\.gates)
                    let newFlags = "--feature-gates=\(FeatureGate.serialize(gates: gates))"
                    manager.updateCollectorFlags(withId: collector.id, flags: newFlags)
                }
            }
        )
    }
}

struct SearchField: View {
    let placeholder: String
    @Binding var text: String
    
    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct CollectorDetailView: View {
    let collector: CollectorInstance
    let manager: CollectorManager
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Status section
                CollectorStatusView(
                    collector: collector,
                    onStartStop: {
                        if collector.isRunning {
                            manager.stopCollector(withId: collector.id)
                        } else {
                            manager.startCollector(withId: collector.id)
                        }
                    }
                )
                
                // Action buttons
                HStack(spacing: 8) {
                    Button("Edit Config") {
                        openWindow(id: "ConfigEditorWindow", value: collector.id)
                    }
                    
                    Button("View Metrics & Logs") {
                        openWindow(id: "MetricsLogViewerWindow", value: collector.id)
                    }
                }
                
                Divider()
                
                // Feature Gates section
                FeatureGatesView(collector: collector, manager: manager)
                
                Divider()
                
                // Components section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Components")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: {
                            Task {
                                try await manager.refreshCollectorComponents(withId: collector.id)
                            }
                        }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .help("Refresh component list")
                    }
                    
                    if let components = collector.components {
                        VStack(alignment: .leading, spacing: 16) {
                            if let receivers = components.receivers, !receivers.isEmpty {
                                ComponentSection(
                                    title: "Receivers",
                                    components: receivers,
                                    version: collector.version,
                                    color: .blue
                                )
                            }
                            
                            if let processors = components.processors, !processors.isEmpty {
                                ComponentSection(
                                    title: "Processors",
                                    components: processors,
                                    version: collector.version,
                                    color: .green
                                )
                            }
                            
                            if let exporters = components.exporters, !exporters.isEmpty {
                                ComponentSection(
                                    title: "Exporters",
                                    components: exporters,
                                    version: collector.version,
                                    color: .purple
                                )
                            }
                            
                            if let extensions = components.extensions, !extensions.isEmpty {
                                ComponentSection(
                                    title: "Extensions",
                                    components: extensions,
                                    version: collector.version,
                                    color: .orange
                                )
                            }
                        }
                        .padding(.vertical, 8)
                    } else {
                        ContentUnavailableView {
                            Label("No Components", systemImage: "square.stack.3d.up.slash")
                        } description: {
                            Text("Click refresh to discover components")
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .background(Color(NSColor.controlBackgroundColor))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SettingsView: View {
    @ObservedObject var manager: CollectorManager
    @State private var hasFetchedReleases: Bool = false
    @State private var selectedCollectorId: UUID? = nil
    @State private var showingAddCollector: Bool = false
    @State private var newCollectorName: String = ""
    @State private var selectedRelease: Release? = nil
    
    var body: some View {
        HStack(spacing: 0) {
            CollectorListView(
                collectors: manager.collectors,
                selectedCollectorId: $selectedCollectorId,
                onAddCollector: { showingAddCollector = true },
                onRemoveCollector: { id in
                    manager.removeCollector(withId: id)
                }
            )
            
            Divider()
            
            if let collectorId = selectedCollectorId,
               let collector = manager.collectors.first(where: { $0.id == collectorId }) {
                CollectorDetailView(collector: collector, manager: manager)
            } else {
                ContentUnavailableView("No Collector Selected", 
                    systemImage: "square.dashed",
                    description: Text("Select a collector to view its details")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingAddCollector) {
            AddCollectorSheet(
                manager: manager,
                name: $newCollectorName,
                selectedRelease: $selectedRelease
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            if !hasFetchedReleases {
                manager.getCollectorReleases(repo: "opentelemetry-collector-releases")
                hasFetchedReleases = true
            }
        }
    }
}

struct ComponentTag: View {
    let name: String
    let module: String
    let version: String
    let color: Color
    @Environment(\.openURL) private var openURL
    
    private var moduleUrl: URL? {
        if module.hasPrefix("github.com") {
            // Split the module path and remove version info
            let moduleWithoutVersion = module.split(separator: " ")[0]
            let parts = moduleWithoutVersion.split(separator: "/")
            
            if parts.count >= 4 {
                let org = "open-telemetry"  // Always use open-telemetry org
                let repo = "opentelemetry-collector-contrib"  // Always use contrib repo
                
                // Get the component path (type + name)
                let remainingPath = parts[3...].joined(separator: "/")
                
                // Construct GitHub URL with version
                let urlString = "https://github.com/\(org)/\(repo)/tree/\(version)/\(remainingPath)"
                return URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString)
            }
        } else {
            // If not GitHub or invalid format, try as direct URL
            // Strip version info if present
            let urlString = module.split(separator: " ").first.map(String.init) ?? module
            return URL(string: "https://\(urlString)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString)
        }
        return nil
    }
    
    var body: some View {
        if let url = moduleUrl {
            Button {
                openURL(url) { success in
                    if success {
                        // Successfully opened URL
                    } else {
                        // Failed to open URL
                    }
                }
            } label: {
                TagContent(name: name, color: color)
            }
            .buttonStyle(.plain)
            .help(url.absoluteString)
        } else {
            TagContent(name: name, color: color)
        }
    }
}

struct TagContent: View {
    let name: String
    let color: Color
    
    var body: some View {
        Text(name)
            .font(.system(.body, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(color.opacity(0.2), lineWidth: 1)
            )
    }
}

struct ComponentSection: View {
    let title: String
    let components: [Component]
    let version: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            
            FlowLayout(spacing: 8) {
                ForEach(components.sorted(by: { $0.name < $1.name }), id: \.name) { component in
                    ComponentTag(
                        name: component.name,
                        module: component.module,
                        version: version,
                        color: color
                    )
                }
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentRow: CGFloat = 0
        
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth {
                currentX = 0
                currentRow += size.height + spacing
            }
            
            currentX += size.width + spacing
            height = max(height, currentRow + size.height)
        }
        
        return CGSize(width: maxWidth, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var maxHeight: CGFloat = 0
        
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            
            if currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += maxHeight + spacing
                maxHeight = 0
            }
            
            view.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(size)
            )
            
            currentX += size.width + spacing
            maxHeight = max(maxHeight, size.height)
        }
    }
}
