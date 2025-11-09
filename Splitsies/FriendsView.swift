// FriendsView.swift
// Splitsies
//
// Uses shared Friend + demoFriends from HomeView.swift

import SwiftUI

struct FriendsView: View {
    @State private var showAddFriendSheet = false

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Your Group")) {
                    ForEach(demoFriends) { friend in
                        NavigationLink {
                            FriendDetailView(friend: friend)
                        } label: {
                            FriendRow(friend: friend)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddFriendSheet = true
                    } label: {
                        Label("Add Friend", systemImage: "plus")
                            .labelStyle(.iconOnly)
                    }
                    .tint(Color(red: 0.90, green: 0.0, blue: 0.0))
                }
            }
            .sheet(isPresented: $showAddFriendSheet) {
                AddFriendSheet(isPresented: $showAddFriendSheet)
            }
        }
    }
}

// MARK: - Row

struct FriendRow: View {
    let friend: Friend

    var body: some View {
        HStack(spacing: 12) {
            // Simple avatar with initial
            ZStack {
                Circle()
                    .fill(Color(red: 0.90, green: 0.0, blue: 0.0).opacity(0.12))
                    .frame(width: 40, height: 40)

                Text(String(friend.name.prefix(1)))
                    .font(.headline)
                    .foregroundColor(Color(red: 0.90, green: 0.0, blue: 0.0))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.name)
                    .font(.headline)
                Text(friend.handle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detail

struct FriendDetailView: View {
    let friend: Friend

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 40)

            // Avatar
            ZStack {
                Circle()
                    .fill(Color(red: 0.90, green: 0.0, blue: 0.0).opacity(0.12))
                    .frame(width: 80, height: 80)

                Text(String(friend.name.prefix(1)))
                    .font(.largeTitle.bold())
                    .foregroundColor(Color(red: 0.90, green: 0.0, blue: 0.0))
            }

            Text(friend.name)
                .font(.title2.bold())

            Text(friend.handle)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("This friend can be assigned to receipt items in the split view. When you tap **Send Money Request** from a receipt, they’ll be included based on how you’ve assigned items.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding()
        .navigationTitle("Friend")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Add Friend Sheet

struct AddFriendSheet: View {
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var handle = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Friend Info")) {
                    TextField("Name", text: $name)
                    TextField("Handle (e.g. @aria)", text: $handle)
                }
            }
            .navigationTitle("Add Friend")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        // For now just dismiss — future hook: append to persistent list
                        isPresented = false
                    }
                    .disabled(name.isEmpty || handle.isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    FriendsView()
}
