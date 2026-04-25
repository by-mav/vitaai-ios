import UIKit
import PDFKit

/// Goodnotes-style floating action toolbar that appears above a selected
/// freeText annotation. 5 buttons: heading presets, color picker, copy,
/// trash, ellipsis (more). Heading + color use native UIMenu (responsive,
/// no extra sheet boilerplate).
///
/// Lifecycle: PdfFreeTextSelectionOverlay creates and positions this above
/// itself when selection becomes active. Callbacks mutate the annotation
/// in-place; overlay forces a redraw cycle.
final class PdfFreeTextSelectionToolbar: UIView {

    // MARK: - Public callbacks

    /// Apply a font preset (size + weight). H1=32 bold, H2=24 bold,
    /// H3=20 semibold, H4=17 semibold, Body=15 regular, Caption=12 regular.
    var onSetHeading: ((CGFloat, UIFont.Weight) -> Void)?
    /// Replace fontColor (text color).
    var onSetColor: ((UIColor) -> Void)?
    /// Toggle annotation background — false = transparent (default), true = opaque dark.
    var onSetOpaqueBackground: ((Bool) -> Void)?
    /// Copy annotation contents to UIPasteboard.
    var onCopy: (() -> Void)?
    /// Delete the annotation entirely.
    var onDelete: (() -> Void)?
    /// More menu — duplicate, future actions.
    var onDuplicate: (() -> Void)?

    // MARK: - Init

    init() {
        super.init(frame: .zero)
        backgroundColor = UIColor(white: 0.10, alpha: 0.92)
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = UIColor(red: 1.0, green: 0.784, blue: 0.471, alpha: 0.40).cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 4)

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment = .center
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
        ])

        // Heading presets — UIMenu primary action
        stack.addArrangedSubview(makeMenuButton(symbol: "textformat.size", menu: makeHeadingMenu()))
        stack.addArrangedSubview(makeSeparator())

        // Color picker — UIMenu with palette + bg toggle
        stack.addArrangedSubview(makeMenuButton(symbol: "circle.lefthalf.filled.righthalf.striped.horizontal", menu: makeColorMenu()))
        stack.addArrangedSubview(makeSeparator())

        // Copy
        stack.addArrangedSubview(makeButton(symbol: "doc.on.doc", action: #selector(copyTapped)))
        // Trash
        stack.addArrangedSubview(makeButton(symbol: "trash", tint: .systemRed, action: #selector(deleteTapped)))
        // More menu
        stack.addArrangedSubview(makeMenuButton(symbol: "ellipsis", menu: makeMoreMenu()))
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Button factories

    private static let goldTint = UIColor(red: 1.0, green: 0.784, blue: 0.471, alpha: 1.0)

    private func makeButton(symbol: String, tint: UIColor = PdfFreeTextSelectionToolbar.goldTint, action: Selector) -> UIButton {
        let cfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: symbol, withConfiguration: cfg), for: .normal)
        btn.tintColor = tint
        btn.addTarget(self, action: action, for: .touchUpInside)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.widthAnchor.constraint(equalToConstant: 36).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 32).isActive = true
        return btn
    }

    private func makeMenuButton(symbol: String, menu: UIMenu) -> UIButton {
        let cfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: symbol, withConfiguration: cfg), for: .normal)
        btn.tintColor = PdfFreeTextSelectionToolbar.goldTint
        btn.menu = menu
        btn.showsMenuAsPrimaryAction = true
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.widthAnchor.constraint(equalToConstant: 36).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 32).isActive = true
        return btn
    }

    private func makeSeparator() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor(white: 1.0, alpha: 0.15)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.widthAnchor.constraint(equalToConstant: 1).isActive = true
        v.heightAnchor.constraint(equalToConstant: 18).isActive = true
        return v
    }

    // MARK: - Menus

    private func makeHeadingMenu() -> UIMenu {
        let presets: [(label: String, size: CGFloat, weight: UIFont.Weight)] = [
            ("H1 Heading 1", 32, .bold),
            ("H2 Heading 2", 24, .bold),
            ("H3 Heading 3", 20, .semibold),
            ("H4 Heading 4", 17, .semibold),
            ("Body",         15, .regular),
            ("Caption",      12, .regular),
        ]
        let actions = presets.map { p in
            UIAction(title: p.label) { [weak self] _ in
                self?.onSetHeading?(p.size, p.weight)
            }
        }
        return UIMenu(title: "Estilo de texto", children: actions)
    }

    private func makeColorMenu() -> UIMenu {
        // Vita palette + medical accent + grayscale. UIMenu shows colored circles
        // when image: is set with alwaysOriginal rendering.
        let swatches: [(name: String, color: UIColor)] = [
            ("Gold",      UIColor(red: 1.0, green: 0.784, blue: 0.471, alpha: 1)),
            ("Branco",    .white),
            ("Preto",     .black),
            ("Vermelho",  UIColor(red: 0.95, green: 0.30, blue: 0.30, alpha: 1)),
            ("Verde",     UIColor(red: 0.20, green: 0.75, blue: 0.40, alpha: 1)),
            ("Azul",      UIColor(red: 0.30, green: 0.55, blue: 0.95, alpha: 1)),
            ("Roxo",      UIColor(red: 0.65, green: 0.40, blue: 0.90, alpha: 1)),
            ("Laranja",   UIColor(red: 0.98, green: 0.60, blue: 0.20, alpha: 1)),
        ]

        let colorActions = swatches.map { swatch in
            let img = Self.swatchImage(color: swatch.color)
            return UIAction(title: swatch.name, image: img) { [weak self] _ in
                self?.onSetColor?(swatch.color)
            }
        }

        let bgGroup = UIMenu(options: .displayInline, children: [
            UIAction(title: "Fundo transparente", image: UIImage(systemName: "square.dashed")) { [weak self] _ in
                self?.onSetOpaqueBackground?(false)
            },
            UIAction(title: "Fundo opaco", image: UIImage(systemName: "square.fill")) { [weak self] _ in
                self?.onSetOpaqueBackground?(true)
            },
        ])

        let colorGroup = UIMenu(options: .displayInline, children: colorActions)
        return UIMenu(title: "Cor & fundo", children: [colorGroup, bgGroup])
    }

    private func makeMoreMenu() -> UIMenu {
        return UIMenu(title: "", children: [
            UIAction(title: "Duplicar", image: UIImage(systemName: "plus.square.on.square")) { [weak self] _ in
                self?.onDuplicate?()
            },
        ])
    }

    private static func swatchImage(color: UIColor, size: CGFloat = 18) -> UIImage {
        let r = CGRect(x: 0, y: 0, width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: r.size)
        let img = renderer.image { ctx in
            color.setFill()
            UIBezierPath(ovalIn: r.insetBy(dx: 1, dy: 1)).fill()
            UIColor.white.withAlphaComponent(0.35).setStroke()
            let stroke = UIBezierPath(ovalIn: r.insetBy(dx: 1, dy: 1))
            stroke.lineWidth = 1
            stroke.stroke()
        }
        return img.withRenderingMode(.alwaysOriginal)
    }

    // MARK: - Direct actions

    @objc private func copyTapped() { onCopy?() }
    @objc private func deleteTapped() { onDelete?() }
}
