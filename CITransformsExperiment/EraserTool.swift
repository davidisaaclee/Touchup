import Foundation
import VectorSwift




// TODO: Move these to other files

extension CGRect {
	init(containing points: [CGPoint]) {
		func unitSquare(at point: CGPoint) -> CGRect {
			return CGRect(origin: point,
			              size: CGSize(width: 1,
			                           height: 1))
		}

		self = points
			.map { unitSquare(at: $0) }
			.reduce(points.first.map(unitSquare(at:)) ?? .zero) { $0.union($1) }
	}
}

extension CIImage {
	func flattened(using context: CIContext = CIContext()) -> CIImage {
		let imageOffset = extent.origin
		let bitmap = context.createCGImage(self, from: extent)!
		let bitmapBackedImage = CIImage(cgImage: bitmap)
			// Apply offset to get back to the `compositedImage`'s extent.
			.applying(CGAffineTransform(translationX: imageOffset.x, y: imageOffset.y))

		return bitmapBackedImage
	}
}


struct ImageFeedback {
	let image: CIImage
	let imageContext: CIContext

	func compositedUnder(_ otherImage: CIImage, dirtyRect: CGRect) -> ImageFeedback {
		let imageʹ = otherImage
			// Only take what's dirty.
			.cropping(to: dirtyRect)
			// Composite the new image over the old one.
			.compositingOverImage(image)
			// Render to a bitmap to keep future renders constant-time.
			.flattened(using: imageContext)

		return ImageFeedback(image: imageʹ,
		                     imageContext: imageContext)
	}

	mutating func setImage(_ image: CIImage, dirtyRect: CGRect) {
		self = self.compositedUnder(image, dirtyRect: dirtyRect)
	}
}

protocol DrawingToolDelegate: class {
	func drawingTool(_ drawingTool: DrawingTool, convertToCoreImageCoordinates point: CGPoint) -> CGPoint

	// This is called within a drawing context.
	func drawingTool(_ drawingTool: DrawingTool, willDrawPath path: UIBezierPath)
}

class DrawingTool {
	weak var delegate: DrawingToolDelegate?

	var imageAccumulator: ImageFeedback

	private(set) var currentPoint: CGPoint = .zero
	private(set) var isDrawing: Bool = false

	var image: CIImage {
		return imageAccumulator.image
	}

	// TODO: remove `extent`
	init?(extent: CGRect, context: CIContext = CIContext()) {
		let initialImage =
			CIImage(color: CIColor(red: 0, green: 0, blue: 1, alpha: 0))
				.cropping(to: extent)
		self.imageAccumulator =
			ImageFeedback(image: initialImage,
			              imageContext: context)
	}

	func clear() {
		let initialImage =
			CIImage(color: CIColor(red: 0, green: 0, blue: 1, alpha: 0))
				.cropping(to: imageAccumulator.image.extent)
		imageAccumulator =
			ImageFeedback(image: initialImage,
			              imageContext: imageAccumulator.imageContext)
	}

	func beginPath(at point: CGPoint) {
		currentPoint = point
		isDrawing = true
	}

	func move(to point: CGPoint) {
		move(to: [point])
	}

	func move(to points: [CGPoint]) {
		guard !points.isEmpty else {
			return
		}

		defer {
			currentPoint = points.last!
		}

		if isDrawing {
			guard let delegate = delegate else {
				return
			}

			let segmentVertices = [currentPoint] + points

			let path = UIBezierPath(points: segmentVertices)

			guard let bitmap = bitmapByDrawing(path) else {
				return
				//				fatalError("Implement me")
			}

			let segmentImage = CIImage(image: bitmap)!

			let dirtyRect =
				CGRect(containing: segmentVertices.map { delegate.drawingTool(self, convertToCoreImageCoordinates: $0) })
					.insetBy(dx: -path.lineWidth,
					         dy: -path.lineWidth)

			imageAccumulator
				.setImage(segmentImage.compositingOverImage(imageAccumulator.image),
				          dirtyRect: dirtyRect)
		}
	}

	func endPath() {
		endPath(at: currentPoint)
	}

	func endPath(at point: CGPoint) {
		currentPoint = point
		isDrawing = false
	}

	private func bitmapByDrawing(_ path: UIBezierPath) -> UIImage? {
		UIGraphicsBeginImageContext(imageAccumulator.image.extent.size)

		delegate?.drawingTool(self, willDrawPath: path)
		path.stroke()

		guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
			return nil
		}

		UIGraphicsEndImageContext()
		
		return image
	}
}










protocol EraserToolDelegate: class {
	func eraserTool(_ eraserTool: EraserTool,
	                didBeginDrawingAt point: CGPoint)
	func eraserTool(_ eraserTool: EraserTool,
	                didUpdateWorkingPath path: CGPath)
	func eraserTool(_ eraserTool: EraserTool,
	                didCommitWorkingPath path: CGPath)

	func coordinateSpaceForEraserTool(_ eraserTool: EraserTool) -> UICoordinateSpace
}

class EraserTool {

	var drawingTool: DrawingTool!

	weak var delegate: EraserToolDelegate?

	fileprivate struct Spline {
		var point: CGPoint
		var controlPoint1: CGPoint
		var controlPoint2: CGPoint

		static func straight(on point: CGPoint) -> Spline {
			return Spline(point: point, controlPoint1: point, controlPoint2: point)
		}
	}

	fileprivate enum Mode {
		case passive
		case active([Spline])
	}

	fileprivate var mode: Mode = .passive

	private let smoothFactor: CGFloat = 0.2

	func begin(with touchSample: TouchSample) {
		guard let delegate = delegate else {
			return
		}

//		let location = delegate.eraserTool(self, locationFor: touch)
		let location =
			touchSample.location(in: delegate.coordinateSpaceForEraserTool(self))
		drawingTool.beginPath(at: location)
		mode = .active([.straight(on: location)])
//		delegate.eraserTool(self, didBeginDrawingAt: location)
	}

	func change(with touchSample: TouchSample) {
		guard
			case var .active(points) = mode,
			let delegate = delegate
			else {
				return
			}

		let location =
			touchSample.location(in: delegate.coordinateSpaceForEraserTool(self))

		drawingTool.move(to: location)

//		var c: Spline = .straight(on: location)

//		// if we have at least two points in the line, we can start to smooth.
//		if var b = points.last, let a = points.dropLast().last {
//			// calling the last three points (a, b, c), where c is the point about to be added
//			let ac = c.point - a.point
//			c.controlPoint1 = smoothFactor * ac + b.point
//			b.controlPoint2 = -smoothFactor * ac + b.point
//			points.removeLast()
//			points.append(b)
//		}
//		points.append(c)

		mode = .active(points)

//		delegate.eraserTool(self, didUpdateWorkingPath: makePath(for: points))
	}

	func end() {
		guard
			case let .active(points) = mode,
			let delegate = delegate
			else {
				return
			}

		drawingTool.endPath()

		delegate.eraserTool(self, didCommitWorkingPath: makePath(for: points))
		mode = .passive
	}

	private func makePath(for points: [Spline]) -> CGPath {
		let path = CGMutablePath()
		points.first.map { path.move(to: $0.point) }
		points.dropFirst()
			.forEach { path.addCurve(to: $0.point,
			                         control1: $0.controlPoint1,
			                         control2: $0.controlPoint2) }
		return path
	}

}
