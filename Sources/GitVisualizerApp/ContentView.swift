import SwiftUI
import GitVisualizerCore
import GitVisualizerUI

struct ContentView: View {
    @ObservedObject var model: RepositoryViewModel

    var body: some View {
        NavigationSplitView {
            Sidebar(model: model)
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        } content: {
            CommitList(model: model)
                .navigationSplitViewColumnWidth(min: 280, ideal: 360)
        } detail: {
            CommitDetail(model: model)
        }
        .navigationTitle(model.repositoryName)
        .navigationSubtitle(model.currentBranch.map { "on \($0.shortName)" } ?? "")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.chooseRepository()
                } label: {
                    Label("Open Repository", systemImage: "folder")
                }
                .help("Open a different git repository")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.load()
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .disabled(model.isLoading)
                .help("Re-read the repository")
            }
        }
    }
}

// MARK: - Sidebar

private struct Sidebar: View {
    @ObservedObject var model: RepositoryViewModel

    var body: some View {
        VStack(spacing: 0) {
            List {
                if let analysis = model.analysis {
                    Section("Repository") {
                        LabeledContent("Commits", value: "\(analysis.totalCommits)")
                        LabeledContent("Contributors", value: "\(analysis.contributors.count)")
                        LabeledContent("Per week", value: String(format: "%.1f", analysis.trends.commitsPerWeek))
                    }
                }

                Section("Branches") {
                    ForEach(model.branches) { branch in
                        HStack(spacing: 6) {
                            Image(systemName: branch.isHead ? "arrow.triangle.branch" : "point.3.filled.connected.trianglepath.dotted")
                                .foregroundStyle(branch.isHead ? Color.accentColor : .secondary)
                                .font(.caption)
                            Text(branch.shortName)
                                .fontWeight(branch.isHead ? .semibold : .regular)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 0)
                            if let status = branch.trackingStatus {
                                Text(status)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                let breakdown = model.intentBreakdown
                if !breakdown.isEmpty {
                    Section("Intent") {
                        ForEach(breakdown) { row in
                            HStack {
                                Circle()
                                    .fill(row.intent.tint)
                                    .frame(width: 7, height: 7)
                                Text(row.intent.label)
                                Spacer(minLength: 0)
                                Text("\(row.count)")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            .font(.callout)
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            // The companion lives down here, reacting to the repository.
            DailyEntityBadge(entity: model.entity)
                .background(.quaternary.opacity(0.4))
        }
    }
}

// MARK: - Commit list

private struct CommitList: View {
    @ObservedObject var model: RepositoryViewModel

    var body: some View {
        Group {
            if model.isLoading && model.commits.isEmpty {
                ProgressView("Reading repository…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let message = model.errorMessage {
                ErrorPane(message: message) { model.chooseRepository() }
            } else if model.commits.isEmpty {
                ContentUnavailableMessage(
                    title: "No commits",
                    detail: "This repository has no history to show yet."
                )
            } else {
                List(model.visibleCommits, selection: $model.selectedCommitID) { commit in
                    CommitRow(commit: commit, intent: model.intent(for: commit))
                }
            }
        }
        .searchable(text: $model.searchText, placement: .toolbar, prompt: "Search commits")
    }
}

private struct CommitRow: View {
    let commit: Commit
    let intent: CommitAnalysis.CommitIntent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(intent.label.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(intent.tint.opacity(0.18), in: Capsule())
                    .foregroundStyle(intent.tint)

                Text(commit.summary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            HStack(spacing: 8) {
                Text(commit.shortHash)
                    .font(.system(size: 10, design: .monospaced))
                Text(commit.author)
                Text(commit.timestamp, style: .date)
                if commit.totalChanges > 0 {
                    Text("\(commit.totalChanges) file\(commit.totalChanges == 1 ? "" : "s")")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Detail

private struct CommitDetail: View {
    @ObservedObject var model: RepositoryViewModel

    var body: some View {
        if let commit = model.selectedCommit {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(commit.summary)
                            .font(.title2.weight(.semibold))
                            .textSelection(.enabled)

                        HStack(spacing: 10) {
                            Label(commit.author, systemImage: "person")
                            Label(commit.timestamp.formatted(date: .abbreviated, time: .shortened),
                                  systemImage: "clock")
                            Label(commit.shortHash, systemImage: "number")
                                .monospaced()
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    let body = commitBody(commit)
                    if !body.isEmpty {
                        Text(body)
                            .font(.callout)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    }

                    if !commit.fileChanges.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(commit.fileChanges.count) file\(commit.fileChanges.count == 1 ? "" : "s") changed")
                                .font(.headline)

                            ForEach(commit.fileChanges) { change in
                                HStack(spacing: 8) {
                                    Text(change.status.rawValue)
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .frame(width: 16)
                                        .foregroundStyle(change.status.tint)
                                    Text(change.path)
                                        .font(.system(size: 11, design: .monospaced))
                                        .lineLimit(1)
                                        .truncationMode(.head)
                                        .textSelection(.enabled)
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                    }

                    if !commit.parentHashes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(commit.parentHashes.count > 1 ? "Parents" : "Parent")
                                .font(.headline)
                            ForEach(commit.parentHashes, id: \.self) { parent in
                                Text(String(parent.prefix(7)))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            ContentUnavailableMessage(
                title: "No commit selected",
                detail: "Pick a commit to see what changed."
            )
        }
    }

    /// Everything after the summary line.
    private func commitBody(_ commit: Commit) -> String {
        commit.message
            .dropFirst(commit.summary.count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Shared

private struct ErrorPane: View {
    let message: String
    let onChoose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Could not read this repository")
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Choose a Repository…", action: onChoose)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A small stand-in for `ContentUnavailableView`, which is macOS 14 only.
private struct ContentUnavailableMessage: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
