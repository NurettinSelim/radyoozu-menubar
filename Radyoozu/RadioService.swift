import Foundation

struct SongInfo {
    let title: String
    let isLive: Bool
}

actor RadioService {
    static let shared = RadioService()

    private let stationId = "s3ab6bdcb9"
    private var baseURL: URL {
        URL(string: "https://public.radio.co/stations/\(stationId)/status")!
    }

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.httpMaximumConnectionsPerHost = 1
        return URLSession(configuration: config)
    }()

    private let decoder = JSONDecoder()

    private var lastModified: String?
    private var cachedStatus: RadioStatus?

    func fetchStatus() async throws -> RadioStatus {
        var request = URLRequest(url: baseURL)

        // Send If-Modified-Since for conditional request
        if let lastMod = lastModified {
            request.setValue(lastMod, forHTTPHeaderField: "If-Modified-Since")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RadioError.invalidResponse
        }

        // 304 Not Modified - return cached (no body transfer, no parsing)
        if http.statusCode == 304, let cached = cachedStatus {
            return cached
        }

        guard http.statusCode == 200 else {
            throw RadioError.invalidResponse
        }

        // Store Last-Modified for next request
        lastModified = http.value(forHTTPHeaderField: "Last-Modified")

        let status = try decoder.decode(RadioStatus.self, from: data)
        cachedStatus = status
        return status
    }

    func getCurrentSong() async -> SongInfo {
        do {
            let status = try await fetchStatus()
            if status.status == "offline" {
                return SongInfo(title: "Offline", isLive: false)
            }
            let title = status.currentTrack?.title ?? "No track info"
            return SongInfo(title: title, isLive: status.isLive)
        } catch {
            return SongInfo(title: "Error", isLive: false)
        }
    }
}

enum RadioError: Error {
    case invalidResponse
    case decodingError
}
