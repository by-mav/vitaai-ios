import SwiftUI

struct VitaMenuSheet: View {
    let onProfile: () -> Void
    let onConfiguracoes: () -> Void
    let onConectores: () -> Void
    let onAssinatura: () -> Void
    let onSobre: () -> Void
    let onLogout: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showLogoutConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            // Header
            HStack {
                Text("Menu")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(VitaColors.white)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(VitaColors.textTertiary)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Fechar")
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 16)

            // Menu items
            VStack(spacing: 2) {
                menuItem(icon: "person.crop.circle", label: "Perfil") {
                    dismiss()
                    onProfile()
                }
                menuItem(icon: "gearshape", label: "Configurações") {
                    dismiss()
                    onConfiguracoes()
                }
                menuItem(icon: "link", label: "Conectores") {
                    dismiss()
                    onConectores()
                }
                menuItem(icon: "creditcard", label: "Assinatura") {
                    dismiss()
                    onAssinatura()
                }
                menuItem(icon: "info.circle", label: "Sobre") {
                    dismiss()
                    onSobre()
                }
            }
            .padding(.horizontal, 16)

            Spacer()

            // Logout
            Button(action: { showLogoutConfirm = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 16))
                    Text("Sair da conta")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(VitaColors.dataRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(VitaColors.dataRed.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(red: 0.04, green: 0.03, blue: 0.05).opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(VitaColors.glassBorder, lineWidth: 1)
                )
        )
        .alert("Sair da conta?", isPresented: $showLogoutConfirm) {
            Button("Cancelar", role: .cancel) {}
            Button("Sair", role: .destructive) {
                dismiss()
                onLogout()
            }
        } message: {
            Text("Você será desconectado do VitaAI.")
        }
    }

    @ViewBuilder
    private func menuItem(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(VitaColors.accent)
                    .frame(width: 24, alignment: .center)

                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(VitaColors.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.001)) // tap area
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
