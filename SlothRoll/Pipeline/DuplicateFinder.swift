import Accelerate
import Foundation

/// Groups near-duplicate screenshots by feature-print distance and says which ones to offer
/// for deletion: everything in a group except its newest.
struct DuplicateFinder: Sendable {
    /// One screenshot to compare.
    struct Entry: Sendable {
        let id: String
        let capturedAt: Date?
        let featurePrint: [Float]
    }

    private let threshold: Float

    /// Two prints closer than `threshold` (Euclidean) are near-duplicates.
    init(threshold: Float = PipelineConfig.duplicateDistanceThreshold) {
        self.threshold = threshold
    }

    /// Off the main actor: the comparison is quadratic in the number of entries.
    @concurrent
    func findOlderDuplicates(in entries: [Entry]) async -> Set<String> {
        olderDuplicates(in: entries)
    }

    /// IDs of every entry that has a newer near-duplicate. Groups are transitive (A~B and
    /// B~C put A, B, C together). Unknown capture dates count as oldest; ties go by ID.
    func olderDuplicates(in entries: [Entry]) -> Set<String> {
        var parent = Array(entries.indices)
        func root(_ index: Int) -> Int {
            var index = index
            while parent[index] != index {
                parent[index] = parent[parent[index]]
                index = parent[index]
            }
            return index
        }

        for first in entries.indices {
            for second in entries.indices where second > first {
                guard
                    let distance = Self.distance(
                        entries[first].featurePrint, entries[second].featurePrint),
                    distance < threshold
                else { continue }
                parent[root(second)] = root(first)
            }
        }

        let groups = Dictionary(grouping: entries.indices, by: root)
        var older: Set<String> = []
        for members in groups.values where members.count > 1 {
            let newestFirst = members.sorted { Self.isNewer(entries[$0], than: entries[$1]) }
            older.formUnion(newestFirst.dropFirst().map { entries[$0].id })
        }
        return older
    }

    /// Euclidean distance, or nil when the prints have different lengths (or are empty).
    static func distance(_ first: [Float], _ second: [Float]) -> Float? {
        guard !first.isEmpty, first.count == second.count else { return nil }
        return vDSP.distanceSquared(first, second).squareRoot()
    }

    private static func isNewer(_ first: Entry, than second: Entry) -> Bool {
        switch (first.capturedAt, second.capturedAt) {
        case let (firstDate?, secondDate?) where firstDate != secondDate: firstDate > secondDate
        case (.some, nil): true
        case (nil, .some): false
        default: first.id > second.id
        }
    }
}
