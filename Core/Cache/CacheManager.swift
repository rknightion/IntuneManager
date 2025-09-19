import Foundation
import SwiftData

class CacheManager {
    static let shared = CacheManager()

    private let memoryCache = NSCache<NSString, CacheEntry>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let queue = DispatchQueue(label: "com.intunemanager.cache", attributes: .concurrent)

    private init() {
        // Setup cache directory
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("IntuneManager", isDirectory: true)

        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Configure memory cache
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB

        // Setup cache expiration timer
        setupExpirationTimer()

        // Configure encoder/decoder
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func configure() {
        // Clear expired cache on app launch
        clearExpiredCache()
    }

    // MARK: - Public Methods

    func setObject<T: Codable>(_ object: T, forKey key: String, expiration: CacheExpiration = .hours(1)) {
        queue.async(flags: .barrier) {
            do {
                let data = try self.encoder.encode(object)
                let entry = CacheEntry(data: data, expiration: expiration.date)

                // Store in memory cache
                self.memoryCache.setObject(entry, forKey: key as NSString, cost: data.count)

                // Store on disk
                let fileURL = self.cacheFileURL(for: key)
                try data.write(to: fileURL)

                // Store expiration metadata
                self.storeExpirationMetadata(key: key, expiration: expiration.date)

                Logger.shared.debug("Cached object for key: \(key)")
            } catch {
                Logger.shared.error("Failed to cache object for key \(key): \(error)")
            }
        }
    }

    func getObject<T: Codable>(forKey key: String, type: T.Type) -> T? {
        return queue.sync {
            // Check memory cache first
            if let entry = memoryCache.object(forKey: key as NSString) {
                if !entry.isExpired {
                    do {
                        return try decoder.decode(type, from: entry.data)
                    } catch {
                        Logger.shared.error("Failed to decode cached object for key \(key): \(error)")
                    }
                } else {
                    // Remove expired entry
                    memoryCache.removeObject(forKey: key as NSString)
                }
            }

            // Check disk cache
            let fileURL = cacheFileURL(for: key)
            if fileManager.fileExists(atPath: fileURL.path) {
                if !isExpired(key: key) {
                    do {
                        let data = try Data(contentsOf: fileURL)
                        let object = try decoder.decode(type, from: data)

                        // Store in memory cache for faster access
                        let entry = CacheEntry(data: data, expiration: getExpiration(key: key) ?? Date().addingTimeInterval(3600))
                        memoryCache.setObject(entry, forKey: key as NSString, cost: data.count)

                        return object
                    } catch {
                        Logger.shared.error("Failed to read cached object from disk for key \(key): \(error)")
                    }
                } else {
                    // Remove expired file
                    try? fileManager.removeItem(at: fileURL)
                    removeExpirationMetadata(key: key)
                }
            }

            return nil
        }
    }

    func removeObject(forKey key: String) {
        queue.async(flags: .barrier) {
            // Remove from memory cache
            self.memoryCache.removeObject(forKey: key as NSString)

            // Remove from disk
            let fileURL = self.cacheFileURL(for: key)
            try? self.fileManager.removeItem(at: fileURL)

            // Remove expiration metadata
            self.removeExpirationMetadata(key: key)

            Logger.shared.debug("Removed cached object for key: \(key)")
        }
    }

    func clearCache() {
        queue.async(flags: .barrier) {
            // Clear memory cache
            self.memoryCache.removeAllObjects()

            // Clear disk cache
            do {
                let files = try self.fileManager.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: nil)
                for file in files {
                    try self.fileManager.removeItem(at: file)
                }
            } catch {
                Logger.shared.error("Failed to clear cache: \(error)")
            }

            // Clear expiration metadata
            UserDefaults.standard.removeObject(forKey: "CacheExpirationMetadata")

            Logger.shared.info("Cache cleared")
        }
    }

    func clearExpiredCache() {
        queue.async(flags: .barrier) {
            let metadata = self.getExpirationMetadata()
            let now = Date()
            var expiredKeys: [String] = []

            for (key, expiration) in metadata {
                if expiration < now {
                    expiredKeys.append(key)

                    // Remove from memory cache
                    self.memoryCache.removeObject(forKey: key as NSString)

                    // Remove from disk
                    let fileURL = self.cacheFileURL(for: key)
                    try? self.fileManager.removeItem(at: fileURL)
                }
            }

            // Update metadata
            if !expiredKeys.isEmpty {
                var updatedMetadata = metadata
                for key in expiredKeys {
                    updatedMetadata.removeValue(forKey: key)
                }
                self.saveExpirationMetadata(updatedMetadata)

                Logger.shared.info("Cleared \(expiredKeys.count) expired cache entries")
            }
        }
    }

    func getCacheSize() -> Int64 {
        return queue.sync {
            var totalSize: Int64 = 0

            do {
                let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
                for file in files {
                    let attributes = try file.resourceValues(forKeys: [.fileSizeKey])
                    totalSize += Int64(attributes.fileSize ?? 0)
                }
            } catch {
                Logger.shared.error("Failed to calculate cache size: \(error)")
            }

            return totalSize
        }
    }

    // MARK: - Private Methods

    private func cacheFileURL(for key: String) -> URL {
        let sanitizedKey = key.replacingOccurrences(of: "/", with: "_")
        return cacheDirectory.appendingPathComponent("\(sanitizedKey).cache")
    }

    private func isExpired(key: String) -> Bool {
        guard let expiration = getExpiration(key: key) else { return false }
        return expiration < Date()
    }

    private func getExpiration(key: String) -> Date? {
        let metadata = getExpirationMetadata()
        return metadata[key]
    }

    private func storeExpirationMetadata(key: String, expiration: Date) {
        var metadata = getExpirationMetadata()
        metadata[key] = expiration
        saveExpirationMetadata(metadata)
    }

    private func removeExpirationMetadata(key: String) {
        var metadata = getExpirationMetadata()
        metadata.removeValue(forKey: key)
        saveExpirationMetadata(metadata)
    }

    private func getExpirationMetadata() -> [String: Date] {
        return UserDefaults.standard.object(forKey: "CacheExpirationMetadata") as? [String: Date] ?? [:]
    }

    private func saveExpirationMetadata(_ metadata: [String: Date]) {
        UserDefaults.standard.set(metadata, forKey: "CacheExpirationMetadata")
    }

    private func setupExpirationTimer() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            self.clearExpiredCache()
        }
    }
}

// MARK: - Supporting Types

private class CacheEntry: NSObject {
    let data: Data
    let expiration: Date

    init(data: Data, expiration: Date) {
        self.data = data
        self.expiration = expiration
    }

    var isExpired: Bool {
        return expiration < Date()
    }
}

enum CacheExpiration {
    case minutes(Int)
    case hours(Int)
    case days(Int)
    case never

    var date: Date {
        switch self {
        case .minutes(let minutes):
            return Date().addingTimeInterval(TimeInterval(minutes * 60))
        case .hours(let hours):
            return Date().addingTimeInterval(TimeInterval(hours * 3600))
        case .days(let days):
            return Date().addingTimeInterval(TimeInterval(days * 86400))
        case .never:
            return Date.distantFuture
        }
    }
}