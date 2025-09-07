import Foundation
import os

/// Centralized file operations service for the application
@MainActor
public class CollectorFileManager: LoggableComponent {
    
    var componentName: String? { "FileManager" }
    var logger: Logger { .fileSystem }
    var signposter: OSSignposter? { .fileSystem }
    
    let baseDirectory: URL
    let templatesDirectory: URL
    
    public init() {
        // Use explicit home directory path to avoid sandboxed container redirection
        let homeDir = URL(fileURLWithPath: NSHomeDirectory())
        self.baseDirectory = homeDir.appendingPathComponent(".locol")
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
    
    
    // MARK: - Common File Operations
    
    /// Check if a file exists at the given path
    func fileExists(at path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }
    
    /// Check if a file exists at the given URL
    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
    
    /// Create a directory at the specified URL
    func createDirectory(at url: URL, withIntermediateDirectories: Bool = true) throws {
        try FileManager.default.createDirectory(
            at: url, 
            withIntermediateDirectories: withIntermediateDirectories,
            attributes: nil
        )
        logger.debug("Created directory: \(url.path)")
    }
    
    /// Remove an item at the specified URL
    func removeItem(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
        logger.debug("Removed item: \(url.path)")
    }
    
    /// Copy an item from source to destination
    func copyItem(from source: URL, to destination: URL) throws {
        try FileManager.default.copyItem(at: source, to: destination)
        logger.debug("Copied item from \(source.path) to \(destination.path)")
    }
    
    /// Move an item from source to destination
    func moveItem(from source: URL, to destination: URL) throws {
        try FileManager.default.moveItem(at: source, to: destination)
        logger.debug("Moved item from \(source.path) to \(destination.path)")
    }
    
    /// Get the contents of a directory
    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]? = nil) throws -> [URL] {
        return try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )
    }
    
    /// Set file attributes
    func setAttributes(_ attributes: [FileAttributeKey: Any], ofItemAt path: String) throws {
        try FileManager.default.setAttributes(attributes, ofItemAtPath: path)
    }
    
    /// Get temporary directory
    var temporaryDirectory: URL {
        FileManager.default.temporaryDirectory
    }
    
    /// Write string to file with error handling
    func writeString(_ content: String, to url: URL, atomically: Bool = true) throws {
        try content.write(to: url, atomically: atomically, encoding: .utf8)
        logger.debug("Wrote content to: \(url.path)")
    }
    
    /// Read string from file with error handling
    func readString(from url: URL) throws -> String {
        let content = try String(contentsOf: url, encoding: .utf8)
        logger.debug("Read content from: \(url.path)")
        return content
    }
    
    /// Write data to file with error handling
    func writeData(_ data: Data, to url: URL) throws {
        try data.write(to: url)
        logger.debug("Wrote data to: \(url.path)")
    }
    
    /// Read data from file with error handling
    func readData(from url: URL) throws -> Data {
        let data = try Data(contentsOf: url)
        logger.debug("Read data from: \(url.path)")
        return data
    }
}

enum FileError: Error {
    case templateNotFound
    case binaryNameNotFound
    case binaryNotFound(String)
    case extractionFailed
    case configurationError(String)
} 
