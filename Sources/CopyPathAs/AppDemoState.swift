import Foundation

enum AppDemoState: String, CaseIterable {
    case overview
    case formats
    case setup
    case copied

    static func parse(arguments: [String]) -> AppDemoState? {
        guard let flagIndex = arguments.firstIndex(of: "--demo") else {
            return nil
        }

        let valueIndex = arguments.index(after: flagIndex)
        guard arguments.indices.contains(valueIndex) else {
            return nil
        }

        return AppDemoState(rawValue: arguments[valueIndex])
    }

    static var current: AppDemoState? {
        parse(arguments: ProcessInfo.processInfo.arguments)
    }
}
