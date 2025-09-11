import Foundation
import GRDB
import os

// MARK: - CollectorStore Data Types

struct CollectorSummary: Sendable, Equatable, Hashable {
    let id: UUID
    let name: String
    let version: String
    let isRunning: Bool
}

struct CollectorRecord: Sendable, Equatable, Hashable {
    let id: UUID
    let name: String
    let version: String
    let binaryPath: String
    let flags: String
    let isRunning: Bool
    let currentConfigId: UUID?
}

struct ConfigVersionSummary: Sendable, Equatable, Hashable {
    let id: UUID
    let rev: Int
    let createdAt: Date
    let autosave: Bool
    let isValid: Bool
}

// MARK: - CollectorStore Actor

actor CollectorStore {
    private let logger = Logger.database
    private let dbQueue: DatabaseQueue
    
    // Allow tests to pass a custom DB location; default to app DB under ~/.locol/telemetry.db
    init(databaseURL: URL? = nil) {
        do {
            let dbURL: URL
            if let databaseURL {
                dbURL = databaseURL
                try FileManager.default.createDirectory(at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            } else {
                let homeDir = URL(fileURLWithPath: NSHomeDirectory())
                let baseDir = homeDir.appendingPathComponent(".locol")
                try FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
                dbURL = baseDir.appendingPathComponent("telemetry.db")
            }
            self.dbQueue = try DatabaseQueue(path: dbURL.path)
            try TelemetryStorage.runMigrations(on: dbQueue)
            logger.info("CollectorStore initialized at \(dbURL.path)")
        } catch {
            logger.error("CollectorStore init failed: \(error.localizedDescription)")
            fatalError("CollectorStore init failed: \(error)")
        }
    }
}

// MARK: - Public API

extension CollectorStore {
    // Create collector with an initial config version and set it current
    func createCollector(
        id explicitId: UUID? = nil,
        name: String,
        version: String,
        binaryPath: String,
        defaultConfig: CollectorConfiguration
    ) async throws -> (collectorId: UUID, versionId: UUID) {
        let collectorId = explicitId ?? UUID()
        let versionId = UUID()
        let now = Date()
        let configData = try JSONEncoder().encode(defaultConfig)
        
        try await dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO collectors (id, name, version, binary_path, command_line_flags, is_running, start_time_nanos, last_state_change_nanos, current_config_id)
                VALUES (?, ?, ?, ?, '', 0, NULL, NULL, ?)
            """, arguments: [collectorId.uuidString, name, version, binaryPath, versionId.uuidString])
            
            try db.execute(sql: """
                INSERT INTO config_versions (id, collector_id, rev, created_at, config_json, yaml, is_valid, autosave)
                VALUES (?, ?, 1, ?, ?, NULL, 1, 0)
            """, arguments: [versionId.uuidString, collectorId.uuidString, now, configData])
        }
        
        logger.debug("Created collector \(name) with id=\(collectorId.uuidString)")
        return (collectorId, versionId)
    }
    
    func listCollectors() async throws -> [CollectorSummary] {
        try await dbQueue.read { db in
            var result: [CollectorSummary] = []
            let rows = try Row.fetchAll(db, sql: """
                SELECT id, name, version, is_running FROM collectors ORDER BY name
            """)
            for row in rows {
                let idStr: String = row["id"]
                let summary = CollectorSummary(
                    id: UUID(uuidString: idStr) ?? UUID(),
                    name: row["name"],
                    version: row["version"],
                    isRunning: row["is_running"]
                )
                result.append(summary)
            }
            return result
        }
    }
    
    func getCollector(_ id: UUID) async throws -> CollectorRecord? {
        try await dbQueue.read { db in
            try Row.fetchOne(db, sql: """
                SELECT id, name, version, binary_path, command_line_flags, is_running, current_config_id
                FROM collectors WHERE id = ?
            """, arguments: [id.uuidString]).map { row in
                CollectorRecord(
                    id: UUID(uuidString: row["id"]) ?? id,
                    name: row["name"],
                    version: row["version"],
                    binaryPath: row["binary_path"],
                    flags: row["command_line_flags"],
                    isRunning: row["is_running"],
                    currentConfigId: (row["current_config_id"] as String?).flatMap(UUID.init(uuidString:))
                )
            }
        }
    }
    
    func getByName(_ name: String) async throws -> CollectorRecord? {
        try await dbQueue.read { db in
            try Row.fetchOne(db, sql: """
                SELECT id, name, version, binary_path, command_line_flags, is_running, current_config_id
                FROM collectors WHERE name = ?
            """, arguments: [name]).map { row in
                let idStr: String = row["id"]
                return CollectorRecord(
                    id: UUID(uuidString: idStr) ?? UUID(),
                    name: row["name"],
                    version: row["version"],
                    binaryPath: row["binary_path"],
                    flags: row["command_line_flags"],
                    isRunning: row["is_running"],
                    currentConfigId: (row["current_config_id"] as String?).flatMap(UUID.init(uuidString:))
                )
            }
        }
    }
    
    func getCurrentConfig(_ collectorId: UUID) async throws -> (versionId: UUID, config: CollectorConfiguration)? {
        try await dbQueue.read { db in
            guard let row = try Row.fetchOne(db, sql: """
                SELECT current_config_id FROM collectors WHERE id = ?
            """, arguments: [collectorId.uuidString]) else { return nil }
            guard let currentIdStr: String = row["current_config_id"], let currentId = UUID(uuidString: currentIdStr) else {
                return nil
            }
            guard let cfgRow = try Row.fetchOne(db, sql: """
                SELECT id, config_json FROM config_versions WHERE id = ?
            """, arguments: [currentIdStr]) else { return nil }
            let data: Data = cfgRow["config_json"]
            let config = try JSONDecoder().decode(CollectorConfiguration.self, from: data)
            return (currentId, config)
        }
    }
    
    func getConfigVersions(_ collectorId: UUID, limit: Int = 20, offset: Int = 0) async throws -> [ConfigVersionSummary] {
        try await dbQueue.read { db in
            var result: [ConfigVersionSummary] = []
            let rows = try Row.fetchAll(db, sql: """
                SELECT id, rev, created_at, autosave, is_valid
                FROM config_versions WHERE collector_id = ?
                ORDER BY rev DESC LIMIT ? OFFSET ?
            """, arguments: [collectorId.uuidString, limit, offset])
            for row in rows {
                let idStr: String = row["id"]
                result.append(ConfigVersionSummary(
                    id: UUID(uuidString: idStr) ?? UUID(),
                    rev: row["rev"],
                    createdAt: row["created_at"],
                    autosave: row["autosave"],
                    isValid: row["is_valid"]
                ))
            }
            return result
        }
    }
    
    func saveConfigVersion(_ collectorId: UUID, config: CollectorConfiguration, autosave: Bool) async throws -> UUID {
        let newId = UUID()
        let data = try JSONEncoder().encode(config)
        let now = Date()
        
        try await dbQueue.write { db in
            // Determine next rev
            let maxRev: Int = try Int.fetchOne(db, sql: "SELECT COALESCE(MAX(rev), 0) FROM config_versions WHERE collector_id = ?", arguments: [collectorId.uuidString]) ?? 0
            let nextRev = maxRev + 1
            try db.execute(sql: """
                INSERT INTO config_versions (id, collector_id, rev, created_at, config_json, yaml, is_valid, autosave)
                VALUES (?, ?, ?, ?, ?, NULL, 1, ?)
            """, arguments: [newId.uuidString, collectorId.uuidString, nextRev, now, data, autosave ? 1 : 0])
        }
        return newId
    }
    
    func setCurrentConfig(_ collectorId: UUID, versionId: UUID) async throws {
        try await dbQueue.write { db in
            try db.execute(sql: "UPDATE collectors SET current_config_id = ? WHERE id = ?", arguments: [versionId.uuidString, collectorId.uuidString])
            try db.execute(sql: "UPDATE collectors SET last_state_change_nanos = ? WHERE id = ?", arguments: [Int64(Date().timeIntervalSince1970 * 1_000_000_000), collectorId.uuidString])
        }
    }
    
    func updateFlags(_ collectorId: UUID, flags: String) async throws {
        try await dbQueue.write { db in
            try db.execute(sql: "UPDATE collectors SET command_line_flags = ? WHERE id = ?", arguments: [flags, collectorId.uuidString])
        }
    }
    
    func markRunning(_ collectorId: UUID, start: Date) async throws {
        let nanos = Int64(start.timeIntervalSince1970 * 1_000_000_000)
        try await dbQueue.write { db in
            try db.execute(sql: "UPDATE collectors SET is_running = 1, start_time_nanos = ?, last_state_change_nanos = ? WHERE id = ?", arguments: [nanos, nanos, collectorId.uuidString])
        }
    }
    
    func markStopped(_ collectorId: UUID) async throws {
        let nanos = Int64(Date().timeIntervalSince1970 * 1_000_000_000)
        try await dbQueue.write { db in
            try db.execute(sql: "UPDATE collectors SET is_running = 0, last_state_change_nanos = ? WHERE id = ?", arguments: [nanos, collectorId.uuidString])
        }
    }
    
    func deleteCollector(_ collectorId: UUID) async throws {
        try await dbQueue.write { db in
            try db.execute(sql: "DELETE FROM config_versions WHERE collector_id = ?", arguments: [collectorId.uuidString])
            try db.execute(sql: "DELETE FROM collectors WHERE id = ?", arguments: [collectorId.uuidString])
        }
    }
}

// MARK: - Observations

extension CollectorStore {
    /// Observe the list of collectors as summaries. Emits on any change.
    func observeCollectors() -> AsyncStream<[CollectorSummary]> {
        AsyncStream { continuation in
            let observation = ValueObservation.tracking { db in
                try Row.fetchAll(db, sql: "SELECT id, name, version, is_running FROM collectors ORDER BY name").map { row in
                    let idStr: String = row["id"]
                    return CollectorSummary(
                        id: UUID(uuidString: idStr) ?? UUID(),
                        name: row["name"],
                        version: row["version"],
                        isRunning: row["is_running"]
                    )
                }
            }
            let cancellable = try? observation.start(
                in: dbQueue,
                onError: { _ in continuation.finish() },
                onChange: { value in continuation.yield(value) }
            )
            continuation.onTermination = { _ in
                cancellable?.cancel()
            }
        }
    }
}
