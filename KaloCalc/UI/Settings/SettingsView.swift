import SwiftUI
import KaloCalcCore

struct SettingsView: View {
    let model: AppModel
    @State private var vm: SettingsViewModel
    @State private var scanning = false
    @State private var addingModel = false
    @Environment(\.openURL) private var openURL

    init(model: AppModel, initialSheet: String? = nil) {
        self.model = model
        let vm = SettingsViewModel(model: model)
        if initialSheet == "report" { vm.loadDemo() }
        _vm = State(initialValue: vm)
        _addingModel = State(initialValue: initialSheet == "model")
    }

    var body: some View {
        Form {
            Section {
                Picker(tr("language_label"), selection: Binding(get: { model.language }, set: { model.setLanguage($0) })) {
                    ForEach(AppLanguage.allCases, id: \.self) { Text("\($0.flag)  \($0.nativeName)").tag($0) }
                }
            }
            Section {
                Text(tr("settings_gemini_intro")).font(.callout)
                keyField
                Button(tr("settings_scan_qr")) { vm.startScan(); scanning = true }
                if vm.scanInvalid {
                    Text(tr("settings_qr_invalid")).font(.footnote).foregroundStyle(.red)
                }
                modelPicker
                HStack {
                    Button(tr("settings_save_key")) { vm.saveKey() }.disabled(!vm.dirty)
                    Spacer()
                    Button(tr("settings_clear_key"), role: .destructive) { vm.clearKey() }.disabled(!vm.canClear)
                }
                .buttonStyle(.bordered)
                Button(vm.testing ? tr("settings_testing") : tr("settings_test")) { Task { await vm.test() } }
                    .disabled(!vm.canTest)
                if let result = vm.testResult {
                    Text(result).font(.footnote).textSelection(.enabled)
                }
                Button(tr("settings_get_key")) {
                    if let url = URL(string: "https://aistudio.google.com/apikey") { openURL(url) }
                }
            } header: {
                Text(tr("settings_gemini_heading"))
            }
            Section {
                Text(tr("settings_notes")).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(tr("settings_title"))
        .fullScreenCover(isPresented: $scanning) {
            BarcodeScanner(formats: [.qr]) { vm.scanned($0) }
        }
        .sheet(isPresented: $addingModel) {
            AddModelSheet(existing: vm.gemini.allModels) { vm.addModel($0) }
        }
    }

    private var keyField: some View {
        HStack {
            Group {
                if vm.keyVisible {
                    TextField(tr("settings_api_key"), text: $vm.key)
                } else {
                    SecureField(tr("settings_api_key"), text: $vm.key)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            Button(vm.keyVisible ? tr("settings_hide") : tr("settings_show")) { vm.keyVisible.toggle() }
                .buttonStyle(.borderless)
        }
    }

    private var modelPicker: some View {
        let g = vm.gemini
        return VStack(alignment: .leading, spacing: 4) {
            Menu {
                ForEach(g.allModels, id: \.self) { name in
                    let custom = !presetGeminiModels.contains(name)
                    Button {
                        vm.selectModel(name)
                    } label: {
                        let title = name == defaultGeminiModel ? tr("model_default_suffix", name) : name
                        if name == g.model { Label(title, systemImage: "checkmark") } else { Text(title) }
                    }
                    if custom {
                        Button(tr("model_remove", name), role: .destructive) { vm.removeModel(name) }
                    }
                }
                Divider()
                Button(tr("model_add_custom"), systemImage: "plus") { addingModel = true }
            } label: {
                LabeledContent(tr("model_label")) {
                    HStack(spacing: 4) { Text(verbatim: g.model); Image(systemName: "chevron.up.chevron.down").font(.caption) }
                }
            }
            Text(g.model == defaultGeminiModel ? tr("model_default") : tr("model_default_value", defaultGeminiModel))
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

private struct AddModelSheet: View {
    let existing: [String]
    let onAdd: (String) -> Void
    @State private var text = ""
    @Environment(\.dismiss) private var dismiss

    private var name: String? { normalizeModelName(text) }
    private var duplicate: Bool { name.map(existing.contains) ?? false }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(tr("model_name_label"), text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    if duplicate {
                        Text(tr("model_duplicate")).foregroundStyle(.red)
                    } else if !text.isEmpty && name == nil {
                        Text(tr("model_invalid_chars")).foregroundStyle(.red)
                    } else {
                        Text(tr("model_hint"))
                    }
                }
            }
            .navigationTitle(tr("model_add_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(tr("action_cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("action_add")) { onAdd(text); dismiss() }.disabled(name == nil || duplicate)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
