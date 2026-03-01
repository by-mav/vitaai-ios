import SwiftUI

// MARK: - EstudosScreen

struct EstudosScreen: View {
    @Environment(\.appContainer) private var container
    @State private var viewModel: EstudosViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                ProgressView()
                    .tint(VitaColors.accent)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = EstudosViewModel(api: container.api)
                Task { await viewModel?.load() }
            }
        }
    }

    @ViewBuilder
    private func content(viewModel: EstudosViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // 1. Stats Row
                EstudosStatsRow(
                    flashcardsDue: viewModel.flashcardsDue,
                    streakDays: viewModel.streakDays,
                    avgAccuracy: viewModel.avgAccuracy
                )

                // 2. Flashcards Section
                FlashcardsSection(decks: viewModel.flashcardDecks)

                // 3. Simulados Section
                SimuladosSection(simulados: viewModel.simulados)

                // 4. Documentos Section
                DocumentosSection(documents: viewModel.documents)

                // 5. Notas Section
                NotasSection(notes: viewModel.notes)

                Spacer().frame(height: 100) // tab bar clearance
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .refreshable {
            await viewModel.load()
        }
    }
}

// MARK: - Stats Row

private struct EstudosStatsRow: View {
    let flashcardsDue: Int
    let streakDays: Int
    let avgAccuracy: Double

    var body: some View {
        HStack(spacing: 10) {
            StatCard(
                value: "\(flashcardsDue)",
                label: "Revisões Hoje",
                color: flashcardsDue > 0 ? Color.orange : VitaColors.textPrimary
            )
            StatCard(
                value: "\(streakDays)d",
                label: "Sequência",
                color: streakDays > 0 ? Color.orange : VitaColors.textPrimary
            )
            StatCard(
                value: "\(Int(avgAccuracy))%",
                label: "Precisão",
                color: avgAccuracy >= 70 ? VitaColors.accent : VitaColors.textPrimary
            )
        }
    }
}

private struct StatCard: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VitaGlassCard {
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(color)
                Text(label)
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
        }
    }
}

// MARK: - Flashcards Section

private struct FlashcardsSection: View {
    let decks: [FlashcardDeckEntry]

    var body: some View {
        VStack(spacing: 8) {
            SectionHeader(title: "Flashcards")

            if decks.isEmpty {
                EmptyStateCard(icon: "brain.fill", message: "Nenhum flashcard pendente")
            } else {
                VStack(spacing: 8) {
                    ForEach(decks) { deck in
                        FlashcardDeckRow(deck: deck)
                    }
                }

                Button {
                    // TODO: navigate to flashcard review
                } label: {
                    Text("Revisar Agora")
                        .font(VitaTypography.labelMedium)
                        .foregroundStyle(Color.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
        }
    }
}

private struct FlashcardDeckRow: View {
    let deck: FlashcardDeckEntry

    var body: some View {
        VitaGlassCard {
            HStack(spacing: 12) {
                IconSquare(systemName: "brain.fill")

                VStack(alignment: .leading, spacing: 2) {
                    Text(deck.title)
                        .font(VitaTypography.labelMedium)
                        .foregroundStyle(VitaColors.textPrimary)
                    Text("\(deck.cards.count) para revisar")
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Simulados Section

private struct SimuladosSection: View {
    let simulados: [SimuladoEntry]

    var body: some View {
        VStack(spacing: 8) {
            SectionHeader(title: "Simulados")

            if simulados.isEmpty {
                EmptyStateCard(icon: "list.clipboard.fill", message: "Nenhum simulado realizado")
            } else {
                VStack(spacing: 8) {
                    ForEach(simulados) { simulado in
                        SimuladoRow(simulado: simulado)
                    }
                }

                Button {
                    // TODO: navigate to new simulado
                } label: {
                    Text("Novo Simulado")
                        .font(VitaTypography.labelMedium)
                        .foregroundStyle(Color.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
        }
    }
}

private struct SimuladoRow: View {
    let simulado: SimuladoEntry

    private var scoreBadgeColor: Color {
        let pct = simulado.scorePercent
        if pct >= 70 { return VitaColors.accent }
        if pct >= 50 { return Color.yellow }
        return Color.red.opacity(0.7)
    }

    var body: some View {
        VitaGlassCard {
            HStack(spacing: 12) {
                IconSquare(systemName: "list.clipboard.fill")

                VStack(alignment: .leading, spacing: 2) {
                    Text(simulado.title)
                        .font(VitaTypography.labelMedium)
                        .foregroundStyle(VitaColors.textPrimary)
                    Text("\(simulado.correctQ)/\(simulado.totalQ) questões")
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }

                Spacer()

                Text("\(simulado.scorePercent)%")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(scoreBadgeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(scoreBadgeColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Documentos Section

private struct DocumentosSection: View {
    let documents: [DocumentEntry]

    var body: some View {
        VStack(spacing: 8) {
            SectionHeader(title: "Documentos")

            if documents.isEmpty {
                EmptyStateCard(icon: "doc.fill", message: "Nenhum documento adicionado")
            } else {
                VStack(spacing: 8) {
                    ForEach(documents) { doc in
                        DocumentRow(doc: doc)
                    }
                }
            }
        }
    }
}

private struct DocumentRow: View {
    let doc: DocumentEntry

    var body: some View {
        VitaGlassCard {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    IconSquare(systemName: "doc.fill")

                    VStack(alignment: .leading, spacing: 2) {
                        Text(doc.title)
                            .font(VitaTypography.labelMedium)
                            .foregroundStyle(VitaColors.textPrimary)
                        Text("Pág. \(doc.currentPage)/\(doc.totalPages)")
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textTertiary)
                    }

                    Spacer()

                    // AI sparkle placeholder button
                    Button {
                        // TODO: open AI doc assistant
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                            .foregroundStyle(VitaColors.accent)
                            .padding(6)
                            .background(VitaColors.accent.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Text("\(doc.readProgress)%")
                        .font(VitaTypography.labelSmall)
                        .monospacedDigit()
                        .foregroundStyle(VitaColors.textSecondary)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(VitaColors.surfaceElevated)
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(VitaColors.accent)
                            .frame(
                                width: geo.size.width * CGFloat(doc.readProgress) / 100,
                                height: 3
                            )
                    }
                }
                .frame(height: 3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Notas Section

private struct NotasSection: View {
    let notes: [NoteEntry]

    var body: some View {
        VStack(spacing: 8) {
            SectionHeader(title: "Notas")

            if notes.isEmpty {
                EmptyStateCard(icon: "note.text", message: "Nenhuma nota criada")
            } else {
                VStack(spacing: 8) {
                    ForEach(notes) { note in
                        NoteRow(note: note)
                    }
                }
            }
        }
    }
}

private struct NoteRow: View {
    let note: NoteEntry

    var body: some View {
        VitaGlassCard {
            HStack(spacing: 12) {
                IconSquare(systemName: "note.text")

                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title)
                        .font(VitaTypography.labelMedium)
                        .foregroundStyle(VitaColors.textPrimary)
                    Text(note.content)
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Shared Sub-components

/// Rounded square icon container — shared across all row types in this screen.
private struct IconSquare: View {
    let systemName: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(VitaColors.surfaceElevated)
                .frame(width: 36, height: 36)
            Image(systemName: systemName)
                .font(.system(size: 14))
                .foregroundStyle(VitaColors.textSecondary)
        }
    }
}

/// Full-width empty state card with centered icon + message.
private struct EmptyStateCard: View {
    let icon: String
    let message: String

    var body: some View {
        VitaGlassCard {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(VitaColors.textTertiary)
                Text(message)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 24)
        }
    }
}
