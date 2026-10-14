import AppKit
import LinkPresentation
import UniformTypeIdentifiers

/// What was found for a link.
struct LinkMetadata: Sendable, Equatable {
    var title: String?
    /// JPEG, at most `MetadataFetcher.thumbnailMaxPixels` on its longest side.
    var thumbnail: Data?
    /// The site's icon: PNG, at most `MetadataFetcher.iconMaxPixels`.
    var icon: Data?
}

/// Fetches a link's title, preview image and site icon. These are Stash's only network requests
/// (what-the-app-is.md, "Privacy"), and none are made when the setting is off.
///
/// YouTube uses its public oEmbed endpoint and thumbnail images; everything else uses
/// LinkPresentation (the page's title, Open Graph image and icon).
@MainActor
final class MetadataFetcher {
    static let shared = MetadataFetcher()

    nonisolated static let thumbnailMaxPixels = 1280
    nonisolated static let iconMaxPixels = 64
    private static let recentLimit = 20

    /// Whether the library already has a site's icon, so it isn't fetched again.
    var hasSiteIcon: (String) -> Bool = { _ in false }

    /// One request per link at a time: Capture's preview and the save that follows share it.
    private var inFlight: [String: Task<LinkMetadata?, Never>] = [:]
    private var recent: [(key: String, metadata: LinkMetadata)] = []

    /// No cookies, no cache kept between requests.
    private nonisolated let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 20
        return URLSession(configuration: configuration)
    }()

    /// Nil when fetching is off, or when the site couldn't be reached (offline, timeout…):
    /// worth trying again later. An empty result means the site answered but had nothing.
    func metadata(for url: URL) async -> LinkMetadata? {
        guard Preferences.fetchMetadata else { return nil }
        let key = YouTube.videoID(in: url).map { "youtube:\($0)" } ?? url.absoluteString
        if let hit = recent.first(where: { $0.key == key }) { return hit.metadata }
        if let task = inFlight[key] { return await task.value }

        let needsIcon = !(Reference.site(for: url).map(hasSiteIcon) ?? false)
        let task = Task { await fetch(url, needsIcon: needsIcon) }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        if let result {
            recent.append((key, result))
            if recent.count > Self.recentLimit { recent.removeFirst() }
        }
        return result
    }

    private func fetch(_ url: URL, needsIcon: Bool) async -> LinkMetadata? {
        if let videoID = YouTube.videoID(in: url) {
            return await fetchYouTube(videoID: videoID, needsIcon: needsIcon)
        }
        return await fetchPage(url)
    }

    // MARK: YouTube

    private func fetchYouTube(videoID: String, needsIcon: Bool) async -> LinkMetadata? {
        async let oEmbed = get(YouTube.oEmbedURL(videoID: videoID))
        async let thumbnail = firstImage(YouTube.thumbnailURLs(videoID: videoID))
        // youtube.com's favicon.ico is 16 px only; its home page offers a sharp icon. Site icons
        // are kept in the library, so this happens once.
        let icon = needsIcon ? await pageIcon(YouTube.homeURL) : nil
        let (oEmbedResult, thumbnailResult) = await (oEmbed, thumbnail)

        guard oEmbedResult.responded || thumbnailResult.responded else { return nil }
        let title = oEmbedResult.data.flatMap(YouTube.title(fromOEmbed:))
        return await processed(title: title, thumbnail: thumbnailResult.data, icon: icon)
    }

    /// The first URL that returns an actual image (missing thumbnail sizes return errors).
    private nonisolated func firstImage(_ urls: [URL]) async -> (data: Data?, responded: Bool) {
        var responded = false
        for url in urls {
            let result = await get(url)
            responded = responded || result.responded
            if let data = result.data, data.count > 2_000 { return (data, true) }
        }
        return (nil, responded)
    }

    private nonisolated func get(_ url: URL) async -> (data: Data?, responded: Bool) {
        do {
            let (data, response) = try await session.data(from: url)
            let ok = (response as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
            return (ok ? data : nil, true)
        } catch {
            return (nil, false)
        }
    }

    // MARK: Other pages

    private func fetchPage(_ url: URL) async -> LinkMetadata? {
        let provider = LPMetadataProvider()
        provider.timeout = 15
        guard let metadata = try? await provider.startFetchingMetadata(for: url) else { return nil }
        let title = metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        async let image = imageData(metadata.imageProvider)
        async let icon = imageData(metadata.iconProvider)
        return await processed(title: title?.isEmpty == false ? title : nil, thumbnail: image, icon: icon)
    }

    private func pageIcon(_ url: URL) async -> Data? {
        let provider = LPMetadataProvider()
        provider.timeout = 15
        provider.shouldFetchSubresources = true
        guard let metadata = try? await provider.startFetchingMetadata(for: url) else { return nil }
        return await imageData(metadata.iconProvider)
    }

    private nonisolated func imageData(_ provider: NSItemProvider?) async -> Data? {
        guard let provider,
              let type = provider.registeredTypeIdentifiers.first(where: { UTType($0)?.conforms(to: .image) == true })
        else { return nil }
        return await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    /// Thumbnails become reasonably sized JPEGs and icons small PNGs, off the main thread.
    private func processed(title: String?, thumbnail: Data?, icon: Data?) async -> LinkMetadata {
        await Task.detached(priority: .utility) {
            LinkMetadata(
                title: title,
                thumbnail: thumbnail.flatMap { ImageInfo.jpegData(from: $0, maxPixels: MetadataFetcher.thumbnailMaxPixels) },
                icon: icon.flatMap { ImageInfo.pngData(from: $0, maxPixels: MetadataFetcher.iconMaxPixels) }
            )
        }.value
    }
}
