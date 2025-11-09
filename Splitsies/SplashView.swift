import SwiftUI

struct SplashView: View {
    @State private var showContent = false
    @State private var animateSplit = false

    private let appName: String = "splitsies"

    var body: some View {
        ZStack {
            // Destination (Home)
            ContentView()
                .opacity(showContent ? 1 : 0)

            // Splash overlay: stays until split animation finishes
            if !showContent || animateSplit {
                GeometryReader { geo in
                    let size = geo.size

                    ZStack {
                        // TOP HALF
                        Image("back")
                            .resizable()
                            .scaledToFill()
                            .frame(width: size.width, height: size.height)
                            .ignoresSafeArea()
                            .mask(
                                VStack(spacing: 0) {
                                    Rectangle()
                                        .frame(height: size.height / 2)
                                    Spacer()
                                }
                            )
                            .offset(y: animateSplit ? -size.height : 0)

                        // BOTTOM HALF
                        Image("back")
                            .resizable()
                            .scaledToFill()
                            .frame(width: size.width, height: size.height)
                            .ignoresSafeArea()
                            .mask(
                                VStack(spacing: 0) {
                                    Spacer()
                                    Rectangle()
                                        .frame(height: size.height / 2)
                                }
                            )
                            .offset(y: animateSplit ? size.height : 0)
                    }
                    .ignoresSafeArea()
                }
                .transition(.identity) // avoid default fade
            }
        }
        .ignoresSafeArea()
        .task {
            // 1) Wait with full splash
            try? await Task.sleep(nanoseconds: 1_500_000_000)

            // 2) Start split + fade in ContentView
            withAnimation(.easeInOut(duration: 0.75)) {
                animateSplit = true
                showContent = true
            }

            // 3) After split ends, remove splash halves
            try? await Task.sleep(nanoseconds: 450_000_000)
            animateSplit = false
        }
    }
}

#Preview {
    SplashView()
}
