import UIKit

class ViewController: UIViewController {

	let stageController =
		ImageStageController(renderView: ImageSourceRenderView(frame: CGRect(origin: .zero,
		                                                                     size: .zero)))

	var renderView: ImageSourceRenderView {
		return stageController.renderView
	}

	enum Mode {
		case cameraControl
		case imageTransform
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		let img =
			CIImage(image: #imageLiteral(resourceName: "test-pattern"))!

		let centerOriginTransform =
			CGAffineTransform(translationX: -img.extent.width / 2,
			                  y: -img.extent.height / 2)

		let xform1 =
			CGAffineTransform(translationX: 200, y: 0)
		let xform2 =
			xform1.inverted()
				.concatenating(CGAffineTransform(rotationAngle: CGFloat(M_PI_2 / 2)))
				.concatenating(xform1)

		stageController.image =
			img
				.applying(centerOriginTransform)
				.applying(xform1)
				.applying(xform2)

		renderView.frame = view.bounds
		view.addSubview(renderView)

		stageController.reload()

		view.isMultipleTouchEnabled = true
		renderView.isMultipleTouchEnabled = true
	}

}
