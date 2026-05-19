import Foundation

/// The source service for a radio station.
public enum RadioService: String, Codable, Sendable {
    case radioBrowser = "Radio Browser"
    case eclipse = "Eclipse Radio"
}

/// A unified model representing a streamable radio station or track.
public struct RadioStation: Identifiable, Codable, Sendable {
    /// Unique identifier for the station.
    public let id: String

    /// The name of the station or track title.
    public let title: String

    /// The artist name (primarily for Eclipse Radio).
    public let artist: String? // Eclipse: t.artist

    /// The album name (primarily for Eclipse Radio).
    public let album: String? // Eclipse: t.album

    /// The direct stream URL if resolved.
    public let streamURL: URL? // RadioBrowser: url_resolved, Eclipse: streamUrl

    /// The homepage or info URL.
    public let infoURL: URL? // RadioBrowser: homepage

    /// The URL for the station's icon or album artwork.
    public let artworkURL: URL? // RadioBrowser: favicon, Eclipse: artworkURL

    /// Tags or genres associated with the station.
    public let tags: [String] // RadioBrowser: tags (split by comma)

    /// The country code (ISO 3166-1 alpha-2).
    public let countryCode: String? // RadioBrowser: countrycode

    /// The bitrate in kbps.
    public let bitrate: Int? // RadioBrowser: bitrate

    /// The audio codec.
    public let codec: String? // RadioBrowser: codec

    /// Indicates if the stream uses HLS.
    public let isHLS: Bool // RadioBrowser: hls == 1

    /// The service this station belongs to.
    public let service: RadioService

    public init(
        id: String,
        title: String,
        artist: String? = nil,
        album: String? = nil,
        streamURL: URL? = nil,
        infoURL: URL? = nil,
        artworkURL: URL? = nil,
        tags: [String] = [],
        countryCode: String? = nil,
        bitrate: Int? = nil,
        codec: String? = nil,
        isHLS: Bool = false,
        service: RadioService
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.streamURL = streamURL
        self.infoURL = infoURL
        self.artworkURL = artworkURL
        self.tags = tags
        self.countryCode = countryCode
        self.bitrate = bitrate
        self.codec = codec
        self.isHLS = isHLS
        self.service = service
    }
}

// MARK: - Internal Decoding Models

struct RadioBrowserStation: Codable {
    let stationuuid: String
    let name: String
    let url: String
    let url_resolved: String
    let homepage: String
    let favicon: String
    let tags: String
    let countrycode: String
    let bitrate: Int
    let codec: String
    let hls: Int

    func toUnified() -> RadioStation {
        RadioStation(
            id: stationuuid,
            title: name,
            streamURL: URL(string: url_resolved),
            infoURL: URL(string: homepage),
            artworkURL: URL(string: favicon),
            tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty },
            countryCode: countrycode,
            bitrate: bitrate,
            codec: codec,
            isHLS: hls == 1,
            service: .radioBrowser
        )
    }
}

struct EclipseTrack: Codable {
    let id: String
    let title: String?
    let artist: String?
    let album: String?
    let duration: Int?
    let artworkURL: String?

    func toUnified(token: String? = nil) -> RadioStation {
        let fullID = token != nil ? "\(token!)__\(id)" : id
        return RadioStation(
            id: fullID,
            title: title ?? "Unknown",
            artist: artist,
            album: album,
            artworkURL: URL(string: artworkURL ?? ""),
            service: .eclipse
        )
    }
}

struct EclipseSearchResponse: Codable {
    let tracks: [EclipseTrack]?
}

struct EclipseTokenResponse: Codable {
    let token: String
}

struct EclipseStreamResponse: Codable {
    let url: String?
    let streamUrl: String?
    let streamURL: String?
    let stream_url: String?

    var resolvedURL: URL? {
        let raw = url ?? streamUrl ?? streamURL ?? stream_url
        return raw != nil ? URL(string: raw!) : nil
    }
}

struct EclipseAlbumResponse: Codable {
    let title: String?
    let artist: String?
    let artworkURL: String?
    let tracks: [EclipseTrack]?
}

struct EclipseArtistResponse: Codable {
    let name: String?
    let artworkURL: String?
    let topTracks: [EclipseTrack]?
    let albums: [EclipseAlbum]?
}

struct EclipseAlbum: Codable {
    let id: String
    let title: String?
    let artist: String?
    let artworkURL: String?
}
