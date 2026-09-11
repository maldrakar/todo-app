import Testing
@testable import SQLiteKit

@Test func linksTheVendoredSQLite() {
    #expect(SQLiteKitSmoke.libraryVersion() == "3.53.4")
}
