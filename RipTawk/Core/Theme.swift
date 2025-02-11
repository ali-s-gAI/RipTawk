import SwiftUI

extension Color {
    static let brandPrimary = Color(hex: "00FF9D")  // Bright neon green
    static let brandSecondary = Color(hex: "00FF9D").opacity(0.8)
    static let brandBackground = Color(hex: "00FF9D").opacity(0.1)
    
    // Semantic colors for specific uses
    static let brandAction = Color.brandPrimary
    static let brandHighlight = Color.brandSecondary
    static let brandSurface = Color.brandBackground
    
    // Tab bar specific colors
    static let tabBarSelected = Color.brandPrimary
    static let tabBarGlow = Color.brandPrimary.opacity(0.6)
    static let tabBarUnselected = Color.white.opacity(0.35)
    
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

struct CustomTabBarModifier: ViewModifier {
    let isSelected: Bool
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(isSelected ? .tabBarSelected : .tabBarUnselected)
            .scaleEffect(isSelected ? 1.25 : 1.0)
            // Multiple layered shadows for stronger glow
            .shadow(color: isSelected ? .tabBarGlow : .clear, radius: 12, x: 0, y: 0)
            .shadow(color: isSelected ? .tabBarGlow : .clear, radius: 8, x: 0, y: 0)
            .shadow(color: isSelected ? .tabBarGlow : .clear, radius: 4, x: 0, y: 0)
            .overlay(
                VStack(spacing: 4) {
                    Spacer()
                    Rectangle()
                        .fill(Color.tabBarSelected)
                        .frame(width: 35, height: 3)
                        .cornerRadius(1.5)
                        // Multiple shadows for the indicator bar too
                        .shadow(color: .tabBarGlow, radius: 8)
                        .shadow(color: .tabBarGlow, radius: 4)
                }
                .opacity(isSelected ? 1 : 0)
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

extension View {
    func customTabBarItem(isSelected: Bool) -> some View {
        self.modifier(CustomTabBarModifier(isSelected: isSelected))
    }
} 