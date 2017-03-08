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

	fileprivate enum Mode {
		case passive
		case active([CGPoint])
	}

	fileprivate var mode: Mode = .passive

//	var workingPath: CGMutablePath? {
//		guard case let .active(path) = mode else {
//			return nil
//		}
//
//		return path
//	}

	func begin(with touch: UITouch) {
		guard let delegate = delegate else {
			return
		}

		let location = delegate.eraserTool(self, locationFor: touch)
		mode = .active([location])
		delegate.eraserTool(self, didBeginDrawingAt: location)
	}

	func change(with touch: UITouch) {
		guard
			case var .active(points) = mode,
			let delegate = delegate
			else {
				return
			}

		// Not actually useful :(
//		if let b = points.last, let a = points.dropLast().last {
//			let c = delegate.eraserTool(self, locationFor: touch)
//			// calling the last three points (a, b, c), where c is the point about to be added
//
//			let ab = b - a
//			let ac = c - a
//			if ab.rejection(on: ac).magnitude < (ac.magnitude / 4) {
////				print("Simplifying...")
//				points.removeLast()
//			}
//		}

		points.append(delegate.eraserTool(self, locationFor: touch))
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

	private func makePath(for points: [CGPoint]) -> CGPath {
		return UIBezierPath(points: points,
		                    smoothFactor: 0).cgPath
	}

}
