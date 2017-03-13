import UIKit

protocol ImageStageControllerDelegate: class {
	func imageStageController(_ controller: ImageStageController,
	                          shouldSetCameraTransformTo cameraTransform: CGAffineTransform) -> Bool
	func imageStageController(_ controller: ImageStageController,
	                          shouldMultiplyCameraTransformBy cameraTransform: CGAffineTransform) -> Bool
}

class ImageStageController: NSObject {

	weak var delegate: ImageStageControllerDelegate?

	var renderView: ImageSourceRenderView =
		ImageSourceRenderView(frame: .zero)

	var image: CIImage? {
		didSet {
//			reload()
		}
	}

	var backgroundImage: CIImage? {
		didSet {
//			reload()
		}
	}

	var stageContents: CIImage {
		return (image ?? CIImage())
			.compositingOverImage(backgroundImage ?? CIImage())
	}

	let cameraControlGestureRecognizer =
		MultitouchGestureRecognizer()
	let doubleTapGestureRecognizer =
		UITapGestureRecognizer()

	var cameraTransform: CGAffineTransform =
		CGAffineTransform(rotationAngle: CGFloat(M_PI_4)) {
		didSet {
//			reload()
		}
	}

	// Apply to a `renderView`'s coordinate system to get stage output's
	// coordinate system.
	var renderViewToStageTransform: CGAffineTransform {
		return CGAffineTransform.identity
			.concatenating(renderView.cameraCenteringTransform.inverted())
			.concatenating(renderView.cameraScalingTransform)
			.concatenating(CGAffineTransform(scaleX: 1, y: -1))
			.concatenating(cameraTransform.inverted())
	}

	init(renderView: ImageSourceRenderView) {
		super.init()

		self.renderView = renderView

		cameraControlGestureRecognizer
			.addTarget(self,
			           action: #selector(ImageStageController.handleTouches(recognizer:)))
		renderView.addGestureRecognizer(cameraControlGestureRecognizer)

		doubleTapGestureRecognizer
			.addTarget(self,
			           action: #selector(ImageStageController.handleDoubleTap(recognizer:)))
		doubleTapGestureRecognizer.numberOfTapsRequired = 2
		renderView.addGestureRecognizer(doubleTapGestureRecognizer)

		doubleTapGestureRecognizer.delegate = self
	}

	fileprivate func attemptToSetCameraTransform(_ cameraTransform: CGAffineTransform) {
		if delegate?.imageStageController(self, shouldSetCameraTransformTo: cameraTransform) ?? true {
			self.cameraTransform = cameraTransform
		}
	}

	fileprivate func attemptToConcatCameraTransform(_ cameraTransform: CGAffineTransform) {
		if delegate?.imageStageController(self, shouldMultiplyCameraTransformBy: cameraTransform) ?? true {
			self.cameraTransform = self.cameraTransform.concatenating(cameraTransform)
		}
	}

	@objc private func handleDoubleTap(recognizer: UITapGestureRecognizer) {
		guard case .ended = recognizer.state else {
			return
		}

		attemptToSetCameraTransform(.identity)
	}


	private var previousTouchLocations: [UITouch: CGPoint] = [:]

	@objc private func handleTouches(recognizer: MultitouchGestureRecognizer) {
		defer {
			previousTouchLocations =
				recognizer.activeTouches.reduce(previousTouchLocations) { (locations, touch) in
					var locationsʹ = locations
					locationsʹ[touch] = stageLocation(of: touch)
					return locationsʹ
			}
		}

		switch recognizer.state {
		case .began:
			break

		case .changed:
			switch recognizer.activeTouches.count {
			case 1:
				recognizer.activeTouches.first.map { touch in
					guard let location = previousTouchLocations[touch] else {
						return
					}

					let displacement =
						stageLocation(of: touch).applying(cameraTransform)
							- location.applying(cameraTransform)

					attemptToConcatCameraTransform(CGAffineTransform(translationX: displacement.x,
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
					transformFromPinch(startingFrom: (pointA: locationA.applying(cameraTransform),
					                                  pointB: locationB.applying(cameraTransform)),
					                   endingAt: (pointA: locationAʹ.applying(cameraTransform),
					                              pointB: locationBʹ.applying(cameraTransform)))

				attemptToSetCameraTransform(cameraTransform.concatenating(transform))

			default:
				break
			}

		case .ended:
			break

		default:
			break
		}
	}

	private func stageLocation(of touch: UITouch) -> CGPoint {
		return touch.location(in: renderView)
			.applying(renderViewToStageTransform)
	}

	func reload() {
		// Pixel buffer isn't generated until first draw.
		if renderView.drawableWidth == 0 {
			renderView.display()
		}

		let cropRect = renderView.bounds
			.applying(renderView.cameraCenteringTransform.inverted())
			.applying(renderView.cameraScalingTransform)

		renderView.ciImage =
			applyCamera(to: stageContents)
				.cropping(to: cropRect)
		renderView.setNeedsDisplay()
	}

	func renderToImage() -> UIImage? {
		let cropRect = renderView.bounds
			.applying(renderView.cameraCenteringTransform.inverted())
			.applying(renderView.cameraScalingTransform)
		return renderView.ciContext
			.createCGImage(stageContents,
			               from: cropRect)
			.map { UIImage(cgImage: $0) }
	}


	private func applyCamera(to image: CIImage) -> CIImage {
		func renderWorkspace(around image: CIImage) -> CIImage {
			let checkerboard =
				CIFilter(name: "CICheckerboardGenerator",
				         withInputParameters: ["inputColor0": CIColor(color: UIColor(white: 1, alpha: 1)),
				                               "inputColor1": CIColor(color: UIColor(white: 0.9, alpha: 1)),
				                               "inputWidth": NSNumber(value: 50)])!

			let black =
				CIFilter(name: "CIConstantColorGenerator",
				         withInputParameters: ["inputColor": CIColor(color: .black)])!

			let translucentBlack =
				CIFilter(name: "CIConstantColorGenerator",
				         withInputParameters: ["inputColor": CIColor(color: UIColor(white: 0, alpha: 0.8))])!

			let croppedBlack = black.outputImage!
				.applyingFilter("CICrop",
				                withInputParameters: ["inputRectangle": CIVector(cgRect: renderView.bounds
													.applying(renderView.cameraCenteringTransform.inverted())
													.applying(renderView.cameraScalingTransform))])

			let cutImageBoundsOutOfScrim =
				CIFilter(name: "CISourceOutCompositing",
				         withInputParameters: ["inputImage": translucentBlack.outputImage!,
				                               "inputBackgroundImage": croppedBlack])!

			let checkerboardBehindImage =
				CIFilter(name: "CISourceOverCompositing",
				         withInputParameters: ["inputImage": image,
				                               "inputBackgroundImage": checkerboard.outputImage!])!

			let scrimOverImage =
				CIFilter(name: "CISourceOverCompositing",
				         withInputParameters: ["inputImage": cutImageBoundsOutOfScrim.outputImage!,
				                               "inputBackgroundImage": checkerboardBehindImage.outputImage!])!

			return scrimOverImage.outputImage!
		}

		return renderWorkspace(around: image)
			.applying(cameraTransform)
	}

	private func convertToStageCoordinates(_ locationInRenderView: CGPoint) -> CGPoint {
		return locationInRenderView
			.applying(renderViewToStageTransform)
	}

}

extension ImageStageController: UIGestureRecognizerDelegate {
	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
	                       shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		switch (gestureRecognizer, otherGestureRecognizer) {
		case (doubleTapGestureRecognizer, cameraControlGestureRecognizer):
			return true
			
		default:
			return false
		}
	}
}


import VectorSwift

typealias LineSegment = (pointA: CGPoint, pointB: CGPoint)
func transformFromPinch(startingFrom startSegment: LineSegment,
                        endingAt endSegment: LineSegment) -> CGAffineTransform {
	let (a, b) = startSegment
	let (aʹ, bʹ) = endSegment

	let displacement = b - a
	let displacementʹ = bʹ - aʹ

	let rotationAngle =
		atan2(displacementʹ.y, displacementʹ.x)
			- atan2(displacement.y, displacement.x)
	let scaleFactor = displacementʹ.magnitude / displacement.magnitude
	let initialMidpoint = 0.5 * displacement + a
	let finalMidpoint = 0.5 * displacementʹ + aʹ

	var pivotPoint: CGPoint? {
		let u_ad = (bʹ.y - aʹ.y) * (b.x - a.x) - (bʹ.x - aʹ.x) * (b.y - a.y)

		guard u_ad != 0 else {
			// parallel
			return nil
		}

		let u_an = (bʹ.x - aʹ.x) * (a.y - aʹ.y) - (bʹ.y - aʹ.y) * (a.x - aʹ.x)
		let u_a = u_an / u_ad

		return CGPoint(x: a.x + u_a * (b.x - a.x),
		               y: a.y + u_a * (b.y - a.y))
	}

	var rotationTransform: CGAffineTransform = .identity

	if let pivotPoint = pivotPoint {
		rotationTransform = rotationTransform
			.concatenating(CGAffineTransform(translationX: -pivotPoint.x, y: -pivotPoint.y))
			.concatenating(CGAffineTransform(rotationAngle: rotationAngle))
			.concatenating(CGAffineTransform(translationX: pivotPoint.x, y: pivotPoint.y))
	}

	let rotatedMidpoint =
		initialMidpoint.applying(rotationTransform)

	let scaleOffset1 =
		CGAffineTransform(translationX: -rotatedMidpoint.x,
		                  y: -rotatedMidpoint.y)
	let scaleXform =
		CGAffineTransform(scaleX: scaleFactor,
		                  y: scaleFactor)
	let scaleOffset2 =
		CGAffineTransform(translationX: finalMidpoint.x,
		                  y: finalMidpoint.y)

	let scaleTransform = CGAffineTransform.identity
		.concatenating(scaleOffset1)
		.concatenating(scaleXform)
		.concatenating(scaleOffset2)
	
	return CGAffineTransform.identity
		.concatenating(rotationTransform)
		.concatenating(scaleTransform)
}
