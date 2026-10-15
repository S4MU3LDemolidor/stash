import Foundation
import UniformTypeIdentifiers

struct LibrarySection: Identifiable, Equatable {
    var title: String
    var items: [Reference]
    var id: String { title }
}

/// Section headers, dates, titles and subtitles shown in the Library.
enum LibraryFormatting {
    /// `Today`, `Yesterday`, `This Week` (the 7 days before that), `Earlier`; empty sections are left out.
    /// Search results aren't grouped: they're one `Results` section in relevance order.
    static func sections(
        for references: [Reference],
        searching: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [LibrarySection] {
        guard !references.isEmpty else { return [] }
        if searching { return [LibrarySection(title: String(localized: "Results"), items: references)] }

        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let weekStart = calendar.date(byAdding: .day, value: -7, to: today)!

        var groups: [(title: String, items: [Reference])] = [(String(localized: "Today"), []), (String(localized: "Yesterday"), []), (String(localized: "This Week"), []), (String(localized: "Earlier"), [])]
        for reference in references {
            let index = reference.created >= today ? 0 : reference.created >= yesterday ? 1 : reference.created >= weekStart ? 2 : 3
            groups[index].items.append(reference)
        }
        return groups.filter { !$0.items.isEmpty }.map { LibrarySection(title: $0.title, items: $0.items) }
    }

    /// Row accessory: `just now`, `5m ago`, `2h ago`, `Yesterday`, `Mon`, `Oct 3`, `Oct 3, 2025`.
    static func relativeDate(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return String(localized: "just now") }
        if seconds < 3600, calendar.isDate(date, inSameDayAs: now) { return String(localized: "\(Int(seconds / 60))m ago") }
        if calendar.isDate(date, inSameDayAs: now) { return String(localized: "\(Int(seconds / 3600))h ago") }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return String(localized: "Yesterday")
        }
        if seconds < 6 * 86_400 { return date.formatted(.dateTime.weekday(.abbreviated).locale(AppLocale.current)) }
        if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            return date.formatted(.dateTime.month(.abbreviated).day().locale(AppLocale.current))
        }
        return date.formatted(.dateTime.month(.abbreviated).day().year().locale(AppLocale.current))
    }

    /// Capture's duplicate line: `Already saved a moment ago`, `Already saved yesterday`,
    /// `Already saved 3 weeks ago`.
    static func alreadySaved(_ date: Date, now: Date = Date()) -> String {
        guard now.timeIntervalSince(date) >= 60 else { return String(localized: "Already saved a moment ago") }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = AppLocale.current
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        let ago = formatter.localizedString(for: date, relativeTo: now)
        return String(localized: "Already saved \(ago)")
    }

    /// Detail pane: `Today, 10:20`, `Yesterday, 10:20`, `Oct 3, 2026, 10:20`.
    static func savedDate(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let time = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: AppLocale.current))
        if calendar.isDate(date, inSameDayAs: now) { return String(localized: "Today, \(time)") }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return String(localized: "Yesterday, \(time)")
        }
        let day = date.formatted(.dateTime.month(.abbreviated).day().year().locale(AppLocale.current))
        return String(localized: "\(day), \(time)", comment: "A date and a time: Oct 3, 2026, 10:20")
    }
}

extension Reference {
    var isYouTube: Bool { url.map { YouTube.videoID(in: $0) != nil } ?? false }

    /// `nngroup.com/articles/f-shaped`: shown until the page's title arrives.
    var displayURL: String? {
        guard let url else { return nil }
        let host = Reference.site(for: url) ?? url.host(percentEncoded: false) ?? ""
        let path = url.path(percentEncoded: false)
        return host + (path == "/" ? "" : path)
    }

    private var firstLineOfNote: String? {
        note.split(whereSeparator: \.isNewline).first.map(String.init)
    }

    /// The row's main line.
    var displayTitle: String {
        switch type {
        case .link: title ?? displayURL ?? String(localized: "Link")
        case .text: text?.split(whereSeparator: \.isNewline).first.map(String.init) ?? firstLineOfNote ?? String(localized: "Text")
        case .image: firstLineOfNote ?? originalFilename ?? String(localized: "Image")
        case .file: originalFilename ?? firstLineOfNote ?? String(localized: "File")
        }
    }

    /// The row's second line: site and timestamp, or the note, or what the item is.
    var displaySubtitle: String? {
        switch type {
        case .link:
            let site = site ?? url?.host(percentEncoded: false)
            return [site, timestamp.map { String(localized: "at \(YouTube.formatTime($0))") }].compactMap { $0 }.joined(separator: " · ")
        case .text:
            return firstLineOfNote ?? String(localized: "Text")
        case .image:
            let size = width.flatMap { w in height.map { h in "\(w)×\(h)" } }
            return [String(localized: "Image"), size].compactMap { $0 }.joined(separator: " · ")
        case .file:
            return originalFilename != nil && !note.isEmpty ? firstLineOfNote : kindDescription
        }
    }

    /// `YouTube video`, `Link`, `Text`, `Image`, `PDF document`…
    var kindDescription: String {
        switch type {
        case .link: isYouTube ? String(localized: "YouTube video") : String(localized: "Link")
        case .text: String(localized: "Text")
        case .image: String(localized: "Image")
        case .file: file.flatMap { UTType(filenameExtension: ($0 as NSString).pathExtension)?.localizedDescription } ?? String(localized: "File")
        }
    }

    /// SF Symbol for the row icon until there's a favicon or thumbnail (design.md §6).
    var symbolName: String {
        switch type {
        case .link: isYouTube ? "play.rectangle.fill" : "link"
        case .text: "text.quote"
        case .image: "photo"
        case .file: "doc"
        }
    }

    /// VoiceOver: "YouTube video, How I Write Hooks…, saved 2h ago, tags hooks".
    func accessibilityDescription(now: Date = Date()) -> String {
        var parts = [kindDescription, displayTitle, String(localized: "saved \(LibraryFormatting.relativeDate(created, now: now))")]
        if !tags.isEmpty { parts.append(String(localized: "tags \(tags.joined(separator: ", "))")) }
        return parts.joined(separator: ", ")
    }
}
