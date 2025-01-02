import Foundation
import Logging

public class FileLogger {
    private let logger: Logging.Logger
    private let fileHandle: FileHandle?
    private let logFilePath: String
    
    public init(label: String) {
        var logger = Logging.Logger(label: label)
        logger.logLevel = .info
        self.logger = logger
        
        // 创建日志目录
        let fileManager = FileManager.default
        let currentDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let logDirectory = currentDirectory.appendingPathComponent("logs")
        
        // 创建日志文件
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        let logFileName = "\(dateString).log"
        let logFileURL = logDirectory.appendingPathComponent(logFileName)
        self.logFilePath = logFileURL.path
        
        do {
            try fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
            
            if !fileManager.fileExists(atPath: logFileURL.path) {
                fileManager.createFile(atPath: logFileURL.path, contents: nil)
            }
            
            self.fileHandle = try FileHandle(forWritingTo: logFileURL)
            self.fileHandle?.seekToEndOfFile()
        } catch {
            print("无法创建日志文件：\(error)")
            self.fileHandle = nil
        }
    }
    
    deinit {
        fileHandle?.closeFile()
    }
    
    public func getLogFilePath() -> String {
        return logFilePath
    }
    
    private func writeToFile(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "\(timestamp) \(message)\n"
        if let data = logMessage.data(using: .utf8) {
            fileHandle?.write(data)
        }
    }
    
    public func trace(_ message: String) {
        logger.trace("\(message)")
        writeToFile("[TRACE] \(message)")
    }
    
    public func debug(_ message: String) {
        logger.debug("\(message)")
        writeToFile("[DEBUG] \(message)")
    }
    
    public func info(_ message: String) {
        logger.info("\(message)")
        writeToFile("[INFO] \(message)")
    }
    
    public func notice(_ message: String) {
        logger.notice("\(message)")
        writeToFile("[NOTICE] \(message)")
    }
    
    public func warning(_ message: String) {
        logger.warning("\(message)")
        writeToFile("[WARNING] \(message)")
    }
    
    public func error(_ message: String) {
        logger.error("\(message)")
        writeToFile("[ERROR] \(message)")
    }
    
    public func critical(_ message: String) {
        logger.critical("\(message)")
        writeToFile("[CRITICAL] \(message)")
    }
} 