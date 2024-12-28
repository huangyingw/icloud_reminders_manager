import Foundation
import EventKit

class MockSource: EKSource {
    private let mockSourceType: EKSourceType
    
    init(sourceType: EKSourceType) {
        self.mockSourceType = sourceType
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var sourceType: EKSourceType {
        return mockSourceType
    }
    
    override var title: String {
        return "Mock Source"
    }
} 