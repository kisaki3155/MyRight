import AppKit

enum PathCopier {
    static func copy(_ target: URL, to pasteboard: NSPasteboard = .general) throws {
        pasteboard.clearContents()
        guard pasteboard.setString(target.standardizedFileURL.path, forType: .string) else {
            throw NSError(domain: "MyRight", code: 2, userInfo: [NSLocalizedDescriptionKey: "无法将路径写入剪贴板，请重试。"])
        }
    }
}
