import Foundation
import EventKit

class MockSource: EKSource {
    private let mockSourceType: EKSourceType
    
    init(sourceType: EKSourceType) {
        self.mockSourceType = sourceType
        super.init()
    }
    
    override var sourceType: EKSourceType {
        return mockSourceType
    }
    
    override var title: String {
        return "Mock Source"
    }
} 