import Foundation
import Testing

@testable import SlothRoll

struct PlaceActionTests {
    @Test @MainActor func fallbackURLIsAMapsSearch() throws {
        let url = try #require(PlaceAction.fallbackURL(for: "Teatro del Estado, Xalapa"))

        #expect(url.scheme == "maps")
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        #expect(query == [URLQueryItem(name: "q", value: "Teatro del Estado, Xalapa")])
    }
}
