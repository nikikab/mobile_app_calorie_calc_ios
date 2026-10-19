import SwiftUI
import PhotosUI
import KaloCalcCore

let addGreen = Color(red: 0.122, green: 0.541, blue: 0.298)
let editYellow = Color(red: 1.0, green: 0.788, blue: 0.235)

private enum SearchSheet: Identifiable {
    case manual, edit(FoodEstimate), portion(Product)
    var id: String {
        switch self {
        case .manual: "manual"
        case .edit(let e): "edit-\(e.name)"
        case .portion(let p): "portion-\(p.name)-\(p.brand)"
        }
    }
}

/// Finds food by name, barcode or photo and adds it to the day shown in the diary.
struct FoodSearchView: View {
    let model: AppModel
    let diary: DiaryViewModel
    let onOpenSettings: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var vm: FoodSearchViewModel
    @State private var query = ""
    @State private var meal = Meal.now()
    @State private var sheet: SearchSheet?
    @State private var scanning = false
    @State private var camera: Bool
    @State private var pickedItem: PhotosPickerItem?
    @State private var removingFavorite: Favorite?

    init(model: AppModel, diary: DiaryViewModel, autoCamera: Bool = false, demo: String? = nil, onOpenSettings: @escaping () -> Void) {
        self.model = model
        self.diary = diary
        self.onOpenSettings = onOpenSettings
        let vm = FoodSearchViewModel(model: model)
        if let demo { vm.loadDemo(demo) }
        _vm = State(initialValue: vm)
        _camera = State(initialValue: autoCamera && CameraPicker.isAvailable)
        _sheet = State(initialValue: demo == "manual" ? .manual : demo == "edit" ? vm.estimates.first.map(SearchSheet.edit) : nil)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                actions
                Picker("", selection: $meal) {
                    ForEach(Meal.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                TextField(tr("search_product_name"), text: $query)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onSubmit { vm.search(query) }
                photoSection
                estimatesSection
                favoritesSection
                if vm.loading { ProgressView().frame(maxWidth: .infinity) }
                if let message = vm.message { Text(message).foregroundStyle(.red) }
                ForEach(vm.results.indices, id: \.self) { i in resultRow(vm.results[i]) }
            }
            .padding()
        }
        .navigationTitle(tr("search_title"))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { vm.reset() }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { vm.photoPicked(data) }
                pickedItem = nil
            }
        }
        .fullScreenCover(isPresented: $camera) { CameraPicker { vm.photoTaken($0) }.ignoresSafeArea() }
        .fullScreenCover(isPresented: $scanning) { BarcodeScanner { vm.lookupBarcode($0) } }
        .sheet(item: $sheet) { which in sheetContent(which) }
        .onChange(of: vm.scanned?.name) { _, _ in
            if let p = vm.scanned { sheet = .portion(p) }
        }
        .confirmationDialog(tr("favorite_remove_title", removingFavorite?.name ?? ""),
                            isPresented: Binding(get: { removingFavorite != nil }, set: { if !$0 { removingFavorite = nil } }),
                            titleVisibility: .visible) {
            Button(tr("action_remove"), role: .destructive) {
                if let f = removingFavorite { vm.removeFavorite(f) }
                removingFavorite = nil
            }
        }
    }

    // MARK: Sections

    private var actions: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                actionButton("camera", "diary_take_photo") { camera = true }
                    .disabled(!CameraPicker.isAvailable)
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Label(tr("search_pick_photo"), systemImage: "photo.on.rectangle").frame(maxWidth: .infinity).lineLimit(1)
                }
                .buttonStyle(.bordered)
            }
            HStack(spacing: 8) {
                actionButton("barcode.viewfinder", "search_scan") { scanning = true }
                actionButton("square.and.pencil", "search_add_manually") { sheet = .manual }
            }
        }
    }

    private func actionButton(_ image: String, _ key: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(tr(key), systemImage: image).frame(maxWidth: .infinity).lineLimit(1) }
            .buttonStyle(.bordered)
    }

    @ViewBuilder private var photoSection: some View {
        if let path = vm.pendingPhoto {
            HStack(spacing: 8) {
                PendingPhotoThumb(path: path)
                Text(tr("search_photo_saved")).font(.footnote).frame(maxWidth: .infinity, alignment: .leading)
                Button(tr("action_remove")) { vm.clearPhoto() }
            }
        }
        if !vm.photoLabels.isEmpty {
            Text(tr("search_recognized")).font(.footnote)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(vm.photoLabels, id: \.self) { label in
                        Button(label) { query = label; vm.search(label) }.buttonStyle(.bordered)
                    }
                }
            }
        }
        if vm.pendingPhoto != nil && !vm.geminiConfigured {
            // The photo still gets on-device suggestions, but estimates need the key from Settings.
            VStack(alignment: .leading, spacing: 8) {
                Text(tr("search_need_key"))
                Button { onOpenSettings(); dismiss() } label: { Label(tr("tab_settings"), systemImage: "gearshape") }
                    .buttonStyle(.borderedProminent)
            }
            .padding(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
        }
    }

    @ViewBuilder private var estimatesSection: some View {
        if !vm.estimates.isEmpty {
            Text(tr("search_gemini_estimate")).font(.footnote)
            if vm.estimates.count > 1 {
                // One tap for a whole plate; the per-item buttons below still allow adding or editing one at a time.
                Button {
                    diary.addAll(meal: meal, items: vm.estimates, pendingPhoto: vm.pendingPhoto)
                    dismiss()
                } label: {
                    Text(tr("action_add_all", vm.estimates.count, vm.estimates.reduce(0) { $0 + roundedKcal($1) }))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(addGreen)
            }
            ForEach(vm.estimates.indices, id: \.self) { i in
                let e = vm.estimates[i]
                EstimateCard(estimate: e, onAdd: { add(e) }, onEdit: { sheet = .edit(e) })
            }
        }
    }

    @ViewBuilder private var favoritesSection: some View {
        // Hidden while a photo is being handled, so the new estimate is the only thing offered for adding.
        if !vm.favorites.isEmpty && vm.pendingPhoto == nil {
            Text(tr("favorites_title")).font(.headline)
            ForEach(vm.favorites, id: \.id) { f in
                HStack(spacing: 12) {
                    if let photo = vm.favoritePhotos[f.name] { PhotoThumb(name: photo, photos: model.photos) } else { Color.clear.frame(width: 48, height: 48) }
                    Text(f.name).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
                // Tap adds the favorite as saved; long-press offers to remove it.
                .onTapGesture { add(f.toEstimate()) }
                .onLongPressGesture { removingFavorite = f }
                Divider()
            }
        }
    }

    private func resultRow(_ p: Product) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(p.name)
            Text(([p.brand].filter { !$0.isEmpty }.joined(separator: ", ") + " " + tr("product_kcal100", roundHalfUp(p.kcal100))).trimmingCharacters(in: .whitespaces))
                .font(.footnote).foregroundStyle(.secondary)
            Divider().padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { sheet = .portion(p) }
    }

    // MARK: Sheets and adding

    @ViewBuilder private func sheetContent(_ which: SearchSheet) -> some View {
        switch which {
        case .manual:
            EntryFormSheet(existing: nil, favorites: [], onRemoveFavorite: { _ in }) { v in
                diary.add(v, pendingPhoto: vm.pendingPhoto)
                dismiss()
            }
        case .edit(let estimate):
            EditEstimateSheet(estimate: estimate, meal: $meal, canSaveFavorite: true, search: vm.searchIngredients) { result, favorite in
                if favorite {
                    vm.saveFavorite(FoodEstimate(name: result.name, grams: result.grams, kcal: Double(result.kcal), proteinG: result.proteinG,
                                                 carbsG: result.carbsG, fatG: result.fatG, ingredients: result.ingredients))
                }
                diary.add(EntryValues(meal: meal, name: result.name, grams: result.grams, kcal: result.kcal,
                                      proteinG: result.proteinG, carbsG: result.carbsG, fatG: result.fatG), pendingPhoto: vm.pendingPhoto)
                dismiss()
            }
        case .portion(let product):
            PortionSheet(product: product, onDismiss: { vm.scanned = nil }) { grams in
                let p = product.portion(grams: grams)
                diary.add(EntryValues(meal: meal, name: product.name, grams: grams, kcal: p.kcal,
                                      proteinG: p.proteinG, carbsG: p.carbsG, fatG: p.fatG), pendingPhoto: vm.pendingPhoto)
                vm.scanned = nil
                dismiss()
            }
        }
    }

    private func add(_ e: FoodEstimate) {
        diary.add(EntryValues(meal: meal, name: e.name, grams: e.grams, kcal: roundedKcal(e), proteinG: e.proteinG, carbsG: e.carbsG, fatG: e.fatG),
                  pendingPhoto: vm.pendingPhoto)
        dismiss()
    }

    private func roundedKcal(_ e: FoodEstimate) -> Int { roundHalfUp(e.kcal) }
}

/// A dish with its ingredients and the green Add / yellow Edit buttons.
private struct EstimateCard: View {
    let estimate: FoodEstimate
    let onAdd: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(estimate.name)
                Text(tr("estimate_line", roundHalfUp(estimate.grams), roundHalfUp(estimate.kcal)) + " · "
                     + tr("macro_short", roundHalfUp(estimate.proteinG), roundHalfUp(estimate.carbsG), roundHalfUp(estimate.fatG)))
                    .font(.footnote)
                if estimate.ingredients.count > 1 {
                    ForEach(estimate.ingredients.indices, id: \.self) { i in
                        Text(tr("ingredient_line", estimate.ingredients[i].name, roundHalfUp(estimate.ingredients[i].grams))).font(.footnote)
                    }
                }
            }
            HStack(spacing: 8) {
                // Green: add as is. Yellow: change it first.
                Button(action: onAdd) { Text(tr("action_add")).frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).tint(addGreen)
                Button(action: onEdit) { Text(tr("action_edit")).frame(maxWidth: .infinity).foregroundStyle(Color(white: 0.1)) }
                    .buttonStyle(.borderedProminent).tint(editYellow)
            }
        }
        .padding(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
    }
}
