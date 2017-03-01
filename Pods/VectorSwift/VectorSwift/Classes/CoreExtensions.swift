/*
Extensions to commonly-used vector types in Apple's core libraries.
*/

import Foundation
import CoreGraphics


extension CGPoint: Vector {
	public static let additionIdentity: CGPoint = .zero
	public static let multiplicationIdentity: CGPoint = CGPoint(x: 1, y: 1)

	public var numberOfDimensions: Int { return 2 }

	public init<T: Collection>(collection: T) where T.Iterator.Element == CGFloat {
		var g = collection.makeIterator()
		guard let x = g.next(), let y = g.next() else {
			fatalError()
		}
		self.init(x: x, y: y)
	}

	public subscript(index: Int) -> CGFloat {
		switch index {
		case 0:
			return x
		case 1:
			return y
		default:
			fatalError()
		}
	}

	public func index(after i: Int) -> Int {
		return i + 1
	}
}

extension CGSize: Vector {
	public typealias Index = Int

	public static let additionIdentity = CGSize.zero
	public static let multiplicationIdentity = CGSize(width: 1, height: 1)

	public var numberOfDimensions: Int { return 2 }

	public init<T: Collection>(collection: T) where T.Iterator.Element == CGFloat {
		var g = collection.makeIterator()
		guard let width = g.next(), let height = g.next() else {
			fatalError()
		}
		self.init(width: width, height: height)
	}

	public subscript(index: Int) -> CGFloat {
		switch index {
		case 0:
			return width
		case 1:
			return height
		default:
			fatalError()
		}
	}

	public func index(after i: Int) -> Int {
		return i + 1
	}
}
