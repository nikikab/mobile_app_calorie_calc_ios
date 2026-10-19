import SwiftUI
import KaloCalcCore

/// Adds a new entry, or edits `existing` when given (then there are no favorites and the button says "Save").
struct EntryFormSheet: View {
    let existing: FoodEntry?
    let favorites: [Favorite]
    let onRemoveFavorite: (Favorite) -> Void
    let onConfirm: (EntryValues) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var meal: Meal
    @State private var name: String
    @State private var grams: String
    @State private var kcal: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String
    @State private var removing: Favorite?

    init(existing: FoodEntry?, favorites: [Favorite], onRemoveFavorite: @escaping (Favorite) -> Void,
         onConfirm: @escaping (EntryValues) -> Void) {
        self.existing = existing
        self.favorites = favorites
        self.onRemoveFavorite = onRemoveFavorite
        self.onConfirm = onConfirm
        _meal = State(initialValue: existing?.meal ?? Meal.now())
        _name = State(initialValue: existing?.name ?? "")
        _grams = State(initialValue: existing.flatMap { $0.grams > 0 ? gramsText($0.grams) : nil } ?? "")
        _kcal = State(initialValue: existing.map { String($0.kcal) } ?? "")
        _protein = State(initialValue: existing.map { gramsText($0.proteinG) } ?? "")
        _carbs = State(initialValue: existing.map { gramsText($0.carbsG) } ?? "")
        _fat = State(initialValue: existing.map { gramsText($0.fatG) } ?? "")
    }

    private var values: EntryValues? {
        parseEntryInput(meal: meal, name: name, grams: grams, kcal: kcal, protein: protein, carbs: carbs, fat: fat)
    }

    var body: some View {
        NavigationStack {
            Form {
                if existing == nil && !favorites.isEmpty {
                    Section(tr("favorites_title")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(favorites, id: \.id) { f in
                                    Button(f.name) { fill(from: f) }
                                        .buttonStyle(.bordered)
                                        .contextMenu { Button(tr("action_remove"), role: .destructive) { removing = f } }
                                }
                            }
                        }
                    }
                }
                Section {
                    Picker("", selection: $meal) {
                        ForEach(Meal.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    TextField(tr("field_name"), text: $name)
                    TextField(tr("field_grams"), text: $grams)
                        .keyboardType(.decimalPad)
                        .onChange(of: grams) { _, text in rescale(to: text) }
                    TextField(tr("field_calories"), text: $kcal)
                        .keyboardType(.numberPad)
                    if let existing, existing.grams > 0 {
                        Text(tr("edit_grams_hint")).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section {
                    TextField(tr("field_protein_short"), text: $protein).keyboardType(.decimalPad)
                    TextField(tr("field_carbs_short"), text: $carbs).keyboardType(.decimalPad)
                    TextField(tr("field_fat_short"), text: $fat).keyboardType(.decimalPad)
                }
            }
            .navigationTitle(tr(existing == nil ? "diary_add_food" : "diary_edit_food"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(tr("action_cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr(existing == nil ? "action_add" : "action_save")) {
                        if let values { onConfirm(values); dismiss() }
                    }
                    .disabled(values == nil)
                }
            }
            .confirmationDialog(tr("favorite_remove_title", removing?.name ?? ""), isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                                titleVisibility: .visible) {
                Button(tr("action_remove"), role: .destructive) {
                    if let f = removing { onRemoveFavorite(f) }
                    removing = nil
                }
            }
        }
    }

    private func fill(from f: Favorite) {
        name = f.name; grams = gramsText(f.grams); kcal = String(f.kcal)
        protein = gramsText(f.proteinG); carbs = gramsText(f.carbsG); fat = gramsText(f.fatG)
    }

    /// With a known original weight the numbers follow the new grams; otherwise the grams are just recorded.
    private func rescale(to text: String) {
        guard let existing, let g = parseDecimal(text), let scaled = existing.scaled(to: g) else { return }
        kcal = String(scaled.kcal)
        protein = gramsText(scaled.proteinG)
        carbs = gramsText(scaled.carbsG)
        fat = gramsText(scaled.fatG)
    }
}
