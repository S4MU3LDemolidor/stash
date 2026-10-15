import Foundation

/// What Library views need to show a reference's images: where its files are, the site's
/// icon, whether its metadata is still being fetched, and the text read from an image.
struct LibraryAssets {
    var assetURL: (String) -> URL
    var siteIconURL: (String?) -> URL?
    var isLoading: (String) -> Bool
    var imageText: (String) -> String? = { _ in nil }
}
