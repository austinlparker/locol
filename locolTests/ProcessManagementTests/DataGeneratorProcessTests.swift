import XCTest
@testable import locol
import Subprocess

@MainActor
class DataGeneratorProcessTests: XCTestCase {
    // Since we can't subclass DataGeneratorProcess due to its private initializer,
    // we'll test the singleton instance directly while taking care to clean up
    
    override func setUpWithError() throws {
        try super.setUpWithError()
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
    }
    
    func testInitialState() async throws {
        let dataGenerator = DataGeneratorProcess.shared
        let isRunning = await dataGenerator.isRunning
        XCTAssertFalse(isRunning, "Process should not be running initially")
    }
    
    func testStartAndStop() async throws {
        let dataGenerator = DataGeneratorProcess.shared
        let outputExpectation = expectation(description: "Output received")
        let terminationExpectation = expectation(description: "Termination callback called")
        
        // Create a temporary script for testing
        let tempScriptPath = createTestScript()
        defer { cleanupTestScript(tempScriptPath) }
        
        // Ensure clean state at start
        if await dataGenerator.isRunning {
            await dataGenerator.stop()
            // Give it time to fully stop
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
        }
        
        do {
            try await dataGenerator.start(
                binary: "/bin/sh",
                arguments: [tempScriptPath],
                outputHandler: { output in
                    if output.contains("test output") {
                        outputExpectation.fulfill()
                    }
                },
                onTermination: {
                    terminationExpectation.fulfill()
                }
            )
            
            let isRunning = await dataGenerator.isRunning
            XCTAssertTrue(isRunning, "Process should be running after start")
            
            // Short delay to allow the script to execute
            await fulfillment(of: [outputExpectation], timeout: 2.0)
            
            // Stop the process
            await dataGenerator.stop()
            
            await fulfillment(of: [terminationExpectation], timeout: 2.0)
            
            let isStillRunning = await dataGenerator.isRunning
            XCTAssertFalse(isStillRunning, "Process should not be running after stop")
            
        } catch {
            XCTFail("Failed to start process: \(error)")
        }
    }
    
    func testAutoTerminateCallback() async throws {
        let dataGenerator = DataGeneratorProcess.shared
        let terminationExpectation = expectation(description: "Termination callback called automatically")
        
        // Create a temporary script for testing that exits quickly
        let tempScriptPath = createQuickExitScript()
        defer { cleanupTestScript(tempScriptPath) }
        
        // Ensure clean state at start
        if await dataGenerator.isRunning {
            await dataGenerator.stop()
            // Give it time to fully stop
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
        }
        
        do {
            try await dataGenerator.start(
                binary: "/bin/sh",
                arguments: [tempScriptPath],
                outputHandler: { _ in },
                onTermination: {
                    terminationExpectation.fulfill()
                }
            )
            
            // Wait for the termination callback
            await fulfillment(of: [terminationExpectation], timeout: 2.0)
            
            let isRunning = await dataGenerator.isRunning
            XCTAssertFalse(isRunning, "Process should not be running after automatic termination")
            
        } catch {
            XCTFail("Failed to start process: \(error)")
        }
    }
    
    // Helper method to create a test script
    private func createTestScript() -> String {
        let tempPath = NSTemporaryDirectory() + "test_script_\(UUID().uuidString).sh"
        let scriptContent = """
        #!/bin/sh
        echo "test output"
        sleep 5  # Keep the process running long enough for test, but not too long
        """
        
        try? scriptContent.write(to: URL(fileURLWithPath: tempPath), atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempPath)
        
        return tempPath
    }
    
    // Helper method to create a script that exits quickly
    private func createQuickExitScript() -> String {
        let tempPath = NSTemporaryDirectory() + "quick_exit_script_\(UUID().uuidString).sh"
        let scriptContent = """
        #!/bin/sh
        echo "quick exit"
        exit 0
        """
        
        try? scriptContent.write(to: URL(fileURLWithPath: tempPath), atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempPath)
        
        return tempPath
    }
    
    // Helper method to clean up test scripts
    private func cleanupTestScript(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }
}