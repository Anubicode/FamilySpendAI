import Foundation
import UIKit

enum SyntheticReceiptKind: String, CaseIterable, Identifiable {
    case walmart
    case tims
    case gas
    case phoneBill
    case messyTotal

    var id: String { rawValue }
}

struct SyntheticReceiptSample: Identifiable, Equatable {
    let kind: SyntheticReceiptKind
    let displayName: String
    let buttonIdentifier: String
    let merchantName: String
    let rawText: String
    let expectedTotal: Double
    let expectedDate: Date?
    let shouldTriggerLowConfidence: Bool

    var id: SyntheticReceiptKind { kind }
}

@MainActor
enum SyntheticReceiptService {
    static func sample(for kind: SyntheticReceiptKind) -> SyntheticReceiptSample {
        switch kind {
        case .walmart:
            return SyntheticReceiptSample(
                kind: .walmart,
                displayName: "Sample Walmart receipt",
                buttonIdentifier: "scan.sampleReceipt.walmart",
                merchantName: "WALMART",
                rawText: """
                WALMART
                2026-04-27
                SUBTOTAL 45.20
                HST 5.88
                TOTAL 51.08
                """,
                expectedTotal: 51.08,
                expectedDate: makeDate(year: 2026, month: 4, day: 27),
                shouldTriggerLowConfidence: false
            )
        case .tims:
            return SyntheticReceiptSample(
                kind: .tims,
                displayName: "Sample Tim Hortons receipt",
                buttonIdentifier: "scan.sampleReceipt.tims",
                merchantName: "TIM HORTONS",
                rawText: """
                TIM HORTONS
                27/04/2026
                COFFEE 2.49
                DONUT 1.79
                HST 0.56
                TOTAL 4.84
                """,
                expectedTotal: 4.84,
                expectedDate: makeDate(year: 2026, month: 4, day: 27),
                shouldTriggerLowConfidence: false
            )
        case .gas:
            return SyntheticReceiptSample(
                kind: .gas,
                displayName: "Sample Petro-Canada receipt",
                buttonIdentifier: "scan.sampleReceipt.gas",
                merchantName: "PETRO-CANADA",
                rawText: """
                PETRO-CANADA
                Apr 27 2026
                FUEL 60.00
                HST 7.80
                TOTAL 67.80
                """,
                expectedTotal: 67.80,
                expectedDate: makeDate(year: 2026, month: 4, day: 27),
                shouldTriggerLowConfidence: false
            )
        case .phoneBill:
            return SyntheticReceiptSample(
                kind: .phoneBill,
                displayName: "Sample Rogers bill",
                buttonIdentifier: "scan.sampleReceipt.phoneBill",
                merchantName: "ROGERS",
                rawText: """
                ROGERS
                2026-04-27
                MONTHLY CHARGES 75.00
                HST 9.75
                AMOUNT DUE 84.75
                """,
                expectedTotal: 84.75,
                expectedDate: makeDate(year: 2026, month: 4, day: 27),
                shouldTriggerLowConfidence: false
            )
        case .messyTotal:
            return SyntheticReceiptSample(
                kind: .messyTotal,
                displayName: "Sample messy receipt",
                buttonIdentifier: "scan.sampleReceipt.messyTotal",
                merchantName: "MESSY RECEIPT",
                rawText: """
                MESSY RECEIPT
                SUBTOTAL 100.00
                DISCOUNT -10.00
                HST 11.70
                VISA 101.70
                """,
                expectedTotal: 101.70,
                expectedDate: nil,
                shouldTriggerLowConfidence: true
            )
        }
    }

    static var uiTestingSamples: [SyntheticReceiptSample] {
        SyntheticReceiptKind.allCases.map(sample(for:))
    }

    static func imageData(for kind: SyntheticReceiptKind) -> Data? {
        let sample = sample(for: kind)
        return imageData(for: sample)
    }

    static func imageData(for sample: SyntheticReceiptSample) -> Data? {
        renderImage(for: sample).pngData()
    }

    static func renderImage(for sample: SyntheticReceiptSample) -> UIImage {
        let merchantFont = UIFont.monospacedSystemFont(ofSize: 56, weight: .bold)
        let bodyFont = UIFont.monospacedSystemFont(ofSize: 42, weight: .regular)
        let merchantAttributes: [NSAttributedString.Key: Any] = [
            .font: merchantFont,
            .foregroundColor: UIColor.black
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: UIColor.black
        ]

        let lines = sample.rawText.components(separatedBy: .newlines)
        let lineHeight = bodyFont.lineHeight + 18
        let merchantHeight = merchantFont.lineHeight + 18
        let horizontalPadding: CGFloat = 72
        let verticalPadding: CGFloat = 88
        let width: CGFloat = 1280
        let height = verticalPadding * 2 + merchantHeight + CGFloat(max(lines.count - 1, 0)) * lineHeight + 48

        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = 2
        rendererFormat.opaque = true

        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: width, height: height),
            format: rendererFormat
        )

        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: width, height: height)))

            let borderRect = CGRect(x: 16, y: 16, width: width - 32, height: height - 32)
            UIBezierPath(roundedRect: borderRect, cornerRadius: 22).addClip()

            UIColor(white: 0.96, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: 44))

            UIColor(white: 0.88, alpha: 1).setStroke()
            context.cgContext.setLineWidth(3)
            context.cgContext.move(to: CGPoint(x: 40, y: 44))
            context.cgContext.addLine(to: CGPoint(x: width - 40, y: 44))
            context.cgContext.strokePath()

            var currentY = verticalPadding
            for (index, line) in lines.enumerated() {
                let attributes = index == 0 ? merchantAttributes : bodyAttributes
                let font = index == 0 ? merchantFont : bodyFont
                let rect = CGRect(
                    x: horizontalPadding,
                    y: currentY,
                    width: width - horizontalPadding * 2,
                    height: font.lineHeight + 12
                )
                NSString(string: line).draw(in: rect, withAttributes: attributes)
                currentY += index == 0 ? merchantHeight : lineHeight
            }
        }
    }

    private static func makeDate(year: Int, month: Int, day: Int) -> Date? {
        let components = DateComponents(
            calendar: .canadian,
            timeZone: Calendar.canadian.timeZone,
            year: year,
            month: month,
            day: day
        )
        return components.date
    }
}
