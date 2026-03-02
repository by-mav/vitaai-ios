import SwiftUI

struct StudyModulesGrid: View {
    let modules: [StudyModule]
    var onModuleTap: ((StudyModule) -> Void)?

    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(modules) { module in
                Button {
                    onModuleTap?(module)
                } label: {
                    VitaGlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: module.icon)
                                .font(.system(size: 24))
                                .foregroundStyle(module.color)

                            Text(module.name)
                                .font(VitaTypography.bodyMedium)
                                .fontWeight(.medium)
                                .foregroundStyle(VitaColors.textPrimary)

                            Text("\(module.count)")
                                .font(VitaTypography.headlineSmall)
                                .foregroundStyle(module.color)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }
}
