public enum PhoneRootTab: String, CaseIterable, Hashable, Identifiable, Sendable {
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
