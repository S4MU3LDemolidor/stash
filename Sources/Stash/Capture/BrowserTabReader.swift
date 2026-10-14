import AppKit

/// A browser Stash can read the current tab of, via AppleScript.
struct Browser: Equatable, Sendable {
    enum Dictionary: Sendable {
        /// Safari: `current tab`, `name`, `do JavaScript`.
        case safari
        /// Chrome, Arc, Brave, Edge: `active tab`, `title`, `execute javascript`.
        case chromium
    }

    let bundleID: String
    /// Short name for the "From …" badge.
    let name: String
    let dictionary: Dictionary

    static let all: [Browser] = [
        Browser(bundleID: "com.apple.Safari", name: "Safari", dictionary: .safari),
        Browser(bundleID: "com.apple.SafariTechnologyPreview", name: "Safari", dictionary: .safari),
        Browser(bundleID: "com.google.Chrome", name: "Chrome", dictionary: .chromium),
        Browser(bundleID: "com.google.Chrome.beta", name: "Chrome", dictionary: .chromium),
        Browser(bundleID: "com.google.Chrome.canary", name: "Chrome", dictionary: .chromium),
        Browser(bundleID: "company.thebrowser.Browser", name: "Arc", dictionary: .chromium),
        Browser(bundleID: "com.brave.Browser", name: "Brave", dictionary: .chromium),
        Browser(bundleID: "com.microsoft.edgemac", name: "Edge", dictionary: .chromium),
    ]

    static func matching(_ app: NSRunningApplication?) -> Browser? {
        guard let bundleID = app?.bundleIdentifier else { return nil }
        return all.first { $0.bundleID == bundleID }
    }

    /// Where the user turns on "Allow JavaScript from Apple Events", needed for YouTube timestamps.
    var javaScriptHint: String {
        switch dictionary {
        case .safari:
            "To save the exact moment of a video, turn on Allow JavaScript from Apple Events in Safari › Settings › Developer."
        case .chromium:
            "To save the exact moment of a video, turn on View › Developer › Allow JavaScript from Apple Events in \(name)."
        }
    }
}

struct TabInfo: Equatable, Sendable {
    var url: URL
    var title: String?
}

enum TabReadError: Error, Equatable {
    /// The user hasn't allowed Stash to control the browser (Privacy & Security › Automation).
    case notPermitted
    /// The browser's "Allow JavaScript from Apple Events" setting is off.
    case javaScriptDisabled
    case timedOut
    case failed(String)
}

/// Runs AppleScript against browsers on one background queue, so the panel never waits on it.
/// Every call has a deadline: a browser that doesn't answer in time counts as a failure.
final class BrowserTabReader: @unchecked Sendable {
    static let shared = BrowserTabReader()

    private let queue = DispatchQueue(label: "dev.stash.browser-applescript", qos: .userInitiated)
    /// Compiled scripts by key. Only touched on `queue`.
    private var scripts: [String: NSAppleScript] = [:]

    /// The YouTube player's position in whole seconds, or "" when there's no video.
    private static let videoPositionJS = """
        (function(){var v=document.querySelector('.html5-main-video')||document.querySelector('video');\
        return v?String(Math.floor(v.currentTime)):''})()
        """

    private struct Script {
        let key: String
        let source: String
    }

    func currentTab(of browser: Browser, timeout: TimeInterval = 0.3) async -> Result<TabInfo, TabReadError> {
        await run(tabScript(for: browser), timeout: timeout) { result in
            guard let url = result.atIndex(1)?.stringValue.flatMap(URL.init(string:)) else {
                return .failure(.failed("No URL"))
            }
            return .success(TabInfo(url: url, title: result.atIndex(2)?.stringValue))
        }
    }

    /// The current video position in the browser's front tab (YouTube), if any.
    func videoPosition(in browser: Browser, timeout: TimeInterval = 0.6) async -> Result<Int?, TabReadError> {
        await run(videoScript(for: browser), timeout: timeout) { result in
            .success(result.stringValue.flatMap { Int($0) })
        }
    }

    /// Compiles the scripts for `browser` ahead of time. The first compile loads the browser's
    /// scripting dictionary, which can take longer than the capture deadline. Only call this
    /// for a browser that's running: it must never be what launches one.
    func prepare(_ browser: Browser) {
        queue.async { [self] in
            _ = compiled(tabScript(for: browser))
            _ = compiled(videoScript(for: browser))
        }
    }

    private func tabScript(for browser: Browser) -> Script {
        let body = switch browser.dictionary {
        case .safari: "set theTab to current tab of front window\nreturn {URL of theTab, name of theTab}"
        case .chromium: "set theTab to active tab of front window\nreturn {URL of theTab, title of theTab}"
        }
        return Script(key: "tab-\(browser.bundleID)", source: wrap(body, for: browser))
    }

    private func videoScript(for browser: Browser) -> Script {
        let js = Self.videoPositionJS
        let body = switch browser.dictionary {
        case .safari: "return do JavaScript \"\(js)\" in current tab of front window"
        case .chromium: "return execute active tab of front window javascript \"\(js)\""
        }
        return Script(key: "video-\(browser.bundleID)", source: wrap(body, for: browser))
    }

    private func wrap(_ body: String, for browser: Browser) -> String {
        // AppleScript's own timeout keeps a hung browser from blocking the queue for 2 minutes.
        "with timeout of 2 seconds\ntell application id \"\(browser.bundleID)\"\n\(body)\nend tell\nend timeout"
    }

    private func run<T: Sendable>(
        _ script: Script,
        timeout: TimeInterval,
        parse: @escaping @Sendable (NSAppleEventDescriptor) -> Result<T, TabReadError>
    ) async -> Result<T, TabReadError> {
        await withCheckedContinuation { continuation in
            let once = ResumeOnce(continuation)
            queue.async { [self] in
                once.resume(execute(script).flatMap(parse))
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                once.resume(.failure(.timedOut))
            }
        }
    }

    /// Runs on `queue`.
    private func compiled(_ script: Script) -> Result<NSAppleScript, TabReadError> {
        if let cached = scripts[script.key] { return .success(cached) }
        guard let compiled = NSAppleScript(source: script.source) else { return .failure(.failed("Invalid script")) }
        var errorInfo: NSDictionary?
        guard compiled.compileAndReturnError(&errorInfo) else { return .failure(Self.error(from: errorInfo)) }
        scripts[script.key] = compiled
        return .success(compiled)
    }

    /// Runs on `queue`.
    private func execute(_ script: Script) -> Result<NSAppleEventDescriptor, TabReadError> {
        compiled(script).flatMap { compiled in
            var errorInfo: NSDictionary?
            let result = compiled.executeAndReturnError(&errorInfo)
            if let errorInfo { return .failure(Self.error(from: errorInfo)) }
            return .success(result)
        }
    }

    private static func error(from info: NSDictionary?) -> TabReadError {
        let number = info?[NSAppleScript.errorNumber] as? Int
        let message = info?[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
        switch number {
        case -1743: return .notPermitted // errAEEventNotPermitted
        case -1712: return .timedOut // errAETimeout
        default: return message.localizedCaseInsensitiveContains("javascript") ? .javaScriptDisabled : .failed(message)
        }
    }
}

/// Resumes a continuation exactly once, whichever of the work or the deadline comes first.
private final class ResumeOnce<T: Sendable>: @unchecked Sendable {
    private var continuation: CheckedContinuation<T, Never>?
    private let lock = NSLock()

    init(_ continuation: CheckedContinuation<T, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: T) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: value)
    }
}
