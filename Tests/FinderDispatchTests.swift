import AppKit
import CoreGraphics

@main
enum FinderDispatchTests {
    static func main() {
        do { try run() }
        catch { print(error.localizedDescription); exit(1) }
    }

    static func commands(in menu: NSMenu) -> [NSMenuItem] {
        menu.items.flatMap { item in
            if let submenu = item.submenu { return commands(in: submenu) }
            return item.action == nil ? [] : [item]
        }
    }

    static func run() throws {
        let finder = MyRightFinderSync(monitorDirectories: false)
        let integration = CommandLine.arguments.contains("--integration")
        let directory = integration
            ? URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("build/Integration-\(UUID().uuidString)", isDirectory: true)
            : URL(fileURLWithPath: "/Users/test/中文 项目", isDirectory: true)
        if integration {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            print("Integration directory: \(directory.path)")
        }
        // Preserve the user's clipboard during the real clipboard integration check.
        let clipboardSnapshot = integration ? NSPasteboard.general.pasteboardItems?.map { item in
            item.types.compactMap { type -> (NSPasteboard.PasteboardType, Data)? in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            }
        } : nil
        defer {
            if integration {
                NSPasteboard.general.clearContents()
                if let clipboardSnapshot {
                    let restored = clipboardSnapshot.map { values in
                        let item = NSPasteboardItem()
                        for (type, data) in values { item.setData(data, forType: type) }
                        return item
                    }
                    NSPasteboard.general.writeObjects(restored)
                }
            }
        }
        var hostWasActivated = false
        var observer: NSObjectProtocol?
        if integration {
            observer = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: nil) { notification in
                if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                   app.bundleIdentifier == "local.otto.MyRight" { hostWasActivated = true }
            }
        }
        defer { if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) } }
        var captured: [URL] = []
        let systemOpener = finder.actionOpener
        finder.actionOpener = { captured.append($0); return integration ? systemOpener($0) : true }

        func waitUntil(_ condition: () -> Bool) throws {
            for _ in 0..<100 {
                if condition() { return }
                RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            }
            throw NSError(domain: "FinderDispatchTests", code: 3, userInfo: [NSLocalizedDescriptionKey: "FAIL: installed app did not complete the requested action"])
        }

        func invoke(_ item: NSMenuItem, expected: ActionRequest.Action, target: URL) throws {
            // Reproduce Finder's reconstructed sender, which has no payload or target.
            let sender = NSMenuItem(title: item.title, action: item.action, keyEquivalent: "")
            sender.tag = item.tag
            sender.isEnabled = item.isEnabled
            sender.image = item.image
            precondition(sender.representedObject == nil)
            guard let selector = sender.action, finder.responds(to: selector) else {
                throw NSError(domain: "FinderDispatchTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Menu action missing on extension principal"])
            }
            let previous = captured.count
            finder.perform(selector, with: sender)
            guard captured.count == previous + 1 else {
                throw NSError(domain: "FinderDispatchTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "FAIL: \(item.title) silently ignored when Finder replaces its sender"])
            }
            let request = try ActionRequest(url: captured.last!)
            precondition(request.action == expected)
            precondition(request.target.path == target.path)
            if integration {
                switch expected {
                case .create(let kind):
                    let output = directory.appendingPathComponent("未命名.\(kind.rawValue)")
                    try waitUntil { FileManager.default.fileExists(atPath: output.path) }
                case .copyPath:
                    try waitUntil { NSPasteboard.general.string(forType: .string) == target.path }
                case .convert(let format):
                    let output = directory.appendingPathComponent(target.deletingPathExtension().lastPathComponent + " - 转换").appendingPathExtension(format.fileExtension)
                    try waitUntil { FileManager.default.fileExists(atPath: output.path) }
                case .terminal: break
                }
            }
            print("PASS: \(item.title), target \(target.lastPathComponent)")
        }

        let folderCommands = commands(in: finder.makeMenu(in: directory))
        let expected: [ActionRequest.Action] = FileKind.allCases.map { .create($0) } + [.terminal, .copyPath]
        precondition(folderCommands.count == expected.count)
        for (item, action) in zip(folderCommands, expected) { try invoke(item, expected: action, target: directory) }

        let text = directory.appendingPathComponent("sample.md")
        if integration { try Data().write(to: text) }
        let fileCommands = commands(in: finder.makeMenu(in: directory, selectedItem: text))
        precondition(fileCommands.count == 1)
        try invoke(fileCommands[0], expected: .copyPath, target: text)

        let image = directory.appendingPathComponent("sample image.png")
        if integration {
            let fixture = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources/AppIcon-preview.png")
            try FileManager.default.copyItem(at: fixture, to: image)
        }
        let imageCommands = commands(in: finder.makeMenu(in: directory, selectedItem: image))
        let imageActions: [ActionRequest.Action] = [.copyPath] + ImageFormat.allCases.map { .convert($0) }
        precondition(imageCommands.count == imageActions.count)
        for (item, action) in zip(imageCommands, imageActions) { try invoke(item, expected: action, target: image) }
        if integration {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            precondition(!hostWasActivated, "MyRight was activated while processing a Finder action")
            let pids = Set(NSRunningApplication.runningApplications(withBundleIdentifier: "local.otto.MyRight").map { Int($0.processIdentifier) })
            guard let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
                throw NSError(domain: "FinderDispatchTests", code: 4, userInfo: [NSLocalizedDescriptionKey: "Cannot verify host window visibility"])
            }
            let hostWindows = windows.filter { entry in
                pids.contains(entry[kCGWindowOwnerPID as String] as? Int ?? -1) && entry[kCGWindowLayer as String] as? Int == 0
            }
            precondition(hostWindows.isEmpty, "MyRight settings became visible during background actions")
            print("PASS: host stayed in background and exposed no settings window")
        }
    }
}
