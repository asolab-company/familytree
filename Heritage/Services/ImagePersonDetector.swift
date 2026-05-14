import ImageIO
import UIKit
import Vision

enum ImagePersonDetector {
    static func containsPerson(in image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else {
            return false
        }

        if detectPerson(in: cgImage, orientation: image.visionOrientation) {
            return true
        }

        guard let normalizedImage = image.normalizedForVision(),
              let normalizedCGImage = normalizedImage.cgImage
        else {
            return false
        }

        return detectPerson(in: normalizedCGImage, orientation: .up)
    }

    private static func detectPerson(
        in cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) -> Bool {
        let faceRequest = VNDetectFaceRectanglesRequest()
        let humanRequest = VNDetectHumanRectanglesRequest()
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: orientation,
            options: [:]
        )

        do {
            try handler.perform([faceRequest, humanRequest])
        } catch {
            return false
        }

        let hasFace = faceRequest.results?.contains {
            $0.confidence >= 0.35 && $0.boundingBox.area >= 0.004
        } ?? false

        let hasHuman = humanRequest.results?.contains {
            $0.confidence >= 0.25 && $0.boundingBox.area >= 0.015
        } ?? false

        return hasFace || hasHuman
    }
}

private extension CGRect {
    var area: CGFloat {
        width * height
    }
}

private extension UIImage {
    var visionOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up:
            .up
        case .upMirrored:
            .upMirrored
        case .down:
            .down
        case .downMirrored:
            .downMirrored
        case .left:
            .leftMirrored
        case .leftMirrored:
            .left
        case .right:
            .rightMirrored
        case .rightMirrored:
            .right
        @unknown default:
            .up
        }
    }

    func normalizedForVision() -> UIImage? {
        guard imageOrientation != .up else {
            return nil
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
