import UIKit
import VectorSwift

struct EraserMark {
	var points: [CGPoint]
}


class ViewController: UIViewController {

	var stageController: ImageStageController!

	@IBOutlet var renderView: ImageSourceRenderView! {
		didSet {
			stageController = ImageStageController(renderView: renderView)
		}
	}

	var image: CIImage? {
		didSet {
			stageController.image = image
			stageController.reload()
		}
	}

	var eraserMarks: [EraserMark] = []

	fileprivate let customToolGestureRecognizer =
		MultitouchGestureRecognizer()

	enum Mode {
		case cameraControl
		case imageTransform
		case eraser
	}

	var mode: Mode = .imageTransform {
		didSet {
			switch mode {
			case .imageTransform:
				customToolGestureRecognizer.isEnabled = true

			case .cameraControl:
				customToolGestureRecognizer.isEnabled = false

			case .eraser:
				customToolGestureRecognizer.isEnabled = true
			}
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		view.isMultipleTouchEnabled = true
		renderView.isMultipleTouchEnabled = true

		image = setupImage()

		customToolGestureRecognizer.addTarget(self,
		                                      action: #selector(ViewController.handleToolGesture(recognizer:)))
		renderView.addGestureRecognizer(customToolGestureRecognizer)
	}


	private var previousTouchLocations: [UITouch: CGPoint] = [:]

	private func stageLocation(of touch: UITouch) -> CGPoint {
		return touch.location(in: stageController.renderView)
			.applying(stageController.renderViewToStageTransform)
	}

	@objc private func handleToolGesture(recognizer: MultitouchGestureRecognizer) {
		defer {
			previousTouchLocations =
				recognizer.activeTouches.reduce(previousTouchLocations) { (locations, touch) in
					var locationsʹ = locations
					locationsʹ[touch] = stageLocation(of: touch)
					return locationsʹ
			}
		}

		switch mode {
		case .cameraControl:
			// Taken care of by the stage controller
			break

		case .imageTransform:
			handleImageTransform(using: recognizer)

		case .eraser:
			handleEraser(using: recognizer)
		}
	}

	func handleImageTransform(using recognizer: MultitouchGestureRecognizer) {
		switch recognizer.state {
		case .changed:
			switch recognizer.activeTouches.count {
			case 1:
				recognizer.activeTouches.first.map { touch in
					guard let location = previousTouchLocations[touch] else {
						return
					}

					let displacement =
						stageLocation(of: touch)
							- location

					image =
						image?.applying(CGAffineTransform(translationX: displacement.x,
						                                  y: displacement.y))
				}

			case let numberOfTouches where numberOfTouches >= 2:
				let sortedTouches =
					recognizer.activeTouches.sorted(by: { $0.hashValue < $1.hashValue })

				let (touchA, touchB) = (sortedTouches[0], sortedTouches[1])

				guard
					let locationA = previousTouchLocations[touchA],
					let locationB = previousTouchLocations[touchB]
					else {
						return
				}

				let (locationAʹ, locationBʹ) =
					(stageLocation(of: touchA), stageLocation(of: touchB))

				let transform =
					transformFromPinch(startingFrom: (pointA: locationA,
					                                  pointB: locationB),
					                   endingAt: (pointA: locationAʹ,
					                              pointB: locationBʹ))

				image =
					image?.applying(transform)

			default:
				break
			}
			
		default:
			break
		}
	}


	private func handleEraser(using recognizer: MultitouchGestureRecognizer) {
		switch recognizer.state {
		case .began:
			eraserMarks.append(EraserMark(points: []))

		case .ended:
			if let mark = eraserMarks.last, mark.points.isEmpty {
				eraserMarks.removeLast()
			} else {
				print(eraserMarks.last!.points)
			}

		case .changed:
			switch recognizer.activeTouches.count {
			case 1:
				recognizer.activeTouches.first.map { touch in
					if var mark = eraserMarks.popLast() {
						mark.points.append(stageLocation(of: touch))
						eraserMarks.append(mark)
						stageController.reload()
					}
				}

			default:
				break
			}
			
		default:
			break
		}
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
		switch mode {
		case .cameraControl:
			mode = .imageTransform
			sender.setTitle("🏞", for: .normal)

		case .imageTransform:
			mode = .eraser
			sender.setTitle("🔪", for: .normal)

		case .eraser:
			mode = .cameraControl
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
