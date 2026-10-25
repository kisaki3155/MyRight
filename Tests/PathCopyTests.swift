import AppKit

@main
enum PathCopyTests {
    static func main() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("MyRight-test-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let url = URL(fileURLWithPath: "/Users/test/中文 & quoted ' filename.png")
        try PathCopier.copy(url, to: pasteboard)
        precondition(pasteboard.string(forType: .string) == url.path)
        print("PASS: copies a plain absolute path, preserving Unicode and special characters")
    }
}
