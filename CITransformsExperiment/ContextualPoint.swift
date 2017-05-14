import Foundation
import CoreGraphics
import UIKit

/// Represents a point defined within a coordinate space.
///
/// Because the point is defined within a coordinate space, it may be converted
/// to a related coordinate space. Note that storing this value relies on
/// storing the context as well; importantly, persisting this value across
/// sessions is not well-defined, since one would need to store the context,
/// which may be a transient value, like a `UIView`.
struct ContextualPoint {
	let baseCoordinateSpace: UICoordinateSpace
	let basePoint: CGPoint

	func point(in coordinateSpace: UICoordinateSpace) -> CGPoint {
		return coordinateSpace.convert(basePoint, from: baseCoordinateSpace)
	}
}

extension ContextualPoint {
	init(touch: UITouch,
	     baseCoordinateSpace: UICoordinateSpace = UIScreen.main.fixedCoordinateSpace) {
		self.init(baseCoordinateSpace: baseCoordinateSpace,
		          basePoint: UIApplication.shared.keyWindow!.convert(touch.location(in: nil), to: baseCoordinateSpace))
	}
}

extension ContextualPoint: Equatable {
	/**
	Checks if two `ContextualPoint`s are equivalent, meaning that they produce the
	same points when converted to equivalent coordinate spaces.
	
	Note: This implementation uses the screen's fixed coordinate space as a
	reference to compare the two points.
	*/
	static func == (lhs: ContextualPoint, rhs: ContextualPoint) -> Bool {
		if lhs.basePoint == rhs.basePoint && lhs.baseCoordinateSpace === rhs.baseCoordinateSpace {
			// If the base points are equivalent and both sides refer to the same base
			// coordinate space, we don't need to do other checks.
			return true
		} else {
			let referenceSpace = UIScreen.main.fixedCoordinateSpace
			return lhs.point(in: referenceSpace) == rhs.point(in: referenceSpace)
		}
	}
}
