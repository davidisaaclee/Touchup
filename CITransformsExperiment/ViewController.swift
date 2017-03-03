import UIKit
import VectorSwift

struct EraserMark {
	var points: [CGPoint]
	let width: Float
}


class ViewController: UIViewController {

	struct Model {
		var image: CIImage? = nil
		var backgroundImage: CIImage? = nil
		var imageTransform: CGAffineTransform = .identity
		var cameraTransform: CGAffineTransform = .identity
		var eraserMarks: [EraserMark] = []
	}

	var stageController: ImageStageController!

	@IBOutlet var renderView: ImageSourceRenderView! {
		didSet {
			stageController = ImageStageController(renderView: renderView)
			stageController.delegate = self
		}
	}

	var model: Model = ViewController.Model() {
		didSet {
			reloadRenderView()
		}
	}

	var history: [Model] = []
	var historyIndex: Int = -1

	fileprivate let customToolGestureRecognizer =
		MultitouchGestureRecognizer()

	enum Mode {
		case cameraControl
		case imageTransform
		case eraser
	}

	var mode: Mode = .cameraControl {
		didSet {
			switch mode {
			case .imageTransform, .eraser:
				customToolGestureRecognizer.isEnabled = true

			case .cameraControl:
				customToolGestureRecognizer.isEnabled = false
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

		setWorkingImage(CIImage(image: #imageLiteral(resourceName: "test-pattern"))!)

		customToolGestureRecognizer
			.addTarget(self,
			           action: #selector(ViewController.handleToolGesture(recognizer:)))
		customToolGestureRecognizer.isEnabled = false
		renderView.addGestureRecognizer(customToolGestureRecognizer)

		pushHistory()
	}

	func setWorkingImage(_ image: CIImage) {
		model.image =
			image
		model.imageTransform =
			CGAffineTransform(translationX: -image.extent.width / 2,
			                  y: -image.extent.height / 2)
		model.eraserMarks = []
	}

	func reloadRenderView() {
		guard let image = model.image else {
			// hm
			return
		}

		stageController.cameraTransform = model.cameraTransform
		stageController.backgroundImage = model.backgroundImage

		if let renderedEraserMarks = renderEraserMarks(model.eraserMarks) {
			let cutOutEraserMarksFromImage =
				CIFilter(name: "CISourceOutCompositing",
				         withInputParameters: ["inputImage": image,
				                               "inputBackgroundImage": renderedEraserMarks])!

			stageController.image =
				cutOutEraserMarksFromImage.outputImage!
					.applying(model.imageTransform)
		} else {
			stageController.image = image.applying(model.imageTransform)
		}
	}

	private func renderEraserMarks(_ marks: [EraserMark]) -> CIImage? {
		// We'll add a 1px margin to each side, to prevent edges showing through.
		// Note that this will make the result of this function `margins` larger
		// than the working image.
		let margins = CGSize(width: 2, height: 2)

		func renderToUIImage(_ marks: [EraserMark]) -> UIImage? {
			guard let size = model.image?.extent.size else {
				return nil
			}

			UIGraphicsBeginImageContext(size + margins)
			defer { UIGraphicsEndImageContext() }

			UIColor.black.set()

			marks.forEach { mark in
				let path = UIBezierPath()

				// Translate points to account for left/top margins.
				let translatedPoints = mark.points.map {
					$0.applying(CGAffineTransform(translationX: margins.width / 2,
					                              y: margins.height / 2))
				}
				translatedPoints.first.map { path.move(to: $0) }
				translatedPoints.dropFirst().forEach { path.addLine(to: $0) }

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
					.applying(CGAffineTransform(translationX: -margins.width / 2,
					                            y: -margins.height / 2))
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
		case .ended:
			pushHistory()

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

					model.imageTransform =
						model.imageTransform
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

				model.imageTransform =
					model.imageTransform
						.concatenating(transform)

			default:
				break
			}
			
		default:
			break
		}
	}

	func pushHistory() {
		history.removeSubrange(history.index(after: historyIndex) ..< history.endIndex)
		history.append(model)
		historyIndex += 1
	}

	@IBAction func undo() {
		let indexʹ = history.index(before: historyIndex)
		guard history.indices.contains(indexʹ) else {
			return
		}

		print("undoing to \(indexʹ) from \(historyIndex)")

		historyIndex = indexʹ
		model = history[indexʹ]
	}

	@IBAction func redo() {
		let indexʹ = history.index(after: historyIndex)
		guard history.indices.contains(indexʹ) else {
			return
		}

		print("redoing to \(indexʹ) from \(historyIndex)")

		historyIndex = indexʹ
		model = history[indexʹ]
	}


	private func handleEraser(using recognizer: MultitouchGestureRecognizer) {
		switch recognizer.state {
		case .began:
			var width: Float {
				var widthConstant: CGFloat = 60
				// need to aupply the 2d transforms to a 1d "distance"...
				let p1 = CGPoint(x: 0, y: 0)
				let p2 = CGPoint(x: widthConstant, y: 0)

				func applyTheTransforms(to point: CGPoint) -> CGPoint {
					return point
						.applying(model.imageTransform.inverted())
						.applying(stageController.cameraTransform.inverted())
				}

				return Float(applyTheTransforms(to: p1)
					.distanceTo(applyTheTransforms(to: p2)))
			}

			model.eraserMarks.append(EraserMark(points: [],
			                              width: width))

		case .ended:
			if let mark = model.eraserMarks.last, mark.points.isEmpty {
				model.eraserMarks.removeLast()
			} else {
				pushHistory()
			}

		case .changed:
			switch recognizer.activeTouches.count {
			case 1:
				recognizer.activeTouches.first.map { touch in
					var eraserMarksʹ = model.eraserMarks

					if var mark = eraserMarksʹ.popLast() {
						let location =
							stageLocation(of: touch)
								.applying(model.imageTransform.inverted())
						mark.points.append(location)
						eraserMarksʹ.append(mark)
						model.eraserMarks = eraserMarksʹ
					}
				}

			default:
				break
			}
			
		default:
			break
		}
	}

	@IBAction func enterImageTransform() {
		mode = .imageTransform
	}

	@IBAction func exitImageTransform() {
		mode = .cameraControl
	}

	@IBAction func enterEraser() {
		mode = .eraser
	}

	@IBAction func exitEraser() {
		mode = .cameraControl
	}

	@IBAction func freezeImage(_ sender: Any) {
		guard let render = stageController.renderToImage().flatMap(CIImage.init) else {
			fatalError("Implement me")
		}

		let centerOriginTransform =
			CGAffineTransform(translationX: -render.extent.width / 2,
			                  y: -render.extent.height / 2)

		model.backgroundImage =
			render.applying(centerOriginTransform)
		pushHistory()
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
			let resizedImage =
				image.resizing(toFitWithin: CGSize(width: 800, height: 800))
			setWorkingImage(CIImage(image: resizedImage)!)
			pushHistory()

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

extension ViewController: ImageStageControllerDelegate {
	func imageStageController(_ controller: ImageStageController,
	                          shouldSetCameraTransformTo cameraTransform: CGAffineTransform) -> Bool {
		model.cameraTransform = cameraTransform
		return false
	}

	func imageStageController(_ controller: ImageStageController,
	                          shouldMultiplyCameraTransformBy cameraTransform: CGAffineTransform) -> Bool {
		model.cameraTransform = model.cameraTransform.concatenating(cameraTransform)
		return false
	}
}
