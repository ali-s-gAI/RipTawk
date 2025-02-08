import SwiftUI

extension Font {
    // System fonts with custom styling
    static func appTitle() -> Font {
        .custom("'-Mono-Bold", size: 34)
    }
    
    static func appHeadline() -> Font {
        .custom("'-Mono-Bold", size: 20)
    }
    
    static func appBody() -> Font {
        .custom("'-Mono-Regular", size: 17)
    }
    
    static func appCaption() -> Font {
        .custom("'-Mono-Regular", size: 12)
    }

} 