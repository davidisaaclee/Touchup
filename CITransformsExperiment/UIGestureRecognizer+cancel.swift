import UIKit

extension UIGestureRecognizer {
	func cancelGesture() {
		guard isEnabled else {
			// no need to do anything
			return
		}

		isEnabled = false
		isEnabled = true
	}
}
