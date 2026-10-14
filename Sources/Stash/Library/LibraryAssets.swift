import Foundation

/// What Library views need to show a reference's images: where its files are, the site's
/// icon, and whether its metadata is still being fetched.
struct LibraryAssets {
    var assetURL: (String) -> URL
    var siteIconURL: (String?) -> URL?
    var isLoading: (String) -> Bool
}
