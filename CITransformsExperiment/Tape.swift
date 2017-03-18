import Foundation


//enum FrameSmoothingAlgorithm {
//	case copyLastKeyframe
//	case fallbackOnEmptyFrames(fallback: ImageSource)
//}

protocol FrameSmoothingAlgorithm {
	associatedtype Frame

	func transform(_ tape: Tape<Frame>) -> [Frame]
}

struct CGImageFrameSmoothingAlgorithm: FrameSmoothingAlgorithm {
	typealias Frame = CGImage

	let transformBlock: (Tape<CGImage>) -> [CGImage]

	func transform(_ tape: Tape<CGImage>) -> [CGImage] {
		return transformBlock(tape)
	}

	static let copyLastKeyframe = CGImageFrameSmoothingAlgorithm { (tape) -> [CGImage] in
		guard let firstFilledFrame = tape.frames.first(where: { $0 != nil }) else {
			fatalError("Implement me")
		}

		var previousWrittenFrame: CGImage = firstFilledFrame!

		return tape.frames.map { frameOrNil in
			if let frame = frameOrNil {
				previousWrittenFrame = frame
				return frame
			} else {
				return previousWrittenFrame
			}
		}
	}

	static func fallbackOnEmptyFrames(fallback: ImageSource) -> CGImageFrameSmoothingAlgorithm {
		return CGImageFrameSmoothingAlgorithm { (tape) -> [CGImage] in
			fatalError("Implement me")
		}
	}
}

struct Tape<Frame> {
	let fps: Double
	var frames: [Frame?]

	var duration: TimeInterval {
		return Double(frames.count) / fps
	}


	init(length: Int, fps: Double = 30) {
		self.frames = [Frame?](repeating: nil, count: length)
		self.fps = fps
	}

	func smoothFrames<A: FrameSmoothingAlgorithm>(using algorithm: A) -> [Frame] where A.Frame == Frame {
		return algorithm.transform(self)
	}

	func frameIndex(for time: TimeInterval) -> Int {
		return Int(time * fps) % frames.count
	}

	func time(for frameIndex: Int) -> TimeInterval {
		fatalError("Implement me")
	}

	mutating func eraseAll() {
		frames = frames.map { _ in nil }
	}

	// erases frames from startIndex ascending to but excluding endIndex, looping if necessary.
	mutating func eraseFrames(from startIndex: Int, to endIndex: Int) {
		if startIndex <= endIndex {
			(startIndex ..< endIndex).forEach { frames[$0] = nil }
		} else {
			(startIndex ..< frames.endIndex).forEach { frames[$0] = nil }
			(frames.startIndex ..< endIndex).forEach { frames[$0] = nil }
		}
	}

	mutating func trimEmptyFramesFromEnd() {
		var numberOfSequentialEmptyFramesAtEnd = 0
		var i = frames.index(before: frames.endIndex)

		while frames.indices.contains(i) && frames[i] == nil {
			i = frames.index(before: i)
			numberOfSequentialEmptyFramesAtEnd += 1
		}

		frames.removeLast(numberOfSequentialEmptyFramesAtEnd)
	}
}

fileprivate enum TapeRecorderState {
	case stopped
	case recording(lastWrittenFrameIndex: Int)
}

struct TapeRecorder<Frame> {
	var tape: Tape<Frame>

	fileprivate var state: TapeRecorderState = .stopped

	init(tape: Tape<Frame>) {
		self.tape = tape
	}

	mutating func beginRecording() {
		state = .recording(lastWrittenFrameIndex: 0)
	}

	// time is relative to time began recording
	mutating func insert(_ frame: Frame, at time: TimeInterval) {
		update(for: time)

		switch state {
		case .stopped:
			return

		case .recording:
			tape.frames[tape.frameIndex(for: time)] = frame
//			print("Inserted at \(frameIndex(for: time))")
		}
	}

	mutating func update(for time: TimeInterval) {
		switch state {
		case .stopped:
			return

		case let .recording(lastWrittenFrameIndex):
			let currentIndex = tape.frameIndex(for: time)

			let lower =
				tape.frames.index(after: lastWrittenFrameIndex) % tape.frames.count
			let upper =
				tape.frames.index(after: currentIndex) % tape.frames.count
			tape.eraseFrames(from: lower, to: upper)

			state = .recording(lastWrittenFrameIndex: currentIndex)
		}

	}

	mutating func stop(at stopTime: TimeInterval) {
		update(for: stopTime)
		state = .stopped
	}

	private func shouldLoop(previousTime: TimeInterval, currentTime: TimeInterval) -> Bool {
		return previousTime.truncatingRemainder(dividingBy: tape.duration)
			> currentTime.truncatingRemainder(dividingBy: tape.duration)
	}
}

