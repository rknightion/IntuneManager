import Foundation

/// Manages rate limiting for Microsoft Graph API requests
/// Based on Intune service limits: 100 requests per 20 seconds for POST/PUT/DELETE/PATCH, 1000 per 20 seconds for all requests
actor RateLimiter {
    static let shared = RateLimiter()

    // Intune limits per app per tenant
    private let maxWriteRequestsPer20Seconds = 100
    private let maxTotalRequestsPer20Seconds = 1000
    private let windowDuration: TimeInterval = 20.0

    // Request tracking
    private var requestTimestamps: [Date] = []
    private var writeRequestTimestamps: [Date] = []

    // Retry configuration
    private let maxRetries = 3
    private let baseRetryDelay: TimeInterval = 1.0
    private let maxRetryDelay: TimeInterval = 32.0

    // Backoff tracking
    private var lastRateLimitTime: Date?
    private var consecutiveRateLimits = 0

    private init() {}

    // MARK: - Public Methods

    /// Check if a request can be made without exceeding rate limits
    func canMakeRequest(isWriteOperation: Bool) async -> Bool {
        cleanupOldTimestamps()

        let totalRequests = requestTimestamps.count
        let writeRequests = writeRequestTimestamps.count

        // Check total request limit
        if totalRequests >= maxTotalRequestsPer20Seconds {
            await MainActor.run {
            Logger.shared.debug("Approaching total rate limit: \(totalRequests)/\(maxTotalRequestsPer20Seconds) requests in window", category: .network)
        }
            return false
        }

        // Check write request limit if applicable
        if isWriteOperation && writeRequests >= maxWriteRequestsPer20Seconds {
            await MainActor.run {
            Logger.shared.debug("Approaching write rate limit: \(writeRequests)/\(maxWriteRequestsPer20Seconds) write requests in window", category: .network)
        }
            return false
        }

        return true
    }

    /// Record that a request was made
    func recordRequest(isWriteOperation: Bool) {
        let now = Date()
        requestTimestamps.append(now)

        if isWriteOperation {
            writeRequestTimestamps.append(now)
        }

        // Keep arrays from growing too large
        if requestTimestamps.count > maxTotalRequestsPer20Seconds * 2 {
            cleanupOldTimestamps()
        }
    }

    /// Record that we hit a rate limit
    func recordRateLimit() async {
        lastRateLimitTime = Date()
        consecutiveRateLimits += 1
        let limits = consecutiveRateLimits
        await MainActor.run {
            Logger.shared.warning("Rate limit hit. Consecutive rate limits: \(limits)", category: .network)
        }
    }

    /// Reset rate limit tracking after successful request
    func resetRateLimitTracking() async {
        if consecutiveRateLimits > 0 {
            await MainActor.run {
                Logger.shared.info("Rate limit tracking reset after successful request", category: .network)
            }
            consecutiveRateLimits = 0
        }
    }

    /// Calculate delay before next request based on current state
    func calculateDelay(isWriteOperation: Bool) async -> TimeInterval {
        cleanupOldTimestamps()

        // If we recently hit a rate limit, add extra delay
        if let lastLimit = lastRateLimitTime,
           Date().timeIntervalSince(lastLimit) < 60 {
            let extraDelay = Double(consecutiveRateLimits) * 2.0
            return min(extraDelay, 10.0)
        }

        // Calculate delay based on current request rate
        let totalRequests = requestTimestamps.count
        let writeRequests = writeRequestTimestamps.count

        // If we're getting close to limits, add preventive delay
        if isWriteOperation {
            let writeUtilization = Double(writeRequests) / Double(maxWriteRequestsPer20Seconds)
            if writeUtilization > 0.8 {
                // 80% utilization - start slowing down
                return 0.5 * (writeUtilization - 0.8) * 10
            }
        }

        let totalUtilization = Double(totalRequests) / Double(maxTotalRequestsPer20Seconds)
        if totalUtilization > 0.8 {
            // 80% utilization - start slowing down
            return 0.5 * (totalUtilization - 0.8) * 10
        }

        return 0
    }

    /// Calculate exponential backoff delay for retries
    func calculateRetryDelay(attemptNumber: Int, retryAfterHeader: String?) async -> TimeInterval {
        // If we have a Retry-After header, use it
        if let retryAfter = retryAfterHeader,
           let retryDelay = TimeInterval(retryAfter) {
            await MainActor.run {
                Logger.shared.info("Using Retry-After header value: \(retryDelay) seconds", category: .network)
            }
            return retryDelay
        }

        // Otherwise, use exponential backoff
        let exponentialDelay = baseRetryDelay * pow(2.0, Double(attemptNumber - 1))
        let jitteredDelay = exponentialDelay * (0.8 + Double.random(in: 0...0.4))
        let finalDelay = min(jitteredDelay, maxRetryDelay)

        await MainActor.run {
            Logger.shared.info("Calculated retry delay: \(finalDelay) seconds (attempt \(attemptNumber))", category: .network)
        }
        return finalDelay
    }

    /// Check if we should retry a request
    func shouldRetry(attemptNumber: Int, error: Error) async -> Bool {
        guard attemptNumber <= maxRetries else {
            let max = maxRetries
            await MainActor.run {
                Logger.shared.warning("Max retries (\(max)) exceeded", category: .network)
            }
            return false
        }

        // Check if error is retryable
        if let graphError = error as? GraphAPIError {
            switch graphError {
            case .rateLimited:
                return true
            case .networkError, .invalidResponse:
                return true  // Network errors might be transient
            case .serverError(_, let code) where code.starts(with: "5"):
                return true  // 5xx errors are often transient
            default:
                return false
            }
        }

        return false
    }

    // MARK: - Private Methods

    private func cleanupOldTimestamps() {
        let cutoffTime = Date().addingTimeInterval(-windowDuration)

        requestTimestamps.removeAll { $0 < cutoffTime }
        writeRequestTimestamps.removeAll { $0 < cutoffTime }
    }

    /// Get current rate limit status for debugging
    func getRateLimitStatus() -> (total: Int, write: Int, maxTotal: Int, maxWrite: Int) {
        cleanupOldTimestamps()
        return (
            total: requestTimestamps.count,
            write: writeRequestTimestamps.count,
            maxTotal: maxTotalRequestsPer20Seconds,
            maxWrite: maxWriteRequestsPer20Seconds
        )
    }
}

// MARK: - Batch Request Rate Limiting

extension RateLimiter {
    /// Calculate optimal batch size based on current rate limits
    func calculateOptimalBatchSize() async -> Int {
        cleanupOldTimestamps()

        let remainingRequests = maxTotalRequestsPer20Seconds - requestTimestamps.count
        let remainingWriteRequests = maxWriteRequestsPer20Seconds - writeRequestTimestamps.count

        // Use the more restrictive limit
        let availableCapacity = min(remainingRequests, remainingWriteRequests)

        // Microsoft Graph batch requests support up to 20 requests per batch
        let maxBatchSize = 20

        // Leave some headroom to avoid hitting limits
        let safeCapacity = Int(Double(availableCapacity) * 0.8)

        return max(1, min(safeCapacity, maxBatchSize))
    }

    /// Split requests into rate-limited batches
    func splitIntoBatches<T>(_ items: [T], isWriteOperation: Bool) async -> [[T]] {
        let batchSize = await calculateOptimalBatchSize()
        var batches: [[T]] = []

        for i in stride(from: 0, to: items.count, by: batchSize) {
            let endIndex = min(i + batchSize, items.count)
            let batch = Array(items[i..<endIndex])
            batches.append(batch)
        }

        let itemCount = items.count
        let batchCount = batches.count
        await MainActor.run {
            Logger.shared.info("Split \(itemCount) items into \(batchCount) batches of size \(batchSize)", category: .network)
        }
        return batches
    }
}