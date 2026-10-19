import SwiftUI
import KaloCalcCore

private enum DiarySheet: Identifiable {
    case add, edit(FoodEntry), target
    var id: String {
        switch self {
        case .add: "add"
        case .edit(let e): "edit-\(e.id)"
        case .target: "target"
        }
    }
}

struct DiaryView: View {
    @State private var vm: DiaryViewModel
    @State private var sheet: DiarySheet?

    init(model: AppModel, initialSheet: String? = nil) {
        _vm = State(initialValue: DiaryViewModel(model: model))
        _sheet = State(initialValue: initialSheet == "entry" ? .add : initialSheet == "target" ? .target : nil)
    }

    var body: some View {
        List {
            Section {
                AppBrand()
                dayHeader
                SummaryCard(summary: vm.summary, onEditTarget: { sheet = .target })
            }
            ForEach(Meal.allCases, id: \.self) { meal in
                let items = vm.entries(for: meal)
                Section(header: Text(verbatim: "\(meal.label) · \(vm.kcal(for: meal)) kcal")) {
                    ForEach(items, id: \.id) { entry in
                        EntryRow(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture { sheet = .edit(entry) }
                            .swipeActions {
                                Button(role: .destructive) { vm.delete(entry) } label: { Label(tr("action_delete"), systemImage: "trash") }
                            }
                    }
                }
            }
        }
        .navigationTitle(tr("tab_diary"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { sheet = .add } label: { Label(tr("diary_add_food"), systemImage: "plus") }
            }
        }
        .sheet(item: $sheet) { which in
            switch which {
            case .add:
                EntryFormSheet(existing: nil, favorites: vm.favorites, onRemoveFavorite: vm.removeFavorite) { vm.add($0) }
            case .edit(let entry):
                EntryFormSheet(existing: entry, favorites: [], onRemoveFavorite: { _ in }) { vm.update(entry, with: $0) }
            case .target:
                TargetSheet(current: vm.summary.targetKcal, usual: vm.summary.defaultKcal, isCustom: vm.summary.isCustomTarget,
                            onSave: vm.setDayTarget, onReset: vm.clearDayTarget)
            }
        }
        .errorAlert($vm.errorMessage)
        .onAppear { vm.reload() }
    }

    private var dayHeader: some View {
        HStack {
            Button { vm.shiftDay(-1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel(tr("diary_prev_day"))
            Spacer()
            Text(vm.isToday ? tr("diary_today") : vm.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                .font(.title3.bold())
            Spacer()
            Button { vm.shiftDay(1) } label: { Image(systemName: "chevron.right") }
                .accessibilityLabel(tr("diary_next_day"))
        }
        .buttonStyle(.borderless)
    }
}

private struct SummaryCard: View {
    let summary: DaySummary
    let onEditTarget: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(verbatim: "\(summary.kcal) / \(summary.targetKcal) kcal").font(.title2.bold())
                Spacer()
                Button(action: onEditTarget) { Image(systemName: "pencil") }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(tr("diary_target_edit"))
            }
            if summary.isCustomTarget {
                Text(tr("diary_target_custom", summary.defaultKcal)).font(.footnote)
            }
            ProgressView(value: summary.kcalProgress)
            Text(summary.remainingKcal >= 0 ? tr("diary_remaining", summary.remainingKcal) : tr("diary_over", -summary.remainingKcal))
            LabeledBar(label: tr("macro_progress", tr("macro_protein"), Int(summary.proteinG.rounded()), summary.goals.proteinG), value: summary.proteinProgress)
            LabeledBar(label: tr("macro_progress", tr("macro_carbs"), Int(summary.carbsG.rounded()), summary.goals.carbsG), value: summary.carbsProgress)
            LabeledBar(label: tr("macro_progress", tr("macro_fat"), Int(summary.fatG.rounded()), summary.goals.fatG), value: summary.fatProgress)
        }
        .padding(.vertical, 4)
    }
}

private struct EntryRow: View {
    let entry: FoodEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(entry.name)
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            Text(verbatim: "\(entry.kcal) kcal")
        }
    }

    private var detail: String {
        let macros = tr("macro_short", Int(entry.proteinG.rounded()), Int(entry.carbsG.rounded()), Int(entry.fatG.rounded()))
        return entry.grams > 0 ? macros + " · " + tr("entry_grams", Int(entry.grams.rounded())) : macros
    }
}

#Preview {
    NavigationStack { DiaryView(model: .demo()) }
}
