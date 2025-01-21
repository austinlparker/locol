import Foundation

class DataGeneratorConfigManager: ObservableObject {
    static let shared = DataGeneratorConfigManager()
    
    @Published private(set) var savedConfigs: [DataGeneratorConfig] = []
    private let configsKey = "SavedDataGeneratorConfigs"
    
    init() {
        loadConfigs()
    }
    
    private func loadConfigs() {
        if let data = UserDefaults.standard.data(forKey: configsKey),
           let configs = try? JSONDecoder().decode([DataGeneratorConfig].self, from: data) {
            savedConfigs = configs
        }
    }
    
    func saveConfig(_ config: DataGeneratorConfig) {
        if let index = savedConfigs.firstIndex(where: { $0.id == config.id }) {
            savedConfigs[index] = config
        } else {
            savedConfigs.append(config)
        }
        persistConfigs()
    }
    
    func deleteConfig(_ config: DataGeneratorConfig) {
        savedConfigs.removeAll { $0.id == config.id }
        persistConfigs()
    }
    
    private func persistConfigs() {
        if let encoded = try? JSONEncoder().encode(savedConfigs) {
            UserDefaults.standard.set(encoded, forKey: configsKey)
        }
    }
} 