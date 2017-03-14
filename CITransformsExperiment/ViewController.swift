import UIKit
import VectorSwift

struct EraserMark {
	var path: CGPath
	let width: Float
}

extension EraserMark: Equatable {
	static func == (lhs: EraserMark, rhs: EraserMark) -> Bool {
		return lhs.path == rhs.path && lhs.width == rhs.width
	}
}

struct History<Model> {
	var stack: [Model] = []
	var currentIndex: Int = -1

	mutating func push(_ model: Model) {
		stack
			.removeSubrange(stack.index(after: currentIndex) ..< stack.endIndex)
		stack.append(model)
		currentIndex += 1
	}

	mutating func undo() -> Model? {
		let indexʹ = stack.index(before: currentIndex)
		guard stack.indices.contains(indexʹ) else {
			return nil
		}

		currentIndex = indexʹ
		return stack[indexʹ]
	}

	mutating func redo() -> Model? {
		let indexʹ = stack.index(after: currentIndex)
		guard stack.indices.contains(indexʹ) else {
			return nil
		}

		currentIndex = indexʹ
		return stack[indexʹ]
	}
}

class ViewController: UIViewController {

	struct Workspace {
		var cameraTransform: CGAffineTransform = .identity
		var workingEraserMark: EraserMark?
		var history: History<Model> = History<Model>()
	}

	struct Model {
		var image: ImageSource? = nil
		var backgroundImage: CIImage? = nil
		var imageTransform: CGAffineTransform = .identity
		var eraserMarks: [EraserMark] = []
	}

	var stageController: ImageStageController!
	let eraserController = EraserTool()

	@IBOutlet var renderView: ImageSourceRenderView! {
		didSet {
			stageController = ImageStageController(renderView: renderView)
			stageController.delegate = self
		}
	}

	@IBOutlet weak var imageTransformButton: UIButton! {
		didSet {
			imageTransformButton.setImage(#imageLiteral(resourceName: "transform_circle"),
			                              for: [.highlighted, .selected])
		}
	}
	@IBOutlet weak var eraserButton: UIButton! {
		didSet {
			eraserButton.setImage(#imageLiteral(resourceName: "eraser_circle"),
			                      for: [.highlighted, .selected])
		}
	}

	let helpOverlayView = UIImageView(image: #imageLiteral(resourceName: "Help"))

	var model: Model = ViewController.Model() {
		didSet {
			reloadRenderView()
		}
	}

	var workspace: Workspace = ViewController.Workspace() {
		didSet {
			reloadRenderView()
		}
	}

	fileprivate var currentTime: TimeInterval {
		return CACurrentMediaTime()
	}

	fileprivate let customToolGestureRecognizer =
		MultitouchGestureRecognizer()

	let undoGestureRecognizer =
		UITapGestureRecognizer()

	let redoGestureRecognizer =
		UITapGestureRecognizer()

	enum Mode {
		case cameraControl
		case imageTransform
		case eraser
	}

	var mode: Mode = .cameraControl {
		didSet {
			previousMode = oldValue

			switch mode {
			case .imageTransform, .eraser:
				stageController.cameraControlGestureRecognizer.cancelGesture()
				customToolGestureRecognizer.isEnabled = true

			case .cameraControl:
				customToolGestureRecognizer.isEnabled = false
			}

			imageTransformButton.isSelected = false
			eraserButton.isSelected = false

			switch mode {
			case .cameraControl:
				break

			case .imageTransform:
				imageTransformButton.isSelected = true

			case .eraser:
				eraserButton.isSelected = true

			}
		}
	}

	override var prefersStatusBarHidden: Bool {
		return true
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		eraserController.delegate = self

		view.isMultipleTouchEnabled = true
		renderView.isMultipleTouchEnabled = true

		let videoPlayer =
			CIVideoPlayer(url: Bundle.main.url(forResource: "runner",
			                                   withExtension: "mp4")!)
		videoPlayer.startPlaying()
		setWorkingImage(videoPlayer)

		customToolGestureRecognizer
			.addTarget(self,
			           action: #selector(ViewController.handleToolGesture(recognizer:)))
		customToolGestureRecognizer.isEnabled = false
		renderView.addGestureRecognizer(customToolGestureRecognizer)

		undoGestureRecognizer
			.addTarget(self,
			           action: #selector(ViewController.handleHistoryGesture(recognizer:)))
		undoGestureRecognizer.numberOfTapsRequired = 2
		undoGestureRecognizer.numberOfTouchesRequired = 2
		undoGestureRecognizer.delegate = self
		view.addGestureRecognizer(undoGestureRecognizer)

		redoGestureRecognizer
			.addTarget(self,
			           action: #selector(ViewController.handleHistoryGesture(recognizer:)))
		redoGestureRecognizer.numberOfTapsRequired = 2
		redoGestureRecognizer.numberOfTouchesRequired = 3
		redoGestureRecognizer.delegate = self
		view.addGestureRecognizer(redoGestureRecognizer)

		helpOverlayView.frame = view.bounds
		helpOverlayView.isHidden = true
		view.addSubview(helpOverlayView)

		pushToHistory()

		let displayLink =
			CADisplayLink(target: self,
			              selector: #selector(ViewController.renderFrame))
		displayLink.add(to: .main, forMode: .commonModes)
	}

	func handleHistoryGesture(recognizer: UITapGestureRecognizer) {
		guard case .ended = recognizer.state else {
			return
		}

		switch recognizer {
		case undoGestureRecognizer:
			undo()

		case redoGestureRecognizer:
			redo()

		default:
			break
		}
	}

	func setWorkingImage(_ image: ImageSource) {
		model.image =
			image
		model.imageTransform =
			CGAffineTransform(translationX: -image.extent.width / 2,
			                  y: -image.extent.height / 2)
		model.eraserMarks = []
	}

	func reloadRenderView() {
		guard let image = model.image?.image(at: self.currentTime) else {
			// hm
			return
		}

		stageController.cameraTransform = workspace.cameraTransform
		stageController.backgroundImage = model.backgroundImage

		if var renderedEraserMarks = renderEraserMarks(model.eraserMarks, shouldCache: true) {
			if let workingEraserMark = workspace.workingEraserMark, let renderedWorkingEraserMark = renderEraserMarks([workingEraserMark], shouldCache: false) {
				renderedEraserMarks =
					renderedWorkingEraserMark.compositingOverImage(renderedEraserMarks)
			}

			let cutOutEraserMarksFromImage =
				CIFilter(name: "CISourceOutCompositing",
				         withInputParameters: ["inputImage": image,
				                               "inputBackgroundImage": renderedEraserMarks])!

			stageController.image =
				cutOutEraserMarksFromImage.outputImage!
					.applying(model.imageTransform)
		} else {
			stageController.image =
				image.applying(model.imageTransform)
		}
	}

	private var eraserMarksCache: (marks: [EraserMark], scaleFactor: CGFloat, image: CIImage)?

	private func renderEraserMarks(_ marks: [EraserMark], shouldCache: Bool) -> CIImage? {
		// We'll add a 1px margin to each side, to prevent edges showing through.
		// Note that this will make the result of this function `margins` larger
		// than the working image.
		let margins = CGSize(width: 10,
		                     height: 10)

		guard let workingImageSize = model.image?.extent.size else {
			return nil
		}

		// How many pixels are we willing to render?
		let maxPixelCount: CGFloat = 250000

//		var scaleFactor = CGSize(width: 1, height: 0)
//			.magnitude
//
//		// Ensure that the scale factor won't make us render more than
//		// `maxPixelCount` pixels.
//		scaleFactor =
//			min(scaleFactor, 
//			    sqrt(maxPixelCount / (workingImageSize.width * workingImageSize.height)))

		let scaleFactor: CGFloat = 1

		if let cached = eraserMarksCache {
			if cached.marks == marks && cached.scaleFactor == scaleFactor {
				return cached.image
			}
		}

		let scaling =
			CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)

		func renderToUIImage(_ marks: [EraserMark]) -> UIImage? {
			let size = workingImageSize.applying(scaling)

			UIGraphicsBeginImageContext(size + margins)
			defer { UIGraphicsEndImageContext() }

			UIColor.black.set()

			marks.forEach { mark in
				let transformedPath = CGMutablePath()
				let transform =
					CGAffineTransform(translationX: margins.width / 2,
					                  y: margins.height / 2)
						.concatenating(scaling)
				transformedPath.addPath(mark.path, transform: transform)

				let path = UIBezierPath(cgPath: transformedPath)

				// This makes smooth lines but gets slow with lots of marks.
//				let path = UIBezierPath(points: transformedPoints, smoothFactor: 0.3)
				path.lineWidth = CGFloat(mark.width) * scaleFactor
				path.lineCapStyle = .round
				path.stroke()
			}

			return UIGraphicsGetImageFromCurrentImageContext()
		}

		let result: CIImage? = renderToUIImage(marks)
			.flatMap { CIImage(image: $0) }
			.map { ciImage in
				// Resize scaled-up image to match the size of the working image
				// (excluding margins).
				let resizedImage: CIImage =
					ciImage
						.applying(CGAffineTransform(translationX: -ciImage.extent.width / 2,
						                            y: -ciImage.extent.height / 2))
						.applying(scaling.inverted())
						.applying(CGAffineTransform(translationX: ciImage.extent.width / (2 * scaleFactor),
						                            y: ciImage.extent.height / (2 * scaleFactor)))

				// Do some transforms to move from top-left origin coordinate system to
				// center origin.
				return resizedImage
					.applying(CGAffineTransform(scaleX: 1, y: -1))
					.applying(CGAffineTransform(translationX: 0,
					                            y: resizedImage.extent.height))
					.applying(CGAffineTransform(translationX: -margins.width / 2,
					                            y: -margins.height / 2))
			}

		if let result = result, shouldCache {
			eraserMarksCache = (marks: marks,
			                    scaleFactor: scaleFactor,
			                    image: result)
		}

		return result
	}


	private var previousTouchLocations: [UITouch: CGPoint] = [:]

	fileprivate func stageLocation(of touch: UITouch) -> CGPoint {
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
		case .began:
			isModeLocked = false

		case .ended:
			pushToHistory()

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

	func pushToHistory() {
		workspace.history.push(model)
	}

	@IBAction func undo() {
		guard let modelʹ = workspace.history.undo() else {
			return
		}
		model = modelʹ

		Analytics.shared.track(.undo)
	}

	@IBAction func redo() {
		guard let modelʹ = workspace.history.redo() else {
			return
		}
		model = modelʹ

		Analytics.shared.track(.redo)
	}


	private func handleEraser(using recognizer: MultitouchGestureRecognizer) {
		func eraserPosition(of touch: UITouch) -> CGPoint {
			return stageLocation(of: touch)
				.applying(model.imageTransform.inverted())
		}

		switch recognizer.state {
		case .began:
			isModeLocked = false
			eraserController.begin(with: recognizer.activeTouches.first!)

		case .ended:
			eraserController.end()

		case .changed:
			eraserController.change(with: recognizer.activeTouches.first!)

		default:
			break
		}
	}

	private var previousMode: Mode?
	private var isModeLocked: Bool = false

	@IBAction func enterImageTransform() {
		isModeLocked = true
		mode = .imageTransform
	}

	@IBAction func exitImageTransform() {
		// switch back if we unlocked the mode,
		// or if tapping on locked transform mode
		if previousMode == .imageTransform {
			Analytics.shared.track(.usedLockedImageTransform)
			mode = .cameraControl
		}

		if !isModeLocked {
			Analytics.shared.track(.usedQuasimodalImageTransform)
			mode = .cameraControl
		}
	}

	@IBAction func enterEraser() {
		isModeLocked = true
		mode = .eraser
	}

	@IBAction func exitEraser() {
		if previousMode == .eraser {
			Analytics.shared.track(.usedLockedEraser)
			mode = .cameraControl
		}

		if !isModeLocked {
			Analytics.shared.track(.usedQuasimodalEraser)
			mode = .cameraControl
		}
	}

	@IBAction func saveToCameraRoll() {
		guard let render = stageController.renderToImage() else {
			fatalError("Implement me")
		}

		let activityController = UIActivityViewController(activityItems: [render],
		                                                  applicationActivities: nil)
		activityController.completionWithItemsHandler = { (activityType, completed, _, _) in
			if completed {
				Analytics.shared.track(.finishedExport)
			} else {
				Analytics.shared.track(.cancelledExport)
			}
		}
		present(activityController, animated: true, completion: nil)

		Analytics.shared.track(.beganExport)
	}

	private var imageSequencer: ImageSequencer!

	@IBAction func freezeImage(_ sender: Any) {

		let targetPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("\(UUID().uuidString)_vid.mp4")
		let targetURL = URL(fileURLWithPath: targetPath)

		let framesToRender = cachedFrames
			.map { $0.resizing(to: renderSize) }

		let imageSequencerConfig =
			ImageSequencer.Configuration(outputVideoSize: renderSize,
			                             destination: targetURL,
			                             frameDuration: 1.0 / 30.0)
		imageSequencer =
			ImageSequencer(configuration: imageSequencerConfig)
		imageSequencer.generateVideo(from: framesToRender,
		                             outputVideoSize: renderSize,
		                             destinationURL: targetURL,
		                             frameDuration: 1.0 / 30.0) { (urlOrNil, errorOrNil) in
																	if let url = urlOrNil {
																		print("Success: \(url)")
																	} else {
																		print("Failure: \(errorOrNil!.localizedDescription)")
																	}
		}

		guard let render = stageController.renderToImage().flatMap(CIImage.init) else {
			fatalError("Implement me")
		}

		let centerOriginTransform =
			CGAffineTransform(translationX: -render.extent.width / 2,
			                  // HACK: need to round because we need an integral translation?
			                  y: (-render.extent.height / 2).rounded(.up))

		model.backgroundImage =
			render.applying(centerOriginTransform)
		pushToHistory()

		Analytics.shared.track(.stampToBackground)
	}

	@IBAction func replaceImage() {
		let imagePicker = CustomImagePicker()
		imagePicker.sourceType = .photoLibrary
		imagePicker.delegate = self
		imagePicker.modalTransitionStyle = .crossDissolve
		present(imagePicker, animated: true, completion: nil)

		Analytics.shared.track(.beganImportFromPhotos)
	}

	@IBAction func replaceImageWithCamera() {
		let imagePicker = CustomImagePicker()
		imagePicker.sourceType = .camera
		imagePicker.delegate = self
		imagePicker.modalTransitionStyle = .crossDissolve
		present(imagePicker, animated: true, completion: nil)

		Analytics.shared.track(.beganImportFromCamera)
	}

	@IBAction func showHelp() {
		helpOverlayView.isHidden = false
	}

	@IBAction func hideHelp() {
		helpOverlayView.isHidden = true
	}

	var renderSize: CGSize {
		let shrunkenSize =
			stageController.imageRenderSize
				.aspectFitting(within: CGSize(width: 1000,
				                              height: 1000))
		return ImageSequencer.coerceSize(size: shrunkenSize)
	}

	@objc private func renderFrame() {
		reloadRenderView()
		stageController.reload()

		stageController.renderToImage()
			.map { image in
				cachedFrames.append(image)
				
				if cachedFrames.count > 60 {
					cachedFrames.removeFirst()
				}
			}
	}

	fileprivate var cachedFrames: [CGImage] = []

	private class CustomImagePicker: UIImagePickerController {
		override var prefersStatusBarHidden: Bool {
			return true
		}
	}
}


extension ViewController: UIImagePickerControllerDelegate {
	func imagePickerController(_ picker: UIImagePickerController,
	                           didFinishPickingMediaWithInfo info: [String: Any]) {
		func swap(image: UIImage) {
			let resizedImage =
				image.resizing(toFitWithin: renderView.bounds.size)
			setWorkingImage(CIImage(image: resizedImage)!)
			pushToHistory()

			dismiss(animated: true, completion: nil)
		}

		if let editedImage = info[UIImagePickerControllerEditedImage] as? UIImage {
			swap(image: editedImage)
		} else if let originalImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
			swap(image: originalImage)
		} else {
			fatalError("Implement me")
		}

		switch picker.sourceType {
		case .camera:
			Analytics.shared.track(.finishedImportFromCamera)

		case .photoLibrary:
			Analytics.shared.track(.finishedImportFromPhotos)

		default:
			break
		}
	}

	func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
		dismiss(animated: true, completion: nil)

		switch picker.sourceType {
		case .camera:
			Analytics.shared.track(.cancelledImportFromCamera)

		case .photoLibrary:
			Analytics.shared.track(.cancelledImportFromPhotos)

		default:
			break
		}
	}
}

// Required for UIImagePickerController's delegate.
extension ViewController: UINavigationControllerDelegate {}

extension ViewController: ImageStageControllerDelegate {
	func imageStageController(_ controller: ImageStageController,
	                          shouldSetCameraTransformTo cameraTransform: CGAffineTransform) -> Bool {
		workspace.cameraTransform = cameraTransform
		return false
	}

	func imageStageController(_ controller: ImageStageController,
	                          shouldMultiplyCameraTransformBy cameraTransform: CGAffineTransform) -> Bool {
		workspace.cameraTransform =
			workspace.cameraTransform.concatenating(cameraTransform)
		return false
	}
}

extension ViewController: UIGestureRecognizerDelegate {
	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		switch (gestureRecognizer, otherGestureRecognizer) {
		case (undoGestureRecognizer, _):
			return true

		case (redoGestureRecognizer, _):
			return true

		default:
			return false
		}
	}
}


extension ViewController: EraserToolDelegate {
	func eraserTool(_ eraserTool: EraserTool,
	                locationFor touch: UITouch) -> CGPoint {
		return stageLocation(of: touch)
			.applying(model.imageTransform.inverted())
	}

	func eraserTool(_ eraserTool: EraserTool, didBeginDrawingAt point: CGPoint) {
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

		workspace.workingEraserMark =
			EraserMark(path: CGMutablePath(),
			           width: width)
	}

	func eraserTool(_ eraserTool: EraserTool, didUpdateWorkingPath path: CGPath) {
		guard var workingEraserMarkʹ = workspace.workingEraserMark else {
			return
		}

		workingEraserMarkʹ.path = path
		workspace.workingEraserMark = workingEraserMarkʹ
	}

	func eraserTool(_ eraserTool: EraserTool,
	                didCommitWorkingPath path: CGPath) {
		guard var committedEraserMark = workspace.workingEraserMark else {
			return
		}

		committedEraserMark.path = path
		model.eraserMarks.append(committedEraserMark)
		workspace.workingEraserMark = nil

		pushToHistory()
	}
}
