import UIKit

/// Represents a sampling of a `UITouch` object at a specific time.
struct TouchSample {
	/// A unique identifier for this touch. `TouchSample`s sampled from the same
	/// `UITouch` will have equivalent `identifier`s.
	let identifier: Int

	/// The radius (in points) of the touch.
	let majorRadius: CGFloat

	/// The tolerance (in points) of the touch’s radius.
	let majorRadiusTolerance: CGFloat

	/// The number of times the finger was tapped for this given touch.
	let tapCount: Int

	/// The time when the touch occurred.
	let timestamp: TimeInterval

	/// The type of the touch.
	let type: UITouchType

	/// The phase of the touch.
	let phase: UITouchPhase

	/// The force of the touch, where a value of 1.0 represents the force of an
	/// average touch (predetermined by the system, not user-specific).
	let force: CGFloat

	/// The maximum possible force for a touch.
	let maximumPossibleForce: CGFloat

	/// Stores a contextual location of the touch, used to replicate the behavior
	/// of `UITouch.location(in:)`.
	fileprivate let contextualLocation: ContextualPoint

	/// Converts the sampled touch location to the specified coordinate space.
	/// This should replicate the behavior of `UITouch.location(in:)`.
	func location(in coordinateSpace: UICoordinateSpace) -> CGPoint {
		return contextualLocation.point(in: coordinateSpace)
	}
}

extension TouchSample {
	init(sampling touch: UITouch) {
		identifier = touch.hashValue
		contextualLocation = ContextualPoint(touch: touch)
		majorRadius = touch.majorRadius
		majorRadiusTolerance = touch.majorRadiusTolerance
		tapCount = touch.tapCount
		timestamp = touch.timestamp
		type = touch.type
		phase = touch.phase
		force = touch.force
		maximumPossibleForce = touch.maximumPossibleForce
	}
}
