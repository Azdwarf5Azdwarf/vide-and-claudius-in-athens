import Foundation

/// A small companion that keeps you company while you read git history.
///
/// The entity's *appearance* is derived deterministically from the calendar day,
/// so it stays the same all day and a new one shows up tomorrow. Its *mood* is
/// derived from what the repository actually did, so it doubles as an ambient
/// status indicator for the work in front of you.
///
/// Inspired by the pixel companions in the Hermes agent ecosystem
/// (github.com/teknium1/hermes-pixel-office).
public struct DailyEntity: Codable, Identifiable {
    public var id: String { dayKey }

    /// Calendar day this entity belongs to, as `yyyy-MM-dd`.
    public let dayKey: String
    /// Deterministic seed derived from `dayKey`.
    public let seed: UInt32
    public let species: Species
    public let name: String
    public let palette: Palette
    public let traits: Traits
    /// How the entity feels about the repository right now.
    public var mood: Mood
    /// Normalized activity level, `0...1`. Drives animation speed and jump height.
    public var energy: Double

    public init(
        dayKey: String,
        seed: UInt32,
        species: Species,
        name: String,
        palette: Palette,
        traits: Traits,
        mood: Mood = .idle,
        energy: Double = 0.3
    ) {
        self.dayKey = dayKey
        self.seed = seed
        self.species = species
        self.name = name
        self.palette = palette
        self.traits = traits
        self.mood = mood
        self.energy = energy
    }

    // MARK: - Generation

    /// Builds the entity for a given day. The same date always yields the same
    /// creature, on any machine.
    public static func forDay(_ date: Date = Date(), calendar: Calendar = .current) -> DailyEntity {
        let key = dayKey(for: date, calendar: calendar)
        var rng = SeededGenerator(seed: fnv1a(key))

        let species = Species.allCases[Int(rng.next(upperBound: UInt32(Species.allCases.count)))]
        let name = generateName(&rng)
        let palette = Palette(generator: &rng)
        let traits = Traits(generator: &rng)

        return DailyEntity(
            dayKey: key,
            seed: fnv1a(key),
            species: species,
            name: name,
            palette: palette,
            traits: traits
        )
    }

    /// Builds today's entity and reads its mood from recent repository activity.
    public static func forDay(
        _ date: Date = Date(),
        reactingTo commits: [Commit],
        calendar: Calendar = .current
    ) -> DailyEntity {
        var entity = forDay(date, calendar: calendar)
        let reaction = Reaction(commits: commits, now: date)
        entity.mood = reaction.mood
        entity.energy = reaction.energy
        return entity
    }

    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private static let firstSyllables = [
        "Do", "Pi", "Nyx", "Ka", "Mo", "Zu", "Bo", "Ru", "Ta", "Vi", "Ha", "Lu"
    ]
    private static let lastSyllables = [
        "bby", "pin", "ra", "zu", "mo", "na", "ko", "li", "bo", "sha", "ka", "ni"
    ]

    private static func generateName(_ rng: inout SeededGenerator) -> String {
        let first = firstSyllables[Int(rng.next(upperBound: UInt32(firstSyllables.count)))]
        let last = lastSyllables[Int(rng.next(upperBound: UInt32(lastSyllables.count)))]
        return first + last
    }

    // MARK: - Species

    public enum Species: String, Codable, CaseIterable {
        case capybara, blob, cat, bird, ghost, fox

        /// Three-line terminal silhouette. `%@` is replaced by the mood face.
        public var sprite: [String] {
            switch self {
            case .capybara:
                return ["  ,-------,",
                        " ( %@  )",
                        "  `-u---u-'"]
            case .blob:
                return ["   .-----.",
                        "  ( %@ )",
                        "   `~~~~~'"]
            case .cat:
                return ["   /\\_/\\",
                        "  ( %@ )",
                        "   >  ^  <"]
            case .bird:
                return ["    .--.",
                        "  ( %@ )",
                        "   ^ vv ^"]
            case .ghost:
                return ["   .-----.",
                        "  ( %@ )",
                        "   ~^~^~^~"]
            case .fox:
                return ["  /\\     /\\",
                        " ( %@  )",
                        "   \\  v  /"]
            }
        }
    }

    // MARK: - Mood

    public enum Mood: String, Codable, CaseIterable {
        case idle
        case waving
        case celebrating
        case focused
        case thinking
        case concerned
        case sleeping

        /// Five-character ASCII face used by the terminal sprite.
        public var face: String {
            switch self {
            case .idle:        return "o w o"
            case .waving:      return "^ w ^"
            case .celebrating: return "^ o ^"
            case .focused:     return "> _ <"
            case .thinking:    return "- . -"
            case .concerned:   return "; _ ;"
            case .sleeping:    return "- z -"
            }
        }

        /// Short line shown next to the entity in the UI.
        public var caption: String {
            switch self {
            case .idle:        return "hanging around"
            case .waving:      return "says hi"
            case .celebrating: return "features shipped!"
            case .focused:     return "squashing bugs"
            case .thinking:    return "pondering the refactor"
            case .concerned:   return "something got reverted"
            case .sleeping:    return "no commits today"
            }
        }
    }

    // MARK: - Appearance

    public struct Palette: Codable {
        /// Base body hue in degrees, `0..<360`.
        public let hue: Double
        /// Accent hue in degrees, used for ears, cheeks and accessories.
        public let accentHue: Double
        public let saturation: Double
        public let lightness: Double

        public init(hue: Double, accentHue: Double, saturation: Double, lightness: Double) {
            self.hue = hue
            self.accentHue = accentHue
            self.saturation = saturation
            self.lightness = lightness
        }

        init(generator rng: inout SeededGenerator) {
            let base = Double(rng.next(upperBound: 360))
            self.hue = base
            // Offset the accent far enough to read as a second colour.
            self.accentHue = (base + 40 + Double(rng.next(upperBound: 120))).truncatingRemainder(dividingBy: 360)
            self.saturation = 0.45 + rng.unitDouble() * 0.35
            self.lightness = 0.55 + rng.unitDouble() * 0.2
        }
    }

    public struct Traits: Codable {
        /// `0...1`, how round the body is versus tall.
        public let roundness: Double
        /// `0...1`, relative eye size.
        public let eyeSize: Double
        public let accessory: Accessory
        /// Pattern painted onto the body.
        public let pattern: Pattern

        public enum Accessory: String, Codable, CaseIterable {
            case none, leaf, scarf, hat, antenna
        }

        public enum Pattern: String, Codable, CaseIterable {
            case plain, spots, stripes, belly
        }

        public init(roundness: Double, eyeSize: Double, accessory: Accessory, pattern: Pattern) {
            self.roundness = roundness
            self.eyeSize = eyeSize
            self.accessory = accessory
            self.pattern = pattern
        }

        init(generator rng: inout SeededGenerator) {
            self.roundness = 0.35 + rng.unitDouble() * 0.6
            self.eyeSize = 0.4 + rng.unitDouble() * 0.5
            self.accessory = Accessory.allCases[Int(rng.next(upperBound: UInt32(Accessory.allCases.count)))]
            self.pattern = Pattern.allCases[Int(rng.next(upperBound: UInt32(Pattern.allCases.count)))]
        }
    }

    // MARK: - Terminal rendering

    /// Renders the entity as three lines of ASCII, with the current mood's face.
    public func asciiSprite() -> [String] {
        species.sprite.map { $0.replacingOccurrences(of: "%@", with: mood.face) }
    }
}

// MARK: - Reaction

/// Maps recent repository activity onto a mood and an energy level.
public struct Reaction {
    public let mood: DailyEntity.Mood
    public let energy: Double
    /// Commits considered "recent" for this reaction.
    public let recentCommits: [Commit]

    /// How far back activity still counts as "today's work".
    public static let window: TimeInterval = 24 * 60 * 60

    public init(commits: [Commit], now: Date = Date()) {
        let cutoff = now.addingTimeInterval(-Reaction.window)
        let recent = commits.filter { $0.timestamp >= cutoff }
        self.recentCommits = recent

        // Saturates at ten commits a day — past that it is all "very busy".
        self.energy = min(Double(recent.count) / 10.0, 1.0)

        guard !recent.isEmpty else {
            self.mood = .sleeping
            return
        }

        let analyzer = CommitAnalyzer()
        let analyses = recent.map { analyzer.analyzeCommit($0, in: commits) }

        // Trouble outranks everything else: if the day included a revert or a
        // clearly negative commit, that is the thing worth surfacing.
        let troubled = analyses.contains { $0.sentiment < -0.3 }
            || recent.contains { $0.message.lowercased().contains("revert") }
        if troubled {
            self.mood = .concerned
            return
        }

        var counts: [CommitAnalysis.CommitIntent: Int] = [:]
        for analysis in analyses {
            counts[analysis.intent, default: 0] += 1
        }

        switch counts.max(by: { $0.value < $1.value })?.key {
        case .feature:  self.mood = .celebrating
        case .bugfix:   self.mood = .focused
        case .refactor: self.mood = .thinking
        case .some:     self.mood = .waving
        case .none:     self.mood = .idle
        }
    }
}

// MARK: - Deterministic randomness

/// FNV-1a, so the same day key produces the same seed in every implementation
/// (Swift, and the JavaScript preview in `docs/`).
func fnv1a(_ string: String) -> UInt32 {
    var hash: UInt32 = 2166136261
    for byte in string.utf8 {
        hash ^= UInt32(byte)
        hash = hash &* 16777619
    }
    return hash
}

/// xorshift32. Small, portable, and good enough for picking hat colours.
struct SeededGenerator {
    private var state: UInt32

    init(seed: UInt32) {
        // xorshift stalls on zero.
        self.state = seed == 0 ? 0x9E3779B9 : seed
    }

    mutating func next() -> UInt32 {
        state ^= state &<< 13
        state ^= state &>> 17
        state ^= state &<< 5
        return state
    }

    mutating func next(upperBound: UInt32) -> UInt32 {
        next() % upperBound
    }

    /// A value in `0..<1`.
    mutating func unitDouble() -> Double {
        Double(next()) / Double(UInt32.max)
    }
}
