import SwiftUI

struct NotchShape: Shape {
    let notchDepth: CGFloat

    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 360
        let sy = notchDepth / 36

        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 130 * sx, y: 0))
        path.addQuadCurve(to: CGPoint(x: 148 * sx, y: 8 * sy), control: CGPoint(x: 142 * sx, y: 0))
        path.addQuadCurve(to: CGPoint(x: 168 * sx, y: 32 * sy), control: CGPoint(x: 158 * sx, y: 24 * sy))
        path.addQuadCurve(to: CGPoint(x: 180 * sx, y: 36 * sy), control: CGPoint(x: 174 * sx, y: 36 * sy))
        path.addQuadCurve(to: CGPoint(x: 192 * sx, y: 32 * sy), control: CGPoint(x: 186 * sx, y: 36 * sy))
        path.addQuadCurve(to: CGPoint(x: 212 * sx, y: 8 * sy), control: CGPoint(x: 202 * sx, y: 24 * sy))
        path.addQuadCurve(to: CGPoint(x: 230 * sx, y: 0), control: CGPoint(x: 218 * sx, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()

        return path
    }
}
