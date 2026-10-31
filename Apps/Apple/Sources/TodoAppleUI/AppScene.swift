// Apps/Apple/Sources/TodoAppleUI/AppScene.swift
import AppFeature
import DesignSystemComponents
import SwiftUI
import TaskViewListFeature

/// The app's scene, and the one thing this library exports: its callers from outside are the `@main` of the Mac
/// executable and the `@main` of the iOS app target, whose body is the same one line in each, as the watch's will be
/// (ADR-0008).
///
/// A window group, so that the Mac opens as many windows as are asked for, New Window among them, each made by its own
/// view around a host of its own (`docs/specs/navigation.md`, section 5). On the Mac and on iOS the group's value is
/// the window's route in its text form beside an identity of the window's own, `WindowView.Value`, whose synthesized
/// `Codable` and `Hashable` are what the group asks of its value. The identity is there because equal values bring a
/// window forward instead of opening one (probed 2026-10-20), so Open in New Window mints a new one and opens a window
/// on the view a window shows too (the owner, 2026-10-20). The window's view writes the route back into the value after
/// every change, keeping its identity, and into the scene's storage beside it (`WindowView`). The Mac restores a window
/// from its value (section 7), and so does iOS: on 2026-10-20, in the iOS 26.3 simulator, a scene the system ended in
/// the background was made again from the value its saved state kept, and on the iPad, where a launch connects only the
/// front scene, each other saved scene was made from its own value once its session was activated. The scene's storage
/// is what a window reads when it has no value of its own, the watch's only restoration; a window opened with neither,
/// the first and every New Window, opens the default window, or the route `TODO_ROUTE` named for the first
/// (`TodoApp.makeWindow`). On watchOS the group takes no value, because `WindowGroup(for:)`, `openWindow` and
/// `handlesExternalEvents` are unavailable there (a file typechecked against the watchOS 10 SDK on 2026-10-14), and its
/// one window opens the default window, or the route its scene's storage kept: a departure from the spec's group with a
/// value on every Apple platform, and the scene's one platform condition. The watch is a compile check in this epic
/// (spec section 8).
///
/// The File menu's new items are the app's commands (`NewItemCommands`), which the watch has no menu bar for.
public struct AppScene: Scene {
    public init() {}

    public var body: some Scene {
        #if os(watchOS)
        WindowGroup {
            WindowView(app: TodoApp.shared, value: .constant(nil))
        }
        #else
        WindowGroup("Todo", id: Self.windowGroupID, for: WindowView.Value.self) { $value in
            WindowView(app: TodoApp.shared, value: $value)
        }
        .commands { NewItemCommands() }
        #endif
    }

    /// The window group's identity, by which New Window opens a window of it with no value, as the system's own New
    /// Window did, and which no other place names: Open in New Window opens one by its value's type.
    private static let windowGroupID = "window"
}

#if !os(watchOS)
// The menu bar's commands, which watchOS has none of (`commands` is unavailable there in Xcode 27.1's SDK).
extension AppScene {
    /// The File menu's new items in place of the system's New Window (the controller's ruling on #149's hand check,
    /// 2026-10-31): the items of the "+" menu of the sidebar in the focused window (`AddMenu`), drawn by `MenuItems`
    /// with the module's words, glyphs and keys, New Task ⌘N and New List ⇧⌘N on the Mac; and New Window on ⌥⌘N,
    /// Mail's New Viewer Window's keys, where the platform opens windows beside one another. On the Mac a closed
    /// `Menu`'s items answer no key: by hand on 2026-10-31, with the sidebar's "+" closed, ⌘N opened File ▸ New Window
    /// and ⇧⌘N did nothing, so the keys are the menu bar's, which answers them whatever the window shows, the sidebar
    /// hidden by its button too. With no window focused there is no "+" menu to draw, and its items are absent rather
    /// than disabled: their words are the window's module's, and there is none.
    ///
    /// New Window opens a window of the group by its identity with no value, so that it opens the default window, as
    /// the system's New Window opened it. On iOS the commands are the iPad's menu bar and the list a held ⌘ shows: the
    /// bar with edit mode carries no keys, so New Task, New List and New Area stand there without them, and New Window
    /// where the iPad opens windows beside one another (`supportsMultipleWindows`), never on iPhone.
    struct NewItemCommands: Commands {
        /// The focused window's "+" menu, and nil when no window is focused.
        @FocusedValue(\.addMenu) private var addMenu

        @Environment(\.openWindow) private var openWindow

        /// Whether the app opens windows beside one another: true on the Mac and the iPad, false on iPhone
        /// (`WindowView`).
        @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows

        var body: some Commands {
            CommandGroup(replacing: .newItem) {
                if let addMenu {
                    MenuItems(addMenu.menu, send: addMenu.send)
                }
                if supportsMultipleWindows {
                    Button("New Window") { openWindow(id: AppScene.windowGroupID) }
                        .keyboardShortcut("n", modifiers: [.option, .command])
                }
            }
        }
    }
}
#endif

extension AppScene {
    /// What a window publishes for the menu bar while it is focused (`NewItemCommands`): the menu of its sidebar's "+",
    /// the module's as the window's platform has it (`TaskViewList.Model.addMenu`), and the way an item chosen there
    /// reaches the window's sidebar, as one chosen in the "+" does. Its root publishes it whatever the window's layout,
    /// so that the sidebar's column hidden by its button, or a narrow window's stack, keeps the items (`RootView`).
    struct AddMenu {
        let menu: MenuModel<TaskViewList.UserAction>
        let send: (TaskViewList.UserAction) -> Void

        /// The "+" menu of the window the host stands for, its items' actions sent to the host's sidebar.
        @MainActor
        init(of host: ModuleHost<AppModule>) {
            menu = host.model.taskViewList.addMenu
            send = { host.send(.taskViewList($0)) }
        }
    }
}

extension FocusedValues {
    /// The focused window's "+" menu (`AppScene.AddMenu`), which the menu bar draws, and nil when no window is focused.
    var addMenu: AppScene.AddMenu? {
        get { self[AddMenuKey.self] }
        set { self[AddMenuKey.self] = newValue }
    }

    /// The key the focused window's "+" menu is published under.
    private struct AddMenuKey: FocusedValueKey {
        typealias Value = AppScene.AddMenu
    }
}
