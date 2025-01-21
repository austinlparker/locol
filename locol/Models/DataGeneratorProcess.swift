import Foundation

class DataGeneratorProcess {
    static let shared = DataGeneratorProcess()
    private var process: Process?
    private init() {}
    
    var isRunning: Bool {
        process != nil
    }
    
    func start(binary: String, arguments: [String], outputHandler: @escaping (String) -> Void) throws {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        
        pipe.fileHandleForReading.readabilityHandler = { handle in
            if let output = String(data: handle.availableData, encoding: .utf8) {
                DispatchQueue.main.async {
                    outputHandler(output)
                }
            }
        }
        
        try process.run()
        self.process = process
    }
    
    func stop() {
        process?.terminate()
        process = nil
    }
} 