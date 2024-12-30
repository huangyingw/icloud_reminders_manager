import Foundation

public class Logger {
    private let dateFormatter: DateFormatter
    
    public init() {
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    }
    
    public func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] \(message)")
    }
} 