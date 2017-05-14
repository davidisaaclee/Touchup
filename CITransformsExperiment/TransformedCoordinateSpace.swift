import Foundation
import UIKit

class TransformedCoordinateSpace: NSObject, UICoordinateSpace {
	let base: UICoordinateSpace
	let transform: CGAffineTransform

	init(base: UICoordinateSpace, transform: CGAffineTransform) {
		self.base = base
		self.transform = transform
		super.init()
	}

	var bounds: CGRect {
		return base.bounds.applying(transform)
	}

	func convert(_ point: CGPoint,
	             to coordinateSpace: UICoordinateSpace) -> CGPoint {
		return base.convert(point, to: coordinateSpace).applying(transform)
	}

	func convert(_ point: CGPoint,
	             from coordinateSpace: UICoordinateSpace) -> CGPoint {
		return base.convert(point, from: coordinateSpace).applying(transform)
	}

	func convert(_ rect: CGRect,
	             to coordinateSpace: UICoordinateSpace) -> CGRect {
		return base.convert(rect, to: coordinateSpace).applying(transform)
	}

	func convert(_ rect: CGRect,
	             from coordinateSpace: UICoordinateSpace) -> CGRect {
		return base.convert(rect, from: coordinateSpace).applying(transform)
	}
}

extension UICoordinateSpace {
	func applying(_ transform: CGAffineTransform) -> UICoordinateSpace {
		return TransformedCoordinateSpace(base: self,
		                                  transform: transform)
	}
}
