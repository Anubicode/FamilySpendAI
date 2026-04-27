import Foundation

struct ReceiptDraftLineItem: Identifiable, Equatable, Hashable {
    let id: UUID
    var itemName: String
    var quantity: Double?
    var unitPrice: Double?
    var totalPrice: Double
    var confidenceScore: Double

    init(
        id: UUID = UUID(),
        itemName: String,
        quantity: Double? = nil,
        unitPrice: Double? = nil,
        totalPrice: Double,
        confidenceScore: Double = 0
    ) {
        self.id = id
        self.itemName = itemName
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalPrice = totalPrice
        self.confidenceScore = confidenceScore
    }
}

struct ReceiptDraft: Identifiable, Equatable {
    let id: UUID
    var merchantName: String
    var transactionDate: Date?
    var subtotal: Double?
    var tax: Double?
    var tip: Double?
    var discount: Double?
    var total: Double?
    var rawText: String
    var confidenceScore: Double
    var fieldConfidence: ReceiptFieldConfidence
    var requiresReview: Bool
    var lineItems: [ReceiptDraftLineItem]

    init(
        id: UUID = UUID(),
        merchantName: String = "",
        transactionDate: Date? = nil,
        subtotal: Double? = nil,
        tax: Double? = nil,
        tip: Double? = nil,
        discount: Double? = nil,
        total: Double? = nil,
        rawText: String = "",
        confidenceScore: Double = 0,
        fieldConfidence: ReceiptFieldConfidence = .zero,
        requiresReview: Bool = true,
        lineItems: [ReceiptDraftLineItem] = []
    ) {
        self.id = id
        self.merchantName = merchantName
        self.transactionDate = transactionDate
        self.subtotal = subtotal
        self.tax = tax
        self.tip = tip
        self.discount = discount
        self.total = total
        self.rawText = rawText
        self.confidenceScore = confidenceScore
        self.fieldConfidence = fieldConfidence
        self.requiresReview = requiresReview
        self.lineItems = lineItems
    }

    var hasUsableContent: Bool {
        !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || total != nil || !merchantName.isEmpty
    }
}
