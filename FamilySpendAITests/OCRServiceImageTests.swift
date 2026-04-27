import XCTest
@testable import FamilySpendAI

final class OCRServiceImageTests: XCTestCase {
    private let ocrService = OCRService()
    private let parser = ReceiptParsingService()

    func testOCRRecognizesSyntheticReceiptTextAcrossSamples() async throws {
        for kind in SyntheticReceiptKind.allCases {
            let sample = await MainActor.run { SyntheticReceiptService.sample(for: kind) }
            let imageData = try await imageData(for: kind)

            let recognizedText = try await ocrService.recognizeText(from: imageData)
            let normalizedText = normalize(recognizedText)

            XCTAssertFalse(
                normalizedText.isEmpty,
                "Expected OCR text for \(sample.displayName) to be non-empty."
            )
            XCTAssertTrue(
                merchantTokens(for: sample.merchantName).contains(where: normalizedText.contains),
                "Expected OCR text for \(sample.displayName) to include a recognizable merchant token."
            )

            let anchorToken = anchorKeyword(for: sample)
            XCTAssertTrue(
                normalizedText.contains(anchorToken),
                "Expected OCR text for \(sample.displayName) to include '\(anchorToken)'."
            )
        }
    }

    func testOCRParserExtractsReliableFieldsFromSyntheticReceipts() async throws {
        let reliableKinds: [SyntheticReceiptKind] = [.walmart, .tims, .gas, .phoneBill]

        for kind in reliableKinds {
            let sample = await MainActor.run { SyntheticReceiptService.sample(for: kind) }
            let imageData = try await imageData(for: kind)
            let recognizedText = try await ocrService.recognizeText(from: imageData)
            let draft = parser.parse(rawText: recognizedText)

            XCTAssertFalse(draft.merchantName.isEmpty, "Expected a merchant for \(sample.displayName).")
            XCTAssertTrue(
                merchantTokens(for: sample.merchantName).contains(where: normalize(draft.merchantName).contains),
                "Expected parsed merchant for \(sample.displayName) to resemble \(sample.merchantName)."
            )
            XCTAssertEqual(
                draft.total ?? 0,
                sample.expectedTotal,
                accuracy: 0.15,
                "Expected parsed total for \(sample.displayName) to stay close to the synthetic total."
            )

            if let expectedDate = sample.expectedDate {
                XCTAssertEqual(
                    draft.transactionDate,
                    expectedDate,
                    "Expected parsed date for \(sample.displayName) to remain deterministic."
                )
            }
        }
    }

    func testMessySyntheticReceiptRemainsReviewableAfterOCR() async throws {
        let sample = await MainActor.run { SyntheticReceiptService.sample(for: .messyTotal) }
        let imageData = try await imageData(for: .messyTotal)
        let recognizedText = try await ocrService.recognizeText(from: imageData)
        let draft = parser.parse(rawText: recognizedText)

        XCTAssertFalse(recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertEqual(draft.total ?? 0, sample.expectedTotal, accuracy: 0.15)
        XCTAssertTrue(
            draft.requiresReview || draft.confidenceScore < 0.7 || draft.fieldConfidence.total < 0.7,
            "Expected messy synthetic receipt to stay review-oriented after OCR."
        )
    }

    private func imageData(for kind: SyntheticReceiptKind) async throws -> Data {
        guard let imageData = await MainActor.run(body: { SyntheticReceiptService.imageData(for: kind) }) else {
            throw XCTSkip("Synthetic receipt image could not be generated for \(kind.rawValue).")
        }

        return imageData
    }

    private func anchorKeyword(for sample: SyntheticReceiptSample) -> String {
        if normalize(sample.rawText).contains("AMOUNT DUE") {
            return "AMOUNT DUE"
        }

        if sample.shouldTriggerLowConfidence {
            return "VISA"
        }

        return "TOTAL"
    }

    private func normalize(_ value: String) -> String {
        value
            .uppercased()
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func merchantTokens(for merchantName: String) -> [String] {
        normalize(merchantName)
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count >= 3 }
    }
}
