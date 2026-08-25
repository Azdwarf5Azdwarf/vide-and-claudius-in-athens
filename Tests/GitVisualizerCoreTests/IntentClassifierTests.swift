import XCTest
@testable import GitVisualizerCore

final class IntentClassifierTests: XCTestCase {
    private let classifier = IntentClassifier()

    // MARK: - The misclassifications this repository actually produced

    /// Every case here was observed in the app against this repository's own
    /// history, where the classifier searched the whole message for substrings
    /// and iterated an unordered dictionary.
    func testCommitsThisRepositoryMisclassified() {
        let cases: [(String, CommitAnalysis.CommitIntent)] = [
            ("chore: add a gitignore for SwiftPM build output", .chore),
            ("fix: add missing public initializers on cross-module types", .bugfix),
            ("ci: build and test the Swift package on macOS", .ci),
            ("feat: add the macOS app window", .feature),
            ("build: Initialize Git Visualizer Swift package with MVP foundation", .ci),
        ]

        for (message, expected) in cases {
            XCTAssertEqual(classifier.classify(message), expected, "misread: \(message)")
        }
    }

    func testBodyKeywordsDoNotOverrideTheSubject() {
        // Reported as a feature because the body says "Adds GitLogParsingTests".
        let message = """
        fix: rewrite git log parsing, which returned garbage on real repos

        Adds GitLogParsingTests: the fixture cases for each fault above plus an
        end-to-end check that parses this repository.
        """
        XCTAssertEqual(classifier.classify(message), .bugfix)
    }

    func testMergeCommitIsNotClassifiedByItsBody() {
        // Reported as a test because the body mentioned "32 tests passing".
        let message = """
        Merge pull request #1: Git Visualizer MVP, daily entity, and macOS app

        Verified on macos-15: 32 tests passing, all targets compiling.
        """
        XCTAssertEqual(classifier.classify(message), .chore)
    }

    // MARK: - Determinism

    func testClassificationIsStableAcrossInstances() {
        // The sidebar and the commit list each build their own classifier. When
        // the rules lived in a dictionary they could disagree about the same
        // commit, so the two panes showed different totals.
        let messages = [
            "chore: add a gitignore",
            "fix: add missing initializers",
            "add support for something",
            "Merge branch 'main'",
            "wip",
        ]

        for message in messages {
            let answers = Set((0..<20).map { _ in IntentClassifier().classify(message) })
            XCTAssertEqual(answers.count, 1, "unstable classification for: \(message)")
        }
    }

    // MARK: - Declared types

    func testDeclaredTypeWins() {
        XCTAssertEqual(classifier.classify("feat: something"), .feature)
        XCTAssertEqual(classifier.classify("fix: something"), .bugfix)
        XCTAssertEqual(classifier.classify("docs: something"), .docs)
        XCTAssertEqual(classifier.classify("test: something"), .test)
        XCTAssertEqual(classifier.classify("refactor: something"), .refactor)
        XCTAssertEqual(classifier.classify("perf: speed up the parser"), .refactor)
        XCTAssertEqual(classifier.classify("style: reformat"), .chore)
    }

    func testScopedAndBreakingPrefixes() {
        XCTAssertEqual(classifier.classify("fix(parser): handle empty output"), .bugfix)
        XCTAssertEqual(classifier.classify("feat(ui)!: redesign the sidebar"), .feature)
        XCTAssertEqual(classifier.classify("chore(deps): bump argument-parser"), .chore)
    }

    func testProseColonIsNotADeclaredType() {
        // "Revert" is not a declared type, and the colon here is punctuation.
        XCTAssertEqual(classifier.classify("Revert \"feat: add the dashboard\""), .bugfix)
    }

    // MARK: - Word boundaries

    func testKeywordsMatchWholeWordsOnly() {
        // "ci" inside "specific", "new" inside "renewed", "add" inside "address".
        XCTAssertNotEqual(classifier.classify("make the error more specific"), .ci)
        XCTAssertNotEqual(classifier.classify("renewed the certificate"), .feature)
        XCTAssertNotEqual(classifier.classify("address the reviewer feedback"), .feature)
    }

    func testUnrecognisedMessageIsUnknown() {
        XCTAssertEqual(classifier.classify("wip"), .unknown)
        XCTAssertEqual(classifier.classify(""), .unknown)
    }

    // MARK: - Confidence

    func testDeclaredTypeIsFullyConfident() {
        XCTAssertEqual(classifier.classifyWithConfidence("fix: a thing").confidence, 1.0)
    }

    func testUnknownHasNoConfidence() {
        XCTAssertEqual(classifier.classifyWithConfidence("wip").confidence, 0.0)
    }
}
