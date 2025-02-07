import SwiftUI

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

@Observable
final class FeatureGatesViewModel {
    let collector: CollectorInstance
    let appState: AppState
    var searchText: String = ""
    var gates: [FeatureGate] = []
    var categories: [FeatureGateCategory] = []
    var isLoadingGates: Bool = true
    
    init(collector: CollectorInstance, appState: AppState) {
        self.collector = collector
        self.appState = appState
        loadGates()
    }
    
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
    
    func loadGates() {
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
        isLoadingGates = false
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
    
    func updateGate(_ gate: FeatureGate, isEnabled: Bool) {
        if let categoryIndex = categories.firstIndex(where: { $0.gates.contains(gate) }),
           let gateIndex = categories[categoryIndex].gates.firstIndex(of: gate) {
            categories[categoryIndex].gates[gateIndex].isEnabled = isEnabled
            gates = categories.flatMap(\.gates)
            
            // Instead of updating command line flags, we'll store the feature gates state
            // This will be used when starting the collector
            do {
                let featureGatesConfig = FeatureGate.serialize(gates: gates)
                let configPath = collector.configPath.replacingOccurrences(of: ".yaml", with: ".featuregates")
                try featureGatesConfig.write(to: URL(fileURLWithPath: configPath), atomically: true, encoding: .utf8)
            } catch {
                // Handle error silently for now
            }
        }
    }
}

struct FeatureGatesView: View {
    @State private var viewModel: FeatureGatesViewModel
    
    init(collector: CollectorInstance, appState: AppState) {
        self._viewModel = State(initialValue: FeatureGatesViewModel(collector: collector, appState: appState))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.isLoadingGates {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if viewModel.gates.isEmpty {
                ContentUnavailableView {
                    Label("No Feature Gates", systemImage: "flag.slash")
                } description: {
                    Text("Failed to load feature gates from the collector")
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.filteredCategories) { category in
                            DisclosureGroup {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(category.gates) { gate in
                                        HStack {
                                            Text(gate.id.replacingOccurrences(of: "\(category.id).", with: ""))
                                                .font(.system(.body, design: .monospaced))
                                                .foregroundStyle(gate.isEnabled ? .primary : .secondary)
                                            
                                            Spacer()
                                            
                                            Toggle("", isOn: Binding(
                                                get: { gate.isEnabled },
                                                set: { viewModel.updateGate(gate, isEnabled: $0) }
                                            ))
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
    }
}
