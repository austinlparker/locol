import Foundation
import Observation
import os

struct OTLPReceiverSettingsData: Codable {
    var grpcPort: Int = 14317
    var tracesEnabled: Bool = true
    var metricsEnabled: Bool = true
    var logsEnabled: Bool = true
    var bindAddress: String = "127.0.0.1"
    var maxRequestSize: Int = 4 * 1024 * 1024 // 4MB default
}

@MainActor
@Observable
class OTLPReceiverSettings {
    
    // gRPC receiver port (single port for all signals)
    var grpcPort: Int = 14317 {
        didSet { save() }
    }
    
    // Receiver enabled states
    var tracesEnabled: Bool = true {
        didSet { save() }
    }
    var metricsEnabled: Bool = true {
        didSet { save() }
    }
    var logsEnabled: Bool = true {
        didSet { save() }
    }
    
    // HTTP server settings  
    var bindAddress: String = "127.0.0.1" {
        didSet { save() }
    }
    var maxRequestSize: Int = 4 * 1024 * 1024 {
        didSet { save() }
    }
    
    init() {
        // Load settings from UserDefaults
        if let loadedData = Self.loadFromUserDefaults() {
            self.grpcPort = loadedData.grpcPort
            self.tracesEnabled = loadedData.tracesEnabled
            self.metricsEnabled = loadedData.metricsEnabled
            self.logsEnabled = loadedData.logsEnabled
            self.bindAddress = loadedData.bindAddress
            self.maxRequestSize = loadedData.maxRequestSize
        }
        // If loading fails, use default values (already set above)
    }
    
    // MARK: - Persistence
    
    private func save() {
        let data = OTLPReceiverSettingsData(
            grpcPort: grpcPort,
            tracesEnabled: tracesEnabled,
            metricsEnabled: metricsEnabled,
            logsEnabled: logsEnabled,
            bindAddress: bindAddress,
            maxRequestSize: maxRequestSize
        )
        
        do {
            let encoded = try JSONEncoder().encode(data)
            UserDefaults.standard.set(encoded, forKey: "OTLPReceiverSettings")
        } catch {
            Logger.app.error("Failed to save OTLP receiver settings: \(error.localizedDescription)")
        }
    }
    
    private static func loadFromUserDefaults() -> OTLPReceiverSettingsData? {
        guard let data = UserDefaults.standard.data(forKey: "OTLPReceiverSettings") else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(OTLPReceiverSettingsData.self, from: data)
        } catch {
            Logger.app.error("Failed to load OTLP receiver settings: \(error.localizedDescription)")
            // Clear corrupted data
            UserDefaults.standard.removeObject(forKey: "OTLPReceiverSettings")
            return nil
        }
    }
    
    // Convenience computed property for gRPC endpoint
    var grpcEndpoint: String {
        "\(bindAddress):\(grpcPort)"
    }
}
