import Foundation

/// Fetches one profile's summary. Protocol-injected so polling logic is
/// testable without the network.
public protocol SummaryFetching: Sendable {
    func fetchSummary(for profile: Profile) async throws -> StatuspageSummary
}

public struct StatuspageClientError: Error, Equatable, Sendable, CustomStringConvertible {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var description: String { message }
}

/// URLSession-backed client for the Statuspage API v2. Redirects are followed
/// (status.anthropic.com → status.claude.com is a live precedent).
public struct StatuspageClient: SummaryFetching {
    private let session: URLSession

    public init(timeout: TimeInterval = 10) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: configuration)
    }

    public func fetchSummary(for profile: Profile) async throws -> StatuspageSummary {
        let (data, response) = try await session.data(from: profile.summaryURL)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw StatuspageClientError("HTTP \(http.statusCode) from \(profile.summaryURL.absoluteString)")
        }
        return try Self.decodeSummary(data)
    }

    /// Pure decode step, separated for tests.
    public static func decodeSummary(_ data: Data) throws -> StatuspageSummary {
        do {
            return try JSONDecoder().decode(StatuspageSummary.self, from: data)
        } catch {
            throw StatuspageClientError("unexpected summary payload: \(error.localizedDescription)")
        }
    }
}

/// Fetch all enabled profiles in parallel and return states in the input
/// order. Failures degrade to `.unknown` per profile; this function never
/// throws — a polling round always yields a complete picture.
public func loadStates(
    profiles: [Profile],
    fetcher: some SummaryFetching
) async -> [ProfileState] {
    let enabled = profiles.filter(\.enabled)
    return await withTaskGroup(of: (Int, ProfileState).self) { group in
        for (index, profile) in enabled.enumerated() {
            group.addTask {
                do {
                    let summary = try await fetcher.fetchSummary(for: profile)
                    return (index, .fetched(profile, summary: summary))
                } catch {
                    return (index, .unreachable(profile, error: "\(error)"))
                }
            }
        }
        var results = [(Int, ProfileState)]()
        for await entry in group { results.append(entry) }
        return results.sorted { $0.0 < $1.0 }.map(\.1)
    }
}
