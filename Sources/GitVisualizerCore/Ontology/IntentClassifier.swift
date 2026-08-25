import Foundation

/// Works out what a commit was trying to do.
///
/// Three rules, in order:
///
/// 1. A conventional-commit prefix (`fix:`, `chore(ci):`) is an explicit
///    statement of intent and wins outright.
/// 2. Otherwise, keywords are matched against the **subject line only**. The
///    body is where false positives live — a `fix:` commit whose body reads
///    "Adds GitLogParsingTests" is still a fix.
/// 3. Keywords are checked in a fixed order, least ambiguous first, so the
///    answer is the same on every run.
public class IntentClassifier {
    public init() {}

    /// Declared types, from the Conventional Commits spec plus common variants.
    private static let declaredTypes: [String: CommitAnalysis.CommitIntent] = [
        "feat": .feature, "feature": .feature,
        "fix": .bugfix, "bugfix": .bugfix, "hotfix": .bugfix,
        "refactor": .refactor, "perf": .refactor,
        "docs": .docs, "doc": .docs,
        "test": .test, "tests": .test,
        "ci": .ci, "build": .ci,
        "chore": .chore, "style": .chore, "deps": .chore
    ]

    /// Ordered, so classification is deterministic. A dictionary here made the
    /// result depend on hash order, which is why the same commit could be
    /// labelled differently in two places in the UI.
    ///
    /// Least ambiguous first: "add" and "new" are generic enough that almost
    /// any commit contains one, so `feature` sits last as the fallback.
    private static let keywordRules: [(CommitAnalysis.CommitIntent, [String])] = [
        (.refactor, ["refactor", "refactoring", "rewrite", "reorganize", "simplify", "extract", "rename"]),
        (.docs,     ["docs", "documentation", "readme", "changelog", "comment", "comments"]),
        (.test,     ["test", "tests", "testing", "spec", "specs", "coverage"]),
        (.ci,       ["ci", "workflow", "workflows", "pipeline", "deploy", "release", "publish"]),
        (.bugfix,   ["fix", "fixes", "fixed", "bug", "bugfix", "patch", "resolve", "resolves", "correct", "repair", "revert"]),
        (.chore,    ["chore", "bump", "dependency", "dependencies", "deps", "cleanup", "tidy", "maintenance"]),
        (.feature,  ["feat", "feature", "add", "adds", "new", "implement", "introduce", "support"])
    ]

    public func classify(_ message: String) -> CommitAnalysis.CommitIntent {
        let subject = Self.subject(of: message)
        let lowered = subject.lowercased()

        // Merges carry the intent of the branch they bring in, not their own.
        if lowered.hasPrefix("merge ") { return .chore }

        if let declared = Self.declaredType(in: lowered) { return declared }

        for (intent, keywords) in Self.keywordRules {
            if keywords.contains(where: { Self.containsWord(lowered, $0) }) {
                return intent
            }
        }

        return .unknown
    }

    public func classifyWithConfidence(_ message: String) -> (intent: CommitAnalysis.CommitIntent, confidence: Double) {
        let subject = Self.subject(of: message).lowercased()

        // A declared type is the author saying it outright.
        if Self.declaredType(in: subject) != nil {
            return (classify(message), 1.0)
        }

        let intent = classify(message)
        guard intent != .unknown else { return (.unknown, 0.0) }

        // Otherwise confidence scales with how many of that intent's keywords
        // appear, which separates "fix typo" from "fix: resolve the bug".
        let matches = Self.keywordRules
            .first { $0.0 == intent }?.1
            .filter { Self.containsWord(subject, $0) }
            .count ?? 0
        return (intent, min(0.4 + Double(matches) * 0.2, 0.9))
    }

    // MARK: - Helpers

    /// The first line. Everything after it is prose that misleads keyword matching.
    static func subject(of message: String) -> String {
        message
            .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? message
    }

    /// Reads `type:` or `type(scope):` off the front of a subject line.
    static func declaredType(in subject: String) -> CommitAnalysis.CommitIntent? {
        guard let colon = subject.firstIndex(of: ":") else { return nil }

        var type = String(subject[subject.startIndex..<colon])
        // Drop a scope, and the "!" that marks a breaking change.
        if let paren = type.firstIndex(of: "(") {
            type = String(type[type.startIndex..<paren])
        }
        type = type.replacingOccurrences(of: "!", with: "")
            .trimmingCharacters(in: .whitespaces)
            .lowercased()

        // A prose sentence containing a colon is not a declared type.
        guard !type.isEmpty, !type.contains(" ") else { return nil }
        return declaredTypes[type]
    }

    /// Whole-word match, so "ci" does not fire on "specific" and "new" does not
    /// fire on "renewed".
    static func containsWord(_ haystack: String, _ needle: String) -> Bool {
        if needle.contains(" ") { return haystack.contains(needle) }
        return haystack
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .contains { $0 == Substring(needle) }
    }
}
