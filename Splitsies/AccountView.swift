// AccountView.swift
// Splitsies
//
// Simple user account/profile screen

import SwiftUI

struct AccountView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 40)

                // Profile avatar
                ZStack {
                    Circle()
                        .fill(Color(red: 0.90, green: 0.0, blue: 0.0).opacity(0.12))
                        .frame(width: 100, height: 100)

                    Text("A")
                        .font(.largeTitle.bold())
                        .foregroundColor(Color(red: 0.90, green: 0.0, blue: 0.0))
                }

                // Name & handle
                VStack(spacing: 4) {
                    Text("Aria Reynolds")
                        .font(.title2.weight(.semibold))
                    Text("@aria")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Divider()
                    .padding(.horizontal, 40)
                    .padding(.top, 8)

                // Basic info / options list
                List {
                    Section(header: Text("Account")) {
                        Label("Edit Profile", systemImage: "person.crop.circle.badge.plus")
                        Label("Payment Methods", systemImage: "creditcard")
                        Label("Notifications", systemImage: "bell.badge")
                    }

                    Section(header: Text("App Settings")) {
                        Label("Privacy & Security", systemImage: "lock.shield")
                        Label("Help & Support", systemImage: "questionmark.circle")
                    }

                    Section {
                        Button(role: .destructive) {
                            // sign out / reset logic placeholder
                        } label: {
                            HStack {
                                Spacer()
                                Text("Log Out")
                                Spacer()
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)

                Spacer()
            }
            .navigationTitle("Account")
        }
    }
}

// Preview
#Preview {
    AccountView()
}
//
//  AccountView.swift
//  Splitsies
//
//  Created by Neel Patel on 11/9/25.
//

