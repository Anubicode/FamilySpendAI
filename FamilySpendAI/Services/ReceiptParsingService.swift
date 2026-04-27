import Foundation

struct ReceiptParsingService {
    private struct CandidateAmount {
        let amount: Double
        let lineIndex: Int
        let label: String
        let confidence: Double
    }

    private let subtotalLabels = ["subtotal", "sub total", "sous-total", "sous total"]
    private let taxLabels = ["gst", "hst", "pst", "qst", "tax", "taxes", "tps", "tvq", "tva"]
    private let tipLabels = ["tip", "gratuity"]
    private let discountLabels = ["discount", "rabais", "coupon", "savings", "saving"]
    private let strongTotalLabels = ["grand total", "amount paid", "balance due", "balance", "total due", "total", "amount"]
    private let weakTotalLabels = ["sale", "purchase"]
    private let merchantNoise = ["thank you", "merci", "welcome", "invoice", "receipt", "order", "transaction", "served by"]
    private let skippedLineItemLabels = ["subtotal", "sub total", "tax", "hst", "gst", "pst", "qst", "tip", "discount", "total", "amount paid", "balance", "sale", "purchase", "change", "cash", "visa", "mastercard", "debit"]
    private let locale = Locale(identifier: "en_CA")
    private let calendar = Calendar.canadian

    func parse(rawText: String) -> ReceiptDraft {
        let lines = normalizedLines(from: rawText)
        guard !lines.isEmpty else {
            return ReceiptDraft(
                rawText: rawText,
                confidenceScore: 0,
                fieldConfidence: .zero,
                requiresReview: true,
                lineItems: []
            )
        }

        var merchantConfidence = 0.2
        let merchant = extractMerchant(from: lines, confidence: &merchantConfidence)

        var dateConfidence = 0.0
        let date = extractDate(from: lines, confidence: &dateConfidence)

        let subtotalCandidate = bestCandidate(in: lines, matchingAny: subtotalLabels, excluding: [])
        let taxCandidates = candidates(in: lines, matchingAny: taxLabels, excluding: ["subtotal", "sub total", "total"])
        let tipCandidate = bestCandidate(in: lines, matchingAny: tipLabels, excluding: [])
        let discountCandidate = bestCandidate(in: lines, matchingAny: discountLabels, excluding: [])
        let totalCandidate = selectTotalCandidate(
            in: lines,
            subtotalAmount: subtotalCandidate?.amount,
            taxAmount: summedAmount(for: taxCandidates),
            tipAmount: tipCandidate?.amount
        )

        let subtotal = subtotalCandidate?.amount
        let tax = summedAmount(for: taxCandidates)
        let tip = tipCandidate?.amount
        let discount = discountCandidate?.amount
        let total = totalCandidate?.amount

        let fieldConfidence = ReceiptFieldConfidence(
            merchant: merchant.isEmpty ? 0 : merchantConfidence,
            date: dateConfidence,
            subtotal: subtotalCandidate?.confidence ?? 0,
            tax: taxCandidates.isEmpty ? 0 : averageConfidence(for: taxCandidates),
            tip: tipCandidate?.confidence ?? 0,
            discount: discountCandidate?.confidence ?? 0,
            total: totalCandidate?.confidence ?? 0
        )

        let lineItems = extractLineItems(
            from: lines,
            merchant: merchant,
            amountsToSkip: [subtotal, tax, tip, discount, total].compactMap { $0 }
        )

        let importantScores = [
            fieldConfidence.merchant,
            fieldConfidence.date,
            fieldConfidence.subtotal,
            fieldConfidence.tax,
            fieldConfidence.tip,
            fieldConfidence.discount,
            fieldConfidence.total
        ]
        .filter { $0 > 0 }

        let confidenceScore: Double
        if importantScores.isEmpty {
            confidenceScore = 0
        } else {
            confidenceScore = importantScores.reduce(0, +) / Double(importantScores.count)
        }

        let requiresReview =
            rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            total == nil ||
            fieldConfidence.total < 0.7 ||
            merchant.isEmpty

        return ReceiptDraft(
            merchantName: merchant,
            transactionDate: date,
            subtotal: subtotal,
            tax: tax,
            tip: tip,
            discount: discount,
            total: total,
            rawText: rawText,
            confidenceScore: confidenceScore,
            fieldConfidence: fieldConfidence,
            requiresReview: requiresReview,
            lineItems: lineItems
        )
    }

    private func normalizedLines(from rawText: String) -> [String] {
        rawText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func extractMerchant(from lines: [String], confidence: inout Double) -> String {
        for line in lines.prefix(5) {
            let normalized = normalizedLabel(line)
            guard !normalized.isEmpty else { continue }
            guard normalized.rangeOfCharacter(from: .letters) != nil else { continue }
            guard !merchantNoise.contains(where: normalized.contains) else { continue }
            guard !containsAny(normalized, labels: subtotalLabels + taxLabels + tipLabels + discountLabels + strongTotalLabels + weakTotalLabels) else { continue }
            guard !looksLikeDate(line) else { continue }

            let digitCount = line.filter(\.isNumber).count
            let letterCount = line.filter(\.isLetter).count
            guard letterCount >= max(3, digitCount) else { continue }

            confidence = line == lines.first ? 0.92 : 0.82
            return cleanedMerchantName(line)
        }

        confidence = 0.1
        return ""
    }

    private func extractDate(from lines: [String], confidence: inout Double) -> Date? {
        let patterns = [
            #"\b\d{4}-\d{2}-\d{2}\b"#,
            #"\b\d{1,2}/\d{1,2}/\d{4}\b"#,
            #"\b[A-Za-z]{3,9}\s+\d{1,2}\s+\d{4}\b"#,
            #"\b\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4}\b"#
        ]

        for line in lines {
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                    continue
                }

                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                for match in regex.matches(in: line, options: [], range: range) {
                    guard let matchRange = Range(match.range, in: line) else { continue }
                    let candidate = String(line[matchRange])
                    if let date = parseDate(candidate) {
                        confidence = pattern.contains("A-Za-z") ? 0.88 : 0.84
                        return date
                    }
                }
            }
        }

        confidence = 0
        return nil
    }

    private func parseDate(_ rawValue: String) -> Date? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let slashDate = parseSlashDate(trimmed) {
            return slashDate
        }

        for formatter in dateFormatters() {
            if let date = formatter.date(from: trimmed) {
                return calendar.startOfDay(for: date)
            }
        }

        return nil
    }

    private func parseSlashDate(_ rawValue: String) -> Date? {
        let parts = rawValue.split(separator: "/")
        guard parts.count == 3 else { return nil }
        guard
            let first = Int(parts[0]),
            let second = Int(parts[1]),
            let year = Int(parts[2]),
            year >= 2000
        else {
            return nil
        }

        let day: Int
        let month: Int

        if first > 12 {
            day = first
            month = second
        } else if second > 12 {
            day = second
            month = first
        } else {
            day = first
            month = second
        }

        guard (1...31).contains(day), (1...12).contains(month) else {
            return nil
        }

        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day
        )
        return components.date.map { calendar.startOfDay(for: $0) }
    }

    private func dateFormatters() -> [DateFormatter] {
        let formats = [
            "yyyy-MM-dd",
            "dd/MM/yyyy",
            "MM/dd/yyyy",
            "MMM dd yyyy",
            "MMMM dd yyyy",
            "dd MMM yyyy",
            "dd MMMM yyyy"
        ]

        return formats.map { format in
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = format
            formatter.isLenient = false
            return formatter
        }
    }

    private func selectTotalCandidate(
        in lines: [String],
        subtotalAmount: Double?,
        taxAmount: Double?,
        tipAmount: Double?
    ) -> CandidateAmount? {
        let strongCandidates = candidates(in: lines, matchingAny: strongTotalLabels, excluding: subtotalLabels + taxLabels)
            .filter { candidate in
                !matches(candidate.amount, subtotalAmount) &&
                !matches(candidate.amount, taxAmount)
            }

        if let bestStrong = strongCandidates
            .sorted(by: { lhs, rhs in
                if lhs.confidence == rhs.confidence {
                    return lhs.lineIndex > rhs.lineIndex
                }
                return lhs.confidence > rhs.confidence
            })
            .first {
            return bestStrong
        }

        let weakCandidates = candidates(in: lines, matchingAny: weakTotalLabels, excluding: subtotalLabels + taxLabels)
            .filter { candidate in
                !matches(candidate.amount, subtotalAmount) &&
                !matches(candidate.amount, taxAmount)
            }

        if let bestWeak = weakCandidates.max(by: { $0.amount < $1.amount }) {
            return bestWeak
        }

        let allAmounts = lines.enumerated().flatMap { index, line in
            extractAmounts(from: line).map {
                CandidateAmount(amount: $0, lineIndex: index, label: line, confidence: 0.35)
            }
        }
        .filter { candidate in
            candidate.amount > 0 &&
            !matches(candidate.amount, taxAmount) &&
            !matches(candidate.amount, subtotalAmount)
        }

        guard let fallback = allAmounts.max(by: { $0.amount < $1.amount }) else {
            return nil
        }

        if let tipAmount, matches(fallback.amount, tipAmount), let next = allAmounts.sorted(by: { $0.amount > $1.amount }).dropFirst().first {
            return next
        }

        return fallback
    }

    private func bestCandidate(in lines: [String], matchingAny labels: [String], excluding excluded: [String]) -> CandidateAmount? {
        candidates(in: lines, matchingAny: labels, excluding: excluded)
            .sorted(by: { lhs, rhs in
                if lhs.confidence == rhs.confidence {
                    return lhs.lineIndex > rhs.lineIndex
                }
                return lhs.confidence > rhs.confidence
            })
            .first
    }

    private func candidates(in lines: [String], matchingAny labels: [String], excluding excluded: [String]) -> [CandidateAmount] {
        lines.enumerated().compactMap { index, line in
            let normalized = normalizedLabel(line)
            guard containsAny(normalized, labels: labels) else { return nil }
            guard !containsAny(normalized, labels: excluded) else { return nil }

            let amounts = extractAmounts(from: line)
            guard let amount = amounts.last else { return nil }

            let confidence = confidenceForLine(normalized, labels: labels)
            return CandidateAmount(amount: amount, lineIndex: index, label: line, confidence: confidence)
        }
    }

    private func extractLineItems(from lines: [String], merchant: String, amountsToSkip: [Double]) -> [ReceiptDraftLineItem] {
        var items: [ReceiptDraftLineItem] = []
        let merchantNormalized = normalizedLabel(merchant)

        for line in lines.dropFirst(merchant.isEmpty ? 0 : 1) {
            let normalized = normalizedLabel(line)
            guard !normalized.isEmpty else { continue }
            if !merchantNormalized.isEmpty && normalized.contains(merchantNormalized) {
                continue
            }
            guard !containsAny(normalized, labels: skippedLineItemLabels) else { continue }
            guard !looksLikeDate(line) else { continue }

            let amounts = extractAmounts(from: line)
            guard let lastAmount = amounts.last, lastAmount > 0 else { continue }
            guard !amountsToSkip.contains(where: { matches(lastAmount, $0) }) else { continue }

            let itemName = line.replacingOccurrences(of: currencyRegexPattern, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard itemName.rangeOfCharacter(from: .letters) != nil else { continue }

            items.append(
                ReceiptDraftLineItem(
                    itemName: itemName,
                    totalPrice: lastAmount,
                    confidenceScore: 0.48
                )
            )

            if items.count == 8 {
                break
            }
        }

        return items
    }

    private func extractAmounts(from line: String) -> [Double] {
        guard let regex = try? NSRegularExpression(pattern: currencyRegexPattern, options: []) else {
            return []
        }

        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        return regex.matches(in: line, options: [], range: nsRange).compactMap { match in
            guard let range = Range(match.range, in: line) else { return nil }
            return parseCurrency(String(line[range]))
        }
    }

    private func parseCurrency(_ rawValue: String) -> Double? {
        var cleaned = rawValue
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: " ", with: "")

        if cleaned.contains(",") && !cleaned.contains(".") {
            let parts = cleaned.split(separator: ",")
            if let last = parts.last, last.count == 2 {
                cleaned = parts.dropLast().joined() + "." + last
            } else {
                cleaned = cleaned.replacingOccurrences(of: ",", with: "")
            }
        } else {
            cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        }

        cleaned = cleaned.replacingOccurrences(of: "--", with: "-")
        return Double(cleaned)
    }

    private func normalizedLabel(_ value: String) -> String {
        value
            .folding(options: .diacriticInsensitive, locale: locale)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9/\-\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cleanedMerchantName(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func containsAny(_ normalizedValue: String, labels: [String]) -> Bool {
        labels.contains { normalizedValue.contains($0) }
    }

    private func confidenceForLine(_ normalizedLine: String, labels: [String]) -> Double {
        if labels == strongTotalLabels {
            if normalizedLine.contains("grand total") || normalizedLine.contains("amount paid") {
                return 0.96
            }
            return 0.9
        }

        if labels == subtotalLabels {
            return 0.88
        }

        if labels == tipLabels || labels == discountLabels {
            return 0.86
        }

        if labels == weakTotalLabels {
            return 0.72
        }

        return 0.82
    }

    private func summedAmount(for candidates: [CandidateAmount]) -> Double? {
        guard !candidates.isEmpty else { return nil }
        return candidates.reduce(0) { $0 + $1.amount }
    }

    private func averageConfidence(for candidates: [CandidateAmount]) -> Double {
        guard !candidates.isEmpty else { return 0 }
        return candidates.reduce(0) { $0 + $1.confidence } / Double(candidates.count)
    }

    private func matches(_ lhs: Double, _ rhs: Double?) -> Bool {
        guard let rhs else { return false }
        return abs(lhs - rhs) < 0.011
    }

    private func looksLikeDate(_ line: String) -> Bool {
        parseDate(line) != nil
    }

    private var currencyRegexPattern: String {
        #"(?<!\d)-?\$?\d{1,3}(?:[,\s]\d{3})*(?:[.,]\d{2})"#
    }
}
