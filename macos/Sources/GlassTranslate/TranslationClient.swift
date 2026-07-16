import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct TranslationClient: Sendable {
    struct Configuration: Sendable {
        let sourceLanguage: SourceLanguage
        let targetLanguage: TargetLanguage
        let freeServiceEmail: String
    }

    private struct MyMemoryResponse: Decodable, Sendable {
        struct ResponseData: Decodable, Sendable {
            let translatedText: String
        }
        let responseData: ResponseData
        let responseStatus: Int?
        let responseDetails: String?
        let quotaFinished: Bool?
    }

    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func translate(_ source: String, configuration: Configuration) async throws -> String {
        try await translateWithMyMemory(source, configuration: configuration)
    }

    private func translateWithMyMemory(_ source: String, configuration: Configuration) async throws -> String {
        let sourceLanguage = configuration.sourceLanguage.languageCode ?? Self.detectedLanguageCode(source)
        let targetLanguage = Self.targetLanguageCode(configuration.targetLanguage, source: sourceLanguage)
        if sourceLanguage == targetLanguage { return source }

        var translations: [String] = []
        for chunk in Self.utf8Chunks(source, maximumBytes: 450) {
            var components = URLComponents(string: "https://api.mymemory.translated.net/get")!
            var queryItems = [
                URLQueryItem(name: "q", value: chunk),
                URLQueryItem(name: "langpair", value: "\(sourceLanguage)|\(targetLanguage)"),
                URLQueryItem(name: "mt", value: "1")
            ]
            let email = configuration.freeServiceEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            if !email.isEmpty { queryItems.append(URLQueryItem(name: "de", value: email)) }
            components.queryItems = queryItems
            guard let url = components.url else { throw TranslationError.invalidEndpoint }

            var request = URLRequest(url: url)
            request.timeoutInterval = 20
            request.setValue("Wonder/0.3", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw TranslationError.invalidResponse }
            guard 200..<300 ~= http.statusCode else {
                throw TranslationError.freeService("请求失败（\(http.statusCode)）")
            }
            guard let result = try? JSONDecoder().decode(MyMemoryResponse.self, from: data) else {
                throw TranslationError.invalidResponse
            }
            if result.quotaFinished == true {
                throw TranslationError.freeService("今日免费额度已用完，可在设置中填写邮箱提升额度。")
            }
            if let status = result.responseStatus, status >= 400 {
                throw TranslationError.freeService(result.responseDetails ?? "请求被拒绝")
            }
            let translated = result.responseData.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !translated.isEmpty else { throw TranslationError.emptyResult }
            translations.append(translated)
        }
        return translations.joined(separator: source.contains("\n") ? "\n" : " ")
    }

    static func detectedLanguageCode(_ text: String) -> String {
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x3040...0x30FF: return "ja"
            case 0xAC00...0xD7AF: return "ko"
            case 0x0400...0x04FF: return "ru"
            default: continue
            }
        }
        if text.unicodeScalars.contains(where: { 0x3400...0x9FFF ~= $0.value }) { return "zh-CN" }
        return "en"
    }

    static func targetLanguageCode(_ target: TargetLanguage, source: String) -> String {
        switch target {
        case .automatic: source.hasPrefix("zh") ? "en" : "zh-CN"
        case .simplifiedChinese: "zh-CN"
        case .traditionalChinese: "zh-TW"
        case .english: "en-US"
        case .englishUK: "en-GB"
        case .japanese: "ja"
        case .korean: "ko"
        case .french: "fr"
        case .german: "de"
        case .spanish: "es"
        case .russian: "ru"
        case .italian: "it"
        case .portuguese: "pt"
        }
    }

    static func utf8Chunks(_ text: String, maximumBytes: Int) -> [String] {
        guard text.utf8.count > maximumBytes else { return [text] }
        var chunks: [String] = []
        var current = ""
        var currentBytes = 0
        for character in text {
            let value = String(character)
            let bytes = value.utf8.count
            if currentBytes + bytes > maximumBytes, !current.isEmpty {
                chunks.append(current)
                current = ""
                currentBytes = 0
            }
            current.append(character)
            currentBytes += bytes
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }
}
