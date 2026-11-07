// Apps/Apple/Sources/TodoAppleUI/ListScreen/WrappingRow.swift
import SwiftUI

/// Views side by side that wrap onto the next line where they run out of width, `spacing` apart on a line and
/// `lineSpacing` apart between lines, each centred up and down on its line, as CSS's `flex-wrap` lays out a row's meta
/// line and a card's pills (`Phone.dc.html`, `.meta` and the pills' row). Every number is its caller's, from a model's
/// style.
struct WrappingRow: Layout {
    let spacing: Double
    let lineSpacing: Double

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return Self.arrangement(of: sizes, in: proposal.width, spacing: spacing, lineSpacing: lineSpacing).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let arrangement = Self.arrangement(of: sizes, in: bounds.width, spacing: spacing, lineSpacing: lineSpacing)
        for (subview, origin) in zip(subviews, arrangement.origins) {
            subview.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    /// Where views of `sizes` stand in `width`, nil for no limit, and how much room they take: each goes on the line it
    /// fits on, a view wider than the width on a line of its own.
    static func arrangement(
        of sizes: [CGSize], in width: CGFloat?, spacing: Double, lineSpacing: Double
    ) -> (origins: [CGPoint], size: CGSize) {
        var lines: [[Int]] = []
        var x: CGFloat = 0
        for (index, size) in sizes.enumerated() {
            if let last = lines.indices.last, width.map({ x + spacing + size.width <= $0 }) ?? true {
                lines[last].append(index)
                x += spacing + size.width
            } else {
                lines.append([index])
                x = size.width
            }
        }
        var origins = [CGPoint](repeating: .zero, count: sizes.count)
        var y: CGFloat = 0
        var widest: CGFloat = 0
        for (number, line) in lines.enumerated() {
            let height = line.map { sizes[$0].height }.max() ?? 0
            var x: CGFloat = 0
            for index in line {
                origins[index] = CGPoint(x: x, y: y + (height - sizes[index].height) / 2)
                x += sizes[index].width + spacing
            }
            widest = max(widest, x - spacing)
            y += height + (number < lines.count - 1 ? lineSpacing : 0)
        }
        return (origins, CGSize(width: widest, height: y))
    }
}
