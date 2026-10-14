import AppKit

/// Realistic sample data for trying out the Library (debug menu). Every sample is tagged
/// `sample`, so they can be removed together. Uses a fixed seed: same samples every time.
@MainActor
enum SampleLibrary {
    static let tag = "sample"

    static func generate(count: Int = 200, into library: LibraryStore) throws {
        var random = SeededRandom(seed: 42)
        let now = Date()
        var references: [Reference] = []

        for index in 0..<count {
            var reference: Reference
            switch index % 8 {
            case 0, 1:
                let title = videos[random.next(videos.count)]
                let id = String((0..<11).map { _ in Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")[random.next(64)] })
                let timestamp = random.next(3) == 0 ? nil : 15 + random.next(900)
                reference = Reference(
                    type: .link, url: YouTube.canonicalURL(videoID: id, timestamp: timestamp),
                    title: title, site: "youtube.com", timestamp: timestamp
                )
            case 2, 3:
                let (title, site) = articles[random.next(articles.count)]
                reference = Reference(
                    type: .link, url: URL(string: "https://\(site)/articles/\(Slug.make(title))"), title: title, site: site
                )
            case 4, 5:
                reference = Reference(type: .text, text: quotes[random.next(quotes.count)])
            case 6:
                reference = Reference(type: .image)
                let (width, height) = [(540, 675), (540, 540), (960, 540)][random.next(3)]
                let label = imageLabels[random.next(imageLabels.count)]
                let data = image(width: width, height: height, hue: Double(random.next(360)) / 360, label: label)
                reference.file = try library.saveAsset(data, id: reference.id, fileExtension: "png")
                (reference.width, reference.height) = (width, height)
                reference.note = label
            default:
                let (name, text) = documents[random.next(documents.count)]
                reference = Reference(type: .file, originalFilename: name)
                reference.file = try library.saveAsset(Data(text.utf8), id: reference.id, fileExtension: "txt")
            }

            if reference.type != .image, random.next(2) == 0 {
                reference.note = notes[random.next(notes.count)]
            }
            var tags = (0..<random.next(3) + 1).map { _ in tagPool[random.next(tagPool.count)] }
            tags.append(tag)
            reference.tags = tags.reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
            reference.created = createdDate(for: index, now: now, random: &random)
            references.append(reference)
        }
        try library.create(references)
    }

    static func removeAll(from library: LibraryStore) throws {
        for reference in try library.index.search(SearchQuery(tags: [tag]), limit: 100_000) {
            try library.delete(id: reference.id)
        }
    }

    /// A few today and yesterday, more this week, the rest over the last six months.
    private static func createdDate(for index: Int, now: Date, random: inout SeededRandom) -> Date {
        let minutes: Int = switch index {
        case 0..<6: 5 + index * 50
        case 6..<12: 24 * 60 + random.next(12 * 60)
        case 12..<30: (2 + random.next(5)) * 24 * 60
        default: (8 + random.next(170)) * 24 * 60 + random.next(24 * 60)
        }
        return Date(timeIntervalSince1970: (now.timeIntervalSince1970 - Double(minutes * 60)).rounded(.down))
    }

    private static func image(width: Int, height: Int, hue: Double, label: String) -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let rect = NSRect(x: 0, y: 0, width: width, height: height)
        let start = NSColor(hue: hue, saturation: 0.7, brightness: 0.9, alpha: 1)
        let end = NSColor(hue: (hue + 0.12).truncatingRemainder(dividingBy: 1), saturation: 0.8, brightness: 0.45, alpha: 1)
        NSGradient(starting: start, ending: end)?.draw(in: rect, angle: -60)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: CGFloat(min(width, height)) / 9, weight: .heavy),
            .foregroundColor: NSColor.white,
        ]
        NSAttributedString(string: label, attributes: attributes)
            .draw(in: rect.insetBy(dx: CGFloat(width) / 12, dy: CGFloat(height) / 12))
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])!
    }

    // MARK: Content

    private static let tagPool = [
        "hooks", "thumbnails", "ads", "copy", "ux", "editing", "inspiration", "branding",
        "typography", "color", "motion", "pricing", "ugc", "landing-pages",
    ]

    private static let videos = [
        "How I Write Hooks That Stop the Scroll", "The 3-Second Rule for Short-Form Video",
        "Thumbnail Psychology, Explained", "Why Your Ads Aren't Converting", "Color Grading in 10 Minutes",
        "Editing Rhythm: Cut on the Beat", "Retention Strategy of the Biggest Creators", "Writing Captions People Read",
        "UGC Ads That Feel Native", "Storyboarding a 15-Second Reel", "Sound Design for Product Videos",
        "B-Roll Ideas for Boring Products", "The Perfect Product Demo", "Pacing Tricks from Movie Trailers",
        "Typography in Motion",
    ]

    private static let articles = [
        ("The F-Shaped Pattern of Reading on the Web", "nngroup.com"), ("A Complete Guide to CSS Grid", "css-tricks.com"),
        ("How to Write a Great Value Proposition", "cxl.com"), ("The Psychology of Pricing", "hbr.org"),
        ("Landing Page Teardown", "growth.design"), ("Designing Better Empty States", "smashingmagazine.com"),
        ("Brand Voice Guidelines That Work", "mailchimp.com"), ("Microcopy That Converts", "uxdesign.cc"),
        ("Typography Basics", "practicaltypography.com"), ("What Makes a Thumbnail Clickable", "vidiq.com"),
        ("Building a Content Calendar", "buffer.com"), ("The Best Ad Creatives of the Year", "adage.com"),
    ]

    private static let quotes = [
        "Stop selling. Start telling.", "People don't buy products, they buy better versions of themselves.",
        "If it doesn't stop the scroll in one second, it doesn't exist.", "Show the result first, then the how.",
        "Specific beats clever.", "Write like you talk. Then cut half.", "One idea per ad.",
        "The hook is a promise; the video is keeping it.", "Make the viewer the hero, not the brand.",
        "Contrast is the cheapest attention you can buy.", "Every frame should earn the next one.",
        "Ask a question the viewer already has.", "Price anchoring: show the expensive option first.",
        "Use numbers in headlines: 7 beats seven.", "Pattern interrupt in the first frame.",
        "Fewer words, bigger type.", "Social proof near the call to action.", "Tension, then release.",
        "The best CTA is the next obvious step.", "Name the pain before the product.",
    ]

    private static let notes = [
        "great hook in the first 3s", "use this pacing for the launch video", "reference for the Q4 campaign",
        "steal the color palette", "nice transition at the start", "good structure for a carousel",
        "send to the team", "try this on the next ad", "clean layout, simple type", "strong first frame",
    ]

    private static let imageLabels = [
        "Black Friday", "Summer Sale", "New Drop", "50% OFF", "Launch Day", "Free Shipping",
        "Last Chance", "Back in Stock", "Holiday Edit", "Members Only",
    ]

    private static let documents = [
        ("Campaign brief Q4.txt", "Q4 campaign brief. Audience: busy parents. Budget: 12k. Channels: Reels, Stories, TikTok."),
        ("Hook ideas.txt", "Hook ideas: question opener, bold claim, before and after, the unexpected prop."),
        ("Brand guidelines.txt", "Brand guidelines: amber accent, generous whitespace, short sentences, no jargon."),
        ("Interview notes.txt", "Customer interview: they found us through a friend, loved the free returns."),
    ]
}

/// SplitMix64: a tiny deterministic random generator, so samples look the same every time.
private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next(_ upperBound: Int) -> Int {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Int(z % UInt64(upperBound))
    }
}
