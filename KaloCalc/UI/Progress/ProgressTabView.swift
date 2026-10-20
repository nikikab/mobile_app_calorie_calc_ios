import SwiftUI
import Charts
import KaloCalcCore

struct ProgressTabView: View {
    @State private var vm: ProgressViewModel

    init(model: AppModel) { _vm = State(initialValue: ProgressViewModel(model: model)) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                weightCard
                kcalCard
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(tr("progress_title"))
        .onAppear { vm.reload() }
        .errorAlert($vm.errorMessage)
    }

    private var weightCard: some View {
        card {
            Text(tr("weight_title")).font(.headline)
            HStack {
                TextField(tr("weight_today"), text: $vm.input)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                Button(tr("weight_log")) { vm.logWeight() }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.kg == nil)
            }
            if let trend = vm.trend {
                Chart(vm.weights, id: \.epochDay) { w in
                    LineMark(x: .value("Day", day(w.epochDay), unit: .day), y: .value("kg", w.kg))
                    PointMark(x: .value("Day", day(w.epochDay), unit: .day), y: .value("kg", w.kg))
                }
                .chartYScale(domain: weightDomain)
                .chartXScale(range: .plotDimension(startPadding: 8, endPadding: 24))
                .frame(height: 160)
                Text(weightLine(trend)).font(.footnote).foregroundStyle(.secondary)
            } else {
                Text(tr("progress_none_yet")).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var kcalCard: some View {
        card {
            Text(tr("kcal_chart_title")).font(.headline)
            Chart {
                ForEach(vm.week, id: \.epochDay) { bar in
                    if let kcal = bar.kcal {
                        BarMark(x: .value("Day", day(bar.epochDay), unit: .day), y: .value("kcal", kcal))
                            .foregroundStyle(kcal > vm.targetKcal ? Color.red : Color.accentColor)
                    }
                }
                RuleMark(y: .value("Goal", vm.targetKcal)).foregroundStyle(.secondary)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated).locale(Locale(identifier: AppStrings.language.code)), centered: true)
                }
            }
            .frame(height: 160)
            Text(vm.average.map { tr("kcal_average", $0, vm.targetKcal) } ?? tr("kcal_no_entries"))
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func day(_ epochDay: Int64) -> Date { middayDate(epochDay: epochDay) }

    /// Padded so a flat series still draws mid-chart and the line doesn't touch the edges.
    private var weightDomain: ClosedRange<Double> {
        let values = vm.weights.map(\.kg)
        guard let lo = values.min(), let hi = values.max() else { return 0...1 }
        let pad = max((hi - lo) * 0.1, 0.5)
        return (lo - pad)...(hi + pad)
    }

    private func oneDecimal(_ v: Double) -> String {
        v.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: AppStrings.language.code)))
    }

    private func weightLine(_ t: WeightTrend) -> String {
        var text = tr("weight_last", oneDecimal(t.latest))
        if let change = t.change {
            text += " " + tr("weight_change", change >= 0 ? "+" : "−", oneDecimal(abs(change)), t.count)
        }
        return text
    }
}
