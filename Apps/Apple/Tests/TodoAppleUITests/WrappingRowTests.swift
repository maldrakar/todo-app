import CoreGraphics
import Testing
@testable import TodoAppleUI

/// Views go on one line while they fit, `spacing` apart, and each is centred up and down on its line.
@Test func viewsThatFitStandOnOneLineCentred() {
    let got = WrappingRow.arrangement(
        of: [CGSize(width: 40, height: 20), CGSize(width: 30, height: 10)], in: 100, spacing: 10, lineSpacing: 3
    )
    #expect(got.origins == [CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 5)])
    #expect(got.size == CGSize(width: 80, height: 20))
}

/// A view that does not fit goes on the next line, `lineSpacing` under the tallest of the line before it.
@Test func aViewThatDoesNotFitWrapsToTheNextLine() {
    let got = WrappingRow.arrangement(
        of: [CGSize(width: 60, height: 20), CGSize(width: 60, height: 10)], in: 100, spacing: 10, lineSpacing: 3
    )
    #expect(got.origins == [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 23)])
    #expect(got.size == CGSize(width: 60, height: 33))
}

/// A view exactly as wide as what is left stays on the line, and one wider than the whole width stands on a line of its
/// own and is not dropped.
@Test func aViewThatExactlyFitsStaysAndAWideOneStandsAlone() {
    let exact = WrappingRow.arrangement(
        of: [CGSize(width: 45, height: 10), CGSize(width: 45, height: 10)], in: 100, spacing: 10, lineSpacing: 3
    )
    #expect(exact.origins == [CGPoint(x: 0, y: 0), CGPoint(x: 55, y: 0)])
    let wide = WrappingRow.arrangement(
        of: [CGSize(width: 150, height: 10), CGSize(width: 20, height: 10)], in: 100, spacing: 10, lineSpacing: 3
    )
    #expect(wide.origins == [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 13)])
}

/// With no limit on the width, as a view is asked its ideal size, everything stands on one line; and nothing takes no
/// room.
@Test func noLimitIsOneLineAndNothingTakesNoRoom() {
    let got = WrappingRow.arrangement(
        of: [CGSize(width: 150, height: 10), CGSize(width: 150, height: 10)], in: nil, spacing: 10, lineSpacing: 3
    )
    #expect(got.origins == [CGPoint(x: 0, y: 0), CGPoint(x: 160, y: 0)])
    #expect(WrappingRow.arrangement(of: [], in: 100, spacing: 10, lineSpacing: 3).size == .zero)
}
