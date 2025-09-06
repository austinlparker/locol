import Foundation
import os

/// Protocol for objects that can be persisted to UserDefaults using JSON encoding
@MainActor
protocol UserDefaultsPersistable: Codable {
    associatedtype PersistedType: Codable
    
    /// The key used to store this object in UserDefaults
    var userDefaultsKey: String { get }
    
    /// The object to be persisted (usually `self`)
    var persistedValue: PersistedType { get }
    
    /// Initialize from the persisted value
    init(from persistedValue: PersistedType)
}

extension UserDefaultsPersistable {
    /// Save the object to UserDefaults
    func saveToUserDefaults() {
        do {
            let encoded = try JSONEncoder().encode(persistedValue)
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
            Logger.app.debug("Successfully saved \(String(describing: type(of: self))) to UserDefaults")
        } catch {
            Logger.app.error("Failed to save \(String(describing: type(of: self))) to UserDefaults: \(error.localizedDescription)")
        }
    }
    
    /// Load the object from UserDefaults
    static func loadFromUserDefaults<T: UserDefaultsPersistable>(
        type: T.Type,
        key: String,
        defaultValue: @autoclosure () -> T
    ) -> T {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            Logger.app.debug("No data found in UserDefaults for key: \(key), using default")
            return defaultValue()
        }
        
        do {
            let persistedValue = try JSONDecoder().decode(T.PersistedType.self, from: data)
            return T(from: persistedValue)
        } catch {
            Logger.app.error("Failed to decode \(String(describing: type)) from UserDefaults: \(error.localizedDescription), using default")
            // Clear corrupted data
            UserDefaults.standard.removeObject(forKey: key)
            return defaultValue()
        }
    }
}

/// Helper for persisting arrays of Codable objects
struct UserDefaultsArrayPersistence<Element: Codable> {
    private let key: String
    private let logger = Logger.app
    
    init(key: String) {
        self.key = key
    }
    
    func save(_ array: [Element]) {
        do {
            let encoded = try JSONEncoder().encode(array)
            UserDefaults.standard.set(encoded, forKey: key)
            logger.debug("Successfully saved array of \(String(describing: Element.self)) to UserDefaults")
        } catch {
            logger.error("Failed to save array to UserDefaults: \(error.localizedDescription)")
        }
    }
    
    func load() -> [Element] {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            logger.debug("No array data found in UserDefaults for key: \(key)")
            return []
        }
        
        do {
            return try JSONDecoder().decode([Element].self, from: data)
        } catch {
            logger.error("Failed to decode array from UserDefaults: \(error.localizedDescription)")
            // Clear corrupted data
            UserDefaults.standard.removeObject(forKey: key)
            return []
        }
    }
}