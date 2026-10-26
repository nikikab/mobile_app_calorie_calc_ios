import SwiftUI

@main
struct KaloCalcApp: App {
    @State private var model: AppModel

    init() {
        SelectAll.install()
        // `-demo` starts with sample data that is thrown away on exit; the CI uses it for screenshots.
        _model = State(initialValue: ProcessInfo.processInfo.arguments.contains("-demo") ? .demo() : .live())
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}
