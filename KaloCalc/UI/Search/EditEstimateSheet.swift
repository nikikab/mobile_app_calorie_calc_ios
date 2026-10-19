import SwiftUI
import KaloCalcCore

/// Lets the user correct a recognized dish before it is added. See `EstimateEditor` for how the fields follow each other.
struct EditEstimateSheet: View {
    let estimate: FoodEstimate
    @Binding var meal: Meal
    let canSaveFavorite: Bool
    let search: (String) async throws -> [Product]
    let onConfirm: (EstimateResult, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var editor: EstimateEditor
    @State private var favorite = false
    @State private var addingIngredient = false

    init(estimate: FoodEstimate, meal: Binding<Meal>, canSaveFavorite: Bool,
         search: @escaping (String) async throws -> [Product], onConfirm: @escaping (EstimateResult, Bool) -> Void) {
        self.estimate = estimate
        _meal = meal
        self.canSaveFavorite = canSaveFavorite
        self.search = search
        self.onConfirm = onConfirm
        _editor = State(initialValue: EstimateEditor(estimate))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("", selection: $meal) { ForEach(Meal.allCases, id: \.self) { Text($0.label).tag($0) } }
                        .pickerStyle(.segmented).labelsHidden()
                    row(tr("field_name"), $editor.name, .default)
                    row(tr("field_grams"), Binding(get: { editor.grams }, set: { editor.changeGrams($0) }), .decimalPad)
                    row(tr("field_calories"), $editor.kcal, .numberPad)
                }
                Section {
                    row(tr("field_protein_short"), $editor.protein, .decimalPad)
                    row(tr("field_carbs_short"), $editor.carbs, .decimalPad)
                    row(tr("field_fat_short"), $editor.fat, .decimalPad)
                }
                if !estimate.ingredients.isEmpty {
                    Section(tr("ingredients_title")) {
                        ForEach(editor.items.indices, id: \.self) { i in
                            HStack {
                                Text(editor.items[i].name).frame(maxWidth: .infinity, alignment: .leading)
                                TextField(tr("field_grams"), text: Binding(get: { editor.ingredientGrams[i] }, set: { editor.changeIngredientGrams(i, $0) }))
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 70)
                                Button { editor.removeIngredient(i) } label: { Image(systemName: "trash") }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel(tr("ingredient_remove"))
                            }
                        }
                        Button(tr("ingredient_add")) { addingIngredient = true }
                    }
                }
                if canSaveFavorite {
                    Section { Toggle(tr("favorite_save"), isOn: $favorite) }
                }
                Section { Text(tr("edit_grams_hint")).font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle(tr("edit_title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(tr("action_cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("action_add")) { if let r = editor.result { onConfirm(r, favorite) } }
                        .disabled(editor.result == nil)
                        .tint(addGreen)
                }
            }
            .sheet(isPresented: $addingIngredient) {
                AddIngredientSheet(search: search) { editor.addIngredient($0) }
            }
        }
    }

    private func row(_ label: String, _ text: Binding<String>, _ keyboard: UIKeyboardType) -> some View {
        LabeledContent(label) { TextField("", text: text).keyboardType(keyboard).multilineTextAlignment(.trailing) }
    }
}

/// Asks for a new ingredient's name, weight and nutrition for that weight. A product found in Open Food Facts fills the
/// name and, from its per-100 g values, the nutrition for whatever grams are typed; the fields stay editable.
struct AddIngredientSheet: View {
    let search: (String) async throws -> [Product]
    let onAdd: (Ingredient) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [Product] = []
    @State private var searching = false
    @State private var message: String?
    @State private var product: Product?
    @State private var name = ""
    @State private var grams = ""
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""

    private var gramsValue: Double? { parseDecimal(grams).flatMap { $0 > 0 ? $0 : nil } }
    private var kcalValue: Double? { parseDecimal(kcal).flatMap { $0 >= 0 ? $0 : nil } }
    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && gramsValue != nil && kcalValue != nil
            && [protein, carbs, fat].allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty || parseDecimal($0) != nil }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField(tr("ingredient_search"), text: $query).submitLabel(.search).onSubmit(runSearch)
                        Button(action: runSearch) { Image(systemName: "magnifyingglass") }
                            .buttonStyle(.borderless).accessibilityLabel(tr("ingredient_search"))
                    }
                    if searching { ProgressView() }
                    if let message { Text(message).font(.footnote).foregroundStyle(.red) }
                    ForEach(results.indices, id: \.self) { i in
                        VStack(alignment: .leading) {
                            Text(results[i].name)
                            Text(([results[i].brand].filter { !$0.isEmpty }.joined(separator: ", ") + " " + tr("product_kcal100", roundHalfUp(results[i].kcal100))).trimmingCharacters(in: .whitespaces))
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { pick(results[i]) }
                    }
                }
                Section {
                    row(tr("field_name"), $name, .default)
                    row(tr("field_grams"), Binding(get: { grams }, set: changeGrams), .decimalPad)
                    row(tr("field_calories"), $kcal, .decimalPad)
                    row(tr("field_protein_short"), $protein, .decimalPad)
                    row(tr("field_carbs_short"), $carbs, .decimalPad)
                    row(tr("field_fat_short"), $fat, .decimalPad)
                    Text(tr(product != nil ? "ingredient_add_hint_off" : "ingredient_add_hint")).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(tr("ingredient_add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(tr("action_cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("action_add")) {
                        if valid, let g = gramsValue, let k = kcalValue {
                            onAdd(Ingredient(name: name.trimmingCharacters(in: .whitespacesAndNewlines), grams: g, kcal: k,
                                             proteinG: parseDecimal(protein) ?? 0, carbsG: parseDecimal(carbs) ?? 0, fatG: parseDecimal(fat) ?? 0))
                            dismiss()
                        }
                    }
                    .disabled(!valid)
                }
            }
        }
    }

    private func row(_ label: String, _ text: Binding<String>, _ keyboard: UIKeyboardType) -> some View {
        LabeledContent(label) { TextField("", text: text).keyboardType(keyboard).multilineTextAlignment(.trailing) }
    }

    /// Fills the nutrition fields for `g` grams of `p`.
    private func fill(from p: Product, grams g: Double) {
        let f = g / 100
        kcal = shownNumber(p.kcal100 * f)
        protein = shownNumber(p.protein100 * f)
        carbs = shownNumber(p.carbs100 * f)
        fat = shownNumber(p.fat100 * f)
    }

    private func changeGrams(_ text: String) {
        grams = text
        if let p = product, let g = parseDecimal(text), g > 0 { fill(from: p, grams: g) }
    }

    private func pick(_ p: Product) {
        product = p
        name = p.name
        if parseDecimal(grams) == nil { grams = "100" }
        fill(from: p, grams: gramsValue ?? 100)
        results = []
    }

    private func runSearch() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !searching else { return }
        searching = true
        message = nil
        Task {
            defer { searching = false }
            do {
                results = Array(try await search(q).prefix(6))
                if results.isEmpty { message = tr("search_none") }
            } catch is CancellationError {
            } catch {
                message = tr("error_prefix", userMessage(for: error))
            }
        }
    }
}
