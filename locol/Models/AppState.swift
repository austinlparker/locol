import Foundation
import os

class AppState: ObservableObject {
    @Published private(set) var collectors: [CollectorInstance]
    private let stateKey = "SavedCollectors"
    private let logger = Logger.app
    
    init() {
        // Try to decode with new format first
        if let data = UserDefaults.standard.data(forKey: stateKey) {
            do {
                self.collectors = try JSONDecoder().decode([CollectorInstance].self, from: data)
            } catch {
                logger.error("Failed to decode collectors with new format: \(error)")
                // If decoding fails, clear the stored data to start fresh
                UserDefaults.standard.removeObject(forKey: stateKey)
                self.collectors = []
            }
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
