// Sources/DesignSystem/Font.swift

extension DesignSystem {
    /// A font as the look names it: a text style, whose size follows the one a person sets (Dynamic Type), a weight,
    /// and whether the face is rounded. A platform renders it as its own font of that style.
    ///
    /// The look's fonts are its static members, the canvas's type (`Main.dc.html`) as text styles. At the iPhone's
    /// default text size each is the canvas's size but the large title, 34 pt against 32, and the meta, 12 against
    /// 12.5 (the owner's review of #151); the Mac's text styles are smaller. The large and section titles are the
    /// rounded face; the rest is the system face.
    public struct Font: Equatable, Sendable {
        public enum TextStyle: Sendable { case largeTitle, headline, body, callout, subheadline, footnote, caption }
        public enum Weight: Sendable { case regular, medium, semibold, heavy }
        public let style: TextStyle
        public let weight: Weight
        public let rounded: Bool

        public static let largeTitle = Font(style: .largeTitle, weight: .heavy, rounded: true)
        public static let sectionTitle = Font(style: .headline, weight: .heavy, rounded: true)
        public static let meta = Font(style: .caption, weight: .medium, rounded: false)
        public static let count = Font(style: .subheadline, weight: .regular, rounded: false)

        /// An area's name on its line, the canvas's 13 pt medium at the iPhone's default text size.
        public static let areaLabel = Font(style: .footnote, weight: .medium, rounded: false)

        /// A row's title: the body at the root and the callout nested, 17 and 16 pt at the iPhone's default text size,
        /// semibold when the row has children and regular otherwise. A depth at or below zero reads as the root's, one
        /// comparison and no trap, since a depth a view sends is never trusted.
        public static func rowTitle(depth: Int, hasChildren: Bool) -> Font {
            Font(style: depth > 0 ? .callout : .body, weight: hasChildren ? .semibold : .regular, rounded: false)
        }
    }
}
