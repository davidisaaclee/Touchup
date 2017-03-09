import Foundation
import VectorSwift

protocol EraserToolDelegate: class {
	func eraserTool(_ eraserTool: EraserTool,
	                didBeginDrawingAt point: CGPoint)
	func eraserTool(_ eraserTool: EraserTool,
	                didUpdateWorkingPath path: CGPath)
	func eraserTool(_ eraserTool: EraserTool,
	                didCommitWorkingPath path: CGPath)

	func eraserTool(_ eraserTool: EraserTool,
	                locationFor touch: UITouch) -> CGPoint
}

class EraserTool {

	weak var delegate: EraserToolDelegate?

	fileprivate struct Spline {
		var point: CGPoint
		var controlPoint1: CGPoint
		var controlPoint2: CGPoint

		static func straight(on point: CGPoint) -> Spline {
			return Spline(point: point, controlPoint1: point, controlPoint2: point)
		}
	}

	fileprivate enum Mode {
		case passive
		case active([Spline])
	}

	fileprivate var mode: Mode = .passive

	private let smoothFactor: CGFloat = 0.2

	func begin(with touch: UITouch) {
		guard let delegate = delegate else {
			return
		}

		let location = delegate.eraserTool(self, locationFor: touch)
		mode = .active([.straight(on: location)])
		delegate.eraserTool(self, didBeginDrawingAt: location)
	}

	func change(with touch: UITouch) {
		guard
			case var .active(points) = mode,
			let delegate = delegate
			else {
				return
			}

		var c: Spline = .straight(on: delegate.eraserTool(self, locationFor: touch))

		// if we have at least two points in the line, we can start to smooth.
		if var b = points.last, let a = points.dropLast().last {
			// calling the last three points (a, b, c), where c is the point about to be added
			let ac = c.point - a.point
			c.controlPoint1 = smoothFactor * ac + b.point
			b.controlPoint2 = -smoothFactor * ac + b.point
			points.removeLast()
			points.append(b)
		}
		points.append(c)

		mode = .active(points)

		delegate.eraserTool(self, didUpdateWorkingPath: makePath(for: points))
	}

	func end() {
		guard
			case let .active(points) = mode,
			let delegate = delegate
			else {
				return
			}

		delegate.eraserTool(self, didCommitWorkingPath: makePath(for: points))
		mode = .passive
	}

	private func makePath(for points: [Spline]) -> CGPath {
		let path = CGMutablePath()
		points.first.map { path.move(to: $0.point) }
		points.dropFirst()
			.forEach { path.addCurve(to: $0.point,
			                         control1: $0.controlPoint1,
			                         control2: $0.controlPoint2) }
		return path
	}

}
