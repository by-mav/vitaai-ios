import SwiftUI

struct FlashcardTopicsScreen: View {
    let deckId: String
    let deckTitle: String
    var onBack: () -> Void
    var onSelectTopic: (String?) -> Void  // tag prefix or nil for "all"

    @Environment(\.appContainer) private var container
    @State private var topics: [FlashcardTopic] = []
    @State private var isLoading = true
    @State private var searchText = ""

    private var totalCards: Int { topics.reduce(0) { $0 + $1.totalCards } }
    private var totalDue: Int { topics.reduce(0) { $0 + $1.dueCount } }

    private var filteredTopics: [FlashcardTopic] {
        guard !searchText.isEmpty else { return topics }
        let q = searchText.lowercased().folding(options: .diacriticInsensitive, locale: nil)
        return topics.filter { $0.name.lowercased().folding(options: .diacriticInsensitive, locale: nil).contains(q) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // Header
                HStack(spacing: 12) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(VitaColors.accentLight.opacity(0.7))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(deckTitle)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.93))
                        Text("\(totalCards) cards \u{00B7} \(totalDue) pendentes")
                            .font(.system(size: 12))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                    }
                    Spacer()
                }
                .padding(.top, 8)
                .padding(.bottom, 20)

                if isLoading {
                    ProgressView()
                        .tint(VitaColors.accentHover)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    // Search bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                        TextField("Buscar tema...", text: $searchText)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.white.opacity(0.90))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(VitaColors.surfaceCard.opacity(0.70))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(VitaColors.glassBorder, lineWidth: 1)
                    )
                    .padding(.bottom, 12)

                    // "Todos os temas" button (hide when searching)
                    if searchText.isEmpty {
                        Button(action: { onSelectTopic(nil) }) {
                            topicRow(name: "Todos os temas", total: totalCards, due: totalDue, isAll: true)
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 6)
                    }

                    // Individual topics
                    ForEach(filteredTopics.filter { $0.name != "Sem tema" }) { topic in
                        Button(action: {
                            onSelectTopic(topic.tags.first)
                        }) {
                            topicRow(name: cleanTopicName(topic.name), total: topic.totalCards, due: topic.dueCount, isAll: false)
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 4)
                    }

                    // "Sem tema" at the bottom if exists (hide when searching)
                    if searchText.isEmpty, let noTopic = topics.first(where: { $0.name == "Sem tema" }), noTopic.totalCards > 0 {
                        Button(action: { onSelectTopic("__none__") }) {
                            topicRow(name: "Sem tema", total: noTopic.totalCards, due: noTopic.dueCount, isAll: false)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                }

                Spacer().frame(height: 130)
            }
            .padding(.horizontal, 16)
        }
        .refreshable {
            do {
                topics = try await container.api.getFlashcardTopics(deckId: deckId)
            } catch {
                print("[FlashcardTopics] refresh error: \(error)")
            }
        }
        .task {
            do {
                topics = try await container.api.getFlashcardTopics(deckId: deckId)
            } catch {
                print("[FlashcardTopics] error: \(error)")
            }
            isLoading = false
        }
    }

    // MARK: - Topic Row

    private func topicRow(name: String, total: Int, due: Int, isAll: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isAll ? "square.stack.3d.up.fill" : "tag.fill")
                .font(.system(size: 14))
                .foregroundStyle(isAll ? VitaColors.accent : VitaColors.accentLight.opacity(0.6))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(isAll ? 0.95 : 0.82))
                    .lineLimit(2)
                Text("\(total) cards\(due > 0 ? " \u{00B7} \(due) pendentes" : "")")
                    .font(.system(size: 11))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.40))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VitaColors.accentLight.opacity(0.3))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            VitaColors.surfaceCard.opacity(isAll ? 0.90 : 0.80),
                            VitaColors.surfaceElevated.opacity(isAll ? 0.85 : 0.75)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(VitaColors.accentHover.opacity(isAll ? 0.18 : 0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
    }

    // MARK: - Helpers

    /// Topic names come pre-translated from the backend. Just pass through.
    private func cleanTopicName(_ name: String) -> String {
        name
    }
}
