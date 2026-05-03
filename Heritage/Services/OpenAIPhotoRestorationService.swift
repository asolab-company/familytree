import Foundation
import UIKit

enum PhotoRestorationError: LocalizedError {
    case missingAPIKey
    case invalidImage
    case invalidURL
    case invalidResponse
    case noPeopleDetected
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "OpenAI API key is missing. Add OPENAI_API_KEY to Info.plist or the launch environment."
        case .invalidImage:
            "Could not prepare this photo for restoration."
        case .invalidURL:
            "OpenAI image restoration URL is invalid."
        case .invalidResponse:
            "OpenAI returned an invalid restored photo."
        case .noPeopleDetected:
            "Please choose a photo with at least one person for restoration."
        case .requestFailed(let message):
            message
        }
    }
}

struct OpenAIPhotoRestorationService {
    private let imageEditEndpoint = URL(string: "https://api.openai.com/v1/images/edits")
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func restore(_ image: UIImage) async throws -> UIImage {
        guard ImagePersonDetector.containsPerson(in: image) else {
            throw PhotoRestorationError.noPeopleDetected
        }

        guard let apiKey = try await OpenAIAPIKeyProvider.shared.apiKey() else {
            throw PhotoRestorationError.missingAPIKey
        }

        guard let imageEditEndpoint else {
            throw PhotoRestorationError.invalidURL
        }

        guard let imageData = image.restorationJPEGData(), !imageData.isEmpty else {
            throw PhotoRestorationError.invalidImage
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: imageEditEndpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(imageData: imageData, boundary: boundary)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PhotoRestorationError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let message = PhotoRestorationOpenAIErrorResponse.message(from: data)
                ?? "OpenAI photo restoration failed with status \(httpResponse.statusCode)."
            throw PhotoRestorationError.requestFailed(message)
        }

        return try await decodeRestoredImage(from: data)
    }

    private var imageModel: String {
        let infoModel = Bundle.main.object(forInfoDictionaryKey: "OPENAI_IMAGE_MODEL") as? String
        let environmentModel = ProcessInfo.processInfo.environment["OPENAI_IMAGE_MODEL"]

        return [infoModel, environmentModel]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !$0.contains("$(") }
            ?? "gpt-image-1"
    }

    private var prompt: String {
        """
        Fully restore this old family photograph.
        Preserve the same people, facial identity, pose, clothing, composition, and background.
        Remove scratches, stains, dust, cracks, paper texture damage, fading, blur, noise, and exposure issues.
        Reconstruct missing or damaged details naturally without changing identity.
        If the photo is black and white or sepia, colorize it realistically with natural skin tones and period-appropriate colors.
        If the photo is already color, restore the original color balance and make it look like a clean modern high-quality scan.
        Keep the result photorealistic. Do not make it look like a painting, illustration, cartoon, glamour retouch, or a different person.
        """
    }

    private func multipartBody(imageData: Data, boundary: String) -> Data {
        var body = Data()

        body.appendField(name: "model", value: imageModel, boundary: boundary)
        body.appendField(name: "prompt", value: prompt, boundary: boundary)
        body.appendField(name: "n", value: "1", boundary: boundary)
        body.appendField(name: "size", value: "auto", boundary: boundary)
        body.appendField(name: "quality", value: "high", boundary: boundary)
        body.appendField(name: "output_format", value: "jpeg", boundary: boundary)
        body.appendFile(
            name: "image",
            filename: "photo.jpg",
            mimeType: "image/jpeg",
            data: imageData,
            boundary: boundary
        )
        body.appendString("--\(boundary)--\r\n")

        return body
    }

    private func decodeRestoredImage(from data: Data) async throws -> UIImage {
        let response = try JSONDecoder().decode(PhotoRestorationOpenAIResponse.self, from: data)

        if let base64 = response.data?.compactMap(\.b64JSON).first,
           let imageData = Data(base64Encoded: base64),
           let image = UIImage(data: imageData) {
            return image
        }

        if let url = response.data?.compactMap(\.url).first {
            let (imageData, _) = try await session.data(from: url)
            if let image = UIImage(data: imageData) {
                return image
            }
        }

        throw PhotoRestorationError.invalidResponse
    }
}

private struct PhotoRestorationOpenAIResponse: Decodable {
    let data: [ImageResult]?

    struct ImageResult: Decodable {
        let b64JSON: String?
        let url: URL?

        enum CodingKeys: String, CodingKey {
            case b64JSON = "b64_json"
            case url
        }
    }
}

private struct PhotoRestorationOpenAIErrorResponse: Decodable {
    let error: ErrorBody?

    static func message(from data: Data) -> String? {
        try? JSONDecoder()
            .decode(PhotoRestorationOpenAIErrorResponse.self, from: data)
            .error?
            .message
    }

    struct ErrorBody: Decodable {
        let message: String
    }
}

private extension Data {
    mutating func appendField(name: String, value: String, boundary: String) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        appendString("\(value)\r\n")
    }

    mutating func appendFile(
        name: String,
        filename: String,
        mimeType: String,
        data: Data,
        boundary: String
    ) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        appendString("Content-Type: \(mimeType)\r\n\r\n")
        append(data)
        appendString("\r\n")
    }

    mutating func appendString(_ string: String) {
        append(Data(string.utf8))
    }
}

private extension UIImage {
    func restorationJPEGData(maxPixel: CGFloat = 1536, quality: CGFloat = 0.92) -> Data? {
        let image = normalizedForRestoration()
        let longestSide = max(image.size.width, image.size.height)
        let scale = longestSide > maxPixel ? maxPixel / longestSide : 1
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let rendered = renderer.image { _ in
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: targetSize)).fill()
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return rendered.jpegData(compressionQuality: quality)
    }

    func normalizedForRestoration() -> UIImage {
        guard imageOrientation != .up else {
            return self
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
