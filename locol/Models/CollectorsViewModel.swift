import Foundation
import Observation

@MainActor
@Observable
final class CollectorsViewModel {
    private let store: CollectorStore
    private var streamTask: Task<Void, Never>? = nil

    private(set) var items: [CollectorSummary] = []

    init(store: CollectorStore) {
        self.store = store
        startObserving()
    }

    func startObserving() {
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let self else { return }
            let stream = await store.observeCollectors()
            for await list in stream {
                await MainActor.run { [weak self] in
                    self?.items = list
                }
            }
        }
    }
}
