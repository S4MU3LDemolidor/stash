import Foundation
import Testing
@testable import Stash

@Suite("YouTube URLs")
struct YouTubeTests {
    @Test(arguments: [
        ("https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=272s", "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=272s"),
        ("https://www.youtube.com/watch?v=dQw4w9WgXcQ", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
        ("https://youtu.be/dQw4w9WgXcQ?t=272", "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=272s"),
        ("https://youtu.be/dQw4w9WgXcQ?si=abc123", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
        ("https://m.youtube.com/watch?v=dQw4w9WgXcQ&feature=share&t=4m32s", "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=272s"),
        ("https://www.youtube.com/shorts/dQw4w9WgXcQ", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
        ("https://youtube.com/embed/dQw4w9WgXcQ?start=30", "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=30s"),
        ("https://www.youtube.com/live/dQw4w9WgXcQ", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
        ("https://music.youtube.com/watch?v=dQw4w9WgXcQ&list=RD", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
    ])
    func normalizes(input: String, expected: String) {
        #expect(YouTube.normalize(URL(string: input)!)?.absoluteString == expected)
    }

    @Test func playingPositionWinsOverTheURL() {
        let url = URL(string: "https://youtu.be/dQw4w9WgXcQ?t=10")!
        #expect(YouTube.normalize(url, timestamp: 272)?.absoluteString
            == "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=272s")
    }

    @Test(arguments: [
        "https://www.youtube.com/@channel",
        "https://www.youtube.com/watch?v=tooShort",
        "https://www.youtube.com/results?search_query=hooks",
        "https://vimeo.com/123456",
        "https://example.com/watch?v=dQw4w9WgXcQ",
    ])
    func ignoresAnythingThatIsntAVideo(input: String) {
        #expect(YouTube.normalize(URL(string: input)!) == nil)
    }

    @Test func parsesTimes() {
        #expect(YouTube.parseTime("272") == 272)
        #expect(YouTube.parseTime("272s") == 272)
        #expect(YouTube.parseTime("4m32s") == 272)
        #expect(YouTube.parseTime("1h2m3s") == 3723)
        #expect(YouTube.parseTime("abc") == nil)
        #expect(YouTube.parseTime("4m32") == nil)
    }

    @Test func formatsTimes() {
        #expect(YouTube.formatTime(272) == "4:32")
        #expect(YouTube.formatTime(5) == "0:05")
        #expect(YouTube.formatTime(3723) == "1:02:03")
    }

    @Test func siteDropsWWWAndMobilePrefixes() {
        #expect(Reference.site(for: URL(string: "https://www.youtube.com/watch?v=x")!) == "youtube.com")
        #expect(Reference.site(for: URL(string: "https://m.facebook.com/ads")!) == "facebook.com")
        #expect(Reference.site(for: URL(string: "https://blog.example.com")!) == "blog.example.com")
    }
}
