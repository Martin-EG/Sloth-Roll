import Foundation
import MapKit
import UIKit

/// Opens Apple Maps on the result's place: the best `MKLocalSearch` match, or a plain Maps
/// search for the text when the lookup finds nothing.
@MainActor
final class PlaceAction: ActionPerformer {
    func perform(_ result: ActionResult, assetID: String) async throws -> ActionOutcome {
        // A place card often has the venue name as title and no separate address.
        let query = [result.title, result.location].compactMap(\.self)
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        guard !query.isEmpty else { throw ActionError.missingLocation }

        let name = result.title.isEmpty ? query : result.title
        if let item = await bestMatch(for: query) {
            item.name = name
            guard item.openInMaps() else { throw ActionError.mapsUnavailable }
            Log.actions.info("place_opened via=search")
        } else {
            guard let url = Self.fallbackURL(for: query),
                await UIApplication.shared.open(url)
            else { throw ActionError.mapsUnavailable }
            Log.actions.info("place_opened via=query_url")
        }
        return ActionOutcome(message: "Opened in Maps: \(name)")
    }

    /// `maps://?q=<query>`, which Maps treats as a search.
    static func fallbackURL(for query: String) -> URL? {
        var components = URLComponents()
        components.scheme = ActionsConfig.mapsFallbackScheme
        components.host = ""
        components.queryItems = [URLQueryItem(name: ActionsConfig.mapsFallbackQueryKey, value: query)]
        return components.url
    }

    private func bestMatch(for query: String) async -> MKMapItem? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        do {
            return try await MKLocalSearch(request: request).start().mapItems.first
        } catch {
            // No match is reported as an error too; the query URL still opens Maps.
            Log.actions.info("place_search_empty error=\(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
