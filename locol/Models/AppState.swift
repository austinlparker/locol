import Foundation

class AppState: ObservableObject {
    @Published private(set) var collectors: [CollectorInstance]
    private let stateKey = "SavedCollectors"
    
    init() {
        if let data = UserDefaults.standard.data(forKey: stateKey),
           let decodedCollectors = try? JSONDecoder().decode([CollectorInstance].self, from: data) {
            self.collectors = decodedCollectors
        } else {
            self.collectors = []
        }
    }
    
    func addCollector(_ collector: CollectorInstance) {
        collectors.append(collector)
        saveState()
    }
    
    func removeCollector(withId id: UUID) {
        collectors.removeAll { $0.id == id }
        saveState()
    }
    
    func updateCollector(_ collector: CollectorInstance) {
        if let index = collectors.firstIndex(where: { $0.id == collector.id }) {
            collectors[index] = collector
            saveState()
        }
    }
    
    func getCollector(withId id: UUID) -> CollectorInstance? {
        collectors.first { $0.id == id }
    }
    
    private func saveState() {
        if let encoded = try? JSONEncoder().encode(collectors) {
            UserDefaults.standard.set(encoded, forKey: stateKey)
        }
    }
} 