import Vision
import UIKit
import CoreImage

struct MatRecognitionResult {
    let isVerified: Bool
    let confidence: Double
    let reasonIfRejected: String?
}

/// On-device prayer-mat verification. No network calls, no persistence of the captured
/// image — the UIImage/CIImage is discarded as soon as this function returns.
///
/// Implementation note (documented limitation): there is no bespoke "prayer mat" Core ML
/// classifier bundled with this project (none ships with iOS, and training one is outside
/// this repo's scope — see README). Instead this pipeline combines Vision's general-purpose
/// on-device classifier (VNClassifyImageRequest, part of iOS's built-in scene/object
/// taxonomy which includes rug/carpet/mat-adjacent labels) with deterministic image-quality
/// heuristics (blur, brightness, rectangle/coverage detection) to reject obviously invalid
/// photos. This is the strongest fully-on-device, Apple-API-only approach without a
/// custom-trained model; it is not claimed to be 100% accurate — see confidenceThreshold.
final class PrayerMatRecognitionService {
    private let confidenceThreshold: Double = 0.35
    private let matRelatedLabels: Set<String> = [
        "rug", "carpet", "mat", "doormat", "prayer rug", "prayer mat", "runner rug",
        "floor", "flooring", "textile", "fabric", "pattern", "tapestry"
    ]
    private let rejectLabels: Set<String> = [
        "person", "face", "screen", "screenshot", "monitor", "television", "furniture",
        "chair", "sofa", "table", "wall", "empty room"
    ]

    func verify(image: UIImage) async -> MatRecognitionResult {
        guard let cgImage = image.cgImage else {
            return MatRecognitionResult(isVerified: false, confidence: 0, reasonIfRejected: "تعذر قراءة الصورة، حاول مرة أخرى.")
        }

        if isTooBlurry(cgImage) {
            return MatRecognitionResult(isVerified: false, confidence: 0, reasonIfRejected: "الصورة غير واضحة. حاول تصوير السجادة كاملة وبإضاءة واضحة")
        }
        if isTooDark(cgImage) {
            return MatRecognitionResult(isVerified: false, confidence: 0, reasonIfRejected: "الإضاءة غير كافية. حاول تصوير السجادة كاملة وبإضاءة واضحة")
        }

        do {
            let (matScore, rejectScore) = try await classify(cgImage: cgImage)
            let passesHeuristics = hasSufficientFloorCoverage(cgImage)
            let confidence = matScore * (passesHeuristics ? 1.0 : 0.5)

            if rejectScore > matScore + 0.15 {
                return MatRecognitionResult(isVerified: false, confidence: confidence, reasonIfRejected: "لم نتمكن من التحقق من سجادة الصلاة")
            }
            if confidence >= confidenceThreshold && passesHeuristics {
                return MatRecognitionResult(isVerified: true, confidence: confidence, reasonIfRejected: nil)
            }
            return MatRecognitionResult(isVerified: false, confidence: confidence, reasonIfRejected: "لم نتمكن من التحقق من سجادة الصلاة")
        } catch {
            return MatRecognitionResult(isVerified: false, confidence: 0, reasonIfRejected: "لم نتمكن من التحقق من سجادة الصلاة")
        }
    }

    private func classify(cgImage: CGImage) async throws -> (matScore: Double, rejectScore: Double) {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNClassificationObservation]) ?? []
                var matScore: Double = 0
                var rejectScore: Double = 0
                for obs in observations {
                    let label = obs.identifier.lowercased()
                    if self.matRelatedLabels.contains(where: { label.contains($0) }) {
                        matScore = max(matScore, Double(obs.confidence))
                    }
                    if self.rejectLabels.contains(where: { label.contains($0) }) {
                        rejectScore = max(rejectScore, Double(obs.confidence))
                    }
                }
                continuation.resume(returning: (matScore, rejectScore))
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Deterministic quality/framing heuristics

    private func isTooBlurry(_ cgImage: CGImage) -> Bool {
        guard let variance = laplacianVariance(cgImage) else { return false }
        return variance < 40.0
    }

    private func isTooDark(_ cgImage: CGImage) -> Bool {
        guard let avg = averageLuminance(cgImage) else { return false }
        return avg < 0.12
    }

    /// Rejects extremely cropped/close-up shots by checking edge-detail spread across the frame —
    /// a real mat laid on the floor tends to show varied texture across most of the frame,
    /// whereas an extreme crop or a mostly-empty floor shows a narrow, uniform region.
    private func hasSufficientFloorCoverage(_ cgImage: CGImage) -> Bool {
        guard let ciImage = CIImage(cgImage: cgImage) as CIImage? else { return true }
        let context = CIContext()
        guard let edges = CIFilter(name: "CIEdges", parameters: [kCIInputImageKey: ciImage, "inputIntensity": 2.0])?.outputImage,
              let extentImage = context.createCGImage(edges, from: edges.extent) else { return true }
        guard let avg = averageLuminance(extentImage) else { return true }
        return avg > 0.02
    }

    private func averageLuminance(_ cgImage: CGImage) -> Double? {
        let ciImage = CIImage(cgImage: cgImage)
        let extentVector = CIVector(x: ciImage.extent.origin.x, y: ciImage.extent.origin.y, z: ciImage.extent.size.width, w: ciImage.extent.size.height)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: ciImage, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        let luminance = (0.299 * Double(bitmap[0]) + 0.587 * Double(bitmap[1]) + 0.114 * Double(bitmap[2])) / 255.0
        return luminance
    }

    private func laplacianVariance(_ cgImage: CGImage) -> Double? {
        let ciImage = CIImage(cgImage: cgImage)
        guard let mono = CIFilter(name: "CIPhotoEffectMono", parameters: [kCIInputImageKey: ciImage])?.outputImage,
              let laplacian = CIFilter(name: "CIConvolution3X3", parameters: [
                kCIInputImageKey: mono,
                "inputWeights": CIVector(values: [0, 1, 0, 1, -4, 1, 0, 1, 0], count: 9),
                "inputBias": 0.5
              ])?.outputImage else { return nil }

        let context = CIContext()
        let extent = laplacian.extent.intersection(CGRect(x: 0, y: 0, width: min(200, ciImage.extent.width), height: min(200, ciImage.extent.height)))
        guard extent.width > 0, extent.height > 0, let cg = context.createCGImage(laplacian, from: extent) else { return nil }
        guard let data = cg.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return nil }

        let width = cg.width, height = cg.height
        let bytesPerPixel = cg.bitsPerPixel / 8
        var sum: Double = 0
        var sumSq: Double = 0
        var count: Double = 0
        var y = 0
        while y < height {
            var x = 0
            while x < width {
                let offset = y * cg.bytesPerRow + x * bytesPerPixel
                if offset < CFDataGetLength(data) {
                    let value = Double(bytes[offset])
                    sum += value
                    sumSq += value * value
                    count += 1
                }
                x += 2
            }
            y += 2
        }
        guard count > 0 else { return nil }
        let mean = sum / count
        return sumSq / count - mean * mean
    }
}
