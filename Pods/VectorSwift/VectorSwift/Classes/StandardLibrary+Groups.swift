import Foundation
import CoreGraphics

extension CGFloat: Field {
	public static let additionIdentity: CGFloat = 0
	public static let multiplicationIdentity: CGFloat = 1

	public func toThePowerOf(_ exponent: CGFloat) -> CGFloat {
		return pow(self, exponent)
	}
}

extension Int: Ring {
	public static let additionIdentity: Int = 0
	public static let multiplicationIdentity: Int = 1
}
