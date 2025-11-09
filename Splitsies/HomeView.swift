import SwiftUI
import SwiftData
import PhotosUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Receipt.receiptDate, order: .reverse) private var receipts: [Receipt]

    @State private var showCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    @State private var capturedImage: UIImage?
    @State private var isParsing = false
    @State private var parseError: String?

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


// MARK: - Detail View

struct ReceiptDetailView: View {
    let receipt: Receipt

    @State private var showImage = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                Text(receipt.storeName ?? "Receipt")
                    .font(.title2.weight(.semibold))

                // Always show something for purchase date
                Text(purchaseDateDetailText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)

                if receipt.imageRef != nil {
                    Button {
                        showImage = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("View image")
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .padding(.top, 2)
                }

                Text("Items")
                    .font(.headline)
                    .padding(.top, 8)

                ForEach(receipt.items) { item in
                    HStack {
                        Text(item.name ?? "Unknown item")
                        Spacer()
                        if let price = item.price {
                            Text(String(format: "$%.2f", price))
                        } else {
                            Text("--")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }

                // Totals at the bottom
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
            }
            .padding()
        }
        .navigationTitle("Receipt Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showImage) {
            ImageViewerSheet(imageRef: receipt.imageRef, isPresented: $showImage)
        }
    }

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
