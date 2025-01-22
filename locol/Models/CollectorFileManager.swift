import Foundation
import os

public class CollectorFileManager {
    static let shared = CollectorFileManager()
    private let logger = Logger.app
    
    let baseDirectory: URL
    let templatesDirectory: URL
    
    public init() {
        self.baseDirectory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".locol")
        self.templatesDirectory = Bundle.main.resourceURL?.appendingPathComponent("templates") ?? baseDirectory.appendingPathComponent("templates")
        
        try? createDirectoryStructure()
    }
    
    private func createDirectoryStructure() throws {
        // Create base directories
        try FileManager.default.createDirectory(at: baseDirectory.appendingPathComponent("collectors"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: baseDirectory.appendingPathComponent("bin"), withIntermediateDirectories: true)
        
        // Copy default templates if they don't exist
        if let defaultConfig = Bundle.main.url(forResource: "defaultConfig", withExtension: "yaml", subdirectory: "templates") {
            let destPath = baseDirectory.appendingPathComponent("collectors/default.yaml")
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
        logger.debug("Created directory at \(binPath.path)")
        
        // Copy default config if it doesn't exist
        if !FileManager.default.fileExists(atPath: configPath.path),
           let defaultConfig = Bundle.main.url(forResource: "defaultConfig", withExtension: "yaml") {
            try FileManager.default.copyItem(at: defaultConfig, to: configPath)
        }
        
        return (binPath.path, configPath.path)
    }
    
    func listConfigTemplates() throws -> [URL] {
        // Look for templates in the bundle's templates directory
        if let bundleTemplatesPath = Bundle.main.resourceURL?.appendingPathComponent("templates") {
            let contents = try FileManager.default.contentsOfDirectory(
                at: bundleTemplatesPath,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            return contents.filter { $0.pathExtension == "yaml" }
        }
        return []
    }
    
    func applyConfigTemplate(named templateName: String, to collectorConfigPath: String) throws {
        guard let templateURL = Bundle.main.url(forResource: templateName.replacingOccurrences(of: ".yaml", with: ""), 
                                              withExtension: "yaml",
                                              subdirectory: "templates") else {
            throw FileError.templateNotFound
        }
        
        let templateContent = try String(contentsOf: templateURL, encoding: .utf8)
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
    
    var dataGeneratorPath: URL {
        baseDirectory
            .appendingPathComponent("bin")
            .appendingPathComponent("otelgen")
    }
}

enum FileError: Error {
    case templateNotFound
    case binaryNameNotFound
    case binaryNotFound(String)
    case extractionFailed
    case configurationError(String)
} 
