public struct FormatPathsUseCase: Sendable {
    private let formatter: any PathFormatting
    private let clipboard: any ClipboardWriting

    public init(formatter: any PathFormatting, clipboard: any ClipboardWriting) {
        self.formatter = formatter
        self.clipboard = clipboard
    }

    public func execute(selection: FileSelection, format: PathFormat) throws {
        let value = formatter.format(selection.urls, as: format)
        guard !value.isEmpty else { return }
        try clipboard.copy(value)
    }
}
