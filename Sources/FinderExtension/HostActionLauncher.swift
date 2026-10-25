import AppKit

enum HostActionLauncher {
    static func configuration() -> NSWorkspace.OpenConfiguration {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        configuration.allowsRunningApplicationSubstitution = false
        return configuration
    }

    static func open(_ url: URL) -> Bool {
        let bundle = Bundle.main.bundleURL
        let host: URL?
        if bundle.pathExtension == "appex" {
            host = bundle.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        } else {
            host = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "local.otto.MyRight")
        }
        guard let host else { return false }
        NSWorkspace.shared.open([url], withApplicationAt: host, configuration: configuration()) { _, error in
            if let error { NSLog("MyRight: background action delivery failed (%@).", String(describing: (error as NSError).code)) }
        }
        return true
    }
}
