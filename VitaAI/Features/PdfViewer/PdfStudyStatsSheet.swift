import SwiftUI
import PDFKit

// MARK: - PdfStudyStatsSheet
//
// Sheet acessível via long-press no botão Study Mode da toolbar. Mostra:
// - Total de masks no documento
// - Accuracy % (acertos / tentativas) das masks que já foram tentadas
// - Lista das 5 masks com mais erros (ordenado por error_rate * attempts)
// - Mini-thumbnail da página de cada mask difícil
//
// Lê tracking do UserDefaults "pdf.mask.attempts.<fileHash>" populado
// pelo Study Mode (PdfViewerScreen.recordStudyAttempt).

struct PdfStudyStatsSheet: View {
    let document: PDFDocument
    let fileHash: String
    let onJumpToPage: (Int) -> Void

    private var attempts: [Attempt] {
        let key = "pdf.mask.attempts.\(fileHash)"
        let raw = UserDefaults.standard.array(forKey: key) as? [[String: Any]] ?? []
        return raw.compactMap { dict in
            guard let id = dict["maskId"] as? String,
                  let correct = dict["correct"] as? Bool else { return nil }
            return Attempt(maskId: id, correct: correct)
        }
    }

    private var stats: Stats {
        let allAttempts = attempts
        let total = allAttempts.count
        let correct = allAttempts.filter { $0.correct }.count
        let accuracy: Double = total == 0 ? 0 : Double(correct) / Double(total)
        // Aggregate por maskId
        var perMask: [String: (correct: Int, total: Int)] = [:]
        for a in allAttempts {
            var entry = perMask[a.maskId] ?? (0, 0)
            entry.total += 1
            if a.correct { entry.correct += 1 }
            perMask[a.maskId] = entry
        }
        let totalMasksInDoc = countMasksInDocument()
        // Sort por error rate descendente, peso pelo número de tentativas
        let hardest = perMask
            .map { (id, v) in
                HardMask(
                    maskId: id,
                    attempts: v.total,
                    correct: v.correct,
                    errorRate: v.total > 0 ? Double(v.total - v.correct) / Double(v.total) : 0
                )
            }
            .sorted { ($0.errorRate * Double($0.attempts)) > ($1.errorRate * Double($1.attempts)) }
            .prefix(5)
        return Stats(
            totalMasks: totalMasksInDoc,
            totalAttempts: total,
            accuracy: accuracy,
            hardest: Array(hardest)
        )
    }

    private func countMasksInDocument() -> Int {
        var count = 0
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            for ann in page.annotations where PdfMaskAnnotation.isMask(ann) {
                count += 1
            }
        }
        return count
    }

    /// Encontra a página onde uma mask com determinado id mora.
    private func pageIndex(for maskId: String) -> Int? {
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            for ann in page.annotations where PdfMaskAnnotation.isMask(ann) {
                if PdfMaskAnnotation.id(for: ann, pageIndex: i) == maskId {
                    return i
                }
            }
        }
        return nil
    }

    var body: some View {
        VitaSheet(title: "Estatísticas — Study Mode", detents: [.medium, .large]) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    statsCards
                    if !stats.hardest.isEmpty {
                        Text("Mais difíceis pra você")
                            .font(VitaTypography.titleSmall)
                            .foregroundStyle(VitaColors.textPrimary)
                            .padding(.top, 8)
                        ForEach(stats.hardest, id: \.maskId) { hard in
                            hardMaskRow(hard)
                        }
                    } else if stats.totalMasks == 0 {
                        emptyState(message: "Crie marcações opacas no PDF e ative o Study Mode pra começar a treinar.")
                    } else {
                        emptyState(message: "Toque em uma mask em Study Mode pra começar a registrar acertos e erros.")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    private var statsCards: some View {
        HStack(spacing: 10) {
            statCard(value: "\(stats.totalMasks)", label: "marcações")
            statCard(value: "\(stats.totalAttempts)", label: "tentativas")
            statCard(
                value: stats.totalAttempts == 0 ? "—" : "\(Int((stats.accuracy * 100).rounded()))%",
                label: "acertos"
            )
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(VitaTypography.titleMedium)
                .foregroundStyle(VitaColors.accent)
                .monospacedDigit()
            Text(label)
                .font(VitaTypography.labelSmall)
                .foregroundStyle(VitaColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(VitaColors.surfaceCard.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(VitaColors.surfaceBorder.opacity(0.5), lineWidth: 0.6)
        )
    }

    private func hardMaskRow(_ hard: HardMask) -> some View {
        let pageIdx = pageIndex(for: hard.maskId)
        return Button {
            if let p = pageIdx { onJumpToPage(p) }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.red.opacity(0.85))
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pageIdx != nil ? "Página \(pageIdx! + 1)" : "Marcação")
                        .font(VitaTypography.labelMedium)
                        .foregroundStyle(VitaColors.textPrimary)
                    Text("\(hard.correct)/\(hard.attempts) acertos · \(Int((hard.errorRate * 100).rounded()))% erro")
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textSecondary)
                        .monospacedDigit()
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(VitaColors.surfaceCard.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func emptyState(message: String) -> some View {
        Text(message)
            .font(VitaTypography.bodySmall)
            .foregroundStyle(VitaColors.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
    }

    // MARK: - Models

    private struct Attempt {
        let maskId: String
        let correct: Bool
    }

    private struct Stats {
        let totalMasks: Int
        let totalAttempts: Int
        let accuracy: Double
        let hardest: [HardMask]
    }

    private struct HardMask {
        let maskId: String
        let attempts: Int
        let correct: Int
        let errorRate: Double
    }
}
