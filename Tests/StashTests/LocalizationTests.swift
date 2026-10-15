import Foundation
import Testing

/// The string tables in Support/Localization: every language translates exactly the English
/// keys, with the same placeholders. (scripts/check-strings.sh checks the keys against the code.)
@Suite("Translations")
struct LocalizationTests {
    static let folder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "Support/Localization", directoryHint: .isDirectory)
    static let languages = ["pt-BR", "es", "fr"]

    private static func table(_ language: String, _ name: String = "Localizable") throws -> [String: String] {
        let url = folder.appending(path: "\(language).lproj/\(name).strings")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: String], "\(url.lastPathComponent) isn't a strings table")
    }

    /// Argument position → format, e.g. `"%1$@ of %lld"` → [1: "@", 2: "lld"].
    static func placeholders(_ text: String) -> [Int: String] {
        let pattern = #/%(?:(\d+)\$)?(@|lld|ld|d|f)/#
        var result: [Int: String] = [:]
        var next = 1
        for match in text.matches(of: pattern) {
            let position = match.1.flatMap { Int($0) } ?? next
            result[position] = String(match.2)
            next = position + 1
        }
        return result
    }

    @Test func englishListsEveryKeyAsItself() throws {
        let english = try Self.table("en")
        #expect(english.count > 100)
        for (key, value) in english {
            #expect(key == value, "en: \(key)")
        }
    }

    @Test(arguments: languages)
    func translatesExactlyTheEnglishKeys(_ language: String) throws {
        let english = Set(try Self.table("en").keys)
        let translated = Set(try Self.table(language).keys)
        #expect(english.subtracting(translated).sorted() == [], "missing in \(language)")
        #expect(translated.subtracting(english).sorted() == [], "unused in \(language)")
    }

    @Test(arguments: languages)
    func keepsThePlaceholders(_ language: String) throws {
        for (key, value) in try Self.table(language) {
            #expect(Self.placeholders(key) == Self.placeholders(value), "\(language): \(key) → \(value)")
        }
    }

    @Test(arguments: languages)
    func translatesThePermissionPrompt(_ language: String) throws {
        let info = try Self.table(language, "InfoPlist")
        #expect(info["NSAppleEventsUsageDescription"]?.isEmpty == false)
    }

    @Test func placeholderPositions() {
        #expect(Self.placeholders("%@ and %lld") == [1: "@", 2: "lld"])
        #expect(Self.placeholders("%2$lld de %1$@") == [1: "@", 2: "lld"])
    }
}
