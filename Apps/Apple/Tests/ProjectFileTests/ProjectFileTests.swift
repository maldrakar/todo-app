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

/// The shell is two targets: the app and the walks that drive it (ADR-0008, amended 2026-11-10).
@Test func theProjectHasTheApplicationAndItsUITestBundle() throws {
    #expect(try decodedProject().targets.map(\.name) == ["Todo", "TodoUITests"])
}

/// The app's code is the library's: an application for iPhone and iPad, the package it links is this one, at the
/// project's own directory, and the product it links is `TodoAppleUI`.
@Test func theApplicationTargetLinksTheLibrary() throws {
    let project = try decodedProject()
    let target = try target(named: "Todo", in: project)
    #expect(target.productTypeID == XCSchema.ProductTypeID(productTypeID: "com.apple.product-type.application"))
    #expect(target.buildSettings["SDKROOT"] == .string("iphoneos"))
    #expect(target.buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] == .string("dev.maldrakar.todo"))
    let thisPackage = XCSchema.SwiftPackage(location: .local(XCSchema.LocalSwiftPackage(path: ".")), traits: [])
    #expect(project.packages == [thisPackage])
    #expect(target.packageProductTargetMembers.map(\.packageProduct.productName) == ["TodoAppleUI"])
}

/// The walks are a UI-test bundle hosted by the app and launching it, each target naming its product, which is what
/// lets the scheme `Todo` test them: with no host or no dependency the scheme has no test action, with no products
/// it finds no test bundle, and with no `TEST_TARGET_NAME` the walks have no app to launch (probed 2026-11-10,
/// Xcode 27.1).
@Test func theUITestBundleDrivesTheApplication() throws {
    let project = try decodedProject()
    let walks = try target(named: "TodoUITests", in: project)
    let app = XCSchema.LocalTargetReference(targetName: "Todo")
    #expect(walks.productTypeID == XCSchema.ProductTypeID(productTypeID: "com.apple.product-type.bundle.ui-testing"))
    #expect(walks.testHostTarget == app)
    #expect(walks.dependencies == [.localTarget(app, [])])
    #expect(walks.buildSettings["TEST_TARGET_NAME"] == .string("Todo"))
    #expect(walks.product != nil)
    #expect(try target(named: "Todo", in: project).product != nil)
}

/// No scheme is shared: once one is, Xcode 27.1 takes the UI-test bundle out of the scheme it makes for `Todo`, and
/// `scripts/ui-walks.sh` finds no walk to run (probed 2026-11-10).
@Test func theProjectSharesNoScheme() {
    let schemes = packageDirectory.appending(path: "Todo.xcodeproj/xcshareddata/xcschemes")
    #expect(!FileManager.default.fileExists(atPath: schemes.path(percentEncoded: false)))
}

/// The Info.plist the target names, read where the target finds it, registers the `todo` scheme a link arrives by and
/// allows the iPad more than one scene (`docs/specs/navigation.md`, sections 7 and 9).
@Test func theInfoPlistRegistersTheSchemeAndMultipleScenes() throws {
    let target = try target(named: "Todo", in: decodedProject())
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

private func target(named name: String, in project: XCSchema.Project) throws -> XCSchema.CommonTargetProperties {
    try #require(project.targets.first { $0.name == name }, "no target \(name)").commonProperties
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
