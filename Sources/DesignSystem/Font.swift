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
        public enum Weight: Sendable { case regular, medium, semibold, bold, heavy }
        public let style: TextStyle
        public let weight: Weight
        public let rounded: Bool

        public static let largeTitle = Font(style: .largeTitle, weight: .heavy, rounded: true)
        public static let sectionTitle = Font(style: .headline, weight: .heavy, rounded: true)
        public static let meta = Font(style: .caption, weight: .medium, rounded: false)
        public static let count = Font(style: .subheadline, weight: .regular, rounded: false)

        /// An area's name on its line, the canvas's 13 pt medium at the iPhone's default text size.
        public static let areaLabel = Font(style: .footnote, weight: .medium, rounded: false)

        /// A row's title, 17 pt at the iPhone's default text size. Which of the four row titles a row takes is the
        /// choice of the feature module that builds its screen's model.
        public static let rowTitle = Font(style: .body, weight: .regular, rounded: false)

        /// A row's title in semibold, 17 pt at the iPhone's default text size.
        public static let rowTitleEmphasized = Font(style: .body, weight: .semibold, rounded: false)

        /// A nested row's title, 16 pt at the iPhone's default text size.
        public static let nestedRowTitle = Font(style: .callout, weight: .regular, rounded: false)

        /// A nested row's title in semibold, 16 pt at the iPhone's default text size.
        public static let nestedRowTitleEmphasized = Font(style: .callout, weight: .semibold, rounded: false)

        /// A word beside a glyph on a bar, the canvas's 15 pt semibold at the iPhone's default text size.
        public static let barLabel = Font(style: .subheadline, weight: .semibold, rounded: false)

        /// A line under a title that says what to do, 13 pt at the iPhone's default text size.
        public static let hint = Font(style: .footnote, weight: .regular, rounded: false)

        /// A search field's placeholder, 17 pt at the iPhone's default text size.
        public static let search = Font(style: .body, weight: .regular, rounded: false)
    }
}
