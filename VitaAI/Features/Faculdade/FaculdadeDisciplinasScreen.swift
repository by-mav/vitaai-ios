import SwiftUI
import Sentry

// MARK: - FaculdadeDisciplinasScreen — lista COMPLETA de disciplinas (CANON)
//
// Rafael 2026-07-15: UI unificada. Usa o MESMO card das pastas do FaculdadeHome
// (DisciplineFolderCard) — a UI de row simples anterior foi aposentada, sem
// duplicata. CRUD completo por pasta (renomear · trocar cor · excluir) + botão
// "+ Adicionar". Fonte única /api/subjects: manual E Canvas caem aqui.
// Rota .faculdadeDisciplinas (o "Ver todas" do Estudos e do Jornada abrem aqui).

struct FaculdadeDisciplinasScreen: View {
    @Environment(\.appData) private var appData
    @Environment(Router.self) private var router

    // Reusa os MESMOS componentes/handlers do FaculdadeHome (1 cérebro).
    @State private var renameTarget: SubjectActionTarget?
    @State private var colorTarget: SubjectActionTarget?
    @State private var deleteTarget: SubjectActionTarget?
    @State private var colorRefreshTrigger = UUID()
    @State private var showAdd = false
    @State private var newName = ""

    private var goldPrimary: Color { VitaColors.accentHover }
    private var textDim: Color { VitaColors.textWarm.opacity(0.30) }

    private struct SubjectActionTarget: Identifiable {
        let id: String
        let name: String
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        // Subscreve a mudanças (renomear) pra re-render — mesmo motivo do FaculdadeHome.
        let _ = appData.enrolledDisciplines.count

        return ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                let cursando = sortedByFavorite(appData.enrolledDisciplines)
                let aprovadas = sortedByFavorite(appData.completedDisciplines)

                if cursando.isEmpty && aprovadas.isEmpty {
                    emptyState
                } else {
                    if !cursando.isEmpty {
                        section("Cursando", subjects: cursando, showAddButton: true)
                    }
                    if !aprovadas.isEmpty {
                        section("Aprovadas", subjects: aprovadas, showAddButton: false)
                    }
                }
                Spacer().frame(height: 100)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .id(colorRefreshTrigger)
        }
        .refreshable { await appData.forceRefresh() }
        .onAppear { SentrySDK.reportFullyDisplayed() }
        .trackScreen("FaculdadeDisciplinas")
        .sheet(item: $renameTarget) { t in
            VitaSheet(detents: [.height(260)]) {
                RenameSubjectSheet(
                    subjectId: t.id,
                    currentName: t.name,
                    initialDisplayName: appData.enrolledDisciplines
                        .first(where: { $0.id == t.id })?.displayName
                )
            }
        }
        .sheet(item: $colorTarget) { t in
            VitaSheet(detents: [.height(380)]) {
                SubjectColorPicker(subjectName: t.name) { _ in colorRefreshTrigger = UUID() }
                    .padding(20)
            }
        }
        .confirmationDialog(
            "Excluir disciplina?",
            isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
            titleVisibility: .visible,
            presenting: deleteTarget
        ) { t in
            Button("Excluir", role: .destructive) {
                let id = t.id
                Task { try? await appData.removeDiscipline(id: id) }
                deleteTarget = nil
            }
            Button("Cancelar", role: .cancel) { deleteTarget = nil }
        } message: { t in
            Text("Isso remove \(t.name) e o que está ligado a ela.")
        }
        .alert("Nova disciplina", isPresented: $showAdd) {
            TextField("Nome da disciplina", text: $newName)
            Button("Adicionar") {
                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                newName = ""
                guard !name.isEmpty else { return }
                Task { _ = try? await appData.addManualDiscipline(name: name) }
            }
            Button("Cancelar", role: .cancel) { newName = "" }
        } message: {
            Text("Cria uma disciplina manual. As do portal (Canvas) entram sozinhas.")
        }
    }

    // MARK: - Seção (header + "+ Adicionar" + grid de pastas)

    private func section(_ title: String, subjects: [AcademicSubject], showAddButton: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))  // ds-allow: chrome de disciplina (consistente com FaculdadeHome)
                    .kerning(0.8)
                    .foregroundStyle(VitaColors.sectionLabel)
                Text("\(subjects.count)")
                    .font(.system(size: 10, weight: .bold))  // ds-allow: chrome de disciplina (consistente com FaculdadeHome)
                    .monospacedDigit()
                    .foregroundStyle(textDim)
                Spacer()
                if showAddButton {
                    Button { showAdd = true } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "plus")
                                .font(.system(size: 9, weight: .bold))  // ds-allow: chrome de disciplina (consistente com FaculdadeHome)
                            Text("Adicionar")
                                .font(.system(size: 10, weight: .semibold))  // ds-allow: chrome de disciplina (consistente com FaculdadeHome)
                        }
                        .foregroundStyle(goldPrimary.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                }
            }
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(subjects) { subject in
                    folderCard(subject)
                }
            }
        }
    }

    // MARK: - Card de pasta (canon) + menu de ações

    private func folderCard(_ subject: AcademicSubject) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                router.navigate(to: .disciplineDetail(
                    disciplineId: subject.id,
                    disciplineName: subject.preferredName
                ))
            } label: {
                DisciplineFolderCard(
                    subjectName: subject.preferredName,
                    itemCount: appData.materialsTotal(forSubjectId: subject.id)
                )
            }
            .buttonStyle(.plain)
            .contextMenu { menuActions(subject) }

            // "..." explícito (long-press não é descobrível). Estilo Notion/Files.
            Menu { menuActions(subject) } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))  // ds-allow: chrome de disciplina (consistente com FaculdadeHome)
                    .foregroundStyle(VitaColors.textWarm.opacity(0.5))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .offset(x: -2, y: 2)
            .accessibilityLabel("Mais ações da disciplina")
        }
    }

    @ViewBuilder private func menuActions(_ subject: AcademicSubject) -> some View {
        Button {
            renameTarget = SubjectActionTarget(id: subject.id, name: subject.preferredName)
        } label: { Label("Renomear", systemImage: "pencil") }
        Button {
            colorTarget = SubjectActionTarget(id: subject.id, name: subject.preferredName)
        } label: { Label("Trocar cor", systemImage: "paintpalette") }
        Button(role: .destructive) {
            deleteTarget = SubjectActionTarget(id: subject.id, name: subject.preferredName)
        } label: { Label("Excluir", systemImage: "trash") }
    }

    // Favoritos primeiro, depois alfabético — igual FaculdadeHome.
    private func sortedByFavorite(_ subjects: [AcademicSubject]) -> [AcademicSubject] {
        let favs = DisciplineFolderCard.favorites()
        return subjects.sorted { a, b in
            let aFav = favs.contains(a.preferredName)
            let bFav = favs.contains(b.preferredName)
            if aFav != bFav { return aFav }
            return a.preferredName.localizedCaseInsensitiveCompare(b.preferredName) == .orderedAscending
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "graduationcap")
                .font(.system(size: 44))  // ds-allow: chrome de disciplina (consistente com FaculdadeHome)
                .foregroundStyle(goldPrimary.opacity(0.40))
            Text("Sem disciplinas ainda")
                .font(.system(size: 15, weight: .semibold))  // ds-allow: chrome de disciplina (consistente com FaculdadeHome)
                .foregroundStyle(VitaColors.textPrimary)
            Text("Conecte seu portal ou toque em “Adicionar” pra criar uma disciplina.")
                .font(.system(size: 12))  // ds-allow: chrome de disciplina (consistente com FaculdadeHome)
                .foregroundStyle(textDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button { showAdd = true } label: {
                Text("Adicionar disciplina")
                    .font(.system(size: 13, weight: .semibold))  // ds-allow: chrome de disciplina (consistente com FaculdadeHome)
                    .foregroundStyle(VitaColors.accentHover)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(Capsule().fill(VitaColors.accentHover.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}
