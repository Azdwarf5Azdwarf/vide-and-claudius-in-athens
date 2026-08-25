import Foundation

public class FileHealthTracker {
    public struct FileHealthMetrics {
        public let path: String
        public let changeCount: Int
        public let lastModified: Date?
        public let linesAdded: Int
        public let linesDeleted: Int
        public let volatilityScore: Double

        public init(
            path: String,
            changeCount: Int,
            lastModified: Date?,
            linesAdded: Int = 0,
            linesDeleted: Int = 0,
            volatilityScore: Double = 0.0
        ) {
            self.path = path
            self.changeCount = changeCount
            self.lastModified = lastModified
            self.linesAdded = linesAdded
            self.linesDeleted = linesDeleted
            self.volatilityScore = volatilityScore
        }
    }

    public func findVolatileFiles(_ commits: [Commit], topN: Int = 10) -> [String] {
        var fileMetrics: [String: (count: Int, lastModified: Date?, linesAdded: Int, linesDeleted: Int)] = [:]

        for commit in commits {
            for fileChange in commit.fileChanges {
                var metrics = fileMetrics[fileChange.path] ?? (count: 0, lastModified: nil, linesAdded: 0, linesDeleted: 0)
                metrics.count += 1
                metrics.lastModified = max(metrics.lastModified ?? commit.timestamp, commit.timestamp)
                metrics.linesAdded += fileChange.insertions
                metrics.linesDeleted += fileChange.deletions
                fileMetrics[fileChange.path] = metrics
            }
        }

        return fileMetrics
            .map { (path, metrics) in
                (path: path, metrics: metrics, volatilityScore: calculateVolatility(metrics))
            }
            .sorted { $0.volatilityScore > $1.volatilityScore }
            .prefix(topN)
            .map { $0.path }
    }

    public func getFileHealthMetrics(_ commits: [Commit]) -> [FileHealthMetrics] {
        var fileMetrics: [String: (count: Int, lastModified: Date?, linesAdded: Int, linesDeleted: Int)] = [:]

        for commit in commits {
            for fileChange in commit.fileChanges {
                var metrics = fileMetrics[fileChange.path] ?? (count: 0, lastModified: nil, linesAdded: 0, linesDeleted: 0)
                metrics.count += 1
                metrics.lastModified = max(metrics.lastModified ?? commit.timestamp, commit.timestamp)
                metrics.linesAdded += fileChange.insertions
                metrics.linesDeleted += fileChange.deletions
                fileMetrics[fileChange.path] = metrics
            }
        }

        return fileMetrics.map { (path, metrics) in
            FileHealthMetrics(
                path: path,
                changeCount: metrics.count,
                lastModified: metrics.lastModified,
                linesAdded: metrics.linesAdded,
                linesDeleted: metrics.linesDeleted,
                volatilityScore: calculateVolatility(metrics)
            )
        }.sorted { $0.volatilityScore > $1.volatilityScore }
    }

    public func identifyCoupling(_ commits: [Commit]) -> [String: [String]] {
        var coupling: [String: Set<String>] = [:]

        for commit in commits {
            let files = Set(commit.fileChanges.map { $0.path })
            for file in files {
                for otherFile in files {
                    if file != otherFile {
                        coupling[file, default: []].insert(otherFile)
                    }
                }
            }
        }

        return coupling.mapValues { Array($0).sorted() }
    }

    private func calculateVolatility(_ metrics: (count: Int, lastModified: Date?, linesAdded: Int, linesDeleted: Int)) -> Double {
        let changeScore = Double(metrics.count)
        let linesScore = Double(metrics.linesAdded + metrics.linesDeleted) * 0.1

        var recencyScore = 0.0
        if let lastModified = metrics.lastModified {
            let daysSinceModified = Date().timeIntervalSince(lastModified) / 86400
            recencyScore = daysSinceModified < 7 ? 2.0 : daysSinceModified < 30 ? 1.0 : 0.5
        }

        return changeScore + linesScore + recencyScore
    }
}
