import SwiftUI
import KaloCalcCore

/// Changes the calorie target of the shown day only; the macros follow in proportion.
struct TargetSheet: View {
    let usual: Int
    let isCustom: Bool
    let onSave: (Int) -> Void
    let onReset: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(current: Int, usual: Int, isCustom: Bool, onSave: @escaping (Int) -> Void, onReset: @escaping () -> Void) {
        self.usual = usual; self.isCustom = isCustom; self.onSave = onSave; self.onReset = onReset
        _text = State(initialValue: String(current))
    }

    private var kcal: Int? { Int(text).flatMap { (1...maxPlanKcal).contains($0) ? $0 : nil } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField(tr("field_calories"), text: $text).keyboardType(.numberPad).digitsOnly($text)
                        Text("kcal").foregroundStyle(.secondary)
                    }
                    Text(tr("diary_target_hint", usual)).font(.footnote).foregroundStyle(.secondary)
                }
                if isCustom {
                    Section {
                        Button(tr("diary_target_reset")) { onReset(); dismiss() }
                    }
                }
            }
            .navigationTitle(tr("diary_target_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(tr("action_cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("action_save")) { if let kcal { onSave(kcal); dismiss() } }.disabled(kcal == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
