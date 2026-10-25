import AppKit
import FinderSync
import Darwin
import UniformTypeIdentifiers

@objc(MyRightFinderSync)
final class MyRightFinderSync: FIFinderSync {
    var actionOpener: (URL) -> Bool = HostActionLauncher.open
    private var menuDirectory: URL?
    private var menuSelectedItem: URL?

    override init() {
        super.init()
        monitorHomeDirectory()
    }

    init(monitorDirectories: Bool) {
        super.init()
        if monitorDirectories { monitorHomeDirectory() }
    }

    private func monitorHomeDirectory() {
        // The extension's Foundation home directory is its sandbox container.
        if let entry = getpwuid(getuid()), let path = entry.pointee.pw_dir {
            FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: String(cString: path), isDirectory: true)]
        }
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForContainer || menuKind == .contextualMenuForItems else { return nil }
        let controller = FIFinderSyncController.default()
        guard let target = controller.targetedURL() else { return nil }
        let directory: URL
        if menuKind == .contextualMenuForItems {
            // Avoid an ambiguous operation when multiple items are selected.
            guard let selected = controller.selectedItemURLs(), selected.count == 1,
                  let item = selected.first else { return nil }
            if (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                directory = item
            } else {
                return makeMenu(in: item.deletingLastPathComponent(), selectedItem: item)
            }
        } else { directory = target }

        return makeMenu(in: directory)
    }

    func makeMenu(in directory: URL, selectedItem: URL? = nil) -> NSMenu {
        // Finder reconstructs the sender; representedObject and target are not
        // a transport for action data. Keep context on the extension principal.
        menuDirectory = directory
        menuSelectedItem = selectedItem
        let menu = NSMenu()
        if selectedItem == nil {
            let newItem = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
            newItem.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: nil)
            let submenu = NSMenu()
            for kind in FileKind.allCases {
                let selector: Selector
                switch kind {
                case .docx: selector = #selector(createWord(_:))
                case .xlsx: selector = #selector(createExcel(_:))
                case .pptx: selector = #selector(createPowerPoint(_:))
                case .md: selector = #selector(createMarkdown(_:))
                case .txt: selector = #selector(createText(_:))
                case .pages: selector = #selector(createPages(_:))
                case .numbers: selector = #selector(createNumbers(_:))
                case .key: selector = #selector(createKeynote(_:))
                }
                let item = NSMenuItem(title: kind.title, action: selector, keyEquivalent: "")
                item.target = self
                item.image = NSImage(systemSymbolName: kind.symbol, accessibilityDescription: nil)
                submenu.addItem(item)
            }
            newItem.submenu = submenu
            menu.addItem(newItem)
            let terminal = NSMenuItem(title: "在终端打开", action: #selector(openTerminal(_:)), keyEquivalent: "")
            terminal.target = self
            terminal.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: nil)
            menu.addItem(terminal)
        }
        let copy = NSMenuItem(title: "拷贝路径", action: #selector(copyPath(_:)), keyEquivalent: "")
        copy.target = self
        copy.image = NSImage(systemSymbolName: "link", accessibilityDescription: nil)
        menu.addItem(copy)

        if let selectedItem, ImageFormat.commonInputExtensions.contains(selectedItem.pathExtension.lowercased()) || UTType(filenameExtension: selectedItem.pathExtension)?.conforms(to: .image) == true {
            let conversion = NSMenuItem(title: "转换图片格式", action: nil, keyEquivalent: "")
            conversion.image = NSImage(systemSymbolName: "photo.on.rectangle.angled", accessibilityDescription: nil)
            let formats = NSMenu()
            for format in ImageFormat.allCases {
                let selector: Selector
                switch format {
                case .png: selector = #selector(convertPNG(_:))
                case .jpeg: selector = #selector(convertJPEG(_:))
                case .heic: selector = #selector(convertHEIC(_:))
                case .tiff: selector = #selector(convertTIFF(_:))
                }
                let item = NSMenuItem(title: format.title, action: selector, keyEquivalent: "")
                item.target = self
                formats.addItem(item)
            }
            conversion.submenu = formats
            menu.addItem(conversion)
        }
        return menu
    }

    @objc private func createWord(_ sender: NSMenuItem) { dispatch(.create(.docx)) }
    @objc private func createExcel(_ sender: NSMenuItem) { dispatch(.create(.xlsx)) }
    @objc private func createPowerPoint(_ sender: NSMenuItem) { dispatch(.create(.pptx)) }
    @objc private func createMarkdown(_ sender: NSMenuItem) { dispatch(.create(.md)) }
    @objc private func createText(_ sender: NSMenuItem) { dispatch(.create(.txt)) }
    @objc private func createPages(_ sender: NSMenuItem) { dispatch(.create(.pages)) }
    @objc private func createNumbers(_ sender: NSMenuItem) { dispatch(.create(.numbers)) }
    @objc private func createKeynote(_ sender: NSMenuItem) { dispatch(.create(.key)) }
    @objc private func openTerminal(_ sender: NSMenuItem) { dispatch(.terminal) }
    @objc private func copyPath(_ sender: NSMenuItem) { dispatch(.copyPath) }
    @objc private func convertPNG(_ sender: NSMenuItem) { dispatch(.convert(.png)) }
    @objc private func convertJPEG(_ sender: NSMenuItem) { dispatch(.convert(.jpeg)) }
    @objc private func convertHEIC(_ sender: NSMenuItem) { dispatch(.convert(.heic)) }
    @objc private func convertTIFF(_ sender: NSMenuItem) { dispatch(.convert(.tiff)) }

    private func dispatch(_ action: ActionRequest.Action) {
        guard let directory = menuDirectory else { return }
        let target: URL
        switch action {
        case .create, .terminal: target = directory
        case .copyPath: target = menuSelectedItem ?? directory
        case .convert:
            guard let item = menuSelectedItem else { return }
            target = item
        }
        if !actionOpener(ActionRequest(action: action, target: target).url) {
            NSLog("MyRight: unable to send the Finder action to its containing app.")
        }
    }
}
