import Foundation
import UIKit

enum HeritageAnalysisError: LocalizedError {
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
            "OpenAI returned an invalid heritage result."
        case .noPeopleDetected:
            "Please choose a photo with at least one person."
        case .requestFailed(let message):
            message
        }
    }
}

struct OpenAIHeritageService {
    private let endpoint = URL(string: "https://api.openai.com/v1/responses")
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func analyze(input: HeritageAnalysisInput, image: UIImage? = nil) async throws -> HeritageAnalysisResult {
        if let image, !ImagePersonDetector.containsPerson(in: image) {
            throw HeritageAnalysisError.noPeopleDetected
        }

        guard let apiKey = try await OpenAIAPIKeyProvider.shared.apiKey() else {
            throw HeritageAnalysisError.missingAPIKey
        }

        guard let endpoint else {
            throw HeritageAnalysisError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: requestBody(for: input, image: image),
            options: []
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HeritageAnalysisError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let message = OpenAIErrorResponse.message(from: data)
                ?? "OpenAI request failed with status \(httpResponse.statusCode)."
            throw HeritageAnalysisError.requestFailed(message)
        }

        return try decodeResult(from: data, fallbackSurname: input.surname)
    }

    private var openAIModel: String {
        let infoModel = Bundle.main.object(forInfoDictionaryKey: "OPENAI_MODEL") as? String
        let environmentModel = ProcessInfo.processInfo.environment["OPENAI_MODEL"]

        return [infoModel, environmentModel]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !$0.contains("$(") }
            ?? "gpt-5-mini"
    }

    private func requestBody(for input: HeritageAnalysisInput, image: UIImage?) -> [String: Any] {
        var userContent: [[String: String]] = [
            [
                "type": "input_text",
                "text": userPrompt(for: input, includesImage: image != nil),
            ],
        ]

        if let imageData = image?.normalizedHeritageJPEGData(),
           !imageData.isEmpty {
            userContent.append(
                [
                    "type": "input_image",
                    "image_url": "data:image/jpeg;base64,\(imageData.base64EncodedString())",
                ]
            )
        }

        return [
            "model": openAIModel,
            "reasoning": [
                "effort": "low",
            ],
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
                    "content": userContent,
                ],
            ],
            "text": [
                "format": responseFormat,
            ],
        ]
    }

    private var developerPrompt: String {
        """
        You generate entertainment-style family heritage insights for an onboarding paywall.
        Do not infer ethnicity, race, nationality, religion, or any protected attribute from a face or photo.
        Use the supplied name/surname and general name-origin context for origin rows.
        If a portrait image is provided, use it only for non-sensitive visual storytelling context such as lighting, composition, clothing era, and portrait mood.
        Return exactly five unique origin rows. This is not a genetic, biometric, or identity claim.
        Origin rows must represent plausible surname/name-origin associations, not the user's actual ethnicity.
        Use only supported flag asset names from the provided choices.
        All user-facing response values must be written in English only, regardless of the user's device language or input language.
        Return country names in English. Return surname and surnameDescription in English.
        Keep surnameDescription concise, readable, and suitable for a premium app card.
        """
    }

    private func userPrompt(for input: HeritageAnalysisInput, includesImage: Bool) -> String {
        """
        Generate a JSON heritage result for:
        Full name: \(input.fullName)
        Surname to analyze: \(input.surname)
        Gender: \(input.gender)
        Birth date: \(input.birthMonth) \(input.birthDay), \(input.birthYear)
        Portrait image included: \(includesImage ? "yes" : "no")

        Supported flag choices:
        \(CountryFlagAssets.promptChoices)

        If a portrait image is included, do not use it to infer protected attributes such as ethnicity, race, nationality, religion, ancestry, or genetic background.
        Treat the image only as non-sensitive visual context for the entertainment presentation.
        The origins array must contain exactly 5 countries. Percentages should look plausible and total 100.
        Use integer percentages only. The highest percentage should be first, followed by descending percentages.
        Do not use duplicate countries. Do not include a percent sign in the JSON number.
        Write every returned text field in English only.
        """
    }

    private var responseFormat: [String: Any] {
        [
            "type": "json_schema",
            "name": "heritage_analysis_result",
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

    private func decodeResult(from data: Data, fallbackSurname: String) throws -> HeritageAnalysisResult {
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)

        guard let outputText = response.outputText else {
            throw HeritageAnalysisError.invalidResponse
        }

        let payloadData = Data(outputText.utf8)
        let payload = try JSONDecoder().decode(OpenAIHeritagePayload.self, from: payloadData)

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
            throw HeritageAnalysisError.invalidResponse
        }

        return HeritageAnalysisResult(
            origins: origins,
            surname: payload.surname.isEmpty ? fallbackSurname : payload.surname,
            surnameDescription: payload.surnameDescription
        )
    }
}

private extension UIImage {
    func normalizedHeritageJPEGData(maxPixel: CGFloat = 1400, quality: CGFloat = 0.86) -> Data? {
        let longestSide = max(size.width, size.height)
        let scale = longestSide > maxPixel ? maxPixel / longestSide : 1
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let image = renderer.image { _ in
            UIColor.black.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: targetSize)).fill()
            draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return image.jpegData(compressionQuality: quality)
    }
}

private struct OpenAIHeritagePayload: Decodable {
    let origins: [Origin]
    let surname: String
    let surnameDescription: String

    struct Origin: Decodable {
        let country: String
        let percentage: Int
        let flagAssetName: String?
    }
}

private struct OpenAIResponse: Decodable {
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

private struct OpenAIErrorResponse: Decodable {
    let error: ErrorBody?

    static func message(from data: Data) -> String? {
        try? JSONDecoder()
            .decode(OpenAIErrorResponse.self, from: data)
            .error?
            .message
    }

    struct ErrorBody: Decodable {
        let message: String
    }
}
