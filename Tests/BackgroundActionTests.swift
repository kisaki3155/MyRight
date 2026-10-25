import AppKit

@main
enum BackgroundActionTests {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        _ = delegate.applicationShouldHandleReopen(app, hasVisibleWindows: false)
        guard !app.windows.contains(where: \.isVisible) else {
            print("FAIL: a background reopen displayed the MyRight settings window")
            app.windows.forEach { $0.close() }
            exit(1)
        }
        print("PASS: background reopen does not display settings")
        precondition(!HostActionLauncher.configuration().activates)
        print("PASS: Finder action delivery never activates the host app")
    }
}
