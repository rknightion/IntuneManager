import Foundation
import os.log

final class Logger: @unchecked Sendable {
    static let shared = Logger()

    private let subsystem = Bundle.main.bundleIdentifier ?? "com.intunemanager"
    private var loggers: [LogCategory: OSLog] = [:]
    private let dateFormatter: DateFormatter

    enum LogCategory: String {
        case app = "App"
        case auth = "Authentication"
        case network = "Network"
        case data = "Data"
        case ui = "UI"
        case sync = "Sync"
        case error = "Error"
    }

    enum LogLevel {
        case debug
        case info
        case warning
        case error
        case critical

        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }

        var prefix: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🔥"
            }
        }
    }

    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        // Initialize loggers for each category
        for category in LogCategory.allCases {
            loggers[category] = OSLog(subsystem: subsystem, category: category.rawValue)
        }
    }

    func configure() {
        #if DEBUG
        // Enable verbose logging in debug builds
        UserDefaults.standard.set(true, forKey: "LOGGING_ENABLED")
        #endif
    }

    // MARK: - Logging Methods

    func debug(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }

    func info(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }

    func warning(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }

    func error(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }

    func critical(_ message: String, category: LogCategory = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .critical, category: category, file: file, function: function, line: line)
    }

    // MARK: - Network Logging

    func logNetworkRequest(_ request: URLRequest) {
        guard UserDefaults.standard.bool(forKey: "LOGGING_ENABLED") else { return }

        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "Unknown URL"

        var logMessage = "\(method) \(url)"

        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            // Redact sensitive headers
            let sanitizedHeaders = headers.mapValues { value in
                value.contains("Bearer") ? "[REDACTED]" : value
            }
            logMessage += "\nHeaders: \(sanitizedHeaders)"
        }

        #if DEBUG
        if let body = request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            logMessage += "\nBody: \(bodyString)"
        }
        #endif

        info(logMessage, category: .network)
    }

    func logNetworkResponse(_ response: URLResponse?, data: Data?, error: Error?) {
        guard UserDefaults.standard.bool(forKey: "LOGGING_ENABLED") else { return }

        if let httpResponse = response as? HTTPURLResponse {
            let statusCode = httpResponse.statusCode
            let url = httpResponse.url?.absoluteString ?? "Unknown URL"

            var logMessage = "Response: \(statusCode) from \(url)"

            #if DEBUG
            if let data = data,
               let responseString = String(data: data, encoding: .utf8) {
                // Truncate long responses
                let maxLength = 1000
                if responseString.count > maxLength {
                    logMessage += "\nData: \(responseString.prefix(maxLength))... [truncated]"
                } else {
                    logMessage += "\nData: \(responseString)"
                }
            }
            #endif

            if statusCode >= 400 {
                self.error(logMessage, category: .network)
            } else {
                info(logMessage, category: .network)
            }
        }

        if let error = error {
            self.error("Network error: \(error.localizedDescription)", category: .network)
        }
    }

    // MARK: - Private Methods

    private func log(_ message: String, level: LogLevel, category: LogCategory, file: String, function: String, line: Int) {
        guard UserDefaults.standard.bool(forKey: "LOGGING_ENABLED") else { return }

        let filename = URL(fileURLWithPath: file).lastPathComponent
        let timestamp = dateFormatter.string(from: Date())

        let formattedMessage = "\(level.prefix) [\(timestamp)] [\(category.rawValue)] \(filename):\(line) - \(function) - \(message)"

        // Log to console in debug builds
        #if DEBUG
        print(formattedMessage)
        #endif

        // Log to system log
        if let logger = loggers[category] {
            os_log("%{public}@", log: logger, type: level.osLogType, formattedMessage)
        }

        // Store critical errors for crash reporting
        if level == .critical {
            storeCriticalError(message: formattedMessage)
        }
    }

    private func storeCriticalError(message: String) {
        var errors = UserDefaults.standard.stringArray(forKey: "CRITICAL_ERRORS") ?? []
        errors.append(message)

        // Keep only last 50 critical errors
        if errors.count > 50 {
            errors = Array(errors.suffix(50))
        }

        UserDefaults.standard.set(errors, forKey: "CRITICAL_ERRORS")
    }

    // MARK: - Crash Reporting

    func getCriticalErrors() -> [String] {
        return UserDefaults.standard.stringArray(forKey: "CRITICAL_ERRORS") ?? []
    }

    func clearCriticalErrors() {
        UserDefaults.standard.removeObject(forKey: "CRITICAL_ERRORS")
    }
}

// MARK: - LogCategory Extension

extension Logger.LogCategory: CaseIterable {}
