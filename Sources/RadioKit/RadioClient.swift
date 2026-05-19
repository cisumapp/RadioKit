import Foundation

/// A unified client for interacting with Radio Browser and Eclipse Radio services.
public actor RadioClient {
    private let session: URLSession
    private let userAgent: String

    // Eclipse Radio State
    private let eclipseBaseURL = "https://radio-six-psi.vercel.app"
    private var eclipseToken: String?

    // Radio Browser State
    private var radioBrowserBaseURL: String = "https://de1.api.radio-browser.info"
    private var discoveredServers: [String] = []

    public init(userAgent: String = "RadioKit/1.0", session: URLSession = .shared) {
        self.userAgent = userAgent
        self.session = session
    }

    // MARK: - Server Discovery (Radio Browser)

    /// Discovers available Radio Browser servers.
    public func discoverServers() async {
        // According to docs, we should do a DNS lookup for all.api.radio-browser.info
        // For simplicity in this implementation, we will use a known reliable list
        // if DNS lookup isn't straightforward in the current environment.
        // However, we can also query the API directly for a list if supported.

        // Let's use the documented ones as a fallback
        let fallbacks = [
            "de1.api.radio-browser.info",
            "at1.api.radio-browser.info",
            "nl1.api.radio-browser.info",
        ]

        discoveredServers = fallbacks.shuffled()
        if let first = discoveredServers.first {
            radioBrowserBaseURL = "https://\(first)"
        }
    }

    // MARK: - Token Management (Eclipse)

    private func ensureEclipseToken() async throws -> String {
        if let token = eclipseToken {
            return token
        }

        let url = URL(string: "\(eclipseBaseURL)/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([String: String]())

        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(EclipseTokenResponse.self, from: data)
        eclipseToken = response.token
        return response.token
    }

    // MARK: - Unified Search

    /// Searches for radio stations or tracks across both services.
    public func search(query: String, limit: Int = 20) async throws -> [RadioStation] {
        async let rbTask = searchRadioBrowser(query: query, limit: limit)
        async let eclipseTask = searchEclipse(query: query, limit: limit)

        let rbResults = await (try? rbTask) ?? []
        let eclipseResults = await (try? eclipseTask) ?? []

        return (rbResults + eclipseResults).sorted { $0.title < $1.title }
    }

    // MARK: - Service Specific Search

    public func searchRadioBrowser(query: String, limit: Int = 20) async throws -> [RadioStation] {
        let endpoint = "\(radioBrowserBaseURL)/json/stations/byname/\(query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")"
        var urlComponents = URLComponents(string: endpoint)!
        urlComponents.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "hidebroken", value: "true"),
            URLQueryItem(name: "order", value: "clickcount"),
            URLQueryItem(name: "reverse", value: "true"),
        ]

        var request = URLRequest(url: urlComponents.url!)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: request)
        let rbStations = try JSONDecoder().decode([RadioBrowserStation].self, from: data)
        return rbStations.map { $0.toUnified() }
    }

    public func searchEclipse(query: String, limit: Int = 20) async throws -> [RadioStation] {
        let token = try await ensureEclipseToken()
        let endpoint = "\(eclipseBaseURL)/u/\(token)/search"
        var urlComponents = URLComponents(string: endpoint)!
        urlComponents.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "\(limit)"),
        ]

        var request = URLRequest(url: urlComponents.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(EclipseSearchResponse.self, from: data)
        return (response.tracks ?? []).map { $0.toUnified(token: token) }
    }

    // MARK: - Stream URL Resolution

    /// Resolves the direct stream URL for a given station.
    public func getStreamURL(for station: RadioStation) async throws -> URL? {
        switch station.service {
        case .radioBrowser:
            // Radio Browser usually provides url_resolved in the search,
            // but we can re-fetch if needed or just return it.
            return station.streamURL

        case .eclipse:
            // Eclipse requires a call to /stream/:id
            let components = station.id.components(separatedBy: "__")
            guard components.count == 2 else { return nil }
            let token = components[0]
            let realID = components[1]

            let endpoint = "\(eclipseBaseURL)/u/\(token)/stream/\(realID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")"
            let url = URL(string: endpoint)!
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let (data, _) = try await session.data(for: request)
            let response = try JSONDecoder().decode(EclipseStreamResponse.self, from: data)
            return response.resolvedURL
        }
    }

    /// Reports a click for a Radio Browser station to help with popularity rankings.
    public func reportClick(for stationUUID: String) async {
        let endpoint = "\(radioBrowserBaseURL)/json/url/\(stationUUID)"
        guard let url = URL(string: endpoint) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        _ = try? await session.data(for: request)
    }

    // MARK: - Eclipse Metadata

    /// Fetches album details and tracks from Eclipse Radio.
    public func getEclipseAlbum(id albumID: String) async throws -> (station: RadioStation, tracks: [RadioStation]) {
        let token = try await ensureEclipseToken()
        let realID = albumID.components(separatedBy: "__").last ?? albumID

        let endpoint = "\(eclipseBaseURL)/u/\(token)/album/\(realID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")"
        let url = URL(string: endpoint)!
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(EclipseAlbumResponse.self, from: data)

        let station = RadioStation(
            id: albumID,
            title: response.title ?? "Unknown Album",
            artist: response.artist,
            artworkURL: URL(string: response.artworkURL ?? ""),
            service: .eclipse
        )

        let tracks = (response.tracks ?? []).map { $0.toUnified(token: token) }
        return (station, tracks)
    }

    /// Fetches artist details, top tracks, and albums from Eclipse Radio.
    public func getEclipseArtist(id artistID: String) async throws -> (name: String, artworkURL: URL?, topTracks: [RadioStation], albums: [RadioStation]) {
        let token = try await ensureEclipseToken()
        let realID = artistID.components(separatedBy: "__").last ?? artistID

        let endpoint = "\(eclipseBaseURL)/u/\(token)/artist/\(realID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")"
        let url = URL(string: endpoint)!
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(EclipseArtistResponse.self, from: data)

        let topTracks = (response.topTracks ?? []).map { $0.toUnified(token: token) }
        let albums = (response.albums ?? []).map { album in
            RadioStation(
                id: "\(token)__\(album.id)",
                title: album.title ?? "Unknown Album",
                artist: album.artist ?? response.name,
                artworkURL: URL(string: album.artworkURL ?? ""),
                service: .eclipse
            )
        }

        return (
            name: response.name ?? "Unknown Artist",
            artworkURL: URL(string: response.artworkURL ?? ""),
            topTracks: topTracks,
            albums: albums
        )
    }
}
