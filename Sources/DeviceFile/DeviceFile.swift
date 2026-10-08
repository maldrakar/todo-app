// Sources/DeviceFile/DeviceFile.swift
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Where an identity a database is written under is kept: in a file beside the database and not in it, since
/// a database carries its identity to every machine it is copied to and a copy is another device (ADR-0005).
///
/// The demo and the Apple app both keep it here, so that they agree on where an identity lives. Which
/// identity a run writes under, and whether an environment variable outranks the file, is each caller's.
public enum DeviceFile {
    /// What the file's name adds to the database's: `todo.sqlite` keeps its identity in `todo.sqlite.device`.
    private static let suffix = ".device"

    /// The identity kept beside the database, or nil when no readable line keeps one there: no file, a
    /// directory, an empty file, or one that cannot be read as UTF-8.
    ///
    /// The first line is the identity, so a file written by hand, which ends in a newline, names the same
    /// device as one written here.
    public static func read(beside database: String) -> String? {
        let kept = try? String(contentsOfFile: database + suffix, encoding: .utf8)
        return kept?.split(whereSeparator: \.isNewline).first.map(String.init)
    }

    /// Writes the identity beside the database.
    ///
    /// The write is not the atomic one, which `FoundationEssentials` on WASI answers with "the requested
    /// operation is not supported" — measured, and the whole wasm32 suite passes without it. This target is
    /// built and tested on the host and on wasm32, and a torn write of a minted identity's 36 bytes costs no
    /// data: what it leaves is a prefix, which the next `read(beside:)` answers as the id the store goes on
    /// under, or an empty file, which it answers as none, so the caller mints another; a prefix of a UUID
    /// names no other device. Either way what was written under the identity is still pushed, because
    /// `own_devices` holds the id the store was opened with whatever the file beside the database ends up
    /// saying.
    public static func keep(_ device: String, beside database: String) throws {
        try device.write(toFile: database + suffix, atomically: false, encoding: .utf8)
    }
}
