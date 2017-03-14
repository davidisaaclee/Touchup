import AVFoundation

extension CGImage {
	var size: CGSize {
		return CGSize(width: width,
		              height: height)
	}
}

/// Turns image sequences into videos.
public class ImageSequencer {
	private typealias WritingContext =
		(videoWriter: AVAssetWriter,
		writerInput: AVAssetWriterInput,
		adaptor: AVAssetWriterInputPixelBufferAdaptor)

	public enum Error: Swift.Error {
		case externalError(Swift.Error)
	}

    public class Session {
        private let sequencer: ImageSequencer
        private let configuration: ImageSequencer.Configuration
        private let writingContext: ImageSequencer.WritingContext

        private var frameIndex = 0

        fileprivate init(sequencer: ImageSequencer,
                     configuration: ImageSequencer.Configuration,
                     writingContext: ImageSequencer.WritingContext) {
            self.sequencer = sequencer
            self.configuration = configuration
            self.writingContext = writingContext
        }
        
        public func append(_ frame: CGImage) {
            let i = self.frameIndex
            self.frameIndex += 1

            DispatchQueue.main.async {
                let (_, framesAdvancedBy) = self.sequencer.writeLoop(frame: frame,
                                                                     frameIndex: i,
                                                                     writingContext: self.writingContext,
                                                                     frameDuration: self.configuration.frameDuration)
//                self.frameIndex += framesAdvancedBy
            }
        }

        public func finish(_ completion: ((URL?, ImageSequencer.Error?) -> Void)?) {
            sequencer.finishWritingSession(writingContext: writingContext) { urlOrNil, errorOrNil in
                if let url = urlOrNil {
                    completion?(url, nil)
                } else if let error = errorOrNil {
                    completion?(nil, error)
                }
            }
        }
    }

    public struct Configuration {
        let outputVideoSize: CGSize
        let destination: URL
        let frameDuration: TimeInterval

        public init(outputVideoSize: CGSize,
                    destination: URL,
                    frameDuration: TimeInterval) {
            self.outputVideoSize = outputVideoSize
            self.destination = destination
            self.frameDuration = frameDuration
        }
    }

//	public static func generateVideoFromImageSequence(imageSequence: [CGImage],
//	                                                  outputVideoSize: CGSize,
//	                                                  destinationURL: NSURL,
//	                                                  frameDuration: NSTimeInterval,
//	                                                  completion: (NSURL?, ErrorType?) -> Void) {
//		return ImageSequencer().generateVideoFromImageSequence(imageSequence,
//		                                                       outputVideoSize: outputVideoSize,
//		                                                       destinationURL: destinationURL,
//		                                                       frameDuration: frameDuration,
//		                                                       completion: completion)
//	}

    public let configuration: Configuration

    public init(configuration: Configuration) {
        self.configuration = configuration
    }

    public func start(completion: @escaping (ImageSequencer.Session?, ImageSequencer.Error?) -> Void) {
        self.setupWritingContext(size: self.configuration.outputVideoSize, destinationFilePath: self.configuration.destination) { writingContextOrNil, errorOrNil in
            if let error = errorOrNil {
                completion(nil, error)
            } else if let writingContext = writingContextOrNil {
                self.startWritingSession(writingContext: writingContext)

                let session = ImageSequencer.Session(sequencer: self,
                                                     configuration: self.configuration,
                                                     writingContext: writingContext)
                completion(session, nil)
            }
        }
    }

	func generateVideo(from imageSequence: [CGImage], outputVideoSize: CGSize,
	                   destinationURL: URL, frameDuration: TimeInterval,
	                   completion: @escaping (URL?, Swift.Error?) -> Void) {
		self.setupWritingContext(size: outputVideoSize, destinationFilePath: destinationURL) { writingContextOrNil, errorOrNil in
			if let error = errorOrNil {
				completion(nil, error)
			} else if let writingContext = writingContextOrNil {
				self.startWritingSession(writingContext: writingContext)

				var frameIndex = 0
				var isWriting = imageSequence.indices.contains(frameIndex)
				while isWriting {
					let (shouldContinueLoop, framesAdvancedBy) =
						self.writeLoop(frame: imageSequence[frameIndex],
						               frameIndex: frameIndex,
						               writingContext: writingContext,
						               frameDuration: frameDuration)
					frameIndex += framesAdvancedBy
					isWriting =
						shouldContinueLoop && imageSequence.indices.contains(frameIndex)
				}

				self.finishWritingSession(writingContext: writingContext) { urlOrNil, errorOrNil in
					if let url = urlOrNil {
						completion(url, nil)
					} else if let error = errorOrNil {
						completion(nil, error)
					}
				}
			}
		}
	}

	// MARK: - Setup

	/// Ensures video's size is divisible by 16.
	static func coerceSize(size: CGSize) -> CGSize {
		let alignment: CGFloat = 16.0
		let newWidth = size.width - (size.width.truncatingRemainder(dividingBy: alignment))
		assert(newWidth.truncatingRemainder(dividingBy: alignment) == 0.0)

		return CGSize(width: newWidth, height: size.height * (newWidth / size.width))
	}

	private func setupWritingContext(size: CGSize, destinationFilePath: URL,
	                                 completion: @escaping (WritingContext?, Error?) -> Void) {
		self.makeVideoWriter(forPath: destinationFilePath, destinationFileType: AVFileTypeAppleM4V) { videoWriterOrNil, errorOrNil in
			if let err = errorOrNil {
				completion(nil, err)
			} else if let videoWriter = videoWriterOrNil {
				let writerInput = self.makeWriterInput(withSize: size)
				let adaptor = self.makeWriterInputAdaptor(forInput: writerInput, size: size)
				videoWriter.add(writerInput)
				let context = (videoWriter, writerInput, adaptor)
				completion(context, nil)
			}
		}
	}

	private func makeVideoWriter(forPath destinationFilePath: URL, destinationFileType: String,
	                                    completion: (AVAssetWriter?, Error?) -> Void) {
		do {
			let videoWriter = try AVAssetWriter(outputURL: destinationFilePath,
			                                    fileType: destinationFileType)
			completion(videoWriter, nil)
		} catch let err {
			completion(nil, .externalError(err))
		}
	}

	private func makeWriterInput(withSize size: CGSize) -> AVAssetWriterInput {
		let input =
			AVAssetWriterInput(mediaType: AVMediaTypeVideo,
			                   outputSettings: self.videoSettings(withSize: size))
		input.expectsMediaDataInRealTime = true
		return input
	}

	private func makeWriterInputAdaptor(forInput writerInput: AVAssetWriterInput, size: CGSize) -> AVAssetWriterInputPixelBufferAdaptor {
		let attributes: [String: Any] =
			[kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: Int32(kCVPixelFormatType_32BGRA)),
			 kCVPixelBufferWidthKey as String: NSNumber(value: Int(size.width)),
			 kCVPixelBufferHeightKey as String: NSNumber(value: Int(size.height)),
			 kCVPixelBufferCGImageCompatibilityKey as String: NSNumber(value: true),
			 kCVPixelBufferCGBitmapContextCompatibilityKey as String: NSNumber(value: true)
		]

		return AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput,
		                                            sourcePixelBufferAttributes: attributes)
	}

	private func videoSettings(withSize size: CGSize) -> [String: Any] {
		return [
			AVVideoCodecKey: AVVideoCodecH264,
			AVVideoWidthKey: NSNumber(value: Int(size.width)),
			AVVideoHeightKey: NSNumber(value: Int(size.height)),
			AVVideoCompressionPropertiesKey: [
				AVVideoAverageBitRateKey: NSNumber(value: 1000000),
//				AVVideoAverageBitRateKey: NSNumber(value: 7500000.0), // 7.5 mbps
				AVVideoMaxKeyFrameIntervalKey: NSNumber(value: 16),
				AVVideoMaxKeyFrameIntervalDurationKey: NSNumber(value: 0.0),
				AVVideoProfileLevelKey: AVVideoProfileLevelH264Main31
//				AVVideoProfileLevelKey: AVVideoProfileLevelH264High41,
			],
		]
	}

	// MARK: - Writing session

	private func startWritingSession(writingContext: WritingContext) {
		writingContext.videoWriter.startWriting()
		writingContext.videoWriter.startSession(atSourceTime: kCMTimeZero)
	}

	private func writeLoop(frame: CGImage, frameIndex: Int, writingContext: WritingContext,
	                       frameDuration: TimeInterval) -> (continueLoop: Bool, framesAdvancedBy: Int) {
		guard writingContext.writerInput.isReadyForMoreMediaData else {
			return (true, 0)
		}
		guard let bufferPool = writingContext.adaptor.pixelBufferPool else {
			fatalError("Could not get buffer pool from adaptor")
		}



		/*
		CMTime = Value and Timescale.
		Timescale = the number of tics per second you want
		Value = the number of tics
		Apple recommend 600 tics per second for video because it is a multiple of the standard video rates 24, 30, 60 fps etc.
		*/
		let ticsPerSecond: CMTimeScale = 600
		let currentTime: CMTime =
			CMTime(value: CMTimeValue(Double(frameIndex) * frameDuration * Double(ticsPerSecond)),
			       timescale: ticsPerSecond)

//		if frameIndex < frames.count, let buffer = self.pixelBufferFromImage(frames[frameIndex], pool: bufferPool) {
		if let buffer = self.pixelBuffer(from: frame, pool: bufferPool) {
			// Append frame to writer.
//			print("Before: ", writingContext.adaptor.pixelBufferPool != nil)
//			print("Appending frame at \(currentTime)...")
			let succeeded =
				writingContext.adaptor
					.append(buffer,
					        withPresentationTime: currentTime)

//			print(succeeded ? "Successful." : "Failed")
//			print("After: ", writingContext.adaptor.pixelBufferPool != nil)
			return (true, 1)
		} else {
//			print("No frame")
//			if let buffer = frames.first.flatMap({ self.pixelBufferFromImage($0, pool: bufferPool) }) {
//				writingContext.adaptor.appendPixelBuffer(buffer, withPresentationTime: currentTime)
//			}
			return (false, 0)
		}
	}

	private func finishWritingSession(writingContext: WritingContext,
	                                  completion: @escaping (URL?, Error?) -> Void) {
		writingContext.writerInput.markAsFinished()
		writingContext.videoWriter.finishWriting {
			if writingContext.videoWriter.status == .completed {
				completion(writingContext.videoWriter.outputURL, nil)
			} else if let error = writingContext.videoWriter.error {
				completion(nil, .externalError(error))
			}
		}
	}

//	private func pixelBufferFromImage(image: UIImage) -> CVPixelBuffer? {
//		return pixelBufferFromImage(image.CGImage)
//	}

	private func pixelBuffer(from image: CGImage, pool: CVPixelBufferPool?) -> CVPixelBuffer? {
//		let dictKeys = [kCVPixelBufferCGImageCompatibilityKey,
//		                kCVPixelBufferCGBitmapContextCompatibilityKey,
//		                kCVPixelBufferPixelFormatTypeKey]
//		let dictValues = [true,
//		                  true,
//		                  NSNumber(value: kCVPixelFormatType_32RGBA)]
//		let pixelBufferAttributes: CFDictionary =
//			CFDictionaryCreate(kCFAllocatorDefault,
//			                   UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: dictKeys.count),
//			                   UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: dictValues.count),
//			                   dictKeys.count,
//			                   nil,
//			                   nil)

		// Create the pixel buffer.

		var pixelBufferOrNil: CVPixelBuffer?

		if let pool = pool {
			let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault,
			                                                pool,
			                                                &pixelBufferOrNil)

			guard status == kCVReturnSuccess else { return nil }
		} else {
			fatalError("Implement me")
//			CVPixelBufferCreate(kCFAllocatorDefault,
//			                    Int(configuration.outputVideoSize.width),
//			                    Int(configuration.outputVideoSize.height),
//			                    OSType.allZeros,
//			                    pixelBufferAttributes,
//			                    &pixelBufferOrNil)
		}

		guard let pixelBuffer = pixelBufferOrNil else { return nil }

		CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
		let pixelDataPointer = CVPixelBufferGetBaseAddress(pixelBuffer)
		guard pixelDataPointer != nil else { return nil }

		// Create output bitmap context.

		let bitsPerComponent = 8
		let bytesPerRow = 4 * image.width
		var colorSpace = CGColorSpaceCreateDeviceRGB()
		let bitmapInfo = CGImageAlphaInfo.noneSkipFirst

		var bitmapContext = CGContext(data: pixelDataPointer,
		                              width: image.width,
		                              height: image.height,
		                              bitsPerComponent: bitsPerComponent,
		                              bytesPerRow: bytesPerRow,
		                              space: colorSpace,
		                              bitmapInfo: bitmapInfo.rawValue)

		// Write from input context to output context.
		bitmapContext?.concatenate(CGAffineTransform(rotationAngle: 0)) // ?
		bitmapContext?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

//		colorSpace = nil
		bitmapContext = nil

		CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
		return pixelBuffer
	}
	
}
