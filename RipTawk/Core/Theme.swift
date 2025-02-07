import SwiftUI

extension Color {
    static let brandPrimary = Color(hex: "08752A")
    static let brandSecondary = Color(hex: "08752A").opacity(0.8)
    static let brandBackground = Color(hex: "08752A").opacity(0.1)
    
    // Semantic colors for specific uses
    static let brandAction = Color.brandPrimary
    static let brandHighlight = Color.brandSecondary
    static let brandSurface = Color.brandBackground
    
    // Hex initializer implementation...
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Navigation bar appearance
extension View {
    func configureNavigationBar() -> some View {
        self.modifier(NavigationBarModifier())
    }
}

struct NavigationBarModifier: ViewModifier {
    init() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(Color.brandBackground)
        appearance.titleTextAttributes = [.foregroundColor: UIColor(Color.brandPrimary)]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color.brandPrimary)]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    func body(content: Content) -> some View {
        content
    }
} 