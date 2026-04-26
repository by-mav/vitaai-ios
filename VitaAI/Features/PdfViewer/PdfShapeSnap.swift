import Foundation
import PencilKit
import CoreGraphics

// MARK: - PdfShapeSnap
//
// Snap-on-pause shape recognition (Goodnotes 6 / Notability pattern).
// Quando o usuário solta a caneta, o último stroke é analisado:
//   - É uma linha reta? Substitui por stroke linear perfeito (2 pontos).
//   - É um círculo? Substitui por círculo perfeito (32 pontos parametrizados).
//
// Threshold conservador (residuals normalizados <= 0.05) — só substitui se
// tiver alta confiança. Senão, mantém o stroke original do usuário (zero
// regressão).
//
// Algoritmos:
//   - Linha reta: regressão linear least-squares + cálculo de residual médio.
//   - Círculo: algebraic least-squares circle fit (Pratt's variant) — fast,
//     numericamente estável, sem dependência externa.
//
// Refs open-source:
//   - https://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm
//   - https://www.scribd.com/document/14819165/Circle-Fitting-LMS-Pratt-1987

enum PdfShapeSnap {

    /// Resultado da detecção.
    enum Result {
        case none
        case line(start: CGPoint, end: CGPoint)
        case circle(center: CGPoint, radius: CGFloat)
    }

    /// Configuração de threshold. Valores mais altos = mais permissivo (pega
    /// mais shapes mas com mais falsos positivos). Default conservador.
    struct Config {
        /// Mínimo de pontos pra considerar tentativa de snap (descarta micro-strokes).
        var minPoints: Int = 8
        /// Resíduo máximo (normalizado pelo bounding box) pra aceitar como linha.
        var lineResidualThreshold: CGFloat = 0.04
        /// Resíduo máximo pra aceitar como círculo.
        var circleResidualThreshold: CGFloat = 0.05
        /// Razão mínima pra considerar círculo (perimetro / hipotenuse_bbox).
        /// Círculo fechado tem ratio > 2.5 — descarta arcos abertos.
        var circleClosureRatio: CGFloat = 2.0

        static let `default` = Config()
    }

    /// Detecta a melhor shape pra um stroke. Retorna `.none` se nada bater no
    /// threshold (caller mantém o stroke original).
    static func detect(stroke: PKStroke, config: Config = .default) -> Result {
        let points = stroke.path.map { $0.location }
        guard points.count >= config.minPoints else { return .none }

        // Tenta linha primeiro (mais barato + mais comum).
        if let line = tryLine(points: points, threshold: config.lineResidualThreshold) {
            return .line(start: line.start, end: line.end)
        }

        // Tenta círculo (mais caro, requer pontos suficientes pra fit estável).
        if points.count >= 12,
           let circle = tryCircle(points: points,
                                  residualThreshold: config.circleResidualThreshold,
                                  closureRatio: config.circleClosureRatio) {
            return .circle(center: circle.center, radius: circle.radius)
        }

        return .none
    }

    /// Constrói um PKStroke geométrico limpo a partir de um Result, herdando o
    /// `ink` (cor + largura) do stroke original do usuário pra preservar estilo.
    static func makeReplacementStroke(for result: Result, ink: PKInk) -> PKStroke? {
        switch result {
        case .none:
            return nil
        case let .line(start, end):
            return makeLineStroke(start: start, end: end, ink: ink)
        case let .circle(center, radius):
            return makeCircleStroke(center: center, radius: radius, ink: ink)
        }
    }

    // MARK: - Algoritmos privados

    /// Tenta ajustar uma reta aos pontos via least-squares. Retorna start/end
    /// projetados sobre a reta, com resíduo médio normalizado pelo bbox.
    private static func tryLine(points: [CGPoint], threshold: CGFloat) -> (start: CGPoint, end: CGPoint)? {
        let n = CGFloat(points.count)
        var sumX: CGFloat = 0, sumY: CGFloat = 0, sumXX: CGFloat = 0, sumXY: CGFloat = 0
        for p in points {
            sumX += p.x; sumY += p.y
            sumXX += p.x * p.x; sumXY += p.x * p.y
        }
        let denom = n * sumXX - sumX * sumX
        guard abs(denom) > 1e-6 else {
            // Linha vertical — fallback: pega pontos extremos no eixo Y.
            if let minY = points.min(by: { $0.y < $1.y }),
               let maxY = points.max(by: { $0.y < $1.y }),
               abs(maxY.y - minY.y) > 10 {
                return (minY, maxY)
            }
            return nil
        }
        let slope = (n * sumXY - sumX * sumY) / denom
        let intercept = (sumY - slope * sumX) / n

        // Resíduo médio (distância perpendicular dos pontos à reta y = mx + b).
        // d = |y - (mx + b)| / sqrt(1 + m^2)
        let denomDist = sqrt(1 + slope * slope)
        var residualSum: CGFloat = 0
        for p in points {
            residualSum += abs(p.y - (slope * p.x + intercept)) / denomDist
        }
        let avgResidual = residualSum / n

        // Normaliza pelo tamanho do bbox.
        let bbox = boundingBox(points)
        let bboxDiag = hypot(bbox.width, bbox.height)
        guard bboxDiag > 1 else { return nil }
        let normResidual = avgResidual / bboxDiag

        guard normResidual <= threshold else { return nil }

        // Projeta primeiro e último ponto sobre a reta pra obter endpoints
        // perfeitos.
        let first = points.first!
        let last = points.last!
        let projFirst = projectOntoLine(point: first, slope: slope, intercept: intercept)
        let projLast = projectOntoLine(point: last, slope: slope, intercept: intercept)
        return (projFirst, projLast)
    }

    /// Algebraic least-squares circle fit. Retorna center+radius+resíduo.
    /// Algoritmo: minimiza ||A·x = b||^2 onde A = [2x, 2y, 1], x = [a, b, c],
    /// b = x²+y². Center = (a, b), radius = sqrt(c + a² + b²).
    private static func tryCircle(points: [CGPoint],
                                  residualThreshold: CGFloat,
                                  closureRatio: CGFloat) -> (center: CGPoint, radius: CGFloat)? {
        // Validação de fechamento — círculos têm perímetro >> hipotenusa do bbox.
        let perim = pathLength(points)
        let bbox = boundingBox(points)
        let bboxDiag = hypot(bbox.width, bbox.height)
        guard bboxDiag > 1, perim / bboxDiag >= closureRatio else { return nil }

        // Monta sistema A·x = b (3x3 normal equations).
        var s00: CGFloat = 0, s01: CGFloat = 0, s02: CGFloat = 0
        var s11: CGFloat = 0, s12: CGFloat = 0
        var b0: CGFloat = 0, b1: CGFloat = 0, b2: CGFloat = 0
        let n = CGFloat(points.count)
        for p in points {
            let x = p.x, y = p.y
            let r2 = x * x + y * y
            s00 += 4 * x * x
            s01 += 4 * x * y
            s02 += 2 * x
            s11 += 4 * y * y
            s12 += 2 * y
            b0 += 2 * x * r2
            b1 += 2 * y * r2
            b2 += r2
        }
        let s22 = n
        // Resolve via Cramer (3x3 — pequeno, estável).
        let det = s00 * (s11 * s22 - s12 * s12)
                - s01 * (s01 * s22 - s12 * s02)
                + s02 * (s01 * s12 - s11 * s02)
        guard abs(det) > 1e-6 else { return nil }
        let a = (b0 * (s11 * s22 - s12 * s12)
                - s01 * (b1 * s22 - s12 * b2)
                + s02 * (b1 * s12 - s11 * b2)) / det
        let bC = (s00 * (b1 * s22 - s12 * b2)
                - b0 * (s01 * s22 - s12 * s02)
                + s02 * (s01 * b2 - b1 * s02)) / det
        let c = (s00 * (s11 * b2 - b1 * s12)
                - s01 * (s01 * b2 - b1 * s02)
                + b0 * (s01 * s12 - s11 * s02)) / det

        let center = CGPoint(x: a, y: bC)
        let radiusSq = c + a * a + bC * bC
        guard radiusSq > 1 else { return nil }
        let radius = sqrt(radiusSq)

        // Resíduo médio: |distância(p, center) - radius|, normalizado pelo radius.
        var residualSum: CGFloat = 0
        for p in points {
            let d = hypot(p.x - center.x, p.y - center.y)
            residualSum += abs(d - radius)
        }
        let avgResidual = residualSum / n
        let normResidual = avgResidual / radius

        guard normResidual <= residualThreshold else { return nil }
        return (center, radius)
    }

    private static func projectOntoLine(point: CGPoint, slope: CGFloat, intercept: CGFloat) -> CGPoint {
        // Projeção ortogonal de p sobre y = mx + b.
        let m = slope, b = intercept, x = point.x, y = point.y
        let denom = 1 + m * m
        let projX = (x + m * y - m * b) / denom
        let projY = m * projX + b
        return CGPoint(x: projX, y: projY)
    }

    private static func boundingBox(_ points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.x, minY = first.y, maxX = first.x, maxY = first.y
        for p in points {
            if p.x < minX { minX = p.x }
            if p.y < minY { minY = p.y }
            if p.x > maxX { maxX = p.x }
            if p.y > maxY { maxY = p.y }
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func pathLength(_ points: [CGPoint]) -> CGFloat {
        guard points.count > 1 else { return 0 }
        var sum: CGFloat = 0
        for i in 1..<points.count {
            sum += hypot(points[i].x - points[i-1].x, points[i].y - points[i-1].y)
        }
        return sum
    }

    // MARK: - Construção de PKStroke geométrico

    private static func makeLineStroke(start: CGPoint, end: CGPoint, ink: PKInk) -> PKStroke {
        // 16 pontos interpolados — suficiente pra renderização suave em qualquer escala.
        var controlPoints: [PKStrokePoint] = []
        let steps = 16
        let dist = hypot(end.x - start.x, end.y - start.y)
        let baseT = Date().timeIntervalSinceReferenceDate
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = start.x + (end.x - start.x) * t
            let y = start.y + (end.y - start.y) * t
            let pt = PKStrokePoint(
                location: CGPoint(x: x, y: y),
                timeOffset: TimeInterval(t) * 0.1,
                size: CGSize(width: 2, height: 2),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: 0
            )
            controlPoints.append(pt)
            _ = dist; _ = baseT
        }
        let path = PKStrokePath(controlPoints: controlPoints, creationDate: Date())
        return PKStroke(ink: ink, path: path)
    }

    private static func makeCircleStroke(center: CGPoint, radius: CGFloat, ink: PKInk) -> PKStroke {
        // 64 pontos parametrizados — círculo visualmente perfeito.
        var controlPoints: [PKStrokePoint] = []
        let steps = 64
        for i in 0...steps {
            let theta = (CGFloat(i) / CGFloat(steps)) * 2 * .pi
            let x = center.x + radius * cos(theta)
            let y = center.y + radius * sin(theta)
            let pt = PKStrokePoint(
                location: CGPoint(x: x, y: y),
                timeOffset: TimeInterval(i) * 0.005,
                size: CGSize(width: 2, height: 2),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: 0
            )
            controlPoints.append(pt)
        }
        let path = PKStrokePath(controlPoints: controlPoints, creationDate: Date())
        return PKStroke(ink: ink, path: path)
    }
}
