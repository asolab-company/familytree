import Foundation
import UIKit

enum ScanAnalysisError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case noPeopleDetected
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "OpenAI API key is missing. Add OPENAI_API_KEY to Info.plist or the launch environment."
        case .invalidURL:
            "OpenAI API URL is invalid."
        case .invalidResponse:
            "OpenAI returned an invalid scan result."
        case .noPeopleDetected:
            "Please choose a photo with at least one person."
        case .requestFailed(let message):
            message
        }
    }
}

struct OpenAIScanAnalysisService {
    private let endpoint = URL(string: "https://api.openai.com/v1/responses")
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func analyze(image: UIImage) async throws -> HeritageAnalysisResult {
        guard ImagePersonDetector.containsPerson(in: image) else {
            throw ScanAnalysisError.noPeopleDetected
        }

        guard let apiKey = try await OpenAIAPIKeyProvider.shared.apiKey() else {
            throw ScanAnalysisError.missingAPIKey
        }

        guard let endpoint else {
            throw ScanAnalysisError.invalidURL
        }

        guard let imageData = image.normalizedScanJPEGData(),
              !imageData.isEmpty
        else {
            throw ScanAnalysisError.invalidResponse
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: requestBody(imageData: imageData),
            options: []
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ScanAnalysisError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let message = ScanOpenAIErrorResponse.message(from: data)
                ?? "OpenAI request failed with status \(httpResponse.statusCode)."
            throw ScanAnalysisError.requestFailed(message)
        }

        return try decodeResult(from: data)
    }

    private var openAIModel: String {
        let infoModel = Bundle.main.object(forInfoDictionaryKey: "OPENAI_MODEL") as? String
        let environmentModel = ProcessInfo.processInfo.environment["OPENAI_MODEL"]

        return [infoModel, environmentModel]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !$0.contains("$(") }
            ?? "gpt-5-mini"
    }

    private func requestBody(imageData: Data) -> [String: Any] {
        [
            "model": openAIModel,
            "reasoning": ["effort": "low"],
            "input": [
                [
                    "role": "developer",
                    "content": [
                        [
                            "type": "input_text",
                            "text": developerPrompt,
                        ],
                    ],
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "input_text",
                            "text": userPrompt,
                        ],
                        [
                            "type": "input_image",
                            "image_url": "data:image/jpeg;base64,\(imageData.base64EncodedString())",
                        ],
                    ],
                ],
            ],
            "text": ["format": responseFormat],
        ]
    }

    private var developerPrompt: String {
        """
        You create an entertainment-only portrait scan result for a family-history app.
        Do not infer or claim the person's ethnicity, race, nationality, religion, ancestry, or genetic background from their face or appearance.
        Use the photo only for non-sensitive visual context such as lighting, composition, clothing era, and portrait mood.
        Return five unique fictional "heritage inspiration" rows using supported country names and flag asset names. The rows are a playful app experience, not an identity claim.
        All user-facing response values must be written in English only, regardless of the user's device language or input language.
        Return country names in English. Return surname and surnameDescription in English.
        Keep surnameDescription short and explain that the result is a visual storytelling scan, not biometric ancestry.
        """
    }

    private var userPrompt: String {
        """
        Analyze this portrait for a non-sensitive, entertainment-style visual heritage scan.
        Supported flag choices:
        \(CountryFlagAssets.promptChoices)

        Return exactly 5 rows. Percentages must total 100.
        Use integer percentages only. The highest percentage should be first, followed by descending percentages.
        Do not use duplicate countries. Do not include a percent sign in the JSON number.
        Write every returned text field in English only.
        """
    }

    private var responseFormat: [String: Any] {
        [
            "type": "json_schema",
            "name": "scan_analysis_result",
            "strict": true,
            "schema": [
                "type": "object",
                "additionalProperties": false,
                "required": ["origins", "surname", "surnameDescription"],
                "properties": [
                    "origins": [
                        "type": "array",
                        "minItems": 5,
                        "maxItems": 5,
                        "items": [
                            "type": "object",
                            "additionalProperties": false,
                            "required": ["country", "percentage", "flagAssetName"],
                            "properties": [
                                "country": ["type": "string"],
                                "percentage": [
                                    "type": "integer",
                                    "minimum": 0,
                                    "maximum": 100,
                                ],
                                "flagAssetName": ["type": "string"],
                            ],
                        ],
                    ],
                    "surname": ["type": "string"],
                    "surnameDescription": ["type": "string"],
                ],
            ],
        ]
    }

    private func decodeResult(from data: Data) throws -> HeritageAnalysisResult {
        let response = try JSONDecoder().decode(ScanOpenAIResponse.self, from: data)

        guard let outputText = response.outputText else {
            throw ScanAnalysisError.invalidResponse
        }

        let payload = try JSONDecoder().decode(
            ScanOpenAIHeritagePayload.self,
            from: Data(outputText.utf8)
        )

        let origins = HeritageOriginResult.normalizedTopFive(payload.origins
            .prefix(5)
            .map {
                HeritageOriginResult(
                    country: $0.country,
                    percentage: $0.percentage,
                    flagAssetName: CountryFlagAssets.assetName(
                        for: $0.country,
                        suggestedAssetName: $0.flagAssetName
                    )
                )
            })

        guard origins.count == 5 else {
            throw ScanAnalysisError.invalidResponse
        }

        return HeritageAnalysisResult(
            origins: origins,
            surname: payload.surname,
            surnameDescription: payload.surnameDescription
        )
    }
}

private struct ScanOpenAIHeritagePayload: Decodable {
    let origins: [Origin]
    let surname: String
    let surnameDescription: String

    struct Origin: Decodable {
        let country: String
        let percentage: Int
        let flagAssetName: String?
    }
}

private struct ScanOpenAIResponse: Decodable {
    let output: [OutputItem]?

    var outputText: String? {
        output?
            .flatMap { $0.content ?? [] }
            .compactMap(\.text)
            .joined()
    }

    struct OutputItem: Decodable {
        let content: [ContentItem]?
    }

    struct ContentItem: Decodable {
        let text: String?
    }
}

private struct ScanOpenAIErrorResponse: Decodable {
    let error: ErrorBody?

    static func message(from data: Data) -> String? {
        try? JSONDecoder()
            .decode(ScanOpenAIErrorResponse.self, from: data)
            .error?
            .message
    }

    struct ErrorBody: Decodable {
        let message: String
    }
}

private extension UIImage {
    func normalizedScanJPEGData() -> Data? {
        let longestSide = max(size.width, size.height)
        let scale = longestSide > 1200 ? 1200 / longestSide : 1
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let renderedImage = renderer.image { _ in
            UIColor.black.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: targetSize)).fill()
            draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return renderedImage.jpegData(compressionQuality: 0.82)
    }
}
