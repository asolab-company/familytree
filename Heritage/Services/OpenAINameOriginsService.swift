import Foundation

enum NameOriginsAnalysisError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "OpenAI API key is missing. Add OPENAI_API_KEY to Info.plist or the launch environment."
        case .invalidURL:
            "OpenAI API URL is invalid."
        case .invalidResponse:
            "OpenAI returned an invalid name origin result."
        case .requestFailed(let message):
            message
        }
    }
}

struct OpenAINameOriginsService {
    private let endpoint = URL(string: "https://api.openai.com/v1/responses")
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func analyze(query: String) async throws -> NameOriginAnalysisResult {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedQuery.isEmpty else {
            throw NameOriginsAnalysisError.invalidResponse
        }

        guard let apiKey = try await OpenAIAPIKeyProvider.shared.apiKey() else {
            throw NameOriginsAnalysisError.missingAPIKey
        }

        guard let endpoint else {
            throw NameOriginsAnalysisError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: requestBody(for: normalizedQuery),
            options: []
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NameOriginsAnalysisError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let message = NameOriginsOpenAIErrorResponse.message(from: data)
                ?? "OpenAI request failed with status \(httpResponse.statusCode)."
            throw NameOriginsAnalysisError.requestFailed(message)
        }

        return try decodeResult(from: data, fallbackQuery: normalizedQuery)
    }

    private var openAIModel: String {
        let infoModel = Bundle.main.object(forInfoDictionaryKey: "OPENAI_MODEL") as? String
        let environmentModel = ProcessInfo.processInfo.environment["OPENAI_MODEL"]

        return [infoModel, environmentModel]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !$0.contains("$(") }
            ?? "gpt-5-mini"
    }

    private func requestBody(for query: String) -> [String: Any] {
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
                            "text": userPrompt(for: query),
                        ],
                    ],
                ],
            ],
            "text": ["format": responseFormat],
        ]
    }

    private var developerPrompt: String {
        """
        You generate entertainment-style name and surname origin insights for a family-history app.
        Use only general linguistic, historical, and geographic name-origin context.
        Do not claim that the user has any ethnicity, nationality, ancestry, race, religion, or protected identity.
        Top country rows must describe where the entered name/surname is commonly found or historically associated, not the user's identity.
        Use only supported country names and flag asset names from the provided choices.
        All user-facing response values must be written in English only, regardless of the user's device language or input language.
        Keep the description clear, polished, and suitable for a premium mobile app result card.
        """
    }

    private func userPrompt(for query: String) -> String {
        """
        Generate a JSON name-origin result for this name or surname: \(query)

        Supported flag choices:
        \(CountryFlagAssets.promptChoices)

        Return exactly 5 topCountries rows. countText must be a short compact estimate label such as "1m", "300k", "50k", "20k", or "15k".
        The description should be 5-8 short paragraphs with headings where useful. Write every returned text field in English only.
        """
    }

    private var responseFormat: [String: Any] {
        [
            "type": "json_schema",
            "name": "name_origin_analysis_result",
            "strict": true,
            "schema": [
                "type": "object",
                "additionalProperties": false,
                "required": ["query", "topCountries", "description"],
                "properties": [
                    "query": ["type": "string"],
                    "topCountries": [
                        "type": "array",
                        "items": [
                            "type": "object",
                            "additionalProperties": false,
                            "required": ["country", "countText", "flagAssetName"],
                            "properties": [
                                "country": ["type": "string"],
                                "countText": ["type": "string"],
                                "flagAssetName": ["type": "string"],
                            ],
                        ],
                    ],
                    "description": ["type": "string"],
                ],
            ],
        ]
    }

    private func decodeResult(from data: Data, fallbackQuery: String) throws -> NameOriginAnalysisResult {
        let response = try JSONDecoder().decode(NameOriginsOpenAIResponse.self, from: data)

        guard let outputText = response.outputText else {
            throw NameOriginsAnalysisError.invalidResponse
        }

        let payload = try JSONDecoder().decode(
            NameOriginsOpenAIPayload.self,
            from: Data(outputText.utf8)
        )

        let countries = payload.topCountries
            .prefix(5)
            .map {
                NameOriginCountryResult(
                    country: $0.country,
                    countText: $0.countText,
                    flagAssetName: CountryFlagAssets.assetName(
                        for: $0.country,
                        suggestedAssetName: $0.flagAssetName
                    )
                )
            }

        guard countries.count == 5 else {
            throw NameOriginsAnalysisError.invalidResponse
        }

        return NameOriginAnalysisResult(
            query: payload.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallbackQuery : payload.query,
            topCountries: countries,
            description: payload.description
        )
    }
}

private struct NameOriginsOpenAIPayload: Decodable {
    let query: String
    let topCountries: [Country]
    let description: String

    struct Country: Decodable {
        let country: String
        let countText: String
        let flagAssetName: String?
    }
}

private struct NameOriginsOpenAIResponse: Decodable {
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

private struct NameOriginsOpenAIErrorResponse: Decodable {
    let error: ErrorBody?

    static func message(from data: Data) -> String? {
        try? JSONDecoder()
            .decode(NameOriginsOpenAIErrorResponse.self, from: data)
            .error?
            .message
    }

    struct ErrorBody: Decodable {
        let message: String
    }
}
