import Foundation
import os
import Observation

@Observable
class AppState {
    private(set) var collectors: [CollectorInstance]
    private let collectorsPersistence = UserDefaultsArrayPersistence<CollectorInstance>(key: "SavedCollectors")
    
    init() {
        self.collectors = collectorsPersistence.load()
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
        collectorsPersistence.save(collectors)
    }
} 
