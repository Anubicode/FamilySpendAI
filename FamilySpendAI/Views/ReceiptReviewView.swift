import UIKit
import SwiftData
import SwiftUI

struct ReceiptReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let imageData: Data?
    let onSave: () -> Void

    @State private var merchantName: String
    @State private var transactionDate: Date
    @State private var hasTransactionDate: Bool
    @State private var subtotalText: String
    @State private var taxText: String
    @State private var tipText: String
    @State private var discountText: String
    @State private var totalText: String
    @State private var rawText: String
    @State private var lineItems: [ReceiptDraftLineItem]
    @State private var fieldConfidence: ReceiptFieldConfidence
    @State private var confidenceScore: Double
    @State private var requiresReview: Bool
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var rawTextExpanded = false

    init(initialDraft: ReceiptDraft, imageData: Data?, onSave: @escaping () -> Void) {
        self.imageData = imageData
        self.onSave = onSave
        _merchantName = State(initialValue: initialDraft.merchantName)
        _transactionDate = State(initialValue: initialDraft.transactionDate ?? .now)
        _hasTransactionDate = State(initialValue: initialDraft.transactionDate != nil)
        _subtotalText = State(initialValue: Self.stringValue(initialDraft.subtotal))
        _taxText = State(initialValue: Self.stringValue(initialDraft.tax))
        _tipText = State(initialValue: Self.stringValue(initialDraft.tip))
        _discountText = State(initialValue: Self.stringValue(initialDraft.discount))
        _totalText = State(initialValue: Self.stringValue(initialDraft.total))
        _rawText = State(initialValue: initialDraft.rawText)
        _lineItems = State(initialValue: initialDraft.lineItems)
        _fieldConfidence = State(initialValue: initialDraft.fieldConfidence)
        _confidenceScore = State(initialValue: initialDraft.confidenceScore)
        _requiresReview = State(initialValue: initialDraft.requiresReview)
    }

    var body: some View {
        Form {
            if let imageData, let image = UIImage(data: imageData) {
                Section("Receipt image") {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            if requiresReview || confidenceScore < 0.7 {
                Section {
                    Label(
                        "Low-confidence receipt fields were detected. Review every value before saving.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("receiptReview.lowConfidenceWarning")
                }
            }

            Section("Detected values") {
                TextField("Merchant", text: $merchantName)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("receiptReview.merchantField")
                confidenceLabel("Merchant confidence", value: fieldConfidence.merchant)

                DatePicker(
                    "Date",
                    selection: Binding(
                        get: { transactionDate },
                        set: {
                            transactionDate = $0
                            hasTransactionDate = true
                        }
                    ),
                    displayedComponents: .date
                )
                .accessibilityIdentifier("receiptReview.dateField")
                confidenceLabel("Date confidence", value: fieldConfidence.date)

                if !hasTransactionDate {
                    Text("No date was detected. Pick a date if you want one saved with the receipt.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                currencyField("Subtotal", text: $subtotalText)
                confidenceLabel("Subtotal confidence", value: fieldConfidence.subtotal)

                currencyField("Tax", text: $taxText)
                confidenceLabel("Tax confidence", value: fieldConfidence.tax)

                currencyField("Tip", text: $tipText)
                confidenceLabel("Tip confidence", value: fieldConfidence.tip)

                currencyField("Discount", text: $discountText)
                confidenceLabel("Discount confidence", value: fieldConfidence.discount)

                currencyField("Final total", text: $totalText)
                confidenceLabel("Total confidence", value: fieldConfidence.total)
            }

            if !lineItems.isEmpty {
                Section("Detected line items") {
                    ForEach($lineItems) { $lineItem in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Item", text: $lineItem.itemName)
                            currencyField("Item total", text: Binding(
                                get: { Self.stringValue(lineItem.totalPrice) },
                                set: { newValue in
                                    lineItem.totalPrice = Self.decimalValue(from: newValue) ?? 0
                                }
                            ))
                            confidenceLabel("Line confidence", value: lineItem.confidenceScore)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Raw OCR text") {
                DisclosureGroup("Show OCR text", isExpanded: $rawTextExpanded) {
                    TextEditor(text: $rawText)
                        .frame(minHeight: 220)
                        .font(.system(.footnote, design: .monospaced))
                        .accessibilityIdentifier("receiptReview.rawOCRText")
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Review Receipt")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "Saving..." : "Save") {
                    saveReviewedReceipt()
                }
                .disabled(isSaving)
                .accessibilityIdentifier("receiptReview.saveButton")
            }
        }
    }

    @ViewBuilder
    private func confidenceLabel(_ label: String, value: Double) -> some View {
        Text("\(label): \(Int((value * 100).rounded()))%")
            .font(.caption)
            .foregroundStyle(value < 0.7 ? .orange : .secondary)
    }

    private func currencyField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .keyboardType(.decimalPad)
            .accessibilityIdentifier(accessibilityIdentifier(for: title))
    }

    private func accessibilityIdentifier(for title: String) -> String {
        switch title {
        case "Subtotal":
            return "receiptReview.subtotalField"
        case "Tax":
            return "receiptReview.taxField"
        case "Final total":
            return "receiptReview.totalField"
        default:
            return "receiptReview.\(title.lowercased().replacingOccurrences(of: " ", with: ""))Field"
        }
    }

    private func saveReviewedReceipt() {
        isSaving = true
        defer { isSaving = false }

        guard let total = Self.decimalValue(from: totalText), total > 0 else {
            errorMessage = "Enter a final total before saving the reviewed receipt."
            return
        }

        let reviewedReceipt = Receipt(
            imageData: imageData,
            rawOCRText: rawText,
            merchantName: sanitizedMerchantName,
            transactionDate: hasTransactionDate ? transactionDate : nil,
            subtotal: Self.decimalValue(from: subtotalText),
            tax: Self.decimalValue(from: taxText),
            tip: Self.decimalValue(from: tipText),
            discount: Self.decimalValue(from: discountText),
            total: total,
            confidenceScore: confidenceScore,
            receiptType: .other,
            lineItems: lineItems.compactMap { lineItem in
                guard !lineItem.itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return nil
                }

                return ReceiptLineItem(
                    itemName: lineItem.itemName.trimmingCharacters(in: .whitespacesAndNewlines),
                    quantity: lineItem.quantity,
                    unitPrice: lineItem.unitPrice,
                    totalPrice: lineItem.totalPrice,
                    confidenceScore: lineItem.confidenceScore
                )
            },
            userReviewed: true
        )

        let transaction = Transaction(
            amount: total,
            date: hasTransactionDate ? transactionDate : .now,
            merchant: sanitizedMerchantName,
            note: "Reviewed from receipt OCR",
            category: .miscellaneous,
            categoryType: BudgetCategoryName.miscellaneous.defaultType,
            paymentMethod: .other,
            source: .receiptOCR,
            isUnnecessary: false,
            receipt: reviewedReceipt
        )

        modelContext.insert(reviewedReceipt)
        modelContext.insert(transaction)

        do {
            try modelContext.save()
            errorMessage = nil
            onSave()
            dismiss()
        } catch {
            errorMessage = "Unable to save the reviewed receipt. \(error.localizedDescription)"
        }
    }

    private var sanitizedMerchantName: String {
        let trimmed = merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Receipt OCR" : trimmed
    }

    private static func stringValue(_ amount: Double?) -> String {
        guard let amount else { return "" }
        return amount.formatted(.number.precision(.fractionLength(2)))
    }

    private static func stringValue(_ amount: Double) -> String {
        amount.formatted(.number.precision(.fractionLength(2)))
    }

    private static func decimalValue(from rawValue: String) -> Double? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let cleaned = trimmed
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")

        return Double(cleaned)
    }
}
