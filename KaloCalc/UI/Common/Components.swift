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

extension View {
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
