import SwiftUI
import SwiftData
import PhotosUI
import UIKit

// MARK: - Demo Friends

struct Friend: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let handle: String
}

let demoFriends: [Friend] = [
    Friend(name: "Aria", handle: "@aria"),
    Friend(name: "Eli", handle: "@eli"),
    Friend(name: "Sofia", handle: "@sofia"),
    Friend(name: "Noah", handle: "@noah")
]

// MARK: - Home View

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Receipt.receiptDate, order: .reverse) private var receipts: [Receipt]

    @State private var showCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    @State private var capturedImage: UIImage?
    @State private var isParsing = false
    @State private var parseError: String?

    // For Home "Send Money Request" button demo
    @State private var showHomeRequestAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {

                // Scan / Upload buttons
                HStack(spacing: 12) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Scan Receipt", systemImage: "camera.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 230/255, green: 0/255, blue: 0/255))
                            .cornerRadius(12)
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Upload Receipt", systemImage: "photo.fill.on.rectangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)

                // Parsing state
                if isParsing {
                    ProgressView("Parsing receipt...")
                        .padding(.horizontal)
                } else if let parseError {
                    Text(parseError)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.horizontal)
                }

                // Recent Activity header
                HStack {
                    Text("Recent Activity")
                        .font(.title3.weight(.semibold))
                    Spacer()
                }
                .padding(.horizontal)

                // Receipts list
                if receipts.isEmpty {
                    Spacer()
                    Text("No receipts yet.\nScan or upload to get started.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    List {
                        ForEach(receipts) { receipt in
                            NavigationLink {
                                ReceiptDetailView(receipt: receipt)
                            } label: {
                                ReceiptRowView(receipt: receipt)
                            }
                        }
                        .onDelete(perform: deleteReceipts)
                    }
                    .listStyle(.plain)
                }


            }
            .navigationTitle("Home")
        }
        .sheet(isPresented: $showCamera) {
            CameraScanSheet(image: $capturedImage)
        }
        // iOS 17+ onChange signature
        .onChange(of: capturedImage) { _, newImage in
            guard let image = newImage else { return }
            Task { await handleNewReceiptImage(image) }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let item = newItem else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await handleNewReceiptImage(image)
                }
            }
        }
        .alert("Send requests from receipt details", isPresented: $showHomeRequestAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Open a receipt to choose who owes what, then tap Send Money Request there.")
        }
    }

    // MARK: - Parsing & Persistence

    @MainActor
    private func handleNewReceiptImage(_ image: UIImage) async {
        isParsing = true
        parseError = nil

        do {
            let fileName = saveImageToDocuments(image)

            let parser = GeminiReceiptParser()
            let parsed = try await parser.parse(image: image)

            let receipt = parsed.toReceipt(imageFileName: fileName)
            modelContext.insert(receipt)
            try modelContext.save()
        } catch GeminiError.missingAPIKey {
            parseError = "Gemini API key not configured."
        } catch {
            parseError = "Couldn't parse that receipt. You can still enter it manually."
        }

        isParsing = false
    }

    private func saveImageToDocuments(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        let filename = UUID().uuidString + ".jpg"
        let url = documentsDirectory().appendingPathComponent(filename)
        do {
            try data.write(to: url)
            return filename
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }

    private func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func deleteReceipts(at offsets: IndexSet) {
        for index in offsets {
            let receipt = receipts[index]

            if let imageRef = receipt.imageRef {
                deleteImage(named: imageRef)
            }

            modelContext.delete(receipt)
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to delete receipts: \(error)")
        }
    }

    private func deleteImage(named: String) {
        let url = documentsDirectory().appendingPathComponent(named)
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Recent Activity Row

struct ReceiptRowView: View {
    let receipt: Receipt

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Store name
            Text(receipt.storeName ?? "Unknown store")
                .font(.headline)

            // Date · item count
            HStack(spacing: 6) {
                Text(purchaseDateText)
                Text("·")
                Text("\(receipt.items.count) \(receipt.items.count == 1 ? "item" : "items")")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)

            // Total
            HStack {
                if let total = receipt.total {
                    Text(String(format: "$%.2f", total))
                        .font(.subheadline.weight(.semibold))
                } else {
                    Text("Total --")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    private var purchaseDateText: String {
        if let date = receipt.receiptDate {
            return date.formatted(date: .abbreviated, time: .omitted)
        } else {
            return "Date unknown"
        }
    }
}

// MARK: - Detail View with Splitting + Inline Editing

struct ReceiptDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let receipt: Receipt

    @State private var showImage = false
    @State private var isEditing = false

    // item.id -> set of friends sharing that item
    // Empty or missing entry = split between all demoFriends evenly
    @State private var itemSplits: [AnyHashable: Set<Friend>] = [:]

    @State private var showRequestAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                // Top row: store name + View image button inline (if available)
                HStack(alignment: .firstTextBaseline) {
                    Text(receipt.storeName ?? "Receipt")
                        .font(.title2.weight(.semibold))

                    Spacer()

                    if receipt.imageRef != nil {
                        Button {
                            showImage = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("View receipt")
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.caption)
                            }
                            .font(.subheadline.weight(.semibold))
                        }
                    }
                }

                // Purchase date
                Text(purchaseDateDetailText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)

                // Items header
                Text("Items")
                    .font(.headline)
                    .padding(.top, 8)

                // Inline editable items with split controls
                ForEach(receipt.items) { item in
                    let key = AnyHashable(item.id)
                    let assignedFriends = itemSplits[key] ?? []

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            if isEditing {
                                // Editable item name
                                TextField(
                                    "Item",
                                    text: Binding(
                                        get: { item.name ?? "" },
                                        set: { item.name = $0 }
                                    )
                                )

                                Spacer()

                                // Editable price
                                TextField(
                                    "Price",
                                    text: Binding(
                                        get: {
                                            if let price = item.price {
                                                return String(format: "%.2f", price)
                                            } else {
                                                return ""
                                            }
                                        },
                                        set: { newValue in
                                            let filtered = newValue.filter { "0123456789.".contains($0) }
                                            item.price = Double(filtered)
                                        }
                                    )
                                )
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            } else {
                                // Read-only state
                                Text(item.name ?? "Unknown item")

                                Spacer()

                                if let price = item.price {
                                    Text(String(format: "$%.2f", price))
                                        .font(.subheadline)
                                } else {
                                    Text("--")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        // Split dropdown
                        Menu {
                            Button("Split evenly between all") {
                                itemSplits[key] = []
                            }

                            ForEach(demoFriends) { friend in
                                let isSelected = assignedFriends.contains(friend)
                                Button {
                                    toggleFriend(friend, for: key)
                                } label: {
                                    Label(friend.name,
                                          systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                                }
                            }
                        } label: {
                            Text(splitLabel(for: assignedFriends))
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Totals
                VStack(alignment: .leading, spacing: 4) {
                    Divider().padding(.top, 8)

                    totalRow(label: "Subtotal", value: receipt.subtotal)
                    totalRow(label: "Tax", value: receipt.tax)
                    totalRow(label: "Tip", value: receipt.tip)

                    if let d = receipt.discount, d != 0 {
                        totalRow(label: "Discount", value: -d)
                    }

                    Divider()

                    totalRow(label: "Total", value: receipt.total, bold: true)

                    // Soft check, no correction
                    let itemSum = receipt.items.compactMap { $0.price }.reduce(0, +)
                    if let subtotal = receipt.subtotal,
                       abs(itemSum - subtotal) > 0.01 {
                        Text("⚠️ Parsed item prices don’t match the subtotal exactly. Please verify.")
                            .font(.footnote)
                            .foregroundColor(.orange)
                            .padding(.top, 4)
                    }
                }
                .padding(.top, 8)

                // Split summary
                let owed = computeOwedTotals()
                if !owed.isEmpty {
                    Text("Split Summary")
                        .font(.headline)
                        .padding(.top, 12)

                    ForEach(demoFriends) { friend in
                        let amount = owed[friend] ?? 0
                        HStack {
                            Text(friend.name)
                            Spacer()
                            Text(String(format: "$%.2f", amount))
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.vertical, 2)
                    }
                }

                // Big Send Money Request button
                Button {
                    showRequestAlert = true
                } label: {
                    Text("Send Money Request")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 230/255, green: 0/255, blue: 0/255))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
                .padding(.top, 16)
            }
            .padding()
        }
        .navigationTitle("Receipt Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
                    if !isEditing {
                        try? modelContext.save()
                    }
                }
            }
        }
        .sheet(isPresented: $showImage) {
            ImageViewerSheet(imageRef: receipt.imageRef, isPresented: $showImage)
        }
        .alert("Requests ready to send", isPresented: $showRequestAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            let owed = computeOwedTotals()
            if owed.isEmpty {
                Text("Set item splits first to calculate who owes what.")
            } else {
                let lines = owed
                    .sorted { $0.key.name < $1.key.name }
                    .map { "\($0.key.name): $\(String(format: "%.2f", $0.value))" }
                    .joined(separator: "\n")
                Text("You can now send requests:\n\(lines)")
            }
        }
    }

    // MARK: - Helpers

    private var purchaseDateDetailText: String {
        if let date = receipt.receiptDate {
            return "Purchased on \(date.formatted(date: .long, time: .omitted))"
        } else {
            return "Purchase date not detected"
        }
    }

    private func totalRow(label: String, value: Double?, bold: Bool = false) -> some View {
        HStack {
            Text(label)
            Spacer()
            if let value = value {
                let text = Text(String(format: "$%.2f", value))
                bold ? text.fontWeight(.semibold) : text
            } else {
                Text("--")
                    .foregroundColor(.secondary)
            }
        }
    }

    private func splitLabel(for assigned: Set<Friend>) -> String {
        if assigned.isEmpty {
            return "Split: Everyone"
        } else if assigned.count == 1, let f = assigned.first {
            return "Split: \(f.name)"
        } else {
            let first = assigned.first!.name
            return "Split: \(first) +\(assigned.count - 1)"
        }
    }

    private func toggleFriend(_ friend: Friend, for key: AnyHashable) {
        var set = itemSplits[key] ?? []
        if set.contains(friend) {
            set.remove(friend)
        } else {
            set.insert(friend)
        }
        itemSplits[key] = set
    }

    /// Compute how much each friend owes based on item-level splits.
    /// Rule:
    /// - If an item has an explicit non-empty friend set: split that item's price evenly among them.
    /// - Otherwise: split that item's price evenly among all demoFriends.
    /// Uses only item prices for now (clean + simple for hackathon).
    private func computeOwedTotals() -> [Friend: Double] {
        var owed: [Friend: Double] = [:]

        for item in receipt.items {
            guard let price = item.price, price > 0 else { continue }
            let key = AnyHashable(item.id)
            let assigned = itemSplits[key] ?? []

            let targets: [Friend]
            if assigned.isEmpty {
                targets = demoFriends
            } else {
                targets = Array(assigned)
            }

            guard !targets.isEmpty else { continue }
            let share = price / Double(targets.count)

            for friend in targets {
                owed[friend, default: 0] += share
            }
        }

        // Round to cents
        for (friend, amount) in owed {
            owed[friend] = (amount * 100).rounded() / 100
        }

        return owed
    }
}

// MARK: - Image Viewer Sheet

struct ImageViewerSheet: View {
    let imageRef: String?
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            if let imageRef,
               let uiImage = loadImage(named: imageRef) {
                VStack {
                    Spacer(minLength: 40)

                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(16)
                        .padding(.horizontal, 16)

                    Spacer()

                    Button {
                        isPresented = false
                    } label: {
                        Text("Close")
                            .font(.headline)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(22)
                    }
                    .padding(.bottom, 32)
                }
            } else {
                VStack {
                    Text("Image not available")
                        .foregroundColor(.white)
                        .padding()
                    Button("Close") {
                        isPresented = false
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(20)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    private func loadImage(named: String) -> UIImage? {
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(named)
        return UIImage(contentsOfFile: url.path)
    }
}
