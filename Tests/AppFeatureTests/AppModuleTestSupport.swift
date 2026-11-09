import AppFeature
import FeatureModule
import TodoCore

// The helpers the target's test files share: one shape for making a window's root and reading what stands in it
// (`docs/style.md`, "One shape everywhere it fits").

let inbox = BuiltInTaskViews.inbox

/// What iPhone's window offers: no window beside it, and edit mode, which every test not about the platform makes its
/// root with.
let iPhone = WindowCapabilities(opensWindowsBeside: false, hasEditMode: true)

/// A view that lists the tasks carrying one tag, with its tag, so that a test can put a task in it.
func taggedView(_ title: String, in store: Store) throws -> (view: ViewID, tag: TagID) {
    let tag = try store.createTag(title: title.lowercased())
    return (try store.createView(NewTaskView(title: title, filter: .hasTag(tag))), tag)
}

/// The ids of the screens standing over the sidebar, bottom up, whichever the layout: narrow, the one path; wide, the
/// column, when a screen stands there, and the path over it (navigation state spec, section 4). The one place a test
/// reads the layout for what stands, so that a test of something else holds in either width.
func idsOverTheSidebar(in model: AppModule.Model) -> [StackElementID] {
    switch model.layout {
    case .narrow(let path): path
    case .wide(let column?, let path): [column] + path
    case .wide(nil, let path): path
    }
}
