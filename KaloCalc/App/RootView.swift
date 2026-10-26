import SwiftUI

import KaloCalcCore

/// The tabs of the app, in the same order as on Android. Help is not a real tab: picking it opens the how-to guide in
/// the browser and leaves the current tab as it was.
enum AppTab: String, CaseIterable {
    case diary, progress, goal, settings, help

    var title: String {
        switch self {
        case .diary: tr("tab_diary")
        case .progress: tr("tab_progress")
        case .goal: tr("tab_goal")
        case .settings: tr("tab_settings")
        case .help: tr("tab_help")
        }
    }

    var systemImage: String {
        switch self {
        case .diary: "fork.knife"
        case .progress: "chart.xyaxis.line"
        case .goal: "function"
        case .settings: "gearshape"
        case .help: "questionmark.circle"
        }
    }
}

struct RootView: View {
    let model: AppModel
    @State private var selection: AppTab
    @Environment(\.openURL) private var openURL

    /// `-tab goal` and `-sheet entry` (launch arguments) open a given tab and dialog, for screenshots.
    init(model: AppModel) {
        self.model = model
        _selection = State(initialValue: UserDefaults.standard.string(forKey: "tab").flatMap(AppTab.init(rawValue:)) ?? .diary)
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                NavigationStack { content(for: tab) }
                    .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                    .tag(tab)
            }
        }
        .onChange(of: selection) { old, new in
            guard new == .help else { return }
            selection = old
            if let url = URL(string: model.language.helpUrl()) { openURL(url) }
        }
        .environment(\.locale, Locale(identifier: model.language.code))
        .id(model.language)
    }

    @ViewBuilder
    private func content(for tab: AppTab) -> some View {
        let sheet = UserDefaults.standard.string(forKey: "sheet")
        switch tab {
        case .diary: DiaryView(model: model, initialSheet: sheet, onOpenSettings: { selection = .settings })
        case .goal: CalculatorView(model: model, initialSheet: sheet)
        case .settings: SettingsView(model: model, initialSheet: sheet)
        case .progress: ProgressTabView(model: model)
        case .help: Color.clear
        }
    }
}

#Preview {
    RootView(model: .demo())
}
