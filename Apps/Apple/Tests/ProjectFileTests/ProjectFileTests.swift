import Testing
import Foundation
import XcodeProjectFormat

// `Todo.xcodeproj/project.xcproj`, the Xcode project's one file, written by hand in the JSON that Xcode 27 reads, is
// decoded here by Apple's model of the format before Xcode sees it and held to the form Apple's formatter writes, so
// that a hand edit Xcode would refuse, or one the formatter would rewrite, fails in `swift test` (ADR-0008, amended
// 2026-10-14; `docs/specs/navigation.md`, section 9).

/// The file reads as a project, in the format's own model.
@Test func theProjectFileDecodes() throws {
    _ = try decodedProject()
}

/// The shell is one app target and nothing more, its code the library's: the package it links is this one, at the
/// project's own directory, and the product it links is `TodoAppleUI`.
@Test func theProjectHasOneApplicationTargetOverTheLibrary() throws {
    let project = try decodedProject()
    #expect(project.targets.map(\.name) == ["Todo"])
    let target = try #require(project.targets.first).commonProperties
    #expect(target.productTypeID == XCSchema.ProductTypeID(productTypeID: "com.apple.product-type.application"))
    #expect(target.buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] == .string("dev.maldrakar.todo"))
    let thisPackage = XCSchema.SwiftPackage(location: .local(XCSchema.LocalSwiftPackage(path: ".")), traits: [])
    #expect(project.packages == [thisPackage])
    #expect(target.packageProductTargetMembers.map(\.packageProduct.productName) == ["TodoAppleUI"])
}

/// The Info.plist the target names, read where the target finds it, registers the `todo` scheme a link arrives by and
/// allows the iPad more than one scene (`docs/specs/navigation.md`, sections 7 and 9).
@Test func theInfoPlistRegistersTheSchemeAndMultipleScenes() throws {
    let project = try decodedProject()
    let target = try #require(project.targets.first).commonProperties
    guard case .string(let path) = try #require(target.buildSettings["INFOPLIST_FILE"]) else {
        Issue.record("INFOPLIST_FILE is not a single path")
        return
    }
    let data = try Data(contentsOf: packageDirectory.appending(path: path))
    let plist = try PropertyListDecoder().decode(InfoPlist.self, from: data)
    #expect(plist.urlTypes.flatMap(\.schemes) == ["todo"])
    #expect(plist.sceneManifest.supportsMultipleScenes)
}

/// The file is byte for byte what the formatter writes for it, so a reformat never changes it, and the message names
/// the command that does.
@Test func theProjectFileIsCanonical() throws {
    let file = try projectFile()
    let canonical = try XCSchema.Project(jsonRepresentation: file).jsonRepresentation()
    #expect(
        file == canonical,
        """
        project.xcproj is not in the formatter's form; \
        run `swift run xcprojformatter --update Todo.xcodeproj` in Apps/Apple
        """
    )
}

/// `Apps/Apple`, three directories up from this file's own path.
private let packageDirectory = URL(filePath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

private func projectFile() throws -> Data {
    try Data(contentsOf: packageDirectory.appending(path: "Todo.xcodeproj/project.xcproj"))
}

private func decodedProject() throws -> XCSchema.Project {
    try XCSchema.Project(jsonRepresentation: projectFile())
}

/// The two keys of the Info.plist the tests read, under the names the plist spells; a key that is missing or of
/// another type fails the decode with the key's name.
private struct InfoPlist: Decodable {
    let urlTypes: [URLType]
    let sceneManifest: SceneManifest

    struct URLType: Decodable {
        let schemes: [String]

        enum CodingKeys: String, CodingKey {
            case schemes = "CFBundleURLSchemes"
        }
    }

    struct SceneManifest: Decodable {
        let supportsMultipleScenes: Bool

        enum CodingKeys: String, CodingKey {
            case supportsMultipleScenes = "UIApplicationSupportsMultipleScenes"
        }
    }

    enum CodingKeys: String, CodingKey {
        case urlTypes = "CFBundleURLTypes"
        case sceneManifest = "UIApplicationSceneManifest"
    }
}
