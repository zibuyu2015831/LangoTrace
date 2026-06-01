public enum PhoneRootTab: String, CaseIterable, Hashable, Identifiable {
    case entries
    case reading
    case practice
    case memory

    public enum Direction {
        case previous
        case next
    }

    public var id: Self {
        self
    }

    public var title: String {
        switch self {
        case .entries:
            "记录"
        case .reading:
            "阅读"
        case .practice:
            "练习"
        case .memory:
            "记忆"
        }
    }

    public func tab(after direction: Direction) -> Self {
        let tabs = Self.allCases
        guard let index = tabs.firstIndex(of: self) else {
            return self
        }

        switch direction {
        case .previous:
            return index > tabs.startIndex ? tabs[tabs.index(before: index)] : self
        case .next:
            let nextIndex = tabs.index(after: index)
            return nextIndex < tabs.endIndex ? tabs[nextIndex] : self
        }
    }

    public func tab(
        horizontalTranslation: Double,
        verticalTranslation: Double,
        threshold: Double = 60
    ) -> Self {
        guard abs(horizontalTranslation) > threshold,
              abs(horizontalTranslation) > abs(verticalTranslation)
        else {
            return self
        }

        return tab(after: horizontalTranslation < 0 ? .next : .previous)
    }
}
