
import Cocoa

class IPNumberFormatter: NumberFormatter {
    
    override func isPartialStringValid(_ partialString: String, newEditingString newString: AutoreleasingUnsafeMutablePointer<NSString?>?, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        
        if partialString.isEmpty {
            return true
        }
        
        if partialString.count > 5 { //"99.99" = 5 chars
            return false
        }
        
        // Actual check
        if let doubleVal = Double(partialString) {
            return doubleVal >= 0 && doubleVal <= 100
        } else {
            return false
        }
    }
}
