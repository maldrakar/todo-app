/// Fractional order keys: `between(a, b)` returns a key strictly between its arguments without renumbering anything.
///
/// Keys are strings over `0-9a-z`, compared byte-wise, never empty and never ending in `0`, so they behave like
/// fractions in (0, 1): `between` walks the common prefix of its neighbours and appends a midpoint digit.
public enum Rank {
    static let alphabet: [Character] = Array("0123456789abcdefghijklmnopqrstuvwxyz")
    static let base = alphabet.count

    /// The key for the first item of an empty list.
    public static let initial = "i"

    public static func isValid(_ key: String) -> Bool {
        !key.isEmpty && key.last != "0" && key.allSatisfy { alphabet.contains($0) }
    }

    /// `nil` on either side means "no neighbour": the start or the end of the list.
    public static func between(_ lower: String?, _ upper: String?) -> String {
        let a = lower.map(digits) ?? []
        let b = upper.map(digits)
        if let b { precondition(a.lexicographicallyPrecedes(b), "lower \(lower ?? "") must sort before upper \(upper ?? "")") }
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

    private static func digits(_ key: String) -> [Int] {
        precondition(isValid(key), "invalid rank key \(key)")
        return key.map { alphabet.firstIndex(of: $0)! }
    }
}
