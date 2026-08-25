import Foundation
import SwiftUI
import AppKit
import GitVisualizerCore

@MainActor
final class RepositoryViewModel: ObservableObject {
    @Published var repositoryPath: String
    @Published private(set) var commits: [Commit] = []
    @Published private(set) var branches: [Branch] = []
    @Published private(set) var analysis: RepositoryAnalysis?
    @Published private(set) var entity: DailyEntity
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    @Published var selectedCommitID: Commit.ID?
    @Published var searchText = ""

    /// Intent per commit, classified once at load. Deriving it per row instead
    /// would re-run the collaboration scan, which is O(commits²), on every
    /// redraw of every row.
    @Published private(set) var intents: [Commit.ID: CommitAnalysis.CommitIntent] = [:]

    private var hasLoaded = false
    private let analyzer = CommitAnalyzer()
    private let classifier = IntentClassifier()

    init(repositoryPath: String? = nil) {
        let resolved = repositoryPath
            ?? Self.pathFromArguments()
            ?? FileManager.default.currentDirectoryPath
        self.repositoryPath = URL(fileURLWithPath: resolved).standardizedFileURL.path
        self.entity = DailyEntity.forDay()
    }

    /// Lets the app be launched against a repository other than the working
    /// directory: `journey ~/some/project`.
    private static func pathFromArguments() -> String? {
        CommandLine.arguments.dropFirst().first { argument in
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: argument, isDirectory: &isDirectory)
            return exists && isDirectory.boolValue
        }
    }

    var repositoryName: String {
        URL(fileURLWithPath: repositoryPath).lastPathComponent
    }

    var currentBranch: Branch? {
        branches.first(where: { $0.isHead })
    }

    /// Commits matching the search box, by summary, author, or hash.
    var visibleCommits: [Commit] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return commits }
        return commits.filter {
            $0.summary.lowercased().contains(query)
                || $0.author.lowercased().contains(query)
                || $0.hash.lowercased().hasPrefix(query)
        }
    }

    var selectedCommit: Commit? {
        guard let selectedCommitID else { return nil }
        return commits.first { $0.id == selectedCommitID }
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        load()
    }

    func load() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        let path = repositoryPath
        Task {
            do {
                let loaded = try await Self.read(path: path)
                self.commits = loaded.commits
                self.branches = loaded.branches
                self.analysis = self.analyzer.analyzeRepository(loaded.commits)
                self.entity = DailyEntity.forDay(Date(), reactingTo: loaded.commits)
                self.selectedCommitID = loaded.commits.first?.id
                self.intents = Dictionary(
                    uniqueKeysWithValues: loaded.commits.map {
                        ($0.id, self.classifier.classify($0.message))
                    }
                )
            } catch {
                self.commits = []
                self.branches = []
                self.analysis = nil
                self.intents = [:]
                self.entity = DailyEntity.forDay()
                self.errorMessage = error.localizedDescription
            }
            self.isLoading = false
        }
    }

    /// git shells out, so keep it off the main actor.
    private static func read(path: String) async throws -> (commits: [Commit], branches: [Branch]) {
        try await Task.detached(priority: .userInitiated) {
            let manager = GitRepositoryManager(repositoryPath: path)
            return (try manager.fetchCommits(limit: 300), try manager.fetchBranches())
        }.value
    }

    func chooseRepository() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        panel.message = "Choose a git repository"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        repositoryPath = url.path
        searchText = ""
        selectedCommitID = nil
        load()
    }

    func intent(for commit: Commit) -> CommitAnalysis.CommitIntent {
        intents[commit.id] ?? .unknown
    }

    /// Counts per intent, ready for `ForEach` — Swift has no key paths into
    /// tuples, so the sorted dictionary needs a named type.
    struct IntentCount: Identifiable {
        let intent: CommitAnalysis.CommitIntent
        let count: Int
        var id: String { intent.rawValue }
    }

    /// Counted from the same per-commit classification the list renders, so the
    /// sidebar totals and the row badges can never disagree.
    var intentBreakdown: [IntentCount] {
        guard !intents.isEmpty else { return [] }
        return intents.values
            .reduce(into: [:]) { counts, intent in counts[intent, default: 0] += 1 }
            .sorted { $0.value > $1.value }
            .map { IntentCount(intent: $0.key, count: $0.value) }
    }
}

extension CommitAnalysis.CommitIntent {
    var label: String {
        rawValue.capitalized
    }

    var tint: Color {
        switch self {
        case .feature:  return .green
        case .bugfix:   return .red
        case .refactor: return .purple
        case .docs:     return .blue
        case .test:     return .teal
        case .ci:       return .orange
        case .chore:    return .gray
        case .unknown:  return .secondary
        }
    }
}

extension FileChange.FileStatus {
    var tint: Color {
        switch self {
        case .added:       return .green
        case .modified:    return .orange
        case .deleted:     return .red
        case .renamed:     return .blue
        case .typeChanged: return .purple
        }
    }
}
