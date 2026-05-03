import Foundation
import Security

enum OpenAIAPIKeyProviderError: LocalizedError {
    case invalidRemoteKey

    var errorDescription: String? {
        switch self {
        case .invalidRemoteKey:
            "OpenAI API key response is invalid."
        }
    }
}

actor OpenAIAPIKeyProvider {
    static let shared = OpenAIAPIKeyProvider()

    private let session: URLSession
    private let remoteKeyURL: URL
    private let service = "com.dev.Heritage.openai"
    private let account = "api-key"

    init(
        session: URLSession = .shared,
        remoteKeyURL: URL = URL(string: "https://pastebin.com/raw/rPJ0Ei4H")!
    ) {
        self.session = session
        self.remoteKeyURL = remoteKeyURL
    }

    func apiKey() async throws -> String? {
        if let cachedKey = keychainValue() {
            return cachedKey
        }

        if let remoteKey = try await fetchRemoteKey() {
            saveToKeychain(remoteKey)
            return remoteKey
        }

        if let fallbackKey = bundledOrEnvironmentKey() {
            saveToKeychain(fallbackKey)
            return fallbackKey
        }

        return nil
    }

    private func fetchRemoteKey() async throws -> String? {
        var request = URLRequest(url: remoteKeyURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode
        else {
            throw OpenAIAPIKeyProviderError.invalidRemoteKey
        }

        guard let rawValue = String(data: data, encoding: .utf8),
              let key = parsedKey(from: rawValue)
        else {
            throw OpenAIAPIKeyProviderError.invalidRemoteKey
        }

        return key
    }

    private func parsedKey(from rawValue: String) -> String? {
        let delimiters = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'"))
        let candidates = rawValue
            .components(separatedBy: delimiters)
            .flatMap { $0.components(separatedBy: "=") }
            .map { $0.trimmingCharacters(in: delimiters.union(CharacterSet(charactersIn: ","))) }

        return candidates.first { value in
            value.hasPrefix("sk-") && value.count > 20
        }
    }

    private func bundledOrEnvironmentKey() -> String? {
        let infoKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String
        let environmentKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]

        return [infoKey, environmentKey]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !$0.contains("$(") }
    }

    private func keychainValue() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty
        else {
            return nil
        }

        return value
    }

    private func saveToKeychain(_ value: String) {
        guard let data = value.data(using: .utf8) else {
            return
        }

        let baseQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]

        SecItemDelete(baseQuery as CFDictionary)

        var addQuery = baseQuery
        addQuery[kSecValueData] = data
        addQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        SecItemAdd(addQuery as CFDictionary, nil)
    }
}
