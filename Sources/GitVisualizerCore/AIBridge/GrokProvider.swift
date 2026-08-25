import Foundation

public class GrokProvider: AIProvider {
    public let name = "Grok"
    private let apiKey: String?
    private let model: String = "grok-2-1212"
    private let baseURL = "https://api.x.ai/v1"

    public var isConfigured: Bool {
        apiKey != nil && !apiKey!.isEmpty
    }

    public init(apiKey: String?) {
        self.apiKey = apiKey
    }

    public func summarizeChanges(in commit: Commit) async throws -> String {
        guard isConfigured else { return "Grok API not configured" }

        let prompt = """
        Give a quick, witty 1-liner about this git commit:

        Message: \(commit.message)
        Files: \(commit.fileChanges.count)
        +\(commit.linesAdded) -\(commit.linesDeleted)
        """

        return try await callGrokAPI(prompt: prompt)
    }

    public func generateCommitMessage(for changes: [FileChange]) async throws -> String {
        guard isConfigured else { return "" }

        let fileList = changes.map { "\($0.path)" }.joined(separator: ", ")
        let prompt = """
        Quick commit message for: \(fileList)
        """

        return try await callGrokAPI(prompt: prompt)
    }

    public func analyzeCodeHealth(in commits: [Commit]) async throws -> CodeHealthAnalysis {
        guard isConfigured else {
            return CodeHealthAnalysis(score: 0.0)
        }

        let commitCount = commits.count
        let uniqueAuthors = Set(commits.map { $0.author }).count

        let prompt = """
        Quick take on code health:
        \(commitCount) commits, \(uniqueAuthors) contributors
        """

        let response = try await callGrokAPI(prompt: prompt)

        return CodeHealthAnalysis(
            score: Double(min(max(uniqueAuthors, 1) / 5, 1)),
            findings: ["Multi-contributor project"],
            recommendations: ["Keep collaborating!"]
        )
    }

    public func suggestWorkflow(for repository: Repository) async throws -> WorkflowSuggestion {
        guard isConfigured else {
            return WorkflowSuggestion(
                recommendation: "Unable to connect",
                rationale: "Grok API not configured"
            )
        }

        let branchCount = repository.branches.count

        let prompt = """
        Grok's take: repo has \(branchCount) branches.
        What's the vibe? What workflow would mesh?
        """

        let response = try await callGrokAPI(prompt: prompt)

        return WorkflowSuggestion(
            recommendation: response,
            rationale: "Grok's real-time analysis"
        )
    }

    private func callGrokAPI(prompt: String) async throws -> String {
        guard let apiKey = apiKey else {
            throw GrokError.notConfigured
        }

        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "temperature": 0.9,
            "max_tokens": 512
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GrokError.apiError("API request failed")
        }

        if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = jsonResponse["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }

        throw GrokError.invalidResponse
    }

    public enum GrokError: LocalizedError {
        case notConfigured
        case apiError(String)
        case invalidResponse

        public var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Grok API key not configured"
            case .apiError(let message):
                return message
            case .invalidResponse:
                return "Invalid Grok API response"
            }
        }
    }
}
