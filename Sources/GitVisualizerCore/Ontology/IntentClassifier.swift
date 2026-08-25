import Foundation

public class IntentClassifier {
    public init() {}

    private let intentPatterns: [CommitAnalysis.CommitIntent: [String]] = [
        .feature: ["feat", "feature", "add", "new", "implement"],
        .bugfix: ["fix", "bug", "bugfix", "patch", "hotfix", "resolve", "close"],
        .refactor: ["refactor", "refactoring", "rewrite", "reorganize", "simplify"],
        .docs: ["doc", "docs", "documentation", "readme", "javadoc", "comment"],
        .test: ["test", "tests", "testing", "test case", "unit test"],
        .ci: ["ci", "github actions", "workflow", "build", "deploy", "release", "pipeline"],
        .chore: ["chore", "deps", "dependencies", "update", "upgrade", "maintenance"]
    ]

    public func classify(_ message: String) -> CommitAnalysis.CommitIntent {
        let lowerMessage = message.lowercased()

        for (intent, keywords) in intentPatterns {
            for keyword in keywords {
                if lowerMessage.contains(keyword) {
                    return intent
                }
            }
        }

        return .unknown
    }

    public func classifyWithConfidence(_ message: String) -> (intent: CommitAnalysis.CommitIntent, confidence: Double) {
        let lowerMessage = message.lowercased()
        var scores: [CommitAnalysis.CommitIntent: Int] = [:]

        for (intent, keywords) in intentPatterns {
            for keyword in keywords {
                if lowerMessage.contains(keyword) {
                    scores[intent, default: 0] += 1
                }
            }
        }

        if let (intent, score) = scores.max(by: { $0.value < $1.value }) {
            let confidence = Double(score) / Double(intentPatterns.values.flatMap({ $0 }).count)
            return (intent: intent, confidence: confidence)
        }

        return (intent: .unknown, confidence: 0.0)
    }
}
