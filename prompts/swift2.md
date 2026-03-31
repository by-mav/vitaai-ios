Voce eh SWIFT-2: UI/UX. Corrija TODOS os bugs visuais abaixo no VitaAI iOS. Edite os arquivos diretamente.

1. TEXTO INVISIVEL DARK MODE: EstudosScreen.swift:471 e :560 - Color.black sobre fundo escuro. Trocar por cor adequada do VitaColors.

2. BOTAO MORTO: AssinaturaScreen.swift:141-149 - Button(action: {}) no Escolher Plano. Implementar navegacao real.

3. TOUCH TARGETS menores que 44pt: VitaTopBar.swift:165 (36x36), VitaTabBar.swift:104 (42x42), ColorPickerView.swift:61,82, AnnotationToolbar.swift:96,196, EditorScreen.swift:149-195, NotificationSettingsScreen.swift:326,381, VitaXpBar.swift:131,146. Adicionar .frame(minWidth:44,minHeight:44) em todos.

4. CORES DUPLICADAS: 8 screens redefinem goldPrimary local. Remover e usar VitaColors.gold em: FaculdadeScreen, ProgressoScreen, ProfileScreen, ConnectionsScreen, DisciplineDetailScreen, ConfiguracoesScreen, AssinaturaScreen, EstudosScreen.

5. ACESSIBILIDADE: VitaTabBar.swift:74, VitaTopBar.swift:91, AnnotationToolbar.swift:169 - botoes sem accessibilityLabel. Adicionar.

6. ESTADOS AUSENTES: ActivityFeedScreen.swift:97 sem error state, LeaderboardScreen.swift:95 sem loading, PlannerScreen.swift:25 ProgressView infinito, DashboardScreen.swift:120 sem empty state. Adicionar todos.

7. OPACIDADES INVISIVEIS: VitaTabBar.swift:120, SubjectsStep.swift:56, SyncingStep.swift:138 - opacity(0.02) quase invisivel. Subir pra 0.06 minimo.

Apos cada fix, explique brevemente.
