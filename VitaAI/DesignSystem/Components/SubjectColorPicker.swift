import SwiftUI

// MARK: - SubjectColorPicker

struct SubjectColorPicker: View {
    let subjectName: String
    var onColorSelected: ((Color) -> Void)?

    @State private var hexInput: String = ""
    @State private var hexPreview: Color? = nil
    @State private var hexError: Bool = false

    @Environment(\.dismiss) private var dismiss

    private var currentColor: Color {
        SubjectColors.colorFor(subject: subjectName)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 2)
                .fill(VitaColors.glassBorder)
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 18)

            // Title
            HStack {
                Text("Cor da Disciplina")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.40))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)

            // Preset grid — 8 per row
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 8),
                spacing: 10
            ) {
                ForEach(0..<SubjectColors.presets.count, id: \.self) { index in
                    let preset = SubjectColors.presets[index]
                    presetCircle(color: preset)
                }
            }
            .padding(.horizontal, 20)

            // Divider
            Rectangle()
                .fill(VitaColors.glassBorder)
                .frame(height: 1)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

            // Hex input row
            HStack(spacing: 10) {
                // Hex field
                HStack(spacing: 0) {
                    Text("#")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(VitaColors.accent)
                        .padding(.leading, 10)

                    TextField("RRGGBB", text: $hexInput)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(hexError ? VitaColors.dataRed : VitaColors.textPrimary)
                        .keyboardType(.asciiCapable)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .onChange(of: hexInput) { _, newValue in
                            let filtered = newValue.uppercased().filter { "0123456789ABCDEF".contains($0) }
                            let clamped = String(filtered.prefix(6))
                            if clamped != hexInput { hexInput = clamped }
                            if clamped.count == 6 {
                                if let color = SubjectColors.color(fromHexString: clamped) {
                                    hexPreview = color
                                    hexError = false
                                } else {
                                    hexError = true
                                }
                            } else {
                                hexPreview = nil
                                hexError = clamped.count > 0 && clamped.count < 6
                            }
                        }
                        .padding(.vertical, 9)
                        .padding(.trailing, 10)
                }
                .background(VitaColors.surfaceCard.opacity(0.60))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(hexError ? VitaColors.dataRed.opacity(0.50) : VitaColors.glassBorder, lineWidth: 1)
                )

                // Preview circle
                ZStack {
                    Circle()
                        .fill(hexPreview ?? currentColor)
                        .frame(width: 32, height: 32)
                    if hexPreview == nil {
                        Image(systemName: "eyedropper")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.60))
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: hexPreview)

                // Apply button
                Button {
                    applyHex()
                } label: {
                    Text("Aplicar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(hexInput.count == 6 && !hexError ? VitaColors.accent : VitaColors.textWarm.opacity(0.35))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(VitaColors.surfaceCard.opacity(0.60))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(VitaColors.glassBorder, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .disabled(hexInput.count != 6 || hexError)
            }
            .padding(.horizontal, 20)

            // Reset button
            Button {
                SubjectColors.resetColor(for: subjectName)
                onColorSelected?(SubjectColors.colorFor(subject: subjectName))
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11))
                    Text("Resetar para cor automatica")
                        .font(.system(size: 13))
                }
                .foregroundStyle(VitaColors.textWarm.opacity(0.45))
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .background(VitaColors.surfaceCard.opacity(0.97))
    }

    // MARK: - Preset circle

    private func presetCircle(color: Color) -> some View {
        let isSelected = isCurrentColor(color)
        return Button {
            SubjectColors.setCustomColor(color, for: subjectName)
            onColorSelected?(color)
            dismiss()
        } label: {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 32, height: 32)

                if isSelected {
                    Circle()
                        .stroke(Color.white.opacity(0.90), lineWidth: 2)
                        .frame(width: 34, height: 34)

                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func isCurrentColor(_ color: Color) -> Bool {
        let uiA = UIColor(currentColor)
        let uiB = UIColor(color)
        var rA: CGFloat = 0, gA: CGFloat = 0, bA: CGFloat = 0
        var rB: CGFloat = 0, gB: CGFloat = 0, bB: CGFloat = 0
        uiA.getRed(&rA, green: &gA, blue: &bA, alpha: nil)
        uiB.getRed(&rB, green: &gB, blue: &bB, alpha: nil)
        return abs(rA - rB) < 0.01 && abs(gA - gB) < 0.01 && abs(bA - bB) < 0.01
    }

    private func applyHex() {
        guard hexInput.count == 6, let color = SubjectColors.color(fromHexString: hexInput) else { return }
        SubjectColors.setCustomColor(color, for: subjectName)
        onColorSelected?(color)
        dismiss()
    }
}
