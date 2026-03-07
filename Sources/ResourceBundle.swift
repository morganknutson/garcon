import Foundation

/// Resolves the SwiftPM resource bundle without fatalError.
///
/// The auto-generated `Bundle.module` calls `fatalError` when it can't find
/// `Garcon_Garcon.bundle`.  Inside a `.app` wrapper the generated accessor
/// looks at `Bundle.main.bundleURL` (the `.app` root) which only works when
/// the packaging script places the bundle there.  This helper searches
/// additional locations so the app degrades gracefully instead of crashing.
enum ResourceBundle {
    static let resolved: Bundle? = {
        let name = "Garcon_Garcon"

        // 1. .app root — where the SwiftPM accessor looks
        let appRoot = Bundle.main.bundleURL
            .appendingPathComponent("\(name).bundle")
        if let b = Bundle(path: appRoot.path) {
            return b
        }

        // 2. Contents/Resources/ — standard macOS app bundle location
        if let resourceURL = Bundle.main.resourceURL {
            let inResources = resourceURL
                .appendingPathComponent("\(name).bundle")
            if let b = Bundle(path: inResources.path) {
                return b
            }
        }

        // 3. Next to the executable (plain CLI / dev builds)
        if let execURL = Bundle.main.executableURL {
            let siblingURL = execURL.deletingLastPathComponent()
                .appendingPathComponent("\(name).bundle")
            if let b = Bundle(path: siblingURL.path) {
                return b
            }
        }

        // 4. Try the auto-generated Bundle.module (may fatalError, so check
        //    the paths it would try first).  We avoid calling it directly.

        Log.error("Resource bundle '\(name)' not found in any search path")
        return nil
    }()

    static func url(forResource name: String, withExtension ext: String) -> URL? {
        resolved?.url(forResource: name, withExtension: ext)
    }
}
