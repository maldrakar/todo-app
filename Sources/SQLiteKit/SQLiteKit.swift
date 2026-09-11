import CSQLite

/// Replaced by the real wrapper in Task 2. Kept minimal so the package builds.
public enum SQLiteKitSmoke {
    public static func libraryVersion() -> String { String(cString: sqlite3_libversion()) }
}
