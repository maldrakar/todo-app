import Testing
import DesignSystem
import TodoCore

/// The design system names the list colours itself, so that the look knows nothing of the domain, and a platform host
/// reads a view's colour as a list colour by its name with `init(rawValue:)`. The two lists agree because this test
/// holds them together: every colour the store can keep is a list colour, and every list colour is one it can keep.
@Test func theStoreAndTheDesignSystemNameTheSameListColours() {
    for color in TaskViewColor.allCases {
        #expect(DesignSystem.ListColor(rawValue: color.rawValue) != nil, "\(color)")
    }
    for color in DesignSystem.ListColor.allCases {
        #expect(TaskViewColor(rawValue: color.rawValue) != nil, "\(color)")
    }
}
