import Foundation
import UIKit
import GLKit

class ImageSourceRenderView: GLKView {

	var ciImage: CIImage?

	// Centers "camera" at origin.
	var cameraCenteringTransform: CGAffineTransform {
		return CGAffineTransform(translationX: bounds.width / 2,
		                         y: bounds.height / 2)
	}

	// Scaling between CIContext coordinate system and view coordinate system.
	var cameraScalingTransform: CGAffineTransform {
		return CGAffineTransform(scaleX: CGFloat(drawableWidth) / bounds.width,
		                         y: CGFloat(drawableHeight) / bounds.height)
	}

	private let glContext = EAGLContext(api: .openGLES2)!
	var ciContext: CIContext!

	var drawableBounds: CGRect {
		return CGRect(x: 0, y: 0,
		              width: drawableWidth,
		              height: drawableHeight)
	}

	override init(frame: CGRect) {
		super.init(frame: frame)
		self.setup()
	}

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		self.setup()
	}

	private func setup() {
		ciContext = CIContext(eaglContext: glContext,
		                      options: [kCIContextUseSoftwareRenderer: false])
		glContext.isMultiThreaded = true
		self.context = glContext
	}

	override func draw(_ rect: CGRect) {
		guard let ciImage = ciImage else {
			return
		}

		clearBackground()
		draw(ciImage, from: ciImage.extent)
	}

	func draw(_ image: CIImage, from sourceBounds: CGRect) {
		let targetRect =
			sourceBounds
				.applying(cameraScalingTransform.inverted())
				// Center the "camera" on the origin.
				.applying(cameraCenteringTransform)
				.applying(cameraScalingTransform)

		ciContext.draw(image,
		               in: targetRect,
		               from: sourceBounds)
	}

	private func clearBackground() {
		var r: CGFloat = 0
		var g: CGFloat = 0
		var b: CGFloat = 0
		var a: CGFloat = 0

		backgroundColor?.getRed(&r, green: &g, blue: &b, alpha: &a)

		glClearColor(GLfloat(r), GLfloat(g), GLfloat(b), GLfloat(a))
		glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
	}
	
}
