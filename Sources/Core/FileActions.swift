import Foundation

enum FileKind: String, CaseIterable {
    case docx, xlsx, pptx, md, txt, pages, numbers, key

    var title: String {
        switch self {
        case .docx: return "Word 文档"
        case .xlsx: return "Excel 工作簿"
        case .pptx: return "PowerPoint 演示文稿"
        case .md: return "Markdown 文件"
        case .txt: return "文本文档"
        case .pages: return "Pages 文稿"
        case .numbers: return "Numbers 表格"
        case .key: return "Keynote 讲演"
        }
    }

    var symbol: String {
        switch self {
        case .docx: return "doc.richtext"
        case .xlsx: return "tablecells"
        case .pptx: return "rectangle.on.rectangle"
        case .md: return "text.alignleft"
        case .txt: return "doc.plaintext"
        case .pages: return "doc.richtext"
        case .numbers: return "tablecells"
        case .key: return "rectangle.on.rectangle"
        }
    }

    var needsTemplate: Bool { self != .md && self != .txt }
}

enum ImageFormat: String, CaseIterable {
    case png, jpeg, heic, tiff

    static let commonInputExtensions: Set<String> = ["png", "jpg", "jpeg", "jpe", "jfif", "heic", "heif", "tif", "tiff", "gif", "bmp", "dib", "webp", "avif", "ico", "icns", "jp2", "j2k", "psd", "dng"]

    var title: String { rawValue.uppercased() }
    var fileExtension: String { self == .jpeg ? "jpg" : rawValue }
    var typeIdentifier: String {
        switch self {
        case .png: return "public.png"
        case .jpeg: return "public.jpeg"
        case .heic: return "public.heic"
        case .tiff: return "public.tiff"
        }
    }
}

enum ActionError: LocalizedError {
    case invalidRequest, unsupportedDirectory, missingTemplate, tooManyFiles

    var errorDescription: String? {
        switch self {
        case .invalidRequest: return "无法识别这次右键操作，请回到 Finder 重试。"
        case .unsupportedDirectory: return "第一版仅支持个人主目录中的本机普通文件夹。请选择桌面、文稿、下载或自己的项目目录。"
        case .missingTemplate: return "空白文档模板缺失，请重新构建或安装 MyRight。"
        case .tooManyFiles: return "未命名文件太多，请先整理当前文件夹。"
        }
    }
}

struct ActionRequest: Equatable {
    enum Action: Equatable { case create(FileKind), terminal, copyPath, convert(ImageFormat) }
    let action: Action
    let target: URL
    var directory: URL { target }

    static func == (lhs: ActionRequest, rhs: ActionRequest) -> Bool {
        lhs.action == rhs.action && lhs.target.standardizedFileURL.path == rhs.target.standardizedFileURL.path
    }

    var url: URL {
        var components = URLComponents()
        components.scheme = "myright"
        components.host = "action"
        var items = [URLQueryItem(name: "target", value: target.path)]
        switch action {
        case .create(let kind):
            items += [URLQueryItem(name: "operation", value: "create"), URLQueryItem(name: "kind", value: kind.rawValue)]
        case .terminal: items.append(URLQueryItem(name: "operation", value: "terminal"))
        case .copyPath: items.append(URLQueryItem(name: "operation", value: "copyPath"))
        case .convert(let format):
            items += [URLQueryItem(name: "operation", value: "convert"), URLQueryItem(name: "format", value: format.rawValue)]
        }
        components.queryItems = items
        return components.url!
    }

    init(action: Action, directory: URL) {
        self.action = action
        self.target = directory
    }

    init(action: Action, target: URL) {
        self.action = action
        self.target = target
    }

    init(url: URL) throws {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
              c.scheme == "myright", c.host == "action",
              c.user == nil, c.password == nil, c.port == nil,
              c.path.isEmpty, c.fragment == nil else { throw ActionError.invalidRequest }
        let items = c.queryItems ?? []
        guard Set(items.map(\.name)).count == items.count,
              items.allSatisfy({ ["operation", "target", "directory", "kind", "format"].contains($0.name) }),
              items.filter({ $0.name == "target" || $0.name == "directory" }).count == 1,
              let path = items.first(where: { $0.name == "target" || $0.name == "directory" })?.value,
              path.hasPrefix("/"), !path.contains("\0") else { throw ActionError.invalidRequest }
        let operation = items.first(where: { $0.name == "operation" })?.value
        switch operation {
        case "create":
            guard !items.contains(where: { $0.name == "format" }),
                  let value = items.first(where: { $0.name == "kind" })?.value,
                  let kind = FileKind(rawValue: value) else { throw ActionError.invalidRequest }
            action = .create(kind)
        case "terminal", "copyPath":
            guard !items.contains(where: { $0.name == "kind" || $0.name == "format" }) else { throw ActionError.invalidRequest }
            action = operation == "terminal" ? .terminal : .copyPath
        case "convert":
            guard !items.contains(where: { $0.name == "kind" }),
                  let value = items.first(where: { $0.name == "format" })?.value,
                  let format = ImageFormat(rawValue: value) else { throw ActionError.invalidRequest }
            action = .convert(format)
        default: throw ActionError.invalidRequest
        }
        target = URL(fileURLWithPath: path)
    }
}

enum LocalDirectory {
    static func validateItem(_ url: URL, home: URL = FileManager.default.homeDirectoryForCurrentUser) throws -> URL {
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL
        let values = try resolved.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
        if values.isDirectory == true { return try validate(resolved, home: home) }
        _ = try validate(resolved.deletingLastPathComponent(), home: home)
        guard values.isRegularFile == true else { throw ActionError.unsupportedDirectory }
        return resolved
    }

    static func validate(_ url: URL, home: URL = FileManager.default.homeDirectoryForCurrentUser) throws -> URL {
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL
        let root = home.resolvingSymlinksInPath().standardizedFileURL
        guard resolved.path == root.path || resolved.path.hasPrefix(root.path + "/") else {
            throw ActionError.unsupportedDirectory
        }
        let values = try resolved.resourceValues(forKeys: [.isDirectoryKey, .volumeIsLocalKey, .isUbiquitousItemKey])
        let cloudRoot = root.appendingPathComponent("Library/Mobile Documents").path
        let providerRoot = root.appendingPathComponent("Library/CloudStorage").path
        guard values.isDirectory == true, values.volumeIsLocal == true, values.isUbiquitousItem != true,
              !resolved.path.hasPrefix(cloudRoot + "/"), resolved.path != cloudRoot,
              !resolved.path.hasPrefix(providerRoot + "/"), resolved.path != providerRoot else {
            throw ActionError.unsupportedDirectory
        }
        return resolved
    }
}

struct FileCreator {
    let templates: URL

    func create(_ kind: FileKind, in directory: URL) throws -> URL {
        let source = templates.appendingPathComponent("Blank.\(kind.rawValue)")
        if kind.needsTemplate && !FileManager.default.fileExists(atPath: source.path) {
            throw ActionError.missingTemplate
        }
        for number in 0..<1000 {
            let name = number == 0 ? "未命名" : "未命名 \(number + 1)"
            let destination = directory.appendingPathComponent(name).appendingPathExtension(kind.rawValue)
            do {
                if kind.needsTemplate {
                    try FileManager.default.copyItem(at: source, to: destination)
                } else {
                    try Data().write(to: destination, options: .withoutOverwriting)
                }
                return destination
            } catch let error as NSError {
                if error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError { continue }
                throw error
            }
        }
        throw ActionError.tooManyFiles
    }
}
