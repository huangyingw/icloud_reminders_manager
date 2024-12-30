import XCTest
import Foundation
@testable import App

final class LoggerTests: XCTestCase {
    var logger: Logger!
    var testLogFile: String!
    
    override func setUp() {
        super.setUp()
        testLogFile = "test_\(UUID().uuidString).log"
        logger = Logger(filename: testLogFile)
    }
    
    override func tearDown() {
        // 清理测试日志文件
        if let testLogFile = testLogFile {
            try? FileManager.default.removeItem(atPath: "logs/\(testLogFile)")
        }
        logger = nil
        testLogFile = nil
        super.tearDown()
    }
    
    func testLogFileCreation() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: "logs/\(testLogFile!)"))
    }
    
    func testLogWriting() throws {
        let testMessage = "Test log message"
        logger.log(testMessage)
        
        // 读取日志文件内容
        let logContent = try String(contentsOfFile: "logs/\(testLogFile!)", encoding: .utf8)
        XCTAssertTrue(logContent.contains(testMessage))
    }
    
    func testLogFormat() throws {
        let testMessage = "Test log message"
        logger.log(testMessage)
        
        // 读取日志文件内容
        let logContent = try String(contentsOfFile: "logs/\(testLogFile!)", encoding: .utf8)
        
        // 验证日志格式：[yyyy-MM-dd HH:mm:ss] message
        let regex = try NSRegularExpression(pattern: #"^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] Test log message\n$"#)
        let range = NSRange(location: 0, length: logContent.utf16.count)
        let matches = regex.matches(in: logContent, range: range)
        
        XCTAssertEqual(matches.count, 1)
    }
} 