import Foundation
import Observation

@Observable
class OTLPReceiverSettings {
    static let shared = OTLPReceiverSettings()
    
    // gRPC receiver port (single port for all signals)
    var grpcPort: Int = 14317
    
    // Receiver enabled states
    var tracesEnabled: Bool = true
    var metricsEnabled: Bool = true
    var logsEnabled: Bool = true
    
    // HTTP server settings  
    var bindAddress: String = "127.0.0.1"
    var maxRequestSize: Int = 4 * 1024 * 1024 // 4MB default
    
    private init() {
        loadFromUserDefaults()
    }
    
    private func loadFromUserDefaults() {
        let defaults = UserDefaults.standard
        
        grpcPort = defaults.object(forKey: "otlp.grpc.port") as? Int ?? 14317
        
        tracesEnabled = defaults.object(forKey: "otlp.traces.enabled") as? Bool ?? true
        metricsEnabled = defaults.object(forKey: "otlp.metrics.enabled") as? Bool ?? true
        logsEnabled = defaults.object(forKey: "otlp.logs.enabled") as? Bool ?? true
        
        bindAddress = defaults.object(forKey: "otlp.bind.address") as? String ?? "127.0.0.1"
        maxRequestSize = defaults.object(forKey: "otlp.max.request.size") as? Int ?? 4 * 1024 * 1024
    }
    
    func saveToUserDefaults() {
        let defaults = UserDefaults.standard
        
        defaults.set(grpcPort, forKey: "otlp.grpc.port")
        
        defaults.set(tracesEnabled, forKey: "otlp.traces.enabled")
        defaults.set(metricsEnabled, forKey: "otlp.metrics.enabled")
        defaults.set(logsEnabled, forKey: "otlp.logs.enabled")
        
        defaults.set(bindAddress, forKey: "otlp.bind.address")
        defaults.set(maxRequestSize, forKey: "otlp.max.request.size")
    }
    
    // Convenience computed property for gRPC endpoint
    var grpcEndpoint: String {
        "\(bindAddress):\(grpcPort)"
    }
}