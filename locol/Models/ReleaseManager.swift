import Foundation
import os

class ReleaseManager: ObservableObject {
    @Published var availableReleases: [Release] = []
    private let logger = Logger.app
    
    private let cacheKeyReleases = "CachedReleases"
    private let cacheKeyTimestamp = "CachedReleasesTimestamp"
    
    func getCollectorReleases(repo: String, forceRefresh: Bool = false, completion: @escaping () -> Void = {}) {
        if !forceRefresh, let cachedReleases = getCachedReleases() {
            DispatchQueue.main.async {
                self.availableReleases = cachedReleases
                self.logger.info("Loaded releases from cache")
                completion()
            }
            return
        }
        
        let urlString = "https://api.github.com/repos/open-telemetry/\(repo)/releases"
        guard let url = URL(string: urlString) else {
            logger.error("Invalid URL: \(urlString)")
            completion()
            return
        }

        logger.debug("Fetching releases from \(urlString)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                self.logger.error("Error fetching releases: \(error.localizedDescription)")
                completion()
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                self.logger.error("Invalid response received")
                completion()
                return
            }

            if httpResponse.statusCode == 403, let resetTime = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Reset") {
                let resetTimestamp = Double(resetTime) ?? 0
                let resetDate = Date(timeIntervalSince1970: resetTimestamp)
                self.logger.error("Rate limited. Retry after \(resetDate)")
                completion()
                return
            }

            guard let data = data else {
                self.logger.error("No data received")
                completion()
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let releases = try decoder.decode([Release].self, from: data)

                let filteredReleases = self.filterReleases(releases)
                self.logger.info("Filtered releases count: \(filteredReleases.count)")
                self.cacheReleases(filteredReleases)

                DispatchQueue.main.async {
                    self.availableReleases = filteredReleases
                    completion()
                }
            } catch {
                self.logger.error("Failed to decode releases: \(error.localizedDescription)")
                completion()
            }
        }

        task.resume()
    }
    
    private func filterReleases(_ releases: [Release]) -> [Release] {
        return releases.compactMap { release -> Release? in
            guard release.tagName.range(of: #"^v\d+\.\d+\.\d+$"#, options: .regularExpression) != nil else {
                return nil
            }

            let darwinBinaryAssets = release.assets?.filter { $0.name.contains("darwin") && $0.name.hasSuffix(".tar.gz") } ?? []
            if darwinBinaryAssets.isEmpty {
                return nil
            }

            return Release(
                url: release.url,
                htmlURL: release.htmlURL,
                assetsURL: release.assetsURL,
                tagName: release.tagName,
                name: release.name,
                publishedAt: release.publishedAt,
                author: release.author,
                assets: darwinBinaryAssets
            )
        }
    }
    
    private func cacheReleases(_ releases: [Release]) {
        let timestamp = Date()
        do {
            let encodedReleases = try JSONEncoder().encode(releases)
            UserDefaults.standard.set(encodedReleases, forKey: cacheKeyReleases)
            UserDefaults.standard.set(timestamp, forKey: cacheKeyTimestamp)
            logger.info("Cached releases at \(timestamp)")
        } catch {
            logger.error("Failed to cache releases: \(error.localizedDescription)")
        }
    }
    
    private func getCachedReleases() -> [Release]? {
        guard let timestamp = UserDefaults.standard.object(forKey: cacheKeyTimestamp) as? Date else { return nil }
        guard Date().timeIntervalSince(timestamp) < 3600 else { return nil } // Cache valid for 1 hour
        guard let encodedReleases = UserDefaults.standard.data(forKey: cacheKeyReleases) else { return nil }

        do {
            return try JSONDecoder().decode([Release].self, from: encodedReleases)
        } catch {
            logger.error("Failed to decode cached releases: \(error.localizedDescription)")
            return nil
        }
    }
    
    func invalidateCache() {
        UserDefaults.standard.removeObject(forKey: cacheKeyReleases)
        UserDefaults.standard.removeObject(forKey: cacheKeyTimestamp)
        logger.info("Cache invalidated")
    }
} 
