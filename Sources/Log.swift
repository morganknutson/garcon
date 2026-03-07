import Foundation

enum Log {
    private static let logDir: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Garcon", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let logFile: URL = logDir.appendingPathComponent("garcon.log")
    private static let maxLogSize: UInt64 = 2 * 1024 * 1024 // 2 MB
    private static let lock = NSLock()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func info(_ message: String) {
        write(level: "INFO", message)
    }

    static func error(_ message: String) {
        write(level: "ERROR", message)
    }

    static func debug(_ message: String) {
        write(level: "DEBUG", message)
    }

    /// Returns the path to the current log file (useful for sharing diagnostics).
    static var logFilePath: String {
        logFile.path
    }

    private static func write(level: String, _ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] [\(level)] \(message)\n"

        lock.lock()
        defer { lock.unlock() }

        rotateIfNeeded()

        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let handle = try? FileHandle(forWritingTo: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logFile, options: .atomic)
            }
        }
    }

    private static func rotateIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: logFile.path),
              let size = attrs[.size] as? UInt64,
              size > maxLogSize
        else {
            return
        }

        let rotated = logDir.appendingPathComponent("garcon.log.1")
        try? FileManager.default.removeItem(at: rotated)
        try? FileManager.default.moveItem(at: logFile, to: rotated)
    }
}
