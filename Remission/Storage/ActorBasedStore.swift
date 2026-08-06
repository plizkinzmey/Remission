// ActorBasedStore.swift
// Remission
//
// Thread-safe, actor-isolated storage for Codable values in UserDefaults.
// Replaces duplicated UserDefaultsBox / *MemoryStore patterns across the codebase.
//
// Usage:
//   let store = UserDefaultsStore<OnboardingProgress>(key: "onboarding.progress")
//   let progress = await store.load()
//   await store.save(newProgress)

import Foundation

/// A thread-safe, actor-isolated wrapper around UserDefaults for a single Codable value.
/// All operations are serialized through the actor, guaranteeing no data races.
/// Generic over any `Codable & Sendable` type.
public actor UserDefaultsStore<Value: Codable & Sendable> {
    private let key: String
    private let suiteName: String?
    private var cache: Value?

    private var defaults: UserDefaults {
        if let suiteName {
            return UserDefaults(suiteName: suiteName) ?? .standard
        }
        return .standard
    }

    /// Creates a new store for the given key using the standard UserDefaults.
    /// - Parameter key: The UserDefaults key to read/write.
    public init(key: String) {
        self.key = key
        self.suiteName = nil
    }

    /// Creates a new store for the given key using a specific UserDefaults suite name.
    /// - Parameter key: The UserDefaults key to read/write.
    /// - Parameter suiteName: The name of the UserDefaults suite (e.g., for tests). Can be nil for standard.
    public init(key: String, suiteName: String?) {
        self.key = key
        self.suiteName = suiteName
    }

    /// Loads the value from UserDefaults, using an in-memory cache after first load.
    /// - Returns: The decoded value, or `nil` if not set or decoding fails.
    public func load() -> Value? {
        if let cache { return cache }
        guard let data = defaults.data(forKey: key),
            let value = try? JSONDecoder().decode(Value.self, from: data)
        else {
            return nil
        }
        cache = value
        return value
    }

    /// Saves the value to UserDefaults and updates the cache.
    /// - Parameter value: The value to encode and persist.
    /// - Throws: EncodingError if the value cannot be encoded.
    public func save(_ value: Value) throws {
        cache = value
        let data = try JSONEncoder().encode(value)
        defaults.set(data, forKey: key)
    }

    /// Removes the value from UserDefaults and clears the cache.
    public func remove() {
        cache = nil
        defaults.removeObject(forKey: key)
    }

    /// Returns `true` if a value exists for the key (checks cache first, then UserDefaults).
    public func exists() -> Bool {
        if cache != nil { return true }
        return defaults.data(forKey: key) != nil
    }
}

/// Convenience actor for storing optional values with a default.
/// Useful when you want `load()` to return a default instead of `nil`.
public actor UserDefaultsStoreWithDefault<Value: Codable & Sendable> {
    private let store: UserDefaultsStore<Value>
    private let defaultValue: Value

    public init(key: String, defaultValue: Value) {
        self.store = UserDefaultsStore(key: key)
        self.defaultValue = defaultValue
    }

    public init(key: String, defaultValue: Value, suiteName: String) {
        self.store = UserDefaultsStore(key: key, suiteName: suiteName)
        self.defaultValue = defaultValue
    }

    public func load() async -> Value {
        await store.load() ?? defaultValue
    }

    public func save(_ value: Value) async throws {
        try await store.save(value)
    }

    public func remove() async {
        await store.remove()
    }

    public func exists() async -> Bool {
        await store.exists()
    }
}

/// Typed keys for compile-time safety (optional, but recommended for consistency).
/// Usage:
///   extension UserDefaultsStoreKey {
///       static let onboardingProgress = UserDefaultsStoreKey<OnboardingProgress>("onboarding.progress")
///   }
///   let store = UserDefaultsStore(key: .onboardingProgress)
public struct UserDefaultsStoreKey<Value: Codable & Sendable>: Hashable, Sendable {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

extension UserDefaultsStore {
    /// Convenience initializer using a typed key.
    public init(key: UserDefaultsStoreKey<Value>) {
        self.init(key: key.rawValue)
    }
}

extension UserDefaultsStoreWithDefault {
    public init(key: UserDefaultsStoreKey<Value>, defaultValue: Value) {
        self.init(key: key.rawValue, defaultValue: defaultValue)
    }
}
