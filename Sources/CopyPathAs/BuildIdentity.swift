import Foundation

struct BuildIdentity {
    let version: String
    let build: String
    let sourceHash: String?

    init(
        version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
        build: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
        sourceHash: String? = Bundle.main.object(forInfoDictionaryKey: "CopyPathSourceHash") as? String
    ) {
        self.version = version
        self.build = build
        self.sourceHash = sourceHash?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayString: String {
        var identity = "Version \(version)"

        if let sourceHash, !sourceHash.isEmpty, !sourceHash.contains("$(") {
            identity += " · Source \(sourceHash)"
        }

        return identity
    }
}
