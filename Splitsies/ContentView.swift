import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }

            // placeholder tabs if you already had them
            FriendsView()
                .tabItem { Label("Friends", systemImage: "person.3") }

            AccountView()
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
        .tint(Color(red: 0.90, green: 0.0, blue: 0.0)) // #E60000-ish
    }
}

struct FriendsView: View {
    var body: some View {
        NavigationStack {
            Text("Friends coming soon")
                .navigationTitle("Friends")
        }
    }
}

struct AccountView: View {
    var body: some View {
        NavigationStack {
            Text("Account coming soon")
                .navigationTitle("Account")
        }
    }
}
