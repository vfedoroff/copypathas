public protocol ClipboardWriting: Sendable {
    func copy(_ value: String) throws
}

