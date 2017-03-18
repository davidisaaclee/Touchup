import UIKit

// from http://samwize.com/2016/06/01/resize-uiimage-in-swift/
extension UIImage {

	/// Returns a image that fills in newSize
	func resizing(to newSize: CGSize) -> UIImage {
		// Guard newSize is different
		guard self.size != newSize else { return self }

		UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0);
		self.draw(in: CGRect(origin: .zero, size: newSize))
		let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
		UIGraphicsEndImageContext()
		return newImage
	}

	/// Returns a resized image that fits in rectSize, keeping it's aspect ratio
	/// Note that the new image size is not rectSize, but within it.
	func resizing(toFitWithin rectSize: CGSize) -> UIImage {
//		let widthFactor = size.width / rectSize.width
//		let heightFactor = size.height / rectSize.height
//
//		var resizeFactor = widthFactor
//		if size.height > size.width {
//			resizeFactor = heightFactor
//		}
//
//		return self.resizing(to: CGSize(width: size.width / resizeFactor,
//		                                height: size.height / resizeFactor))
		return self.resizing(to: size.aspectFitting(within: rectSize))
	}

}


extension CGImage {

	/// Returns a image that fills in newSize
	func resizing(to newSize: CGSize) -> CGImage {
		// Guard newSize is different
		guard self.size != newSize else { return self }

		UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0);
		guard let context = UIGraphicsGetCurrentContext() else {
			fatalError("Implement me")
		}

		context.draw(self, in: CGRect(origin: .zero, size: newSize))
		let image =
			context.makeImage()!
		UIGraphicsEndImageContext()

		return image

//		self.draw(in: CGRect(origin: .zero, size: newSize))
//		let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
//		UIGraphicsEndImageContext()
//		return newImage.cgImage
	}

}

extension CGSize {
	func aspectFitting(within bounds: CGSize) -> CGSize {
		let widthFactor = self.width / bounds.width
		let heightFactor = self.height / bounds.height

		var resizeFactor = widthFactor
		if self.height > self.width {
			resizeFactor = heightFactor
		}

		return CGSize(width: self.width / resizeFactor,
		              height: self.height / resizeFactor)
	}
}
