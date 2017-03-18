import Foundation
import CoreImage


extension CIFilter {
	convenience init?(transform: CGAffineTransform) {
		self.init(name: "CIAffineTransform",
		          withInputParameters: [kCIInputTransformKey: NSValue(cgAffineTransform: transform)])
	}
}
