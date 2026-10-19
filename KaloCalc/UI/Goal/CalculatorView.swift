import SwiftUI
import KaloCalcCore

private enum GoalSheet: Identifiable {
    case plan(GoalPlan)
    var id: String { switch self { case .plan(let p): "plan-\(p.id)-\(p.name)" } }
}

struct CalculatorView: View {
    @State private var vm: CalculatorViewModel
    @State private var sheet: GoalSheet?
    @State private var deleting: GoalPlan?

    init(model: AppModel, initialSheet: String? = nil) {
        let vm = CalculatorViewModel(model: model)
        _vm = State(initialValue: vm)
        _sheet = State(initialValue: initialSheet == "plan" ? .plan(vm.newPlanDraft()) : nil)
    }

    var body: some View {
        Form {
            Section(tr("calc_sex")) {
                Picker(tr("calc_sex"), selection: $vm.sex) {
                    ForEach(Sex.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            Section {
                HStack {
                    numberField(tr("calc_age"), $vm.age)
                    numberField(tr("calc_height"), $vm.height)
                    numberField(tr("calc_weight"), $vm.weight, decimal: true)
                }
            }
            Section(tr("calc_activity")) {
                Picker(tr("calc_activity"), selection: $vm.activity) {
                    ForEach(ActivityLevel.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            Section(tr("calc_goal")) { goalChoices }
            Section {
                Toggle(isOn: $vm.insulinResistance) {
                    VStack(alignment: .leading) {
                        Text(tr("calc_insulin_resistance"))
                        Text(tr(vm.activePlan == nil ? "calc_insulin_resistance_hint" : "calc_insulin_resistance_hint_custom"))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            Section { resultCard }
            Section {
                Button(tr("calc_save")) { vm.save() }.disabled(vm.parsed == nil)
            }
        }
        .navigationTitle(tr("calc_title"))
        .sheet(item: $sheet) { which in
            switch which {
            case .plan(let draft):
                PlanSheet(draft: draft) { vm.savePlan($0) }
            }
        }
        .confirmationDialog(tr("plan_delete_title"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible, presenting: deleting) { plan in
            Button(tr("action_delete"), role: .destructive) { vm.deletePlan(plan) }
        } message: { plan in
            Text(tr("plan_delete_message", plan.name))
        }
        .errorAlert($vm.errorMessage)
        .onAppear { vm.reload() }
    }

    private func numberField(_ label: String, _ text: Binding<String>, decimal: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, text: text).keyboardType(decimal ? .decimalPad : .numberPad)
        }
    }

    /// The built-in goals and the saved ones side by side; exactly one is selected, and "New goal" adds another.
    private var goalChoices: some View {
        VStack(alignment: .leading, spacing: 8) {
            let savedSelected = vm.plans.contains { $0.id == vm.activePlanId }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(Goal.allCases, id: \.self) { g in
                        chip(g.label, selected: !savedSelected && vm.goal == g) { vm.selectGoal(g) }
                    }
                    ForEach(vm.plans, id: \.id) { p in
                        chip(p.name, selected: p.id == vm.activePlanId) { vm.selectPlan(p.id) }
                    }
                    Button { sheet = .plan(vm.newPlanDraft()) } label: { Label(tr("plan_new"), systemImage: "plus") }
                        .buttonStyle(.bordered)
                }
            }
            if let plan = vm.activePlan {
                let t = plan.scaled(to: vm.currentTarget)
                HStack {
                    Text(tr("plan_summary", t.kcal, t.macros.proteinG, t.macros.carbsG, t.macros.fatG)).font(.subheadline)
                    Spacer()
                    Button { sheet = .plan(copyDraft(of: plan)) } label: { Image(systemName: "doc.on.doc") }
                        .accessibilityLabel(tr("plan_clone"))
                    Button { sheet = .plan(plan.rebased(onTarget: vm.currentTarget)) } label: { Image(systemName: "pencil") }
                        .accessibilityLabel(tr("action_edit"))
                    Button { deleting = plan } label: { Image(systemName: "trash") }
                        .accessibilityLabel(tr("action_delete"))
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func copyDraft(of plan: GoalPlan) -> GoalPlan {
        var draft = plan.rebased(onTarget: vm.currentTarget)
        draft.id = 0
        draft.name = String(tr("plan_copy_name", plan.name).prefix(maxPlanName))
        return draft
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .tint(selected ? .accentColor : .gray)
            .fontWeight(selected ? .semibold : .regular)
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let result = vm.result {
                let t = vm.targets
                Text(verbatim: "\(t.kcal) kcal").font(.largeTitle.bold())
                Text(vm.activePlan.map { tr("calc_active_goal", $0.name) } ?? tr("calc_recommended"))
                Text("BMR: \(result.bmr) kcal · TDEE: \(result.tdee) kcal").font(.footnote)
                Text(tr("calc_macros_line", t.macros.proteinG, t.macros.carbsG, t.macros.fatG))
                Text(tr("calc_weight_follows")).font(.footnote).foregroundStyle(.secondary)
                if vm.insulinResistance {
                    let limits = intakeLimits(targetKcal: t.kcal)
                    Text(tr("calc_limits_line", limits.fiberMinG, limits.freeSugarMaxG)).font(.footnote)
                    Text(tr("calc_medical_note")).font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                Text(tr("calc_invalid"))
            }
        }
    }
}

#Preview {
    NavigationStack { CalculatorView(model: .demo()) }
}
