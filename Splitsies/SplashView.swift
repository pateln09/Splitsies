import SwiftUI

struct SplashView: View {
    @State private var isActive = false
    private let appName: String = "splitsies"

    var body: some View {
        if isActive {
            ContentView()
        } else {
            ZStack {
                // Background image with brightness and blur adjustment
                Image("receipt_background")
                    .resizable()
                    .scaledToFill()
                    .brightness(0.25) // make it brighter (positive = brighter, negative = darker)
                    .overlay(Color.white.opacity(0.1)) // subtle bright overlay
                    .ignoresSafeArea()

                // Centered logo text
                VStack {
                    Spacer()
                    Text(appName)
                        .font(.custom("OCR-A", size: 70))
                        .fontWeight(.bold)
                        .kerning(0.5)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                withAnimation(.easeInOut(duration: 0.3)) {
                    isActive = true
                }
            }
        }
    }
}

#Preview {
    SplashView()
}
