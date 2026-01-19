import Foundation

enum AppVersion {
    static var shortLabel: String {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String
        return shortVersion?.isEmpty == false ? shortVersion ?? "-" : "-"
    }

    static var footerText: String {
        #if DEBUG
            return String(
                format: L10n.tr("app.footer.version.debug"),
                shortLabel
            )
        #else
            return String(
                format: L10n.tr("app.footer.version"),
                shortLabel
            )
        #endif
    }
}
