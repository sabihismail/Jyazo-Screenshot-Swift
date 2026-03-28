import Foundation
import AppKit

class AppLogger {
    static let shared = AppLogger()

    private let fileManager = FileManager.default
    private var logFileURL: URL

    init() {
        // Create logs directory in Application Support
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let logsURL = appSupportURL.appendingPathComponent("ScreenShot/Logs", isDirectory: true)

        // Create directory if needed
        try? fileManager.createDirectory(at: logsURL, withIntermediateDirectories: true)

        // Create log file with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        logFileURL = logsURL.appendingPathComponent("ScreenShot_\(timestamp).log")

        // Write header
        write("=== ScreenShot App Started ===")
        write("Time: \(Date())")
        write("Bundle: arkaprime.ScreenShot\n")
    }

    func log(_ message: String) {
        // Print to console
        print(message)
        // Write to file
        write(message)
    }

    private func write(_ message: String) {
        let timestamped = "[\(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium))] \(message)\n"

        if let data = timestamped.data(using: .utf8) {
            if fileManager.fileExists(atPath: logFileURL.path) {
                // Append to existing file
                if let fileHandle = FileHandle(forWritingAtPath: logFileURL.path) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                // Create new file
                try? data.write(to: logFileURL)
            }
        }
    }

    func getLogFilePath() -> String {
        logFileURL.path
    }

    func openLogFile() {
        NSWorkspace.shared.open(logFileURL)
    }

    func showLogDirectory() {
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let logsURL = appSupportURL.appendingPathComponent("ScreenShot/Logs", isDirectory: true)
        NSWorkspace.shared.open(logsURL)
    }

    func getLogFileCount() -> Int {
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let logsURL = appSupportURL.appendingPathComponent("ScreenShot/Logs", isDirectory: true)

        do {
            let files = try fileManager.contentsOfDirectory(atPath: logsURL.path)
            return files.filter { $0.hasSuffix(".log") }.count
        } catch {
            return 0
        }
    }
}
