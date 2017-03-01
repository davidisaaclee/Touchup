# VectorSwift

## Usage

VectorSwift provides a `Vector` protocol which can give any type the power to perform vector operations.

Here is a `CGPoint` extension, adopting the `Vector` protocol.

```swift
extension CGPoint: Vector {
	// What is the CGPoint `i` which, when added to any other CGPoint `p`, produces `p`?
	public static let additionIdentity: CGPoint = .zero
	
	// What is the CGPoint `i` which, when multiplied with any other CGPoint `p`, produces `p`?
	public static let multiplicationIdentity: CGPoint = CGPoint(x: 1, y: 1)

	// We need to specify the number of dimensions, so that the vector operations can be configured
	// to fit the dimension.
	public var numberOfDimensions: Int { return 2 }

	// Every `Vector` can be initialized from a collection. This allows easy conversion among similar
	// vector types.
	public init<T: Collection>(collection: T) where T.Iterator.Element == CGFloat {
		var g = collection.makeIterator()
		guard let x = g.next(), let y = g.next() else {
			fatalError()
		}
		self.init(x: x, y: y)
	}

	// `Vector` inherits from `Collection`, and internally leverages `Collection`'s methods for supporting
	// multi-dimensional vectors.
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
```

Once we define this adoption, we can use all of `Vector`'s operations within `CGPoint`.

```swift
let pt1 = CGPoint(x: 3, y: 4)
let pt2 = CGPoint(collection: [1, -2])

pt1.magnitude == 5
pt1 + pt2 == CGPoint(x: 4, y: 2)
pt2 * 0.5 == CGPoint(x: 0.5, y: -1)
-pt1 == CGPoint(x: -4, y: -2)
```

`Vector` also supports a handful of operations which can combine different kinds of `Vector`s. In the following example, both `CGPoint` and `CGSize` have adopted `Vector`.

```swift
let point = CGPoint(x: 1, y: -1)
let size = CGSize(width: 5, height: 10)

let pointDifference: CGPoint = point - size
let sizeDifference: CGSize = point - size

pointDifference == CGPoint(x: -4, y: -11)
sizeDifference == CGSize(width: -4, height: -11)
```

## Running the tests

~~To run the tests included in the example project, clone the repo, and run `pod install` from the Example directory first.~~

Test frameworks need to be updated to Swift 3 :(

## Installation

Vector is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "VectorSwift", :git => "https://github.com/davidisaaclee/VectorSwift.git"
```

## Author

David Lee, http://david-lee.net

## License

VectorSwift is available under the MIT license. See the LICENSE file for more info.
