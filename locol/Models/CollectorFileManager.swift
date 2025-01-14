import Foundation

class CollectorFileManager {
    let baseDirectory: URL
    let templatesDirectory: URL
    
    init() {
        self.baseDirectory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".locol")
        self.templatesDirectory = Bundle.main.resourceURL?.appendingPathComponent("Templates") ?? baseDirectory.appendingPathComponent("Templates")
        
        try? createDirectoryStructure()
    }
    
    private func createDirectoryStructure() throws {
        // Create base directories
        try FileManager.default.createDirectory(at: baseDirectory.appendingPathComponent("collectors"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: baseDirectory.appendingPathComponent("templates"), withIntermediateDirectories: true)
        
        // Copy default templates if they don't exist
        if let defaultConfig = Bundle.main.url(forResource: "defaultConfig", withExtension: "yaml") {
            let destPath = baseDirectory.appendingPathComponent("templates/default.yaml")
            if !FileManager.default.fileExists(atPath: destPath.path) {
                try FileManager.default.copyItem(at: defaultConfig, to: destPath)
            }
        }
    }
    
    func createCollectorDirectory(name: String, version: String) throws -> (binaryPath: String, configPath: String) {
        let collectorDir = baseDirectory.appendingPathComponent("collectors").appendingPathComponent(name)
        let binPath = collectorDir.appendingPathComponent("bin")
        let configPath = collectorDir.appendingPathComponent("config.yaml")
        
        try FileManager.default.createDirectory(at: binPath, withIntermediateDirectories: true)
        AppLogger.shared.debug("Created directory at \(binPath.path)")
        
        // Copy default config if it doesn't exist
        if !FileManager.default.fileExists(atPath: configPath.path),
           let defaultConfig = Bundle.main.url(forResource: "defaultConfig", withExtension: "yaml") {
            try FileManager.default.copyItem(at: defaultConfig, to: configPath)
        }
        
        return (binPath.path, configPath.path)
    }
    
    func listConfigTemplates() throws -> [URL] {
        let templateDir = baseDirectory.appendingPathComponent("templates")
        let contents = try FileManager.default.contentsOfDirectory(
            at: templateDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return contents.filter { $0.pathExtension == "yaml" }
    }
    
    func applyTemplate(named templateName: String, to collectorConfigPath: String) throws {
        let templatePath = baseDirectory.appendingPathComponent("templates").appendingPathComponent(templateName)
        if !FileManager.default.fileExists(atPath: templatePath.path) {
            throw FileError.templateNotFound
        }
        
        let templateContent = try String(contentsOf: templatePath, encoding: .utf8)
        try writeConfig(templateContent, to: collectorConfigPath)
    }
    
    func handleDownloadedAsset(tempLocalURL: URL, assetName: String, destinationPath: String) throws -> String {
        let extractedPath = try extractTarGz(at: tempLocalURL)
        
        let binaryName = assetName.components(separatedBy: "_").first ?? ""
        if binaryName.isEmpty {
            throw FileError.binaryNameNotFound
        }
        
        let binaryPath = extractedPath.appendingPathComponent(binaryName)
        guard FileManager.default.fileExists(atPath: binaryPath.path) else {
            throw FileError.binaryNotFound(binaryName)
        }
        
        let destinationURL = URL(fileURLWithPath: destinationPath)
        let destinationBinaryPath = destinationURL.appendingPathComponent(binaryName)
        
        if FileManager.default.fileExists(atPath: destinationBinaryPath.path) {
            try FileManager.default.removeItem(at: destinationBinaryPath)
        }
        try FileManager.default.moveItem(at: binaryPath, to: destinationBinaryPath)
        
        // Make the binary executable
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destinationBinaryPath.path)
        
        return destinationBinaryPath.path
    }
    
    func extractTarGz(at fileURL: URL) throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let outputDirectory = tempDirectory.appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xzvf", fileURL.path, "-C", outputDirectory.path]

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw FileError.extractionFailed
        }

        return outputDirectory
    }
    
    func writeConfig(_ config: String, to path: String) throws {
        try config.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
    }
    
    func readConfig(from path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
    }
    
    func deleteCollector(name: String) throws {
        let collectorDir = baseDirectory.appendingPathComponent("collectors").appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: collectorDir.path) {
            try FileManager.default.removeItem(at: collectorDir)
        }
    }
}

enum FileError: Error {
    case templateNotFound
    case binaryNameNotFound
    case binaryNotFound(String)
    case extractionFailed
    case configurationError(String)
} 