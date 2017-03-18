import Foundation

enum Result<Wrapped> {
	case success(Wrapped)
	case failure(Error)
}

extension Result {
	func map<T>(_ transform: (Wrapped) -> T) -> Result<T> {
		switch self {
		case let .success(value):
			return .success(transform(value))

		case let .failure(error):
			return .failure(error)
		}
	}

	func flatMap<T>(_ transform: (Wrapped) -> Result<T>) -> Result<T> {
		switch self {
		case let .success(value):
			return transform(value)

		case let .failure(error):
			return .failure(error)
		}
	}
}
