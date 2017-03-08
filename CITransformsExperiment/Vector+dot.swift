import UIKit
import VectorSwift

extension Vector where Self.Iterator.Element == CGFloat, Self.LengthType == CGFloat, Self.Index == Int {
	func dot<V: Vector>(other: V) -> Iterator.Element
		where V.Iterator.Element == Iterator.Element,
		V.LengthType == Self.LengthType,
		V.Index == Self.Index
	{
		return self.magnitude * other.magnitude * cos(atan2(other[0] - self[1], other[0] - self[0]))
	}

	func angle<V: Vector>(to otherVector: V) -> CGFloat
		where V.Iterator.Element == Iterator.Element,
		V.LengthType == Self.LengthType,
		V.Index == Self.Index
	{
		return acos(self.dot(other: otherVector) / (self.magnitude * otherVector.magnitude))
	}

	func scalarProjection<V: Vector>(on otherVector: V) -> Iterator.Element
		where V.Iterator.Element == Iterator.Element,
		V.LengthType == Self.LengthType,
		V.Index == Self.Index
	{
		return self.magnitude * cos(angle(to: otherVector))
	}

	func vectorProjection<V: Vector>(on otherVector: V) -> V
		where V.Iterator.Element == Iterator.Element,
		V.LengthType == Self.LengthType,
		V.Index == Self.Index
	{
		return scalarProjection(on: otherVector) * otherVector.unit
	}

	func rejection<V: Vector>(on otherVector: V) -> V
		where V.Iterator.Element == Iterator.Element,
		V.LengthType == Self.LengthType,
		V.Index == Self.Index
	{
		return self - self.vectorProjection(on: otherVector)
	}
}
