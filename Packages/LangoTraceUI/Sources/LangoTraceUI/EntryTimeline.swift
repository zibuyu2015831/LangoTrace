import Foundation
import LangoTraceCore
import LangoTraceData
import SwiftUI

// MARK: - Filter

enum EntryTimelineFilter: CaseIterable, Equatable, Hashable {
    case all
    case photo
    case needsPractice
    case settled

    var titleKey: String {
        switch self {
        case .all: "pad.filter.all"
        case .photo: "entrySource.photoWriting"
        case .needsPractice: "pad.filter.needsPractice"
        case .settled: "filter.settled"
        }
    }

    /// hasMaterialWithoutRecording: caller computes `practiceReadiness[entry.id] == false`
    /// (present in dict = has material, value false = no completed recording yet).
    /// hasPhotoAttachment: caller provides per-entry attachment presence.
    /// hasDepositedMemory: caller computes `depositedEntryIDs.contains(entry.id)` (E7) — an entry
    /// is "settled" once at least one of its memory candidates has been deposited.
    func includes(
        entry: LearningEntry,
        hasMaterialWithoutRecording: Bool,
        hasPhotoAttachment: Bool,
        hasDepositedMemory: Bool = false
    ) -> Bool {
        switch self {
        case .all: true
        case .photo: entry.source == .photoWriting || hasPhotoAttachment
        case .needsPractice: hasMaterialWithoutRecording
        case .settled: hasDepositedMemory
        }
    }
}

// MARK: - Scene facet

/// Scene tags form a facet orthogonal to `EntryTimelineFilter`: both apply
/// with AND semantics. `nil` means "all scenes".
enum EntrySceneFacet {
    /// Distinct non-empty scene values present in `entries`: presets first in
    /// `EntryScenePreset.allCases` order, then free-form values (importable
    /// via the E10 plaintext package) in Unicode code-point order — a
    /// locale-independent, deterministic ordering.
    static func availableScenes(in entries: [LearningEntry]) -> [String] {
        let present = Set(entries.map(\.scene).filter { !$0.isEmpty })
        let presets = EntryScenePreset.allCases.map(\.rawValue).filter(present.contains)
        let freeForm = present
            .filter { EntryScenePreset(rawValue: $0) == nil }
            .sorted { $0.unicodeScalars.lexicographicallyPrecedes($1.unicodeScalars) }
        return presets + freeForm
    }

    static func entriesMatching(scene: String?, in entries: [LearningEntry]) -> [LearningEntry] {
        guard let scene else { return entries }
        return entries.filter { $0.scene == scene }
    }

    /// Per-scene match counts over the *full* entry list — mirroring the iPad
    /// sidebar `matchCount` precedent, each facet reports its standalone hit
    /// count and does not shrink when the other facet narrows the timeline.
    static func counts(in entries: [LearningEntry]) -> [String: Int] {
        entries.reduce(into: [:]) { counts, entry in
            guard !entry.scene.isEmpty else { return }
            counts[entry.scene, default: 0] += 1
        }
    }

    /// Keeps a selection valid against the current entry set: a stale scene
    /// (deleted last entry, switched space) falls back to nil instead of
    /// leaving an unexplained empty timeline.
    static func normalizedSelection(_ selection: String?, in entries: [LearningEntry]) -> String? {
        guard let selection else { return nil }
        return availableScenes(in: entries).contains(selection) ? selection : nil
    }
}

// MARK: - Day grouping

struct EntryDayGroup: Identifiable {
    let date: Date
    let entries: [LearningEntry]

    var id: TimeInterval {
        date.timeIntervalSince1970
    }
}

/// Groups `entries` (already sorted newest-first) into day buckets while preserving order.
/// Returns groups newest-day-first, each group's entries in the original order.
func groupEntriesByDay(_ entries: [LearningEntry], calendar: Calendar = .current) -> [EntryDayGroup] {
    var groups: [EntryDayGroup] = []
    for entry in entries {
        let dayStart = calendar.startOfDay(for: entry.createdAt)
        if let last = groups.last, last.date == dayStart {
            groups[groups.count - 1] = EntryDayGroup(
                date: dayStart,
                entries: last.entries + [entry]
            )
        } else {
            groups.append(EntryDayGroup(date: dayStart, entries: [entry]))
        }
    }
    return groups
}

// MARK: - Counts

struct EntryTimelineCounts {
    let total: Int
    let today: Int
    let photo: Int
    let needsPractice: Int
    let settled: Int
}

/// `practiceReadiness`: entryID → hasCompletedRecording (true = done, false = material but no recording).
/// `today`: reference date for "today" window — pass `Date()` in production, a fixed date in tests.
func timelineCounts(
    entries: [LearningEntry],
    practiceReadiness: [String: Bool],
    today: Date,
    calendar: Calendar = .current
) -> EntryTimelineCounts {
    let todayStart = calendar.startOfDay(for: today)
    var todayCount = 0
    var photoCount = 0
    var needsPracticeCount = 0

    for entry in entries {
        if calendar.startOfDay(for: entry.createdAt) == todayStart {
            todayCount += 1
        }
        if entry.source == .photoWriting {
            photoCount += 1
        }
        if practiceReadiness[entry.id] == false {
            needsPracticeCount += 1
        }
    }

    return EntryTimelineCounts(
        total: entries.count,
        today: todayCount,
        photo: photoCount,
        needsPractice: needsPracticeCount,
        settled: 0 // E7
    )
}

// MARK: - Material status

enum EntryMaterialStatus: Equatable {
    case noMaterial
    case stale(sentenceCount: Int)
    case fresh(sentenceCount: Int)
}

func materialStatus(entry: LearningEntry, rendering: LearningRendering?) -> EntryMaterialStatus {
    guard let rendering else { return .noMaterial }
    let currentHash = LearningMaterialTextHash.sha256(for: entry.body)
    if rendering.sourceEntryBodyHash != currentHash {
        return .stale(sentenceCount: rendering.sentences.count)
    }
    return .fresh(sentenceCount: rendering.sentences.count)
}

// MARK: - Material status pill view

struct EntryMaterialStatusPill: View {
    let entry: LearningEntry
    let rendering: LearningRendering?

    private var status: EntryMaterialStatus {
        materialStatus(entry: entry, rendering: rendering)
    }

    var body: some View {
        switch status {
        case .noMaterial:
            pill(key: "entry.material.status.none", image: "sparkles")
        case .stale:
            pill(key: "entry.material.status.stale", image: "clock.arrow.circlepath")
        case let .fresh(count):
            InlineStatusLabel(
                text: freshLabel(count: count),
                systemImage: "text.book.closed"
            )
        }
    }

    private func pill(key: String, image: String) -> some View {
        InlineStatusLabel(localizedTextKey: key, systemImage: image)
    }

    private func freshLabel(count: Int) -> String {
        String(format: localizedString("entry.material.status.fresh"), count)
    }
}
