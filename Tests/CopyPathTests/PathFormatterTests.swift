import Foundation
import Testing
@testable import CopyPathCore

@Suite("PathFormatter")
struct PathFormatterTests {
    private let formatter = PathFormatter()

    @Test func formatsSimplePath() {
        #expect(format(.path, "/Users/me/Projects/App/main.go") == "/Users/me/Projects/App/main.go")
    }

    @Test func quotesAndEscapesPath() {
        #expect(format(.quotedPath, #"/tmp/a "quote"\file"#) == #""/tmp/a \"quote\"\\file""#)
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

    private func format(_ pathFormat: PathFormat, _ path: String) -> String {
        formatter.format([URL(fileURLWithPath: path)], as: pathFormat)
    }
}
