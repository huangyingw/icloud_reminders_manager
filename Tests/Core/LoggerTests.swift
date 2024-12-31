import XCTest
import Foundation
import Logging
@testable import Core

final class LoggerTests: XCTestCase {
    var logger: Core.Logger!
    
    override func setUp() {
        super.setUp()
        logger = Core.Logger()
    }
    
    override func tearDown() {
        logger = nil
        super.tearDown()
    }
    
    func testLogInfo() {
        // 测试 info 级别的日志
        logger.info("测试信息")
    }
    
    func testLogWarning() {
        // 测试 warning 级别的日志
        logger.warning("测试警告")
    }
    
    func testLogError() {
        // 测试 error 级别的日志
        logger.error("测试错误")
    }
} 