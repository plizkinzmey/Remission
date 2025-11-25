import Foundation

enum L10n {
    static func tr(_ key: String, table: String = "Localizable") -> String {
        localizedString(forKey: key, table: table) ?? key
    }

    private static func localizedString(forKey key: String, table: String) -> String? {
        // Prefer any compiled app bundle (".app") that contains the localization.
        if let appBundle = Bundle.allBundles.first(where: { bundle in
            bundle.bundlePath.hasSuffix(".app")
                && bundle.path(forResource: table, ofType: "strings") != nil
        }) {
            let value = appBundle.localizedString(forKey: key, value: nil, table: table)
            if value != key { return value }
        }

        // Fallback to main bundle.
        let mainValue = Bundle.main.localizedString(forKey: key, value: nil, table: table)
        if mainValue != key { return mainValue }

        // Force Russian localization if available, regardless of current locale.
        for bundle in Bundle.allBundles + Bundle.allFrameworks {
            guard let ruPath = bundle.path(forResource: "ru", ofType: "lproj") else {
                continue
            }
            guard let ruBundle = Bundle(path: ruPath) else {
                continue
            }
            let value = ruBundle.localizedString(forKey: key, value: nil, table: table)
            if value != key { return value }
        }

        // Search other bundles/frameworks just in case.
        for bundle in Bundle.allBundles + Bundle.allFrameworks {
            let value = bundle.localizedString(forKey: key, value: nil, table: table)
            if value != key { return value }
        }
        return nil
    }
}
