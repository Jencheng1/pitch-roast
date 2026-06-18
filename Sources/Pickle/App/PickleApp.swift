import SwiftUI

/// Entry point. There is no standard window — Pickle is a companion. The
/// `AppDelegate` builds the floating companion + panel and sets the app to
/// accessory mode so it lives above the Dock with no Dock icon of its own.
@main
struct PickleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Empty Settings scene keeps SwiftUI happy without opening a window.
        Settings { EmptyView() }
    }
}
