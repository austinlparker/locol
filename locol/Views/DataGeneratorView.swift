import SwiftUI

struct DataGeneratorView: View {
    @ObservedObject var manager: DataGeneratorManager
    @StateObject private var configManager = DataGeneratorConfigManager.shared
    @State private var error: Error?
    @State private var showError = false
    @State private var showingSaveDialog = false
    @State private var showingLoadDialog = false
    @State private var newConfigName = ""
    @State private var selectedHeader: String?
    @State private var newHeaderKey = ""
    @State private var newHeaderValue = ""
    @State private var selectedTab = 0
    @State private var isDownloading = false
    
    init(manager: DataGeneratorManager = .shared) {
        self._manager = ObservedObject(wrappedValue: manager)
    }
    
    private var controlBar: some View {
        HStack {
            if manager.isRunning {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                        .opacity(0.8)
                    Text("Running")
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            }
            
            Spacer()
            
            if manager.isRunning {
                Button(role: .destructive) {
                    Task {
                        await manager.stopGenerator()
                    }
                } label: {
                    Label("Stop Generator", systemImage: "stop.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                Button {
                    Task {
                        await manager.startGenerator()
                    }
                } label: {
                    Label("Start Generator", systemImage: "play.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .animation(.default, value: manager.isRunning)
    }
    
    private var configurationView: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    Button(action: { showingSaveDialog = true }) {
                        Label("Save Configuration", systemImage: "square.and.arrow.down")
                    }
                    Button(action: { showingLoadDialog = true }) {
                        Label("Load Configuration", systemImage: "square.and.arrow.up")
                    }
                }
            }
            
            Section("Connection") {
                TextField("Endpoint", text: $manager.config.endpoint)
                    .textFieldStyle(.roundedBorder)
                Toggle("Insecure Connection", isOn: $manager.config.insecure)
                Picker("Protocol", selection: $manager.config.transportProtocol) {
                    ForEach(DataGeneratorConfig.ProtocolType.allCases, id: \.self) { type in
                        Text(type.rawValue.uppercased())
                            .tag(type)
                    }
                }
            }
            
            Section("Headers") {
                ForEach(Array(manager.config.headers.keys), id: \.self) { key in
                    HStack {
                        Text(key)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(manager.config.headers[key] ?? "")
                        Button(role: .destructive) {
                            manager.config.headers.removeValue(forKey: key)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                
                HStack {
                    TextField("Key", text: $newHeaderKey)
                        .textFieldStyle(.roundedBorder)
                    TextField("Value", text: $newHeaderValue)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        if !newHeaderKey.isEmpty {
                            manager.config.headers[newHeaderKey] = newHeaderValue
                            newHeaderKey = ""
                            newHeaderValue = ""
                        }
                    }
                    .disabled(newHeaderKey.isEmpty)
                }
            }
            
            Section("Generation Settings") {
                TextField("Service Name", text: $manager.config.serviceName)
                    .textFieldStyle(.roundedBorder)
                
                Picker("Log Level", selection: $manager.config.logLevel) {
                    ForEach(DataGeneratorConfig.LogLevel.allCases, id: \.self) { level in
                        Text(level.rawValue.uppercased())
                            .tag(level)
                    }
                }
                
                Picker("Data Type", selection: $manager.config.dataType) {
                    ForEach(DataGeneratorConfig.DataType.allCases, id: \.self) { type in
                        Text(type.rawValue.capitalized)
                            .tag(type)
                    }
                }
            }
            
            // Type-specific configuration
            Section {
                switch manager.config.dataType {
                case .traces:
                    TracesConfigView(config: $manager.config.tracesConfig)
                case .metrics:
                    MetricsConfigView(config: $manager.config.metricsConfig)
                case .logs:
                    LogsConfigView(config: $manager.config.logsConfig)
                }
            }
            
            Section {
                HStack {
                    Text("Rate (per second)")
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("Rate", value: $manager.config.rate, format: .number)
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .formStyle(.grouped)
        .disabled(manager.isDownloading)
    }
    
    private var downloadPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            
            Text("Data Generator Not Found")
                .font(.headline)
            Text("The data generator binary needs to be downloaded before use.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: downloadGenerator) {
                Label("Download Generator", systemImage: "arrow.down.circle")
                    .frame(minWidth: 200)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(nsColor: .controlBackgroundColor))
            .shadow(radius: 2))
        .padding()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            controlBar
            
            if manager.needsDownload {
                downloadPrompt
            } else if isDownloading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Downloading generator...")
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else {
                TabView(selection: $selectedTab) {
                    configurationView
                        .tabItem {
                            Label("Configuration", systemImage: "gear")
                        }
                        .tag(0)
                    
                    DataGeneratorLogView()
                        .padding()
                        .tabItem {
                            Label("Logs", systemImage: "text.alignleft")
                        }
                        .tag(1)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 800)
        .sheet(isPresented: $showingSaveDialog) {
            SaveConfigurationView(
                config: manager.config,
                configName: $newConfigName,
                onSave: { name in
                    var configToSave = manager.config
                    configToSave.name = name
                    configManager.saveConfig(configToSave)
                }
            )
        }
        .sheet(isPresented: $showingLoadDialog) {
            LoadConfigurationView(
                configs: configManager.savedConfigs,
                onLoad: { config in
                    manager.config = config
                },
                onDelete: { config in
                    configManager.deleteConfig(config)
                }
            )
        }
        .alert("Download Error", isPresented: $showError, presenting: error) { _ in
            Button("OK") {}
        } message: { error in
            Text(error.localizedDescription)
        }
    }
    
    private func downloadGenerator() {
        isDownloading = true
        Task {
            do {
                try await manager.downloadGenerator()
                await MainActor.run {
                    manager.needsDownload = false
                    isDownloading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.showError = true
                    isDownloading = false
                }
            }
        }
    }
}

struct SaveConfigurationView: View {
    let config: DataGeneratorConfig
    @Binding var configName: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Configuration Name", text: $configName)
                    .textFieldStyle(.roundedBorder)
            }
            .formStyle(.grouped)
            .navigationTitle("Save Configuration")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(configName)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(configName.isEmpty)
                }
            }
        }
    }
}

struct LoadConfigurationView: View {
    let configs: [DataGeneratorConfig]
    let onLoad: (DataGeneratorConfig) -> Void
    let onDelete: (DataGeneratorConfig) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(configs) { config in
                    HStack {
                        Text(config.name)
                        Spacer()
                        Button("Load") {
                            onLoad(config)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        onDelete(configs[index])
                    }
                }
            }
            .navigationTitle("Load Configuration")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
} 