import Foundation

extension Dictionary {
	func withTransformedValue(at key: Key,
	                          transform: (Value) -> Value) -> Dictionary {
		var copy = self
		copy[key] = self[key].map(transform)
		return copy
	}
}

extension Dictionary {
	/// Creates a copy of `dictionary` which includes the provided key-value pair.
	static func from<K, V>(_ dictionary: Dictionary<K, V>, inserting keyValuePair: (K, V)) -> Dictionary<K, V> {
		var dictionaryʹ = dictionary
		dictionaryʹ[keyValuePair.0] = keyValuePair.1
		return dictionaryʹ
	}

	/// Creates a copy of this dictionary which includes the provided key-value pair.
	func inserting(_ keyValuePair: (Key, Value)) -> Dictionary {
		return Dictionary.from(self, inserting: keyValuePair)
	}
}

extension Dictionary {
	func mapValues<T>(_ transform: @escaping (Key, Value) -> T) -> [Key: T] {
		return self.reduce([:]) { (acc: [Key: T], keyValuePair: (key: Key, value: Value)) -> [Key: T] in
			let (key, value) = keyValuePair
			return acc.inserting((key, transform(key, value)))
		}
	}

	func flatMapValues<T>(_ transform: @escaping (Key, Value) -> T?) -> [Key: T] {
		return self.reduce([:]) { (acc: [Key: T], keyValuePair: (key: Key, value: Value)) -> [Key: T] in
			let (key, value) = keyValuePair
			if let transformedValue = transform(key, value) {
				return acc.inserting((key, transformedValue))
			} else {
				return acc
			}
		}
	}
}

extension Dictionary {
	func merged(with otherDictionary: [Key: Value]) -> [Key: Value] {
		return otherDictionary.reduce(self, { $0.inserting($1) })
	}
}

extension Dictionary {
	func filterDictionary(isIncluded predicate: (Key, Value) -> Bool) -> Dictionary {
		return self.reduce([:], { (acc, kvPair) in
			if predicate(kvPair.0, kvPair.1) {
				return acc.inserting(kvPair)
			} else {
				return acc
			}
		})
	}
}

