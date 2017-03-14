import Foundation

struct History<Model> {
	var stack: [Model] = []
	var currentIndex: Int = -1

	mutating func push(_ model: Model) {
		stack
			.removeSubrange(stack.index(after: currentIndex) ..< stack.endIndex)
		stack.append(model)
		currentIndex += 1
	}

	mutating func undo() -> Model? {
		let indexʹ = stack.index(before: currentIndex)
		guard stack.indices.contains(indexʹ) else {
			return nil
		}

		currentIndex = indexʹ
		return stack[indexʹ]
	}

	mutating func redo() -> Model? {
		let indexʹ = stack.index(after: currentIndex)
		guard stack.indices.contains(indexʹ) else {
			return nil
		}

		currentIndex = indexʹ
		return stack[indexʹ]
	}
}
