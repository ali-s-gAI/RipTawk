import SwiftUI

struct SplashView: View {
    @State private var isAnimating = false
    @State private var opacity = 0.0
    @State private var scale = 0.8
    @State private var rotation = 0.0
    
    private let brandGreen = Color.brandPrimary
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack {
                Image("SplashIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(brandGreen, lineWidth: 3)
                            .scaleEffect(isAnimating ? 1.2 : 1.0)
                            .opacity(isAnimating ? 0.0 : 1.0)
                    )
                    .opacity(opacity)
                    .scaleEffect(scale)
                    .rotationEffect(.degrees(rotation))
            }
        }
        .onAppear {
            print(" [SPLASH] View appeared - starting animations")
            
            withAnimation(.easeOut(duration: 0.8)) {
                opacity = 1.0
                scale = 1.0
            }
            
            withAnimation(
                .easeInOut(duration: 1.2)
                .repeatCount(1, autoreverses: false)
            ) {
                rotation = 360
            }
            
            withAnimation(
                .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    SplashView()
} 