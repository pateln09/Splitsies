import Foundation
import SwiftData

// MARK: - SwiftData Models

@Model
final class Receipt {
    @Attribute(.unique) var id: UUID
    var storeName: String?
    var receiptDate: Date?
    var subtotal: Double?
    var tax: Double?
    var tip: Double?
    var discount: Double?
    var total: Double?
    var imageRef: String? // file name in Documents directory

    @Relationship(deleteRule: .cascade, inverse: \ReceiptItem.parentReceipt)
    var items: [ReceiptItem]

    init(
        id: UUID = UUID(),
        storeName: String?,
        receiptDate: Date?,
        subtotal: Double?,
        tax: Double?,
        tip: Double?,
        discount: Double?,
        total: Double?,
        imageRef: String?,
        items: [ReceiptItem] = []
    ) {
        self.id = id
        self.storeName = storeName
        self.receiptDate = receiptDate
        self.subtotal = subtotal
        self.tax = tax
        self.tip = tip
        self.discount = discount
        self.total = total
        self.imageRef = imageRef
        self.items = items
    }
}

@Model
final class ReceiptItem {
    @Attribute(.unique) var id: UUID
    var name: String?
    var price: Double?

    @Relationship var parentReceipt: Receipt?

    init(
        id: UUID = UUID(),
        name: String?,
        price: Double?,
        parentReceipt: Receipt? = nil
    ) {
        self.id = id
        self.name = name
        self.price = price
        self.parentReceipt = parentReceipt
    }
}

// MARK: - DTOs from Gemini

struct ParsedItemDTO: Codable {
    let name: String?
    let price: Double?
    let confidence: String
}

struct ParsedReceiptDTO: Codable {
    let storeName: String?
    let receiptDate: String?
    let subtotal: Double?
    let tax: Double?
    let tip: Double?
    let discount: Double?
    let total: Double?
    let items: [ParsedItemDTO]
}

// MARK: - Mapping DTO -> SwiftData

extension ParsedReceiptDTO {
    func toReceipt(imageFileName: String?) -> Receipt {
        let parsedDate: Date? = receiptDate.flatMap { DateFormatter.yyyyMMdd.date(from: $0) }

        let receipt = Receipt(
            storeName: storeName,
            receiptDate: parsedDate,
            subtotal: subtotal,
            tax: tax,
            tip: tip,
            discount: discount,
            total: total,
            imageRef: imageFileName
        )

        let mappedItems: [ReceiptItem] = items.map { dto in
            ReceiptItem(
                name: dto.name,
                price: dto.price,
                parentReceipt: receipt
            )
        }

        receipt.items = mappedItems
        return receipt
    }
}

// MARK: - Date Formatter

private extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = .init(identifier: "en_US_POSIX")
        f.timeZone = .init(secondsFromGMT: 0)
        return f
    }()
}
