import Foundation
import DuckDB
import os

final class DatabaseManager: DatabaseProtocol {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "DatabaseManager")
    private var database: Database?
    private(set) var connection: Connection?
    private var appenders: [String: Appender] = [:]
    
    init() {
        setupDatabase()
    }
    
    func connect() throws {
        do {
            database = try Database(store: .inMemory)
            connection = try database?.connect()
            try createTables()
        } catch {
            logger.error("Failed to connect to database: \(error.localizedDescription)")
            throw DatabaseError.connectionFailed
        }
    }
    
    func disconnect() {
        try? flushAppenders()
        connection = nil
        database = nil
        appenders.removeAll()
    }
    
    func createAppender(for table: String) throws -> Appender {
        guard let connection = connection else {
            throw DatabaseError.connectionFailed
        }
        
        if let existingAppender = appenders[table] {
            return existingAppender
        }
        
        do {
            let appender = try Appender(connection: connection, table: table)
            appenders[table] = appender
            return appender
        } catch {
            throw DatabaseError.appenderFailedToInitialize(reason: error.localizedDescription)
        }
    }
    
    func flushAppenders() throws {
        for appender in appenders.values {
            try appender.flush()
        }
    }
    
    func executeQuery(_ query: String) async throws -> [String: [Any]] {
        guard let connection = connection else {
            throw DatabaseError.connectionFailed
        }
        
        do {
            let result = try connection.query(query)
            var data: [String: [Any]] = [:]
            
            // Get column names and data
            for i in 0..<result.columnCount {
                let column = result[i]
                let name = column.name
                let dbType = column.underlyingDatabaseType
                
                switch dbType {
                case .date, .timestamp, .timestampS, .timestampMS, .timestampNS:
                    data[name] = column.cast(to: Foundation.Date.self).compactMap { $0 }
                case .double, .float:
                    data[name] = column.cast(to: Double.self).compactMap { $0 }
                case .integer:
                    data[name] = column.cast(to: Int32.self).compactMap { $0 }
                case .bigint:
                    data[name] = column.cast(to: Int64.self).compactMap { $0 }
                case .boolean:
                    data[name] = column.cast(to: Bool.self).compactMap { $0 }
                default:
                    data[name] = column.cast(to: String.self).compactMap { $0 }
                }
            }
            
            return data
        } catch {
            throw DatabaseError.queryFailed(error.localizedDescription)
        }
    }
    
    private func setupDatabase() {
        do {
            try connect()
            logger.info("Database setup completed successfully")
        } catch {
            logger.error("Failed to setup database: \(error.localizedDescription)")
        }
    }
    
    private func createTables() throws {
        try connection?.execute("""
            CREATE TABLE resource_attributes (
                attribute_id VARCHAR PRIMARY KEY,
                key VARCHAR,
                value VARCHAR,
                timestamp TIMESTAMP,
                UNIQUE(key, value)
            );

            CREATE TABLE resource_attribute_mappings (
                resource_id VARCHAR,
                attribute_id VARCHAR,
                PRIMARY KEY (resource_id, attribute_id)
            );

            CREATE TABLE resources (
                resource_id VARCHAR PRIMARY KEY,
                timestamp TIMESTAMP,
                dropped_attributes_count INTEGER
            );

            CREATE TABLE instrumentation_scopes (
                timestamp TIMESTAMP,
                scope_id VARCHAR PRIMARY KEY,
                resource_id VARCHAR,
                name VARCHAR,
                version VARCHAR,
                attributes JSON,
                dropped_attributes_count INTEGER
            );

            CREATE TABLE spans (
                trace_id VARCHAR,
                span_id VARCHAR,
                parent_span_id VARCHAR,
                resource_id VARCHAR,
                scope_id VARCHAR,
                name VARCHAR,
                kind INTEGER,
                attributes JSON,
                start_time TIMESTAMP,
                end_time TIMESTAMP,
                PRIMARY KEY (trace_id, span_id)
            );
            
            CREATE TABLE metric_points (
                metric_point_id VARCHAR PRIMARY KEY,
                resource_id VARCHAR,
                scope_id VARCHAR,
                metric_name VARCHAR,
                description VARCHAR,
                unit VARCHAR,
                type VARCHAR,
                value DOUBLE,
                attributes JSON,
                time TIMESTAMP
            );
            
            CREATE TABLE log_records (
                log_id VARCHAR PRIMARY KEY,
                resource_id VARCHAR,
                scope_id VARCHAR,
                severity_text VARCHAR,
                severity_number INTEGER,
                body TEXT,
                attributes JSON,
                timestamp TIMESTAMP
            );

            -- Indexes for common query patterns
            CREATE INDEX idx_spans_resource ON spans(resource_id);
            CREATE INDEX idx_spans_time ON spans(start_time);
            CREATE INDEX idx_metric_points_resource ON metric_points(resource_id);
            CREATE INDEX idx_metric_points_time ON metric_points(time);
            CREATE INDEX idx_log_records_resource ON log_records(resource_id);
            CREATE INDEX idx_log_records_time ON log_records(timestamp);
            CREATE INDEX idx_resource_attributes_key ON resource_attributes(key);
            CREATE INDEX idx_resource_attributes_value ON resource_attributes(value);
            CREATE INDEX idx_resource_attribute_mappings_resource ON resource_attribute_mappings(resource_id);
            CREATE INDEX idx_resource_attribute_mappings_attribute ON resource_attribute_mappings(attribute_id);
        """)
    }
} 