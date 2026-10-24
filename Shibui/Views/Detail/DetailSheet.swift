import DesignSystem
import SwiftUI

/// 詳細シート。スワイプと右上の閉じるボタンの両方で閉じられる(脱出性)。
/// 削除だけは破壊的なので朱色で最後に置き、確認を挟む。消したあとはホームで「元に戻す」ができる。
struct DetailSheet: View {
    @Environment(EntryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let entry: Record
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            DSScreen(entry.title) {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text(entry.date, format: .dateTime.year().month().day().hour().minute())
                        .font(.dsCaption)
                        .foregroundStyle(Theme.Palette.secondaryText)
                    StatusLabel("記録済み", kind: .positive)
                }
                .padding(.top, Theme.Spacing.m)

                SectionHeader("メモ")
                Text(entry.note.isEmpty ? "メモはありません" : entry.note)
                    .font(.dsBody)
                    .foregroundStyle(entry.note.isEmpty ? Theme.Palette.secondaryText : Theme.Palette.text)
                    .padding(.top, Theme.Spacing.s)

                SectionHeader("操作")
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("この記録を削除", systemImage: "trash")
                        .foregroundStyle(Theme.Palette.vermilion)
                        .frame(maxWidth: .infinity, minHeight: Theme.Size.minTouch, alignment: .leading)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { CloseButton() }
            }
            .confirmationDialog("この記録を削除しますか?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("削除", role: .destructive) {
                    Haptics.warning()
                    store.delete(entry)
                    dismiss()
                }
            } message: {
                Text("削除したあと、ホームで元に戻せます。")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
