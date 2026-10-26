import SwiftUI

/// Icon-less header with the name and tagline, shown at the top of the first screen.
struct AppBrand: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("KaloCalc").font(.title2.bold())
            Text(tr("app_tagline")).font(.footnote).foregroundStyle(.secondary)
        }
    }
}

/// A labelled progress bar.
struct LabeledBar: View {
    let label: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.footnote)
            ProgressView(value: value)
        }
    }
}

/// Text fields marked with `selectAllOnFocus()` select their whole value when they gain focus, so a number can be typed over.
/// SwiftUI has no API for it: the field's identifier lets one app-wide observer find the UITextField behind it.
enum SelectAll {
    static let identifier = "kalocalc.selectAllOnFocus"
    nonisolated(unsafe) private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true
        NotificationCenter.default.addObserver(forName: UITextField.textDidBeginEditingNotification, object: nil, queue: .main) { note in
            guard let field = note.object as? UITextField, field.accessibilityIdentifier == identifier else { return }
            // The tap that gave focus also places the cursor, so select after it has landed.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { field.selectAll(nil) }
        }
    }
}

extension View {
    func selectAllOnFocus() -> some View { accessibilityIdentifier(SelectAll.identifier) }

    /// Keeps a text field to digits, at most `limit` of them.
    func digitsOnly(_ text: Binding<String>, limit: Int = 5) -> some View {
        onChange(of: text.wrappedValue) { _, new in
            let cleaned = String(new.filter(\.isNumber).prefix(limit))
            if cleaned != new { text.wrappedValue = cleaned }
        }
    }

    func errorAlert(_ message: Binding<String?>) -> some View {
        alert(message.wrappedValue ?? "", isPresented: Binding(get: { message.wrappedValue != nil }, set: { if !$0 { message.wrappedValue = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }
}
