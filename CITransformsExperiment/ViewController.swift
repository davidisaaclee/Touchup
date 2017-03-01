import UIKit

class ViewController: UIViewController {

	var stageController: ImageStageController!

	@IBOutlet var renderView: ImageSourceRenderView! {
		didSet {
			stageController = ImageStageController(renderView: renderView)
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		stageController.image = setupImage()
		stageController.reload()

		view.isMultipleTouchEnabled = true
		renderView.isMultipleTouchEnabled = true
	}

	private func setupImage() -> CIImage {
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

		return img
			.applying(centerOriginTransform)
			.applying(xform1)
			.applying(xform2)
	}

	@IBAction func toggleMode(_ sender: UIButton) {
		switch stageController.mode {
		case .cameraControl:
			stageController.mode = .imageTransform
			sender.setTitle("🏞", for: .normal)

		case .imageTransform:
			stageController.mode = .cameraControl
			sender.setTitle("🎥", for: .normal)

		}
	}

	@IBAction func freezeImage(_ sender: Any) {
		guard let render = stageController.renderToImage().flatMap(CIImage.init) else {
			fatalError("Implement me")
		}

		let centerOriginTransform =
			CGAffineTransform(translationX: -render.extent.width / 2,
			                  y: -render.extent.height / 2)

		stageController.backgroundImage =
			render.applying(centerOriginTransform)
	}
}
