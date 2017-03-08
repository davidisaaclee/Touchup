import Foundation

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
		case active(CGMutablePath)
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

		let path = CGMutablePath()
		let location = delegate.eraserTool(self, locationFor: touch)
		path.move(to: location)
		mode = .active(path)
		delegate.eraserTool(self, didBeginDrawingAt: location)
	}

	func change(with touch: UITouch) {
		guard
			case let .active(path) = mode,
			let delegate = delegate
			else {
				return
			}

		path.addLine(to: delegate.eraserTool(self, locationFor: touch))
		mode = .active(path)
		if let copy = path.copy() {
			delegate.eraserTool(self, didUpdateWorkingPath: copy)
		}
	}

	func end() {
		guard
			case let .active(path) = mode,
			let delegate = delegate
			else {
				return
			}

		if let copy = path.copy() {
			delegate.eraserTool(self, didCommitWorkingPath: copy)
		}
		mode = .passive
	}

}
