import AppKit
import SwiftUI
import FinderSync
import ServiceManagement

@MainActor
final class SettingsModel: ObservableObject {
    @Published var extensionEnabled = false
    @Published var loginEnabled = false
    @Published var loginNeedsApproval = false
    @Published var message: String?

    func refresh() {
        extensionEnabled = FIFinderSyncController.isExtensionEnabled
        loginEnabled = SMAppService.mainApp.status == .enabled
        loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
    }

    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            message = nil
        } catch { message = "无法更新登录启动设置：\(error.localizedDescription)" }
        refresh()
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage(size: NSSize(width: 72, height: 72)))
                    .resizable()
                    .frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text("MyRight").font(.largeTitle.weight(.semibold))
                    Text("右键，少绕几步。").foregroundStyle(.secondary)
                }
                Spacer()
            }
            GroupBox {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label(model.extensionEnabled ? "Finder 扩展已开启" : "开启 Finder 右键菜单", systemImage: model.extensionEnabled ? "checkmark.circle.fill" : "puzzlepiece.extension")
                            .foregroundStyle(model.extensionEnabled ? Color.green : Color.primary)
                        Spacer()
                        Button("打开扩展设置") { FIFinderSyncController.showExtensionManagementInterface() }
                    }
                    Text("在系统设置中找到 MyRight，打开 Finder 扩展。然后在本机文件夹空白处右键即可使用。")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Divider()
                    Toggle("登录后自动启动", isOn: Binding(get: { model.loginEnabled || model.loginNeedsApproval }, set: { model.setLogin($0) }))
                    if model.loginNeedsApproval {
                        HStack {
                            Text("请在登录项设置中允许 MyRight 启动。").font(.callout).foregroundStyle(.secondary)
                            Button("打开登录项") { SMAppService.openSystemSettingsLoginItems() }
                        }
                    }
                }.padding(10)
            }
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("你的右键工具").font(.headline)
                    HStack(alignment: .top, spacing: 24) {
                        feature("doc.badge.plus", "新建文件", "Office · iWork\nMarkdown · TXT")
                        Divider()
                        feature("terminal", "在终端打开", "当前目录或选中的文件夹\n使用系统 Terminal")
                    }.frame(height: 70)
                    Divider()
                    Text("文件会以“未命名”保存并在 Finder 中选中。按回车即可改名，重名时自动编号。")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Divider()
                    Label("拷贝路径：文件、文件夹及当前目录", systemImage: "link")
                    Label("图片转换：PNG · JPEG · HEIC · TIFF", systemImage: "photo.on.rectangle.angled")
                    Text("右键单张图片即可转换。新图片保存在原目录，保留原图；JPEG 的透明区域填充白色。")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }.padding(10)
            }
            if let message = model.message {
                Text(message).font(.callout).foregroundStyle(.orange).textSelection(.enabled)
            }
            HStack {
                Text("仅支持个人主目录中的本机普通文件夹。\n首次访问受保护目录时，macOS 可能请求授权。")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("刷新状态") { model.refresh() }
            }
        }
        .padding(28)
        .frame(width: 570)
    }

    private func feature(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).font(.title2).foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = SettingsModel()
    private var statusItem: NSStatusItem!
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: "MyRight")
        let menu = NSMenu()
        let settings = NSMenuItem(title: "MyRight 设置…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let extensions = NSMenuItem(title: "开启 Finder 扩展…", action: #selector(openExtensions), keyEquivalent: "")
        extensions.target = self
        menu.addItem(extensions)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出 MyRight", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        statusItem.menu = menu
        model.refresh()
        // Register only from a stable install location, and respect later opt-outs.
        if !UserDefaults.standard.bool(forKey: "loginSetupAttempted"), isInstalled {
            model.setLogin(true)
            UserDefaults.standard.set(true, forKey: "loginSetupAttempted")
        }
    }

    private var isInstalled: Bool {
        let path = Bundle.main.bundleURL.deletingLastPathComponent().standardizedFileURL.path
        return path == "/Applications" || path == FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
    }

    func applicationDidBecomeActive(_ notification: Notification) { model.refresh() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Launch Services can send a reopen event before an action URL. Only
        // the explicit menu-bar Settings command should present this window.
        return false
    }

    @objc func openExtensions() { FIFinderSyncController.showExtensionManagementInterface() }

    @objc func showSettings() {
        model.refresh()
        if window == nil {
            let host = NSHostingView(rootView: SettingsView(model: model))
            let created = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 626, height: 540), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            created.title = "MyRight"
            created.contentView = host
            created.setContentSize(host.fittingSize)
            created.isReleasedWhenClosed = false
            created.center()
            window = created
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard urls.count == 1, let url = urls.first else { return }
        do {
            let request = try ActionRequest(url: url)
            switch request.action {
            case .create(let kind):
                let directory = try LocalDirectory.validate(request.target)
                guard let resources = Bundle.main.resourceURL else { throw ActionError.missingTemplate }
                let file = try FileCreator(templates: resources.appendingPathComponent("Templates")).create(kind, in: directory)
                NSWorkspace.shared.activateFileViewerSelecting([file])
            case .terminal:
                let directory = try LocalDirectory.validate(request.target)
                guard let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
                    throw NSError(domain: "MyRight", code: 1, userInfo: [NSLocalizedDescriptionKey: "找不到系统 Terminal 应用。"])
                }
                NSWorkspace.shared.open([directory], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
                    if let error { Task { @MainActor in self?.showError(error) } }
                }
            case .copyPath:
                _ = try LocalDirectory.validateItem(request.target)
                try PathCopier.copy(request.target)
            case .convert(let format):
                let source = try LocalDirectory.validateItem(request.target)
                Task { [weak self] in
                    do {
                        let output = try await Task.detached(priority: .userInitiated) {
                            try ImageConverter.convert(source, to: format)
                        }.value
                        NSWorkspace.shared.activateFileViewerSelecting([output])
                    } catch { self?.showError(error) }
                }
            }
        } catch { showError(error) }
    }

    private func showError(_ error: Error) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "这次操作没有完成"
        let cocoaError = error as NSError
        let needsPermission = cocoaError.domain == NSCocoaErrorDomain && [NSFileReadNoPermissionError, NSFileWriteNoPermissionError].contains(cocoaError.code)
        alert.informativeText = error.localizedDescription + (needsPermission ? "\n\n请检查系统设置中的“隐私与安全性 → 文件与文件夹”，允许 MyRight 访问对应位置。" : "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}

#if !MYRIGHT_TEST
@main
enum MyRightMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}
#endif
