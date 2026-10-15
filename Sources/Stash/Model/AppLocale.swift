import Foundation

/// The locale Stash shows dates in: the language Stash runs in (which can differ from the
/// system's, see System Settings › General › Language & Region › Applications), with the
/// user's region for formats.
enum AppLocale {
    static var current: Locale {
        guard let language = Bundle.main.preferredLocalizations.first else { return .current }
        var components = Locale.Components(identifier: language)
        if let region = Locale.current.region { components.region = region }
        return Locale(components: components)
    }
}
