import Foundation
import AppKit

class AppLogger {
    static let shared = AppLogger()

    private let fileManager = FileManager.default
    private let logsURL: URL
    private var logFileURL: URL
    private var lineCount = 0
    private let maxLinesPerFile = 1000

    init() {
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        logsURL = appSupportURL.appendingPathComponent("ScreenShot/Logs", isDirectory: true)
        try? fileManager.createDirectory(at: logsURL, withIntermediateDirectories: true)

        logFileURL = Self.newLogFileURL(in: logsURL)
        write("=== Jyazo Started ===")
        write("Time: \(Date())")
        write("Bundle: arkaprime.Jyazo\n")
    }

    func log(_ message: String) {
        print(message)
        write(message)
    }

    private func write(_ message: String) {
        if lineCount >= maxLinesPerFile {
            rotate()
        }

        let timestamped = "[\(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium))] \(message)\n"
        guard let data = timestamped.data(using: .utf8) else { return }

        if fileManager.fileExists(atPath: logFileURL.path) {
            if let fh = FileHandle(forWritingAtPath: logFileURL.path) {
                fh.seekToEndOfFile()
                fh.write(data)
                fh.closeFile()
            }
        } else {
            try? data.write(to: logFileURL)
        }
        lineCount += 1
    }

    private func rotate() {
        logFileURL = Self.newLogFileURL(in: logsURL)
        lineCount = 0
        // Write a continuation header so each part is self-contained
        let header = "=== Log continued ===\nTime: \(Date())\n"
        try? header.data(using: .utf8)?.write(to: logFileURL)
    }

    private static func newLogFileURL(in directory: URL) -> URL {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return directory.appendingPathComponent("Jyazo_\(fmt.string(from: Date())).log")
    }

    func getLogFilePath() -> String { logFileURL.path }

    func openLogFile() {
        NSWorkspace.shared.open(logFileURL)
    }

    func showLogDirectory() {
        NSWorkspace.shared.open(logsURL)
    }

    func getLogFileCount() -> Int {
        (try? fileManager.contentsOfDirectory(atPath: logsURL.path))?.filter { $0.hasSuffix(".log") }.count ?? 0
    }
}
