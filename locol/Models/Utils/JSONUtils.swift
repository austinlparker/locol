import Foundation
import DuckDB

struct JSONUtils {
    static func attributesToJSON(_ attributes: [Opentelemetry_Proto_Common_V1_KeyValue]) -> String {
        let dict = attributes.reduce(into: [String: Any]()) { result, kv in
            result[kv.key] = anyValueToJSON(kv.value)
        }
        
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
    
    private static func anyValueToJSON(_ value: Opentelemetry_Proto_Common_V1_AnyValue) -> Any {
        if let val = value.value {
            switch val {
            case .stringValue(let str): return str
            case .boolValue(let bool): return bool
            case .intValue(let int): return int
            case .doubleValue(let double): return double
            case .arrayValue(let array):
                return array.values.map { anyValueToJSON($0) }
            case .kvlistValue(let kvlist):
                return kvlist.values.reduce(into: [String: Any]()) { result, kv in
                    result[kv.key] = anyValueToJSON(kv.value)
                }
            case .bytesValue(let data):
                return data.base64EncodedString()
            }
        }
        return NSNull()
    }
    
    static func parseJSONColumn(_ jsonString: String) -> [String: String] {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        
        return json.reduce(into: [:]) { result, pair in
            // Convert any value to string representation
            let stringValue: String
            switch pair.value {
            case let num as NSNumber:
                stringValue = num.stringValue
            case let str as String:
                stringValue = str
            case let bool as Bool:
                stringValue = bool ? "true" : "false"
            case let array as [Any]:
                stringValue = array.map { "\($0)" }.joined(separator: ", ")
            case is NSNull:
                stringValue = "null"
            default:
                stringValue = "\(pair.value)"
            }
            result[pair.key] = stringValue
        }
    }
    
    static func expandJsonColumns(_ columns: [DuckDB.Column<String>]) -> [(name: String, values: [String], isJsonExpanded: Bool)] {
        var expandedColumns: [(name: String, values: [String], isJsonExpanded: Bool)] = []
        
        for column in columns {
            let columnName = column.name
            let dbType = column.underlyingDatabaseType
            
            // Check if this is a potential JSON column (all JSON is stored as varchar)
            if dbType == .varchar {
                let values = column.cast(to: String.self)
                let sampleValue = values.prefix(5).compactMap { $0 }.first ?? ""
                
                // Check if this looks like a JSON object
                if sampleValue.starts(with: "{") && sampleValue.hasSuffix("}") {
                    // Get all unique keys from the JSON objects
                    var jsonKeys = Set<String>()
                    let parsedRows = values.map { jsonStr -> [String: String] in
                        let parsed = parseJSONColumn(jsonStr ?? "{}")
                        jsonKeys.formUnion(parsed.keys)
                        return parsed
                    }
                    
                    // Create a column for each JSON key
                    for key in jsonKeys.sorted() {
                        let columnValues = parsedRows.map { row in
                            row[key] ?? "null"
                        }
                        expandedColumns.append((
                            name: "\(columnName).\(key)",
                            values: columnValues,
                            isJsonExpanded: true
                        ))
                    }
                    continue
                }
            }
            
            // Handle non-JSON columns as before
            let values: [String]
            switch dbType {
            case .date, .timestamp, .timestampS, .timestampMS, .timestampNS, .time, .timeTz:
                values = column.cast(to: Date.self).map { $0?.formatted() ?? "null" }
            case .double, .float:
                values = column.cast(to: Double.self).map { $0.map { String(format: "%.6f", $0) } ?? "null" }
            case .integer:
                values = column.cast(to: Int32.self).map { $0.map(String.init) ?? "null" }
            case .bigint:
                values = column.cast(to: Int64.self).map { $0.map(String.init) ?? "null" }
            case .decimal:
                values = column.cast(to: Decimal.self).map { $0.map(String.init) ?? "null" }
            case .boolean:
                values = column.cast(to: Bool.self).map { $0.map(String.init) ?? "null" }
            case .varchar, .uuid:
                values = column.cast(to: String.self).map { $0 ?? "null" }
            default:
                values = column.cast(to: String.self).map { $0 ?? "null" }
            }
            
            expandedColumns.append((name: columnName, values: values, isJsonExpanded: false))
        }
        
        return expandedColumns
    }
} 
