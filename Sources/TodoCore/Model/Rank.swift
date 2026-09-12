/// Fractional order keys: `between(a, b)` returns a key strictly between its arguments without renumbering anything.
///
/// Keys are strings over `0-9a-z`, compared byte-wise, never empty and never ending in `0`, so they behave like
/// fractions in (0, 1): `between` walks the common prefix of its neighbours and appends a midpoint digit.
public enum Rank {
    private static let alphabet: [Character] = Array("0123456789abcdefghijklmnopqrstuvwxyz")
    private static let base = alphabet.count

    /// The key for the first item of an empty list.
    public static let initial = "i"

    public static func isValid(_ key: String) -> Bool {
        !key.isEmpty && key.last != "0" && key.allSatisfy { alphabet.contains($0) }
    }

    /// `nil` on either side means "no neighbour": the start or the end of the list.
    ///
    /// Neighbours come out of the database, so they are whatever a merge or another version of the app wrote:
    /// a key this version would never produce, or a pair that does not increase because two devices appended
    /// to the same list offline and computed the same rank. Such a side is read as no neighbour at all, the
    /// way ADR-0003 ignores a merged parent link it cannot use instead of rejecting it.
    public static func between(_ lower: String?, _ upper: String?) -> String {
        let a = lower.flatMap(digits) ?? []
        let b = upper.flatMap(digits).flatMap { a.lexicographicallyPrecedes($0) ? $0 : nil }
        var result: [Int] = []
        var bounded = b != nil
        var i = 0
        while true {
            let x = i < a.count ? a[i] : 0
            // While `bounded` holds, `result` is the common prefix of `a` and `b`, and `a` sorts before `b`,
            // so `b` has a digit at every position `a` has one, and one more when `a` runs out.
            let y = bounded ? b![i] : base
            if y - x >= 2 {
                result.append((x + y) / 2)
                break
            }
            result.append(x)
            if y == x + 1 { bounded = false }
            i += 1
        }
        return String(result.map { alphabet[$0] })
    }

    private static func digits(_ key: String) -> [Int]? {
        guard isValid(key) else { return nil }
        return key.map { alphabet.firstIndex(of: $0)! }
    }
}
