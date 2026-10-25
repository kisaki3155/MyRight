import Foundation

final class FileActionsTests {
    private var directory: URL!
    private var templates: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/Templates")
    }

    func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    func testCreatesAllEightFormatsWithoutChangingTemplates() throws {
        let creator = FileCreator(templates: templates)
        for kind in FileKind.allCases {
            let created = try creator.create(kind, in: directory)
            expectEqual(created.lastPathComponent, "未命名.\(kind.rawValue)")
            let data = try Data(contentsOf: created)
            if kind.needsTemplate {
                expectEqual(data, try Data(contentsOf: templates.appendingPathComponent("Blank.\(kind.rawValue)")))
                expectEqual(data.prefix(2), Data([0x50, 0x4b]))
            } else { expect(data.isEmpty) }
        }
    }

    func testCollisionNeverOverwritesExistingFilesOrDirectories() throws {
        let original = directory.appendingPathComponent("未命名.md")
        try Data("Keep me".utf8).write(to: original)
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("未命名 2.md"), withIntermediateDirectories: false)
        let result = try FileCreator(templates: templates).create(.md, in: directory)
        expectEqual(result.lastPathComponent, "未命名 3.md")
        expectEqual(try String(contentsOf: original, encoding: .utf8), "Keep me")
    }

    func testOfficeCollisionDoesNotOverwrite() throws {
        let creator = FileCreator(templates: templates)
        let first = try creator.create(.docx, in: directory)
        let second = try creator.create(.docx, in: directory)
        expectEqual(second.lastPathComponent, "未命名 2.docx")
        expectEqual(try Data(contentsOf: first), try Data(contentsOf: second))
    }

    func testMissingTemplateCreatesNothing() throws {
        expectThrows(try FileCreator(templates: directory).create(.pptx, in: directory))
        expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    func testRequestRoundTripsSpecialPathCharactersWithoutShellInterpretation() throws {
        let path = URL(fileURLWithPath: "/Users/test/中文 & # + % ' \" $(touch hacked)\nfolder", isDirectory: true)
        for action in [ActionRequest.Action.create(.md), .terminal, .copyPath, .convert(.jpeg)] {
            let request = ActionRequest(action: action, directory: path)
            expectEqual(try ActionRequest(url: request.url), request)
        }
    }

    func testRejectsMalformedRequests() {
        let invalid = [
            "https://action?operation=terminal&directory=/Users/test",
            "myright://action?operation=terminal&directory=relative",
            "myright://action?operation=create&kind=exe&directory=/Users/test",
            "myright://action?operation=terminal&operation=create&directory=/Users/test",
            "myright://action?operation=terminal&directory=/Users/test&extra=1",
            "myright://action/other?operation=terminal&directory=/Users/test",
            "myright://action?operation=copyPath&target=/Users/test&directory=/Users/test",
            "myright://action?operation=convert&target=/Users/test/a.png&format=exe",
            "myright://action?operation=convert&target=/Users/test/a.png&format=png&kind=md"
        ]
        for value in invalid { expectThrows(try ActionRequest(url: URL(string: value)!)) }
    }

    func testRejectsEscapesFromHomeIncludingSymlinks() throws {
        let home = directory.appendingPathComponent("home", isDirectory: true)
        let outside = directory.appendingPathComponent("outside", isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let link = home.appendingPathComponent("escape")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        expectNoThrow(try LocalDirectory.validate(home, home: home))
        expectThrows(try LocalDirectory.validate(link, home: home))
        expectThrows(try LocalDirectory.validate(home.appendingPathComponent(".."), home: home))
        let cloud = home.appendingPathComponent("Library/CloudStorage/Provider")
        try FileManager.default.createDirectory(at: cloud, withIntermediateDirectories: true)
        expectThrows(try LocalDirectory.validate(cloud, home: home))
    }
}


private func expect(_ value: Bool, file: StaticString = #file, line: UInt = #line) {
    precondition(value, "Expectation failed", file: file, line: line)
}
private func expectEqual<T: Equatable>(_ left: T, _ right: T, file: StaticString = #file, line: UInt = #line) {
    precondition(left == right, "Expected equal values", file: file, line: line)
}
private func expectNoThrow<T>(_ expression: @autoclosure () throws -> T) {
    do { _ = try expression() } catch { fatalError("Unexpected error: \(error)") }
}
private func expectThrows<T>(_ expression: @autoclosure () throws -> T) {
    do { _ = try expression() } catch { return }
    fatalError("Expected an error")
}

@main
struct CoreTestRunner {
    static func main() throws {
        let tests = FileActionsTests()
        let cases: [(String, () throws -> Void)] = [
            ("All eight file formats", tests.testCreatesAllEightFormatsWithoutChangingTemplates),
            ("File and directory name collisions", tests.testCollisionNeverOverwritesExistingFilesOrDirectories),
            ("Office name collisions", tests.testOfficeCollisionDoesNotOverwrite),
            ("Missing template", tests.testMissingTemplateCreatesNothing),
            ("Special path characters", tests.testRequestRoundTripsSpecialPathCharactersWithoutShellInterpretation),
            ("Malformed requests", tests.testRejectsMalformedRequests),
            ("Directory boundary and symlinks", tests.testRejectsEscapesFromHomeIncludingSymlinks)
        ]
        for (name, run) in cases {
            try tests.setUpWithError()
            do { try run() } catch {
                try? tests.tearDownWithError()
                throw error
            }
            try tests.tearDownWithError()
            print("PASS: \(name)")
        }
        print("All \(cases.count) core checks passed.")
    }
}
