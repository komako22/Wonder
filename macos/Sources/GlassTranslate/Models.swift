import CoreGraphics
import Foundation

struct SelectionSnapshot: Equatable, Sendable {
    let text: String
    let screenRect: CGRect

    var signature: String {
        "\(text)|\(Int(screenRect.midX))|\(Int(screenRect.midY))"
    }
}

enum SelectionMethod: String, CaseIterable, Identifiable, Codable, Sendable {
    case automatic
    case accessibilityOnly
    case clipboardOnly

    static var allCases: [SelectionMethod] { [.automatic, .accessibilityOnly] }

    var id: String { rawValue }
    var title: String {
        switch self {
        case .automatic: "自动兼容（推荐）"
        case .accessibilityOnly: "仅辅助功能"
        case .clipboardOnly: "仅安全复制"
        }
    }
}

enum BubblePosition: String, CaseIterable, Identifiable, Codable, Sendable {
    case below
    case above
    case pointer

    var id: String { rawValue }
    var title: String {
        switch self {
        case .below: "选区下方"
        case .above: "选区上方"
        case .pointer: "鼠标附近"
        }
    }
}

enum GlassTheme: String, CaseIterable, Identifiable, Codable, Sendable {
    case system
    case frost
    case midnight
    case aurora

    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "跟随系统"
        case .frost: "霜白"
        case .midnight: "深海"
        case .aurora: "极光"
        }
    }
}

enum SourceLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case automatic
    case simplifiedChinese
    case traditionalChinese
    case englishUS
    case englishUK
    case japanese
    case korean
    case french
    case german
    case spanish
    case russian
    case italian
    case portuguese

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "自动检测"
        case .simplifiedChinese: "中文（简体）"
        case .traditionalChinese: "中文（繁体）"
        case .englishUS: "英语（美国）"
        case .englishUK: "英语（英国）"
        case .japanese: "日语"
        case .korean: "韩语"
        case .french: "法语"
        case .german: "德语"
        case .spanish: "西班牙语"
        case .russian: "俄语"
        case .italian: "意大利语"
        case .portuguese: "葡萄牙语"
        }
    }

    var languageCode: String? {
        switch self {
        case .automatic: nil
        case .simplifiedChinese: "zh-CN"
        case .traditionalChinese: "zh-TW"
        case .englishUS: "en-US"
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
}

enum TargetLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case automatic
    case simplifiedChinese
    case traditionalChinese
    case english
    case englishUK
    case japanese
    case korean
    case french
    case german
    case spanish
    case russian
    case italian
    case portuguese

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "自动（中英互译）"
        case .simplifiedChinese: "中文（简体）"
        case .traditionalChinese: "中文（繁体）"
        case .english: "英语（美国）"
        case .englishUK: "英语（英国）"
        case .japanese: "日语"
        case .korean: "韩语"
        case .french: "法语"
        case .german: "德语"
        case .spanish: "西班牙语"
        case .russian: "俄语"
        case .italian: "意大利语"
        case .portuguese: "葡萄牙语"
        }
    }

    static var quickTranslationChoices: [TargetLanguage] {
        allCases.filter { $0 != .automatic }
    }
}

enum TranslationError: LocalizedError, Equatable {
    case invalidEndpoint
    case invalidResponse
    case emptyResult
    case freeService(String)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint: "API 地址无效。"
        case .invalidResponse: "翻译服务返回了无法识别的数据。"
        case .emptyResult: "翻译服务返回了空结果。"
        case let .freeService(message): "免费翻译服务：\(message)"
        }
    }
}
