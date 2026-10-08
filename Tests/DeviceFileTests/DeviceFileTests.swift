import Testing
import DeviceFile
import TodoCore
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The file is `<database>.device`, the name the README gives it, so that a database the demo has already
/// written under keeps its identity when the app opens it. Written under `.build/`, the way the demo's tests
/// write, because that is a directory the runner on wasm32 can reach too.
@Test func anIdentityKeptBesideADatabaseIsReadBack() throws {
    let database = ".build/device-file-test-\(EntityID().rawValue).sqlite"
    let device = Store.newDeviceID()
    try DeviceFile.keep(device, beside: database)
    #expect(DeviceFile.read(beside: database) == device)
    #expect(try String(contentsOfFile: database + ".device", encoding: .utf8) == device)
}

/// `echo given > todo.sqlite.device` is how a person writes one, and it ends in a newline.
@Test func aFileWrittenByHandIsReadByItsFirstLine() throws {
    let database = ".build/device-file-test-\(EntityID().rawValue).sqlite"
    try "given\n".write(toFile: database + ".device", atomically: false, encoding: .utf8)
    #expect(DeviceFile.read(beside: database) == "given")
}

@Test func nothingIsReadBesideADatabaseThatHasNoIdentityKept() {
    #expect(DeviceFile.read(beside: ".build/device-file-test-\(EntityID().rawValue).sqlite") == nil)
}
