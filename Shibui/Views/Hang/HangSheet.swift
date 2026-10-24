import DesignSystem
import SwiftUI

/// 欲しい物を軒下に吊るす。名前・値段・干す長さだけを聞く。
struct HangSheet: View {
    @Environment(KakiStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var priceText = ""
    @State private var period = Period.week
    @AppStorage("lastKind") private var kind = Kaki.Kind.imo
    @FocusState private var focused: Field?

    private enum Field { case name, price }

    enum Period: CaseIterable, Identifiable {
        case trial, threeDays, week, month
        var id: Self { self }
        var label: String {
            switch self {
            case .trial: "1分"
            case .threeDays: "3日"
            case .week: "7日"
            case .month: "30日"
            }
        }
        var seconds: TimeInterval {
            switch self {
            case .trial: 60
            case .threeDays: 3 * 86_400
            case .week: 7 * 86_400
            case .month: 30 * 86_400
            }
        }
    }

    private var price: Int? { Int(priceText.filter(\.isNumber)) }
    private var canHang: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && (price ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            DSScreen("吊るす") {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    SectionHeader("欲しい物")
                    TextField("例: ワイヤレスイヤホン", text: $name)
                        .font(.dsBody)
                        .focused($focused, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focused = .price }
                        .frame(minHeight: Theme.Size.minTouch)

                    SectionHeader("値段")
                    HStack {
                        Text("¥").foregroundStyle(Theme.Palette.secondaryText)
                        TextField("例: 24800", text: $priceText)
                            .keyboardType(.numberPad)
                            .focused($focused, equals: .price)
                    }
                    .font(.dsBody)
                    .frame(minHeight: Theme.Size.minTouch)

                    SectionHeader("何として干す?")
                    HStack(spacing: Theme.Spacing.s) {
                        ForEach(Kaki.Kind.allCases) { k in
                            Button {
                                Haptics.selection()
                                kind = k
                            } label: {
                                VStack(spacing: Theme.Spacing.xs) {
                                    DryView(kind: k, ripeness: 1, size: 44)
                                    Text(k.label)
                                        .font(.dsCaption.weight(.semibold))
                                        .foregroundStyle(Theme.Palette.text)
                                }
                                .frame(maxWidth: .infinity, minHeight: 88)
                                .background(kind == k ? Theme.Palette.surface : .clear, in: .rect(cornerRadius: Theme.Radius.m))
                                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m)
                                    .strokeBorder(kind == k ? Theme.Palette.text : Theme.Palette.separator, lineWidth: kind == k ? 1.5 : 1))
                                .contentShape(.rect)
                            }
                            .buttonStyle(PressScaleStyle())
                            .accessibilityAddTraits(kind == k ? .isSelected : [])
                        }
                    }
                    .padding(.top, Theme.Spacing.s)

                    SectionHeader("干す長さ")
                    Picker("干す長さ", selection: $period) {
                        ForEach(Period.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, Theme.Spacing.s)
                    Text("この間は買わずに待ちます。食べごろになったら、本当に欲しいかを決めます。")
                        .font(.dsCaption)
                        .foregroundStyle(Theme.Palette.secondaryText)
                        .padding(.top, Theme.Spacing.xs)
                }
            } bottom: {
                PrimaryButton("軒下に吊るす", systemImage: "arrow.down.to.line") { hang() }
                    .disabled(!canHang)
                    .opacity(canHang ? 1 : 0.4)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { CloseButton() }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { focused = .name }
    }

    private func hang() {
        guard canHang, let price else { return }
        Notifier.requestPermission()
        store.hang(name: name.trimmingCharacters(in: .whitespaces), price: price, dryingSeconds: period.seconds, kind: kind)
        Haptics.success()
        dismiss()
    }
}
