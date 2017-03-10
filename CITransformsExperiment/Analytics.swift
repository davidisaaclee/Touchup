import Foundation
import Mixpanel

class Analytics {
	static let shared = Analytics()

	enum Event: String {
		case beganImportFromPhotos
		case finishedImportFromPhotos
		case cancelledImportFromPhotos

		case beganImportFromCamera
		case finishedImportFromCamera
		case cancelledImportFromCamera

		case beganExport
		case finishedExport
		case cancelledExport

		case usedQuasimodalEraser
		case usedLockedEraser

		case usedQuasimodalImageTransform
		case usedLockedImageTransform

		case undo
		case redo

		case stampToBackground

		var name: String {
			return rawValue
		}
	}

	private var mixpanel: MixpanelInstance?

	func setup() {
		#if DEBUG
			mixpanel = Mixpanel.initialize(token: "3a201f871093e667887cfa7f0ff85c33")
		#else
			mixpanel = Mixpanel.initialize(token: "d3ea2f328b77d5a2391f28caf1253fe1")
		#endif
	}

	func track(_ event: Event) {
		guard let mixpanel = mixpanel else {
			return
		}

		mixpanel.track(event: event.name)
	}
}
