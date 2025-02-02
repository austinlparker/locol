import Foundation
import os
import Observation

@Observable
final class ReleaseManager {
    var availableReleases: [Release] = []
    private let logger = Logger.app
    
    private let cacheKeyReleases = "CachedReleases"
    private let cacheKeyTimestamp = "CachedReleasesTimestamp"
    
    func getCollectorReleases(repo: String, forceRefresh: Bool = false, completion: @escaping () -> Void = {}) async {
        if !forceRefresh, let cachedReleases = getCachedReleases() {
            Task { @MainActor in
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

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
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
                let releases = try JSONDecoder().decode([Release].self, from: data)
                let filteredReleases = releases.compactMap { release -> Release? in
                    guard let assets = release.assets else { return nil }
                    let darwinBinaryAssets = assets.filter { asset in
                        asset.name.contains("darwin")
                    }
                    guard !darwinBinaryAssets.isEmpty else { return nil }
                    return self.createFilteredRelease(from: release, with: darwinBinaryAssets)
                }
                
                Task { @MainActor in
                    self.availableReleases = filteredReleases
                    self.cacheReleases(filteredReleases)
                    completion()
                }
            } catch {
                self.logger.error("Failed to decode releases: \(error.localizedDescription)")
                completion()
            }
        }
        task.resume()
    }
    
    private func createFilteredRelease(from release: Release, with darwinBinaryAssets: [ReleaseAsset]) -> Release {
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
