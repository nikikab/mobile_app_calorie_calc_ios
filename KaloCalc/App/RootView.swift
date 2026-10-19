import SwiftUI

/// The four tabs of the app, in the same order as on Android.
enum AppTab: CaseIterable {
    case diary, progress, goal, settings

    var title: LocalizedStringKey {
        switch self {
        case .diary: "tab_diary"
        case .progress: "tab_progress"
        case .goal: "tab_goal"
        case .settings: "tab_settings"
        }
    }

    var systemImage: String {
        switch self {
        case .diary: "fork.knife"
        case .progress: "chart.xyaxis.line"
        case .goal: "function"
        case .settings: "gearshape"
        }
    }
}

struct RootView: View {
    @State private var selection: AppTab = .diary

    var body: some View {
        TabView(selection: $selection) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                NavigationStack {
                    TabPlaceholder(title: tab.title)
                }
                .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                .tag(tab)
            }
        }
    }
}

/// Stands in for each screen until it is ported.
private struct TabPlaceholder: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .navigationTitle(title)
    }
}

#Preview {
    RootView()
}
