import Foundation

public struct Branch: Identifiable, Codable {
    public let id: String
    public let name: String
    public let shortName: String
    public let tipHash: String
    public let isLocal: Bool
    public let isHead: Bool
    public let trackingBranch: String?
    public let aheadCount: Int
    public let behindCount: Int

    public init(
        name: String,
        tipHash: String,
        isLocal: Bool = true,
        isHead: Bool = false,
        trackingBranch: String? = nil,
        aheadCount: Int = 0,
        behindCount: Int = 0
    ) {
        self.id = name
        self.name = name
        self.shortName = name.split(separator: "/").last.map(String.init) ?? name
        self.tipHash = tipHash
        self.isLocal = isLocal
        self.isHead = isHead
        self.trackingBranch = trackingBranch
        self.aheadCount = aheadCount
        self.behindCount = behindCount
    }

    public var displayName: String {
        if isHead {
            return "→ \(shortName)"
        }
        return shortName
    }

    public var trackingStatus: String? {
        guard trackingBranch != nil else { return nil }
        if aheadCount == 0 && behindCount == 0 {
            return "in sync"
        } else if aheadCount > 0 && behindCount == 0 {
            return "↑ \(aheadCount)"
        } else if aheadCount == 0 && behindCount > 0 {
            return "↓ \(behindCount)"
        } else {
            return "↑ \(aheadCount) ↓ \(behindCount)"
        }
    }
}
