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
    func includes(entry: LearningEntry, hasMaterialWithoutRecording: Bool) -> Bool {
        switch self {
        case .all: true
        case .photo: entry.source == .photoWriting
        case .needsPractice: hasMaterialWithoutRecording
        case .settled: false  // E7 will replace with real memory-deposit judgment
        }
    }
}

// MARK: - Day grouping

struct EntryDayGroup: Identifiable {
    let date: Date
    let entries: [LearningEntry]

    var id: TimeInterval { date.timeIntervalSince1970 }
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
        settled: 0  // E7
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
