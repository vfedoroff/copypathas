import Foundation
import Testing
@testable import CopyPathCore

@Suite("FormatPathsUseCase")
struct FormatPathsUseCaseTests {
    @Test func forwardsSelectionAndCopiesFormattedValue() throws {
        let formatter = FormatterStub(result: "formatted")
        let clipboard = ClipboardSpy()
        let selection = FileSelection([URL(fileURLWithPath: "/tmp/a")])!

        try FormatPathsUseCase(formatter: formatter, clipboard: clipboard).execute(selection: selection, format: .jsonArray)

        #expect(formatter.receivedURLs == selection.urls)
        #expect(formatter.receivedFormat == .jsonArray)
        #expect(clipboard.values == ["formatted"])
    }

    @Test func propagatesClipboardFailure() {
        let useCase = FormatPathsUseCase(formatter: FormatterStub(result: "value"), clipboard: ClipboardSpy(error: TestError.failed))
        let selection = FileSelection([URL(fileURLWithPath: "/tmp/a")])!
        #expect(throws: TestError.failed) { try useCase.execute(selection: selection, format: .path) }
    }
}

private final class FormatterStub: PathFormatting, @unchecked Sendable {
    let result: String
    var receivedURLs: [URL] = []
    var receivedFormat: PathFormat?
    init(result: String) { self.result = result }
    func format(_ urls: [URL], as format: PathFormat) -> String {
        receivedURLs = urls
        receivedFormat = format
        return result
    }
}

private final class ClipboardSpy: ClipboardWriting, @unchecked Sendable {
    var values: [String] = []
    let error: Error?
    init(error: Error? = nil) { self.error = error }
    func copy(_ value: String) throws {
        if let error { throw error }
        values.append(value)
    }
}

private enum TestError: Error { case failed }
