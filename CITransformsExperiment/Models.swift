import Foundation
import CoreImage
import AVFoundation

protocol ImageSource {
	var extent: CGRect { get }
	func image(at time: TimeInterval) -> CIImage?
}

protocol ImageTransformer {
	func transform(_ image: CIImage) -> CIImage
}


// MARK: - Stills

extension CIFilter: ImageTransformer {
	func transform(_ image: CIImage) -> CIImage {
		setValue(image, forKey: kCIInputImageKey)
		return outputImage!
	}
}

extension CIImage: ImageSource {
	func image(at time: TimeInterval) -> CIImage? {
		return self
	}
}



// MARK: - Videos

/// Handles notifications for looping an item in a player.
class PlayerLooper: NSObject {
	let player: AVQueuePlayer

	init(player: AVQueuePlayer = AVQueuePlayer(), templateItem: AVPlayerItem) {
		self.player = player
		super.init()

		player.actionAtItemEnd = .none
		player.insert(templateItem, after: nil)
		NotificationCenter.default
			.addObserver(self,
			             selector: #selector(PlayerLooper.didFinishPlayingItem(_:)),
			             name: .AVPlayerItemDidPlayToEndTime,
			             object: templateItem)
	}

	@objc private func didFinishPlayingItem(_ notification: NSNotification) {
		if let firstItem = player.items().first {
			firstItem.seek(to: kCMTimeZero)
		} else {
			fatalError("Unexpected empty queue")
		}
	}
}


class CIVideoPlayer {

	var playerLayer: AVPlayerLayer!

	private(set) var isPlaying: Bool = false

	fileprivate let item: AVPlayerItem
	fileprivate let output = AVPlayerItemVideoOutput()
	fileprivate var looper: PlayerLooper!

	init(item: AVPlayerItem) {
		self.item = item

		item.add(output)
		looper = PlayerLooper(templateItem: item)
	}

	convenience init(url: URL) {
		self.init(item: AVPlayerItem(url: url))
	}

	func startPlaying() {
		looper.player.play()
		isPlaying = true
	}

	func frame(at time: CFTimeInterval) -> CIImage? {
		let result = pixelBuffer(at: output.itemTime(forHostTime: time))
			.map { CIImage(cvPixelBuffer: $0) }

		return result
	}

	func frameForCurrentTime() -> CIImage? {
		return frame(at: CACurrentMediaTime())
	}

	private func pixelBuffer(at time: CMTime) -> CVPixelBuffer? {
		return output.copyPixelBuffer(forItemTime: time,
		                              itemTimeForDisplay: nil)
	}
}

extension CIVideoPlayer: ImageSource {
	func image(at time: TimeInterval) -> CIImage? {
		return frame(at: time)
	}

	var extent: CGRect {
		return CGRect(origin: .zero,
		              size: item.asset.tracks(withMediaType: AVMediaTypeVideo).first!.naturalSize)
	}
}


