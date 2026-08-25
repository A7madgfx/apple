//
//  TimelapseGenerator.swift
//  Merges all "5:00 AM Progress" photos sequentially into an MP4 video.
//

import AVFoundation
import UIKit

struct TimelapseGenerator {
    /// Renders an MP4 from the given ordered set of morning-review photos.
    /// Each frame holds for `secondsPerPhoto`.
    static func generate(
        photos: [ProgressPhoto],
        secondsPerPhoto: Double = 0.5,
        size: CGSize = CGSize(width: 1080, height: 1350),
        progress: @escaping (Double) -> Void = { _ in }
    ) async throws -> URL {
        guard !photos.isEmpty else { throw TimelapseError.noPhotos }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("timelapse_\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: outputURL)

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB
            ]
        )
        input.expectsMediaDataInRealTime = false
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let fps: Int32 = 30
        let framesPerPhoto = Int32(secondsPerPhoto * Double(fps))
        var frameIndex: Int64 = 0

        for (i, photo) in photos.sorted(by: { $0.takenAt < $1.takenAt }).enumerated() {
            guard let image = PhotoStorageService.shared.loadImage(fileName: photo.fileName),
                  let buffer = image.pixelBuffer(size: size) else { continue }

            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
            }
            let time = CMTime(value: frameIndex, timescale: fps)
            adaptor.append(buffer, withPresentationTime: time)
            frameIndex += Int64(framesPerPhoto)
            progress(Double(i + 1) / Double(photos.count))
        }

        input.markAsFinished()
        await writer.finishWriting()
        return outputURL
    }

    enum TimelapseError: Error { case noPhotos }
}

private extension UIImage {
    /// Renders the image, centered and aspect-filled, into a pixel buffer
    /// suitable for AVAssetWriter.
    func pixelBuffer(size: CGSize) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height),
                             kCVPixelFormatType_32ARGB, attrs as CFDictionary, &pixelBuffer)
        guard let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width), height: Int(size.height),
            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }

        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        let aspect = max(size.width / self.size.width, size.height / self.size.height)
        let drawSize = CGSize(width: self.size.width * aspect, height: self.size.height * aspect)
        let origin = CGPoint(x: (size.width - drawSize.width) / 2, y: (size.height - drawSize.height) / 2)

        UIGraphicsPushContext(context)
        draw(in: CGRect(origin: origin, size: drawSize))
        UIGraphicsPopContext()

        return buffer
    }
}
