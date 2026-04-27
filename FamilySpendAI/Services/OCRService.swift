import Foundation
import Vision

enum OCRServiceError: LocalizedError {
    case emptyImage
    case noTextRecognized

    var errorDescription: String? {
        switch self {
        case .emptyImage:
            return "The selected image could not be read."
        case .noTextRecognized:
            return "No readable receipt text was found in that image."
        }
    }
}

protocol OCRServing {
    func recognizeText(from imageData: Data) async throws -> String
}

struct OCRService: OCRServing {
    func recognizeText(from imageData: Data) async throws -> String {
        guard !imageData.isEmpty else {
            throw OCRServiceError.emptyImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .filter { !$0.isEmpty }

                let rawText = lines.joined(separator: "\n")

                if rawText.isEmpty {
                    continuation.resume(throwing: OCRServiceError.noTextRecognized)
                } else {
                    continuation.resume(returning: rawText)
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-CA", "en-US", "fr-CA"]
            request.minimumTextHeight = 0.015

            let handler = VNImageRequestHandler(data: imageData)
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
