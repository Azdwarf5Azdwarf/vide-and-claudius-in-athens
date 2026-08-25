import XCTest
@testable import GitVisualizerCore

final class DailyEntityTests: XCTestCase {

    private func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: string)!
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func commit(
        _ message: String,
        author: String = "Alice",
        at date: Date = Date(),
        hash: String = UUID().uuidString
    ) -> Commit {
        Commit(
            hash: hash,
            author: author,
            authorEmail: "\(author.lowercased())@example.com",
            timestamp: date,
            message: message
        )
    }

    // MARK: - Determinism

    func testSameDayProducesSameEntity() {
        let day = date("2026-08-25")
        let first = DailyEntity.forDay(day, calendar: utcCalendar)
        let second = DailyEntity.forDay(day, calendar: utcCalendar)

        XCTAssertEqual(first.seed, second.seed)
        XCTAssertEqual(first.name, second.name)
        XCTAssertEqual(first.species, second.species)
        XCTAssertEqual(first.traits.accessory, second.traits.accessory)
        XCTAssertEqual(first.palette.hue, second.palette.hue)
    }

    func testDifferentDaysProduceDifferentEntities() {
        let days = (1...14).map { date(String(format: "2026-08-%02d", $0)) }
        let seeds = Set(days.map { DailyEntity.forDay($0, calendar: utcCalendar).seed })

        // Seeds come from distinct day keys, so every one should be unique.
        XCTAssertEqual(seeds.count, days.count)
    }

    func testTimeOfDayDoesNotChangeTheEntity() {
        let morning = date("2026-08-25").addingTimeInterval(60 * 60 * 2)
        let evening = date("2026-08-25").addingTimeInterval(60 * 60 * 22)

        XCTAssertEqual(
            DailyEntity.forDay(morning, calendar: utcCalendar).seed,
            DailyEntity.forDay(evening, calendar: utcCalendar).seed
        )
    }

    func testDayKeyIsZeroPadded() {
        XCTAssertEqual(DailyEntity.dayKey(for: date("2026-01-05"), calendar: utcCalendar), "2026-01-05")
    }

    /// The JavaScript preview in `docs/` reimplements this hash, so the value is
    /// pinned here to keep the two in sync.
    func testFNV1aMatchesReferenceValues() {
        XCTAssertEqual(fnv1a(""), 2166136261)
        XCTAssertEqual(fnv1a("a"), 0xe40c292c)
        XCTAssertEqual(fnv1a("foobar"), 0xbf9cf968)
    }

    func testGeneratorNeverStallsOnZeroSeed() {
        var rng = SeededGenerator(seed: 0)
        let values = (0..<5).map { _ in rng.next() }
        XCTAssertFalse(values.allSatisfy { $0 == 0 })
    }

    // MARK: - Mood

    func testNoRecentCommitsMeansSleeping() {
        let stale = commit("feat: something", at: Date().addingTimeInterval(-60 * 60 * 48))
        XCTAssertEqual(Reaction(commits: [stale]).mood, .sleeping)
    }

    func testEmptyRepositoryMeansSleeping() {
        XCTAssertEqual(Reaction(commits: []).mood, .sleeping)
        XCTAssertEqual(Reaction(commits: []).energy, 0)
    }

    func testFeatureCommitsMeanCelebrating() {
        let commits = [
            commit("feat: add the dashboard"),
            commit("feat: add a second thing")
        ]
        XCTAssertEqual(Reaction(commits: commits).mood, .celebrating)
    }

    func testBugfixCommitsMeanFocused() {
        let commits = [commit("fix: correct the off-by-one")]
        XCTAssertEqual(Reaction(commits: commits).mood, .focused)
    }

    func testRefactorCommitsMeanThinking() {
        let commits = [commit("refactor: simplify the parser")]
        XCTAssertEqual(Reaction(commits: commits).mood, .thinking)
    }

    func testRevertOutranksEverythingElse() {
        let commits = [
            commit("feat: add the dashboard"),
            commit("feat: add another thing"),
            commit("Revert \"feat: add the dashboard\"")
        ]
        // Three commits, two of them features — but the revert is the story.
        XCTAssertEqual(Reaction(commits: commits).mood, .concerned)
    }

    func testEnergyRisesWithCommitCountAndSaturates() {
        let quiet = Reaction(commits: [commit("docs: tweak")])
        let busy = Reaction(commits: (0..<25).map { commit("docs: tweak \($0)") })

        XCTAssertEqual(quiet.energy, 0.1, accuracy: 0.0001)
        XCTAssertEqual(busy.energy, 1.0, accuracy: 0.0001)
    }

    func testOnlyCommitsInsideTheWindowCount() {
        let now = Date()
        let commits = [
            commit("feat: recent", at: now.addingTimeInterval(-60 * 60)),
            commit("feat: old", at: now.addingTimeInterval(-Reaction.window - 60))
        ]
        XCTAssertEqual(Reaction(commits: commits, now: now).recentCommits.count, 1)
    }

    // MARK: - Rendering

    func testAsciiSpriteRendersMoodFace() {
        var entity = DailyEntity.forDay(date("2026-08-25"), calendar: utcCalendar)
        entity.mood = .celebrating

        let sprite = entity.asciiSprite()
        XCTAssertEqual(sprite.count, 3)
        XCTAssertTrue(sprite.joined().contains(DailyEntity.Mood.celebrating.face))
        XCTAssertFalse(sprite.joined().contains("%@"))
    }

    func testEverySpeciesHasAPlaceholderForTheFace() {
        for species in DailyEntity.Species.allCases {
            XCTAssertTrue(
                species.sprite.joined().contains("%@"),
                "\(species.rawValue) sprite is missing its face placeholder"
            )
        }
    }

    func testEveryMoodFaceIsTheSameWidth() {
        // The sprites are hand-aligned around a five-character face.
        for mood in DailyEntity.Mood.allCases {
            XCTAssertEqual(mood.face.count, 5, "\(mood.rawValue) face is the wrong width")
        }
    }
}
