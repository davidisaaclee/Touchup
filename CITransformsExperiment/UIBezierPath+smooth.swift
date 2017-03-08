import Foundation
import VectorSwift

extension UIBezierPath {
	convenience init(points: [CGPoint], smoothFactor: CGFloat = 0) {
		self.init()

		guard let first = points.first, let last = points.last else {
			return
		}

		move(to: first)

		if smoothFactor == 0 {
			points.dropFirst().forEach { addLine(to: $0) }
		} else {
			var pts = points.grouping(into: 3).flatMap { (pointGroup: [CGPoint]) -> [CGPoint] in
				let (previous, current, next) =
					(pointGroup[0], pointGroup[1], pointGroup[2])
				let tangent = next - previous
				let cp1 = -smoothFactor * tangent + current
				let cp2 = smoothFactor * tangent + current

				return [cp1, current, cp2]
			}

			pts = [first] + pts + [last, last]

			for idx in stride(from: pts.startIndex, to: pts.endIndex, by: 3) {
				self.addCurve(to: pts[idx + 2],
				              controlPoint1: pts[idx],
				              controlPoint2: pts[idx + 1])
			}
		}
	}
}


// group [a, b, c, d, e] 2 => [(a, b), (b, c), (c, d), (d, e)]
// group [b, c, d, e] 2 => [(b, c), (c, d), (d, e)]
// group [c, d, e] 2 => [(c, d), (d, e)]

// group [a, b, c, d, e] 3 => [(a, b, c), (b, c, d), (c, d, e)]
// group [b, c, d, e] 3 => [(b, c, d), (c, d, e)]
// group [c, d, e] 3 => [(c, d, e)]

// group [a, b, c] 2 => [(a, b), (b, c)]
// group [a, b, c] 3 => [(a, b ,c)]
// group [a, b, c] 4 => []

extension Array {
	func grouping(into size: Int) -> [[Iterator.Element]] {
		guard self.count >= size else {
			return []
		}

		return [Array(self.prefix(size))] + Array(self.dropFirst()).grouping(into: size)
	}
}
