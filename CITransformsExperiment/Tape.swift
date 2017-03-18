import Foundation


enum FrameSmoothingAlgorithm {
	case copyLastKeyframe
}

struct Tape<Frame> {
	let fps: Double
	var frames: [Frame?]

	var duration: TimeInterval {
		return Double(frames.count) / fps
	}

	func smoothFrames(using algorithm: FrameSmoothingAlgorithm) -> [Frame] {
		switch algorithm {
		case .copyLastKeyframe:
			guard let firstFilledFrame = frames.first(where: { $0 != nil }) else {
				fatalError("Implement me")
			}

			var previousWrittenFrame: Frame = firstFilledFrame!

			return frames.map { frameOrNil in
				if let frame = frameOrNil {
					previousWrittenFrame = frame
					return frame
				} else {
					return previousWrittenFrame
				}
			}
		}
	}

	init(length: Int, fps: Double = 30) {
		self.frames = [Frame?](repeating: nil, count: length)
		self.fps = fps
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

//			print("Erased (\(startIndex)..<\(endIndex)): \(Array((startIndex ..< frames.endIndex)) + Array(frames.startIndex ..< endIndex))")
		}
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

	func frameIndex(for time: TimeInterval) -> Int {
		return Int(time * tape.fps) % tape.frames.count
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
			tape.frames[frameIndex(for: time)] = frame
//			print("Inserted at \(frameIndex(for: time))")
		}
	}

	mutating func update(for time: TimeInterval) {
		switch state {
		case .stopped:
			return

		case let .recording(lastWrittenFrameIndex):
			let currentIndex = frameIndex(for: time)

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

