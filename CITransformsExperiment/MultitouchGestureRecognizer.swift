import Foundation
import UIKit
import UIKit.UIGestureRecognizerSubclass

public class MultitouchGestureRecognizer: UIGestureRecognizer {
	var activeTouches: Set<UITouch> = [] {
		didSet {
			switch (oldValue.count, activeTouches.count) {
			case (0, let n) where n > 0:
				state = .began

			case (let n, 0) where n > 0:
				state = .ended

			case (let m, let n) where n > 0 && m > 0:
				state = .changed

			default:
				break
			}
		}
	}

	public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
		super.touchesBegan(touches, with: event)
		activeTouches.formUnion(touches)
	}

	public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
		super.touchesMoved(touches, with: event)
		state = .changed
	}

	public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
		super.touchesCancelled(touches, with: event)
		activeTouches.subtract(touches)
	}

	public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
		super.touchesEnded(touches, with: event)
		activeTouches.subtract(touches)
	}
}
