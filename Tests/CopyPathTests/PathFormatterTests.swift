import Foundation
import Testing
@testable import CopyPathCore

@Suite("PathFormatter")
struct PathFormatterTests {
    private let formatter = PathFormatter()

    @Test func formatsSimplePath() {
        #expect(format(.path, "/Users/me/Projects/App/main.go") == "/Users/me/Projects/App/main.go")
    }

    @Test func quotesPathWithSingleQuotesForShellSafety() {
        #expect(format(.quotedPath, #"/tmp/a "quote"\file"#) == #"'/tmp/a "quote"\file'"#)
    }

    @Test func singleQuotedPathDoesNotLeaveShellExpansionsActive() {
        #expect(format(.quotedPath, "/tmp/$(touch exploited)`whoami`/$HOME") == #"'/tmp/$(touch exploited)`whoami`/$HOME'"#)
        #expect(format(.quotedPath, "/tmp/it's here") == #"'/tmp/it'\''s here'"#)
    }

    @Test func shellEscapesSpacesAndMetacharacters() {
        #expect(format(.shellEscapedPath, "/Users/me/My App/$file's.txt") == #"/Users/me/My\ App/\$file\'s.txt"#)
    }

    @Test func shellQuotesEmbeddedNewlineSafely() {
        #expect(format(.shellEscapedPath, "/tmp/a\nb's") == "'/tmp/a\nb'\\''s'")
    }

    @Test func preservesReadableUnicode() {
        #expect(format(.shellEscapedPath, "/tmp/日本語 file.swift") == #"/tmp/日本語\ file.swift"#)
        #expect(format(.filename, "/tmp/日本語.swift") == "日本語.swift")
    }

    @Test func formatsFileURL() {
        #expect(format(.fileURL, "/tmp/My App.swift") == "file:///tmp/My%20App.swift")
    }

    @Test func formatsFilenameVariants() {
        #expect(format(.filename, "/tmp/archive.tar.gz") == "archive.tar.gz")
        #expect(format(.filenameWithoutExtension, "/tmp/archive.tar.gz") == "archive.tar")
        #expect(format(.filenameWithoutExtension, "/tmp/README") == "README")
        #expect(format(.filenameWithoutExtension, "/tmp/.gitignore") == ".gitignore")
    }

    @Test func formatsParentFolder() {
        #expect(format(.parentFolder, "/Users/me/App/main.go") == "/Users/me/App")
    }

    @Test func joinsMultiplePlainValuesInSelectionOrder() {
        let urls = [URL(fileURLWithPath: "/tmp/one"), URL(fileURLWithPath: "/tmp/two")]
        #expect(formatter.format(urls, as: .path) == "/tmp/one\n/tmp/two")
        #expect(formatter.format(urls, as: .filename) == "one\ntwo")
    }

    @Test func producesValidEscapedJSON() throws {
        let paths = [#"/tmp/a\"b"#, "/tmp/back\\slash", "/tmp/日本語"]
        let output = formatter.format(paths.map(URL.init(fileURLWithPath:)), as: .jsonArray)
        let decoded = try JSONDecoder().decode([String].self, from: Data(output.utf8))
        #expect(decoded == paths)
        #expect(output.contains("\n"))
    }

    @Test func escapesMarkdownTextAndDestination() {
        let output = format(.markdownLink, #"/tmp/a[b]\c (draft).md"#)
        #expect(output == #"[a\[b\]\\c (draft).md](file:///tmp/a%5Bb%5D%5Cc%20%28draft%29.md)"#)
    }

    @Test func joinsMarkdownLinksWithNewlines() {
        let urls = [URL(fileURLWithPath: "/tmp/a.md"), URL(fileURLWithPath: "/tmp/b.md")]
        #expect(formatter.format(urls, as: .markdownLink) == "[a.md](file:///tmp/a.md)\n[b.md](file:///tmp/b.md)")
    }

    @Test func formatsHomeRelativePath() {
        let home = NSHomeDirectory()
        #expect(format(.homeRelative, home + "/Documents/project") == "~/Documents/project")
        #expect(format(.homeRelative, home) == "~")
        #expect(format(.homeRelative, "/var/tmp") == "/var/tmp")
    }

    @Test func formatsJSONString() {
        #expect(format(.jsonString, #"/tmp/My "Document"\File"#) == #""/tmp/My \"Document\"\\File""#)
    }

    @Test func formatsRepoRelativePath() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let gitDir = tempDir.appendingPathComponent(".git")
        let fileInRepo = tempDir.appendingPathComponent("Sources/main.swift")

        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: fileInRepo.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "test".write(to: fileInRepo, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let output = formatter.format([fileInRepo], as: .repoRelative)
        #expect(output == "Sources/main.swift")
    }

    @Test func formatsRepoRelativePathFallback() {
        let randomPath = "/tmp/\(UUID().uuidString)/file.txt"
        let output = format(.repoRelative, randomPath)
        let home = NSHomeDirectory()
        let expected = randomPath.replacingOccurrences(of: home, with: "~")
        #expect(output == expected)
    }


    private func format(_ pathFormat: PathFormat, _ path: String) -> String {
        formatter.format([URL(fileURLWithPath: path)], as: pathFormat)
    }
}
