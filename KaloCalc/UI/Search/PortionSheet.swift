import SwiftUI
import KaloCalcCore

/// Asks how much of a product was eaten; the nutrition follows the weight.
struct PortionSheet: View {
    let product: Product
    let onDismiss: () -> Void
    let onConfirm: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var grams = "100"

    private var value: Double? { parseDecimal(grams).flatMap { $0 > 0 ? $0 : nil } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(tr("field_grams")) {
                        TextField("", text: $grams).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    if let g = value {
                        let p = product.portion(grams: g)
                        Text(tr("portion_line", p.kcal) + " · " + tr("macro_short", roundHalfUp(p.proteinG), roundHalfUp(p.carbsG), roundHalfUp(p.fatG)))
                    }
                }
            }
            .navigationTitle(product.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(tr("action_cancel")) { onDismiss(); dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("action_add")) { if let g = value { onConfirm(g) } }.disabled(value == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
