import XCTest
@testable import Wonder

final class TranslationClientTests: XCTestCase {
    func testDetectsCommonSourceLanguages() {
        XCTAssertEqual(TranslationClient.detectedLanguageCode("你好世界"), "zh-CN")
        XCTAssertEqual(TranslationClient.detectedLanguageCode("hello world"), "en")
        XCTAssertEqual(TranslationClient.detectedLanguageCode("こんにちは"), "ja")
        XCTAssertEqual(TranslationClient.detectedLanguageCode("안녕하세요"), "ko")
    }

    func testFreeProviderSplitsAtUtf8ByteLimit() {
        let chunks = TranslationClient.utf8Chunks(String(repeating: "翻译", count: 200), maximumBytes: 450)
        XCTAssertGreaterThan(chunks.count, 1)
        XCTAssertTrue(chunks.allSatisfy { $0.utf8.count <= 450 })
        XCTAssertEqual(chunks.joined(), String(repeating: "翻译", count: 200))
    }

    func testExpandedLanguageCodes() {
        XCTAssertEqual(SourceLanguage.traditionalChinese.languageCode, "zh-TW")
        XCTAssertEqual(SourceLanguage.englishUK.languageCode, "en-GB")
        XCTAssertEqual(TranslationClient.targetLanguageCode(.traditionalChinese, source: "en"), "zh-TW")
        XCTAssertEqual(TranslationClient.targetLanguageCode(.englishUK, source: "zh-CN"), "en-GB")
    }
}
