import UIKit
import VectorSwift

struct EraserMark {
	var points: [CGPoint]
	let width: Float
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
			reloadRenderView()
		}
	}

	var imageTransform: CGAffineTransform = .identity {
		didSet {
			reloadRenderView()
		}
	}

	var eraserMarks: [EraserMark] = [] {
		didSet {
			reloadRenderView()
		}
	}

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

	override var prefersStatusBarHidden: Bool {
		return true
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		view.isMultipleTouchEnabled = true
		renderView.isMultipleTouchEnabled = true

		image = setupImage()
		let centerOriginTransform =
			CGAffineTransform(translationX: -image!.extent.width / 2,
			                  y: -image!.extent.height / 2)

		imageTransform = centerOriginTransform

		customToolGestureRecognizer
			.addTarget(self,
			           action: #selector(ViewController.handleToolGesture(recognizer:)))
		renderView.addGestureRecognizer(customToolGestureRecognizer)
	}

	func reloadRenderView() {
		guard let image = image else {
			// hm
			return
		}

		if let renderedEraserMarks = renderEraserMarks(eraserMarks) {
			let cutOutEraserMarksFromImage =
				CIFilter(name: "CISourceOutCompositing",
				         withInputParameters: ["inputImage": image,
				                               "inputBackgroundImage": renderedEraserMarks])!

			stageController.image =
				cutOutEraserMarksFromImage.outputImage!
					.applying(imageTransform)
		} else {
			stageController.image = image.applying(imageTransform)
		}
	}

	private func renderEraserMarks(_ marks: [EraserMark]) -> CIImage? {
		func renderToUIImage(_ marks: [EraserMark]) -> UIImage? {
			guard let size = image?.extent.size else {
				return nil
			}

			UIGraphicsBeginImageContext(size)
			defer { UIGraphicsEndImageContext() }

			UIColor.blue.set()

			marks.forEach { mark in
				let path = UIBezierPath()
				mark.points.first.map { path.move(to: $0) }
				mark.points.dropFirst().forEach { path.addLine(to: $0) }

				path.lineWidth = CGFloat(mark.width)
				path.lineCapStyle = .round
				path.stroke()
			}

			return UIGraphicsGetImageFromCurrentImageContext()
		}

		return renderToUIImage(marks)
			.flatMap { CIImage(image: $0) }
			.map { ciImage in
				ciImage
					.applying(CGAffineTransform(scaleX: 1, y: -1))
					.applying(CGAffineTransform(translationX: 0,
					                            y: ciImage.extent.height))
			}
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

					imageTransform =
						imageTransform
							.concatenating(CGAffineTransform(translationX: displacement.x,
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

				imageTransform =
					imageTransform
						.concatenating(transform)

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
			eraserMarks.append(EraserMark(points: [],
			                              width: 25))

		case .ended:
			if let mark = eraserMarks.last, mark.points.isEmpty {
				eraserMarks.removeLast()
			}

		case .changed:
			switch recognizer.activeTouches.count {
			case 1:
				recognizer.activeTouches.first.map { touch in
					var eraserMarksʹ = eraserMarks

					if var mark = eraserMarksʹ.popLast() {
						let location =
							stageLocation(of: touch)
								.applying(imageTransform.inverted())
						mark.points.append(location)
						eraserMarksʹ.append(mark)
						eraserMarks = eraserMarksʹ
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

		return img
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

	@IBAction func replaceImage() {
		let imagePicker = UIImagePickerController()
		imagePicker.sourceType = .camera
		imagePicker.delegate = self
		present(imagePicker, animated: true, completion: nil)
	}
}


extension ViewController: UIImagePickerControllerDelegate {
	func imagePickerController(_ picker: UIImagePickerController,
	                           didFinishPickingMediaWithInfo info: [String: Any]) {
		func swap(image: UIImage) {
			self.image = CIImage(image: image)
			let centerOriginTransform =
				CGAffineTransform(translationX: -image.size.width / 2,
				                  y: -image.size.height / 2)
			self.imageTransform = centerOriginTransform

			dismiss(animated: true, completion: nil)
		}

		if let editedImage = info[UIImagePickerControllerEditedImage] as? UIImage {
			swap(image: editedImage)
		} else if let originalImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
			swap(image: originalImage)
		} else {
			fatalError("Implement me")
		}
	}

	func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
		dismiss(animated: true, completion: nil)
	}
}

// Required for UIImagePickerController's delegate.
extension ViewController: UINavigationControllerDelegate {}
