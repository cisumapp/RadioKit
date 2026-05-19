import Foundation
@testable import RadioKit
import Testing

@Suite("RadioKit Live Tests")
struct RadioKitTests {
    @Test("Live Search Test")
    func liveSearch() async throws {
        let client = RadioClient()

        print("Discovering servers...")
        await client.discoverServers()

        print("Searching for 'Jazz'...")
        let results = try await client.search(query: "Jazz", limit: 10)

        #expect(!results.isEmpty, "Search should return at least one result")

        for station in results.prefix(5) {
            print("Found station: \(station.title) (Service: \(station.service.rawValue))")
            #expect(!station.title.isEmpty)
        }

        // Verify we have results from both services if possible
        let servicesFound = Set(results.map(\.service))
        print("Services found: \(servicesFound.map(\.rawValue).joined(separator: ", "))")
    }

    @Test("Live Stream URL Resolution Test")
    func liveStreamURL() async throws {
        let client = RadioClient()
        await client.discoverServers()

        // Test Radio Browser Resolution
        print("Testing Radio Browser resolution...")
        let rbResults = try await client.searchRadioBrowser(query: "Classic", limit: 5)
        if let firstRB = rbResults.first {
            let url = try await client.getStreamURL(for: firstRB)
            print("Resolved Radio Browser URL: \(url?.absoluteString ?? "nil")")
            #expect(url != nil, "Should resolve a stream URL for Radio Browser station")
        }

        // Test Eclipse Resolution
        print("Testing Eclipse resolution...")
        let eclipseResults = try await client.searchEclipse(query: "Pop", limit: 5)
        if let firstEclipse = eclipseResults.first {
            let url = try await client.getStreamURL(for: firstEclipse)
            print("Resolved Eclipse URL: \(url?.absoluteString ?? "nil")")
            #expect(url != nil, "Should resolve a stream URL for Eclipse track")
        }
    }
}
