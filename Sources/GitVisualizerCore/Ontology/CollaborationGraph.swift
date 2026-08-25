import Foundation

public class CollaborationGraph {
    public init() {}

    public struct CollaborationMetrics {
        public let pairs: [String: Int]
        public let reviewed: [String: Int]
        public let coauthors: [String: [String]]

        public init(pairs: [String: Int] = [:], reviewed: [String: Int] = [:], coauthors: [String: [String]] = [:]) {
            self.pairs = pairs
            self.reviewed = reviewed
            self.coauthors = coauthors
        }
    }

    public func findCollaborators(for commit: Commit, in commits: [Commit]) -> [String] {
        var collaborators: Set<String> = []

        for otherCommit in commits {
            if otherCommit.hash != commit.hash && touchesSameFiles(commit, otherCommit) {
                collaborators.insert(otherCommit.author)
            }
        }

        return Array(collaborators).sorted()
    }

    public func calculateCollaboration(_ commits: [Commit]) -> CollaborationMetrics {
        var pairs: [String: Int] = [:]
        var coauthors: [String: [String]] = [:]

        let authors = Array(Set(commits.map { $0.author }))

        for i in 0..<authors.count {
            for j in (i + 1)..<authors.count {
                let authorA = authors[i]
                let authorB = authors[j]

                let commonCommits = commits.filter { commit in
                    commit.author == authorA || commit.author == authorB
                }

                if commonCommits.count > 1 {
                    let key = "\(authorA) <-> \(authorB)"
                    pairs[key] = commonCommits.count
                    coauthors[authorA, default: []].append(authorB)
                    coauthors[authorB, default: []].append(authorA)
                }
            }
        }

        return CollaborationMetrics(pairs: pairs, reviewed: [:], coauthors: coauthors)
    }

    private func touchesSameFiles(_ commit1: Commit, _ commit2: Commit) -> Bool {
        let files1 = Set(commit1.fileChanges.map { $0.path })
        let files2 = Set(commit2.fileChanges.map { $0.path })
        return !files1.intersection(files2).isEmpty
    }
}
