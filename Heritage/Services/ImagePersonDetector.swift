import ImageIO
import UIKit
import Vision

enum ImagePersonDetector {
    static func containsPerson(in image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else {
            return false
        }

        let faceRequest = VNDetectFaceRectanglesRequest()
        let humanRequest = VNDetectHumanRectanglesRequest()
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: image.visionOrientation,
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
            .left
        case .leftMirrored:
            .leftMirrored
        case .right:
            .right
        case .rightMirrored:
            .rightMirrored
        @unknown default:
            .up
        }
    }
}
