# RadioKit 📻

**RadioKit** is a modern Swift package designed for building high-quality radio streaming applications on iOS and macOS. It provides a unified, thread-safe interface for interacting with two powerful radio services: **Radio Browser** and **Eclipse Radio**.

Built with **Swift 6**, **Actors**, and **Async/Await**, it is optimized for performance and safety.

## Features

- 🚀 **Unified Search**: Query multiple radio services simultaneously with a single call.
- 🧵 **Thread-Safe**: Built as a Swift `actor` to handle state management (tokens, server discovery) safely.
- 🌍 **Radio Browser Integration**: Access a community-driven database of 40,000+ stations.
- 🎵 **Eclipse Radio Support**: Stream high-quality tracks and browse album/artist metadata.
- 📱 **Modern Targets**: Strictly supports iOS 17+ and macOS 14+.

## Installation

Add RadioKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/RadioKit.git", from: "1.0.0")
]
```

## Quick Start

### Initialize the Client

```swift
import RadioKit

let client = RadioClient(userAgent: "MyCoolRadioApp/1.0")

// Discover Radio Browser servers for better reliability
await client.discoverServers()
```

### Search for Stations

You can perform a unified search across all supported services:

```swift
let results = try await client.search(query: "Jazz", limit: 20)

for station in results {
    print("Found \(station.title) via \(station.service.rawValue)")
}
```

### Resolve a Stream URL

Stations often require resolution to get the direct streamable URL:

```swift
if let streamURL = try await client.getStreamURL(for: station) {
    // Pass this to AVPlayer or your streaming engine
    print("Streaming from: \(streamURL)")
}
```

### Eclipse Specific Metadata

Eclipse Radio provides rich metadata for albums and artists:

```swift
// Get Artist details
let artist = try await client.getEclipseArtist(id: "artist_id")
print("Artist: \(artist.name)")
print("Top Tracks: \(artist.topTracks.count)")

// Get Album details
let album = try await client.getEclipseAlbum(id: "album_id")
print("Album: \(album.station.title)")
```

## Models

RadioKit uses a unified `RadioStation` model to simplify your UI logic:

| Property | Description | Service |
| :--- | :--- | :--- |
| `id` | Unique identifier | Both |
| `title` | Station or Track name | Both |
| `artist` | Artist name | Eclipse |
| `album` | Album name | Eclipse |
| `streamURL` | Resolved URL | Both |
| `artworkURL` | Icon or Cover Art | Both |
| `tags` | Genres/Tags | Radio Browser |
| `bitrate` | Stream Quality | Radio Browser |
| `service` | Source service | Both |

## Requirements

- iOS 17.0+
- macOS 14.0+
- Swift 6.0+

## License

This project is licensed under the MIT License.
