import Foundation
import PhotosUI

@MainActor
final class ReceiptScannerViewModel: ObservableObject {
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var recognizedTextPreview = ""
    @Published var reviewDraft: ReceiptDraft?
    @Published var selectedImageData: Data?

    private let ocrService: OCRServing
    private let parsingService: ReceiptParsingService

    init(
        ocrService: OCRServing = OCRService(),
        parsingService: ReceiptParsingService = ReceiptParsingService()
    ) {
        self.ocrService = ocrService
        self.parsingService = parsingService
    }

    func processSelectedPhoto() async {
        guard let selectedPhotoItem else { return }

        isProcessing = true
        errorMessage = nil
        recognizedTextPreview = ""
        reviewDraft = nil

        defer { isProcessing = false }

        do {
            guard let data = try await selectedPhotoItem.loadTransferable(type: Data.self), !data.isEmpty else {
                errorMessage = "The selected image could not be loaded."
                return
            }

            selectedImageData = data

            let recognizedText: String
            do {
                recognizedText = try await ocrService.recognizeText(from: data)
            } catch OCRServiceError.noTextRecognized {
                recognizedText = ""
            }

            let parsedDraft = parsingService.parse(rawText: recognizedText)
            recognizedTextPreview = previewText(for: parsedDraft.rawText)
            reviewDraft = parsedDraft

            if recognizedText.isEmpty {
                errorMessage = "No readable text was found. You can still review and fill in the receipt manually."
            }
        } catch {
            errorMessage = "Receipt OCR could not be completed. \(error.localizedDescription)"
        }
    }

    func clearResult() {
        selectedPhotoItem = nil
        selectedImageData = nil
        recognizedTextPreview = ""
        reviewDraft = nil
        errorMessage = nil
        isProcessing = false
    }

    private func previewText(for rawText: String) -> String {
        rawText
            .components(separatedBy: .newlines)
            .prefix(6)
            .joined(separator: "\n")
    }
}
