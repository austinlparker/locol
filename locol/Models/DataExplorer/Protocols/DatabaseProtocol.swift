import Foundation
import DuckDB

protocol DatabaseProtocol {
    var connection: Connection? { get }
    
    func connect() throws
    func disconnect()
    func executeQuery(_ query: String) async throws -> ResultSet
    func createAppender(for table: String) throws -> Appender
    func flushAppenders() throws
} 