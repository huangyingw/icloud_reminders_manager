import Foundation
import EventKit

class MockSource: EKSource {
    private var _title: String = ""
    private var _sourceType: EKSourceType = .local
    
    override var title: String {
        get { return _title }
    }
    
    override var sourceType: EKSourceType {
        get { return _sourceType }
    }
    
    func setTitle(_ title: String) {
        _title = title
    }
    
    func setSourceType(_ sourceType: EKSourceType) {
        _sourceType = sourceType
    }
} 