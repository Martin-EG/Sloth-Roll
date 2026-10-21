import Foundation
import Testing

@testable import SlothRoll

struct DuplicateFinderTests {
    private let finder = DuplicateFinder(threshold: 1)

    private func entry(_ id: String, _ print: [Float], day: Double?) -> DuplicateFinder.Entry {
        .init(id: id, capturedAt: day.map { Date(timeIntervalSince1970: $0 * 86_400) }, featurePrint: print)
    }

    @Test func keepsTheNewestOfEachGroup() {
        let older = finder.olderDuplicates(in: [
            entry("old", [0, 0], day: 1), entry("new", [0, 0.5], day: 3),
            entry("mid", [0.5, 0], day: 2), entry("alone", [10, 10], day: 4),
        ])
        #expect(older == ["old", "mid"])
    }

    @Test func groupsAreTransitive() {
        // a~b and b~c, but a and c are 1.6 apart.
        let older = finder.olderDuplicates(in: [
            entry("a", [0], day: 3), entry("b", [0.8], day: 2), entry("c", [1.6], day: 1),
        ])
        #expect(older == ["b", "c"])
    }

    @Test func unknownDatesCountAsOldest() {
        let older = finder.olderDuplicates(in: [entry("undated", [0], day: nil), entry("dated", [0], day: 1)])
        #expect(older == ["undated"])
    }

    @Test func mismatchedOrEmptyPrintsNeverMatch() {
        #expect(DuplicateFinder.distance([0, 0], [0]) == nil)
        #expect(DuplicateFinder.distance([], []) == nil)
        #expect(finder.olderDuplicates(in: [entry("a", [0, 0], day: 1), entry("b", [0], day: 2)]).isEmpty)
    }

    @Test func distanceIsEuclidean() {
        #expect(DuplicateFinder.distance([0, 0], [3, 4]) == 5)
    }

    @Test func featurePrintRoundTripsThroughData() {
        let print: [Float] = [0.25, -1, 3.5]
        #expect(ImageSignals.featurePrint(from: ImageSignals.data(from: print)) == print)
    }
}
