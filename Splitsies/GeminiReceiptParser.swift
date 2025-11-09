import UIKit

enum GeminiError: Error {
    case encodingFailed
    case invalidResponse
    case missingAPIKey
    case parseFailed
}

struct GeminiReceiptParser {
    // Adjust if you’re using a different model name
    let model: String = "gemini-2.5-flash"

    func parse(image: UIImage) async throws -> ParsedReceiptDTO {
        guard !Secrets.geminiAPIKey.isEmpty else {
            throw GeminiError.missingAPIKey
        }
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            throw GeminiError.encodingFailed
        }

        let base64Image = imageData.base64EncodedString()

        // Expected JSON schema
        let schema: [String: Any] = [
            "type": "object",
            "required": ["storeName","receiptDate","subtotal","tax","tip","discount","total","items"],
            "properties": [
                "storeName": [
                    "type": ["string","null"],
                    "description": "Name of the store or restaurant"
                ],
                "receiptDate": [
                    "type": ["string","null"],
                    "description": "Date from receipt in ISO format YYYY-MM-DD if possible"
                ],
                "subtotal": [
                    "type": ["number","null"],
                    "description": "Subtotal before tax and tip"
                ],
                "tax": [
                    "type": ["number","null"],
                    "description": "Total tax amount"
                ],
                "tip": [
                    "type": ["number","null"],
                    "description": "Tip amount if present"
                ],
                "discount": [
                    "type": ["number","null"],
                    "description": "Total discount amount if present"
                ],
                "total": [
                    "type": ["number","null"],
                    "description": "Final total amount paid"
                ],
                "items": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "required": ["name","price","confidence"],
                        "properties": [
                            "name": [
                                "type": ["string","null"],
                                "description": "Item name including any modifiers"
                            ],
                            "price": [
                                "type": ["number","null"],
                                "description": "Price as numeric value"
                            ],
                            "confidence": [
                                "type": "string",
                                "enum": ["high","medium","low"],
                                "description": "Confidence level in price accuracy"
                            ]
                        ]
                    ]
                ]
            ]
        ]

        let systemPrompt = """
        You are a receipt parsing assistant specialized in accurate data extraction. Analyze the receipt image and extract all purchased items along with financial totals. Return the data in strict JSON format.

        # CRITICAL ACCURACY RULES:
        - Extract ONLY what you can clearly read from the image.
        - DO NOT adjust or "correct" item prices to make them sum to the total.
        - DO NOT calculate or infer prices based on other values.
        - If a price is unclear, blurry, or unreadable, set it to null. Do NOT guess.
        - Extract each field independently without cross-referencing other fields.
        - Accuracy of individual values is MORE important than mathematical consistency.

        # Core Extraction Rules:
        1. Extract purchasable items separately from financial totals (subtotal, tax, tip, discount, total).
        2. If an item has a quantity greater than 1 (e.g., "2x Burger" or "Burger x2"), create SEPARATE entries for each unit.
        3. Preserve the original item name exactly as it appears on the receipt.
        4. Parse all monetary values as numeric values without currency symbols.
        5. Include item modifiers/customizations in the item name (e.g., "Coffee - Extra Shot").
        6. Ignore promotional text, loyalty info, and store policies.
        7. Each duplicate item should appear as a separate object in the items array.

        # Financial Totals Extraction:
        - Extract subtotal, tax, tip, discount, and total as separate fields when visible.
        - Set any unavailable financial field to null.
        - Discounts should be positive in the "discount" field.
        - Do NOT force totals to match item sums.

        # Additional Metadata:
        - Extract storeName from the receipt header/branding; else set to null.
        - Extract receiptDate when possible:
          - Prefer the printed transaction/purchase date on the receipt.
          - Format as YYYY-MM-DD when possible.
          - If multiple dates appear, choose the purchase/transaction date.
          - Do NOT fabricate or infer dates from filenames or EXIF or context.

        # Confidence:
        - For each item, set "confidence" to "high", "medium", or "low" based ONLY on readability.
        - Do NOT omit the confidence field.
        - This confidence value is metadata only and will NOT be visualized.

        # Output:
        - Output MUST be valid JSON.
        - MUST strictly match the provided JSON schema.
        - Do NOT include comments or text outside the JSON.
        """

        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    [
                        "inline_data": [
                            "mime_type": "image/jpeg",
                            "data": base64Image
                        ]
                    ],
                    [
                        "text": systemPrompt
                    ]
                ]
            ]],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseJsonSchema": schema
            ]
        ]

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(Secrets.geminiAPIKey, forHTTPHeaderField: "x-goog-api-key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard
            let http = response as? HTTPURLResponse,
            200..<300 ~= http.statusCode
        else {
            throw GeminiError.invalidResponse
        }

        struct GeminiEnvelope: Codable {
            struct Candidate: Codable {
                struct Content: Codable {
                    struct Part: Codable {
                        let text: String?
                    }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }

        let envelope = try JSONDecoder().decode(GeminiEnvelope.self, from: data)

        guard
            let jsonText = envelope.candidates.first?.content.parts.first?.text,
            let jsonData = jsonText.data(using: .utf8)
        else {
            throw GeminiError.parseFailed
        }

        return try JSONDecoder().decode(ParsedReceiptDTO.self, from: jsonData)
    }
}
