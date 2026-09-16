// Sources/TodoCore/Model/Placement.swift

/// Where a created or moved item lands among its siblings. Tasks, tags and the views of Task 9 are all
/// ordered lists of one parent's children, and all three rank a new member the same way.
public enum Placement: Sendable, Equatable {
    case end
    case start
    case after(EntityID)
}
