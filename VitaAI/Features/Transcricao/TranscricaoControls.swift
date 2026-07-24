import SwiftUI

// MARK: - DisciplinePicker
//
// Replaces the horizontal scroll of chips (which cut off while scrolling).
// A single compact chip that, on tap, opens a popover with:
//   - "Auto-detectar" (default)
//   - All user disciplines (current + completed)
//   - "Outro..." → inline text field for a custom folder name
//
// Custom names land in `selectedDiscipline` just like any discipline, so
// the recording gets grouped under its own folder in the list view.


// MARK: - LanguagePicker (native Menu)

struct TranscricaoLanguagePicker: View {
    @Binding var selected: String
    let disabled: Bool

    struct Language: Identifiable, Equatable {
        let code: String
        let label: String
        let flag: String
        var id: String { code }
    }

    static let all: [Language] = [
        .init(code: "pt", label: "Português",  flag: "🇧🇷"),
        .init(code: "en", label: "English",    flag: "🇺🇸"),
        .init(code: "es", label: "Español",    flag: "🇪🇸"),
        .init(code: "fr", label: "Français",   flag: "🇫🇷"),
        .init(code: "de", label: "Deutsch",    flag: "🇩🇪"),
        .init(code: "it", label: "Italiano",   flag: "🇮🇹"),
        .init(code: "la", label: "Latim",      flag: "📜"),
    ]

    private var current: Language {
        Self.all.first { $0.code == selected } ?? Self.all[0]
    }

    var body: some View {
        Menu {
            ForEach(Self.all) { lang in
                Button {
                    selected = lang.code
                } label: {
                    if selected == lang.code {
                        Label("\(lang.flag) \(lang.label)", systemImage: "checkmark")
                    } else {
                        Text("\(lang.flag) \(lang.label)")
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(current.flag)
                    .font(.system(size: 12))
                Text(current.code.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.80))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.30))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.03))
                    .overlay(Capsule().stroke(VitaColors.accent.opacity(0.18), lineWidth: 0.5))
            )
            .contentShape(Capsule())
        }
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }
}

// MARK: - Pause/Resume Button

struct TranscricaoPauseResumeButton: View {
    let isPaused: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 10, weight: .bold))
                Text(isPaused ? "Retomar" : "Pausar")
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(VitaColors.accentHover.opacity(0.88))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(VitaColors.accent.opacity(0.10)))
            .overlay(Capsule().stroke(VitaColors.accent.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared helpers

/// Shortens long discipline names for the picker chip + row labels.
/// Shared with the filter chips in the recordings list.
func abbreviateDiscipline(_ name: String) -> String {
    let prepositions: Set<String> = ["de", "do", "da", "dos", "das", "em", "e", "a", "o", "na", "no", "para"]

    let words: [String] = name.lowercased().split(separator: " ").compactMap { segment in
        let w = String(segment)
        if prepositions.contains(w) { return nil }
        if w.allSatisfy({ "ivxlcdm".contains($0) }) && !w.isEmpty {
            return w.uppercased()
        }
        return w.prefix(1).uppercased() + w.dropFirst()
    }

    let full = words.joined(separator: " ")
    if full.count <= 18 { return full }

    guard let first = words.first else { return full }
    if words.count == 1 {
        return String(first.prefix(16)) + "."
    }

    var result = first
    if result.count > 12 {
        result = String(first.prefix(4)) + "."
    }

    for i in 1..<words.count {
        let w = words[i]
        let candidate = result + " " + w
        if candidate.count <= 18 {
            result = candidate
        } else if w.count <= 3 && w.allSatisfy({ "IVX".contains($0) }) {
            result += " " + w
        } else {
            break
        }
    }
    return result
}
