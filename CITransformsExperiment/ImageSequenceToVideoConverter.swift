//// adapted from http://stackoverflow.com/questions/3741323/how-do-i-export-uiimage-array-as-a-movie/3742212#3742212
//
//import Foundation
//import AVFoundation
//
//private typealias WritingContext = (videoWriter: AVAssetWriter, writerInput: AVAssetWriterInput, adaptor: AVAssetWriterInputPixelBufferAdaptor)
//
//enum Result<T> {
//	case success(T)
//	case failure(Error)
//}
//
//func convertImageSequenceToVideo(imageSequence: [CGImage],
//                                 outputVideoSize: CGSize,
//                                 completion: @escaping (Result<URL>) -> Void) {
//	do {
//		let outputFilePath =
//			(NSTemporaryDirectory() as NSString).appendingPathComponent("\(UUID().uuidString)_vid.mp4")
//		let destinationFilePath =
//			URL(fileURLWithPath: outputFilePath, isDirectory: false)
//
//		let writingContext =
//			try setupWritingContext(size: outputVideoSize,
//			                        destinationFilePath: destinationFilePath)
//
//		startWritingSession(writingContext: writingContext)
//
//		var remainingImageSequence: ArraySlice<CGImage> = ArraySlice(imageSequence)
//		var isWriting = true
//		var frameIndex = 0
//		while isWriting {
//			let (shouldContinueLoop, framesAdvancedBy) =
//				writeLoop(frameGenerator: remainingImageSequence,
//				          frameIndex: frameIndex,
//				          writingContext: writingContext)
//
//			remainingImageSequence = remainingImageSequence.dropFirst(framesAdvancedBy)
//			frameIndex += framesAdvancedBy
//			isWriting = shouldContinueLoop
//		}
//
//		finishWritingSession(writingContext: writingContext, completion: completion)
//	} catch {
//		completion(.failure(error))
//	}
//}
//
//
//// MARK: - Setup
//
//private func setupWritingContext(size: CGSize, destinationFilePath: URL) throws -> WritingContext {
//	let videoWriter = try makeVideoWriter(writingTo: destinationFilePath,
//	                                      destinationFileType: AVFileTypeQuickTimeMovie)
//	let writerInput = makeWriterInput(size: size)
//	let adaptor = makeWriterInputAdaptor(forInput: writerInput)
//	videoWriter.add(writerInput)
//	return (videoWriter, writerInput, adaptor)
//}
//
//private func makeVideoWriter(writingTo destinationFilePath: URL, destinationFileType: String) throws -> AVAssetWriter {
//	return try AVAssetWriter(outputURL: destinationFilePath,
//	                         fileType: destinationFileType)
//}
//
//private func makeWriterInput(size: CGSize) -> AVAssetWriterInput {
//	return AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoSettings(withSize: size))
//}
//
//private func makeWriterInputAdaptor(forInput writerInput: AVAssetWriterInput) -> AVAssetWriterInputPixelBufferAdaptor {
//	return AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: nil)
//}
//
//private func videoSettings(withSize size: CGSize) -> [String: Any] {
//	return [
//		AVVideoCodecKey: AVVideoCodecH264,
//		AVVideoWidthKey: size.width,
//		AVVideoHeightKey: size.height
//	]
//}
//
//
//
//// MARK: - Writing session
//
//private func startWritingSession(writingContext: WritingContext) {
//	writingContext.videoWriter.startWriting()
//	writingContext.videoWriter.startSession(atSourceTime: kCMTimeZero)
//}
//
//private func finishWritingSession(writingContext: WritingContext,
//                                  completion: @escaping (Result<URL>) -> Void) {
//	writingContext.writerInput.markAsFinished()
//	writingContext.videoWriter.finishWriting {
//		if writingContext.videoWriter.status == .completed {
//			completion(.success(writingContext.videoWriter.outputURL))
//		} else {
//			completion(.failure(writingContext.videoWriter.error!))
//		}
//	}
//	// TODO: `CVPixelBufferPoolRelease` is no longer available. Does this work as a replacement?
////	CVPixelBufferPoolFlush(writingContext.adaptor.pixelBufferPool!, kCVPixelBufferPoolFlushExcessBuffers)
//}
//
//private func writeLoop<A: Collection>(frameGenerator: A,
//                       frameIndex: Int,
//                       writingContext: WritingContext) -> (continueLoop: Bool, framesAdvancedBy: Int)
//		where A.Iterator.Element: CGImage {
//
//	guard writingContext.writerInput.isReadyForMoreMediaData else { return (true, 0) }
//
//	/*
//	CMTime = Value and Timescale.
//	Timescale = the number of tics per second you want
//	Value = the number of tics
//
//	Apple recommend 600 tics per second for video because it is a multiple of the standard video rates 24, 30, 60 fps etc.
//	*/
//	let frameDurationInSeconds: Float = 0.01666
//	let ticsPerSecond: Float = 600
//	let frameDuration: CMTime = CMTimeMake(Int64(frameDurationInSeconds * ticsPerSecond), Int32(ticsPerSecond))
//	let previousTime: CMTime = CMTimeMake(Int64(frameIndex) * frameDuration.value, Int32(ticsPerSecond))
//	// This switch ensures the first frame starts at 0.
//	let currentTime: CMTime = frameIndex == 0 ? CMTimeMake(0, Int32(ticsPerSecond)) : CMTimeAdd(previousTime, frameDuration)
//
//	if let frame = frameGenerator.first, let buffer = pixelBuffer(from: frame) {
//		// Append frame to writer.
//		writingContext.adaptor.append(buffer, withPresentationTime: currentTime)
//		return (true, 1)
//	} else {
//		return (false, 0)
//	}
//}
//
//
//// MARK: - Helpers
//
//private func pixelBuffer(from image: UIImage) -> CVPixelBuffer? {
//	return pixelBuffer(from: image.cgImage!)
//}
//
//private func pixelBuffer(from image: CGImage) -> CVPixelBuffer? {
//	let imageWidth = image.width
//	let imageHeight = image.height
//	let dictKeys = [kCVPixelBufferCGImageCompatibilityKey, kCVPixelBufferCGBitmapContextCompatibilityKey]
//	let dictValues = [true, true]
//	let pixelBufferAttributes: CFDictionary =
//		CFDictionaryCreate(kCFAllocatorDefault,
//		                   UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: dictKeys.count),
//		                   UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: dictValues.count),
//		                   dictKeys.count,
//		                   nil,
//		                   nil)
//
//	// Create the pixel buffer.
//
//	var pixelBufferOrNil: CVPixelBuffer?
//	let status = CVPixelBufferCreate(kCFAllocatorDefault, imageWidth, imageHeight, kCVPixelFormatType_32ARGB, pixelBufferAttributes, &pixelBufferOrNil)
//
//	guard status == kCVReturnSuccess else { return nil }
//	guard let pixelBuffer = pixelBufferOrNil else { return nil }
//
//	CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly) // was 0, not .readOnly :/
//	let pixelDataPointer = CVPixelBufferGetBaseAddress(pixelBuffer)
//	guard pixelDataPointer != nil else { return nil }
//
//
//	// Create output bitmap context.
//
//	let bitsPerComponent = 8
//	let bytesPerRow = 4 * imageWidth
//	let colorSpace = CGColorSpaceCreateDeviceRGB()
//	let bitmapInfo = CGImageAlphaInfo.noneSkipFirst
//
//	let bitmapContext: CGContext? =
//		CGContext(data: pixelDataPointer,
//		          width: imageWidth,
//		          height: imageHeight,
//		          bitsPerComponent: bitsPerComponent,
//		          bytesPerRow: bytesPerRow,
//		          space: colorSpace,
//		          bitmapInfo: bitmapInfo.rawValue)
//
//
//	// Write from input context to output context.
//
//	bitmapContext?.concatenate(CGAffineTransform(rotationAngle: 0)) // ??
////	CGContextConcatCTM(bitmapContext, CGAffineTransformMakeRotation(0))
//	bitmapContext?.draw(image, in: CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
////	CGContextDrawImage(bitmapContext, CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight), image)
////	CGColorSpaceRelease(colorSpace)
////	CGContextRelease(bitmapContext)
////	colorSpace = nil
////	bitmapContext = nil
//
////	CVPixelBufferUnlockBaseAddress(pixelBuffer, 0)
//	CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
//
//	return pixelBuffer
//}
