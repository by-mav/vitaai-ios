import SwiftUI
import Sentry

// MARK: - FaculdadeDisciplinasScreen
//
// Full list of user's disciplines with navigation to detail.
// Route: Faculdade → Disciplinas → [tap] → DisciplineDetailScreen

struct FaculdadeDisciplinasScreen: View {
    @Environment(\.appData) private var appData
    @Environment(Router.self) private var router

    // Rename sheet state
    @State private var renameTarget: RenameTarget?

    private var goldPrimary: Color { VitaColors.accentHover }
    private var textWarm: Color { VitaColors.textWarm }
    private var textDim: Color { VitaColors.textWarm.opacity(0.30) }

    private struct RenameTarget: Identifiable {
        let id: String      // academic_subjects.id
        let currentName: String
    }

    var body: some View {
        // Read enrolledDisciplines at the top level so SwiftUI subscribes
        // to changes. Without this, `displayText(for:)` reads it inside a
        // sub-helper and @Observable may not propagate the mutation back
        // to this view's render, leaving renamed cards stuck on old name.
        let _ = appData.enrolledDisciplines.count

        return ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                // Fonte única (/api/subjects): Cursando = em curso, Aprovadas =
                // concluídas — mesma regra de status do backend, notas embutidas.
                // Sem gradesResponse, sem "Catálogo Vita" suplementar (tudo já
                // vem na fonte), sem dedup no cliente (Rafael 2026-07-02).
                let cursando = appData.enrolledDisciplines.sorted {
                    $0.preferredName.localizedCaseInsensitiveCompare($1.preferredName) == .orderedAscending
                }
                let aprovadas = appData.completedDisciplines.sorted {
                    $0.preferredName.localizedCaseInsensitiveCompare($1.preferredName) == .orderedAscending
                }

                if cursando.isEmpty && aprovadas.isEmpty {
                    emptyState
                } else {
                    if !cursando.isEmpty {
                        sectionHeader("Cursando", count: cursando.count)
                        academicDisciplinesList(cursando)
                    }

                    if !aprovadas.isEmpty {
                        sectionHeader("Aprovadas", count: aprovadas.count)
                            .padding(.top, cursando.isEmpty ? 0 : 8)
                        academicDisciplinesList(aprovadas)
                    }
                }

                Spacer().frame(height: 100)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .refreshable { await appData.forceRefresh() }
        .onAppear { SentrySDK.reportFullyDisplayed() }
        .trackScreen("FaculdadeDisciplinas")
        .sheet(item: $renameTarget) { target in
            VitaSheet(detents: [.height(260)]) {
                RenameSubjectSheet(
                    subjectId: target.id,
                    currentName: target.currentName,
                    initialDisplayName: appData.enrolledDisciplines
                        .first(where: { $0.id == target.id })?.displayName
                )
            }
        }
    }

    // Resolve the best name for a subject row: user edit > catalog > portal.
    private func displayText(for subject: AcademicSubject) -> String {
        subject.displayName ?? subject.canonicalName ?? subject.name
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "graduationcap")
                .font(.system(size: 44))
                .foregroundStyle(goldPrimary.opacity(0.40))
            Text("Sem disciplinas sincronizadas")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VitaColors.textPrimary)
            Text("Conecte seu portal acadêmico para ver suas disciplinas.")
                .font(.system(size: 12))
                .foregroundStyle(textDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.8)
                .foregroundStyle(VitaColors.sectionLabel)
            Text("\(count)")
                .font(.system(size: 10, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(textDim)
            Spacer()
        }
    }

    // MARK: - List

    private func academicDisciplinesList(_ subjects: [AcademicSubject]) -> some View {
        VStack(spacing: 8) {
            ForEach(subjects) { subject in
                ZStack(alignment: .topTrailing) {
                    Button {
                        router.navigate(to: .disciplineDetail(
                            disciplineId: subject.id,
                            disciplineName: displayText(for: subject)
                        ))
                    } label: {
                        disciplineCard(subject)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            renameTarget = RenameTarget(
                                id: subject.id,
                                currentName: displayText(for: subject)
                            )
                        } label: {
                            Label("Renomear", systemImage: "pencil")
                        }
                    }

                    // Affordance explícito de "mais ações" (renomear) — long-press
                    // não é descobrível, ainda mais no Simulador. Estilo Notion/Files.
                    Menu {
                        Button {
                            renameTarget = RenameTarget(
                                id: subject.id,
                                currentName: displayText(for: subject)
                            )
                        } label: {
                            Label("Renomear", systemImage: "pencil")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .offset(x: -4, y: 4)
                    .accessibilityLabel("Mais ações da disciplina")
                }
            }
        }
    }

    // MARK: - Card

    private func disciplineCard(_ subject: AcademicSubject) -> some View {
        let color = SubjectColors.colorFor(subject: subject.canonicalName ?? subject.name)
        let rendered = displayText(for: subject)
        let shortName = rendered
            .replacingOccurrences(of: "(?i),.*$", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        return HStack(spacing: 12) {
            Rectangle()
                .fill(color)
                .frame(width: 3, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            VStack(alignment: .leading, spacing: 2) {
                Text(shortName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(textWarm.opacity(0.90))
                    .lineLimit(1)

                if let count = subject.questionCount, count > 0 {
                    miniStat("Questões", value: "\(count)")
                } else if let area = subject.area, !area.isEmpty {
                    Text(area.capitalized)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(textDim)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(textWarm.opacity(0.20))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(VitaColors.surfaceCard.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(VitaColors.textWarm.opacity(0.06), lineWidth: 0.5)
        )
    }

    private func miniStat(_ label: String, value: String) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(textDim)
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(textWarm.opacity(0.70))
        }
    }
}
