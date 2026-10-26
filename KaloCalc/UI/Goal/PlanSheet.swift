import SwiftUI
import KaloCalcCore

/// Name, calories and the three gram amounts, each free: the macros don't have to add up to the calories.
struct PlanSheet: View {
    let draft: GoalPlan
    let onConfirm: (GoalPlan) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var kcal: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String

    init(draft: GoalPlan, onConfirm: @escaping (GoalPlan) -> Void) {
        self.draft = draft; self.onConfirm = onConfirm
        _name = State(initialValue: draft.name)
        _kcal = State(initialValue: String(draft.kcal))
        _protein = State(initialValue: String(draft.proteinG))
        _carbs = State(initialValue: String(draft.carbsG))
        _fat = State(initialValue: String(draft.fatG))
    }

    private var candidate: GoalPlan {
        var p = draft
        p.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        p.kcal = Int(kcal) ?? 0; p.proteinG = Int(protein) ?? 0; p.carbsG = Int(carbs) ?? 0; p.fatG = Int(fat) ?? 0
        return p
    }
    private var complete: Bool { [kcal, protein, carbs, fat].allSatisfy { !$0.isEmpty } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(tr("plan_name")) {
                        TextField("", text: $name).multilineTextAlignment(.trailing).selectAllOnFocus()
                    }
                    .onChange(of: name) { _, new in if new.count > maxPlanName { name = String(new.prefix(maxPlanName)) } }
                    field(tr("field_calories"), $kcal, suffix: "kcal")
                }
                Section {
                    field(tr("field_protein_short"), $protein, suffix: tr("unit_g"))
                    field(tr("field_carbs_short"), $carbs, suffix: tr("unit_g"))
                    field(tr("field_fat_short"), $fat, suffix: tr("unit_g"))
                    Text(tr("plan_macros_kcal", candidate.proteinG * 4 + candidate.carbsG * 4 + candidate.fatG * 9))
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(tr(draft.id == 0 && draft.name.isEmpty ? "plan_dialog_new" : "plan_dialog_edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(tr("action_cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("action_save")) { onConfirm(candidate); dismiss() }
                        .disabled(!(complete && candidate.isUsable))
                }
            }
        }
    }

    private func field(_ label: String, _ text: Binding<String>, suffix: String) -> some View {
        LabeledContent(label) {
            HStack {
                TextField("", text: text).keyboardType(.numberPad).multilineTextAlignment(.trailing).digitsOnly(text).selectAllOnFocus()
                Text(suffix).foregroundStyle(.secondary)
            }
        }
    }
}
