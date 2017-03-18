import Foundation
import CoreImage
import AVFoundation

protocol ImageSource {
	var extent: CGRect { get }
	func image(at time: TimeInterval) -> CIImage?
	func transformed(by transformer: ImageTransformer) -> ImageSource
}

protocol ImageTransformer {
	func transform(_ image: CIImage) -> CIImage
//	func transform<Source: ImageSource>(_ source: Source) -> Source
}

protocol Playable: class {
	func play()
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

	func transformed(by transformer: ImageTransformer) -> ImageSource {
		return transformer.transform(self)
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


class CIVideoPlayer: Playable {

	var playerLayer: AVPlayerLayer!

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

	func play() {
		looper.player.play()
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

	// result retains `transformer`?
	func transformed(by transformer: ImageTransformer) -> ImageSource {
		let newExtent = transformer
			.transform(CIImage(color: .black()).cropping(to: extent))
			.extent
		return LazilyTransformedCIVideoPlayer(base: self,
		                                      transformer: transformer,
		                                      extent: newExtent)
	}
}

private class LazilyTransformedCIVideoPlayer: ImageSource, Playable {
	let base: ImageSource & Playable
	let transformer: ImageTransformer
	private(set) var extent: CGRect

	init(base: ImageSource & Playable, transformer: ImageTransformer) {
		self.base = base
		self.transformer = transformer
		self.extent = base.extent
	}

	init(base: ImageSource & Playable, transformer: ImageTransformer, extent: CGRect) {
		self.base = base
		self.transformer = transformer
		self.extent = extent
	}

	func image(at time: TimeInterval) -> CIImage? {
		let result = base.image(at: time).map(transformer.transform)
		result.map(updateExtent(withOutput:))
		return result
	}

	func transformed(by transformer: ImageTransformer) -> ImageSource {
		return LazilyTransformedCIVideoPlayer(base: self,
		                                      transformer: transformer)
	}

	func play() {
		base.play()
	}

	private func updateExtent(withOutput image: CIImage) {
		extent = image.extent
	}

}
