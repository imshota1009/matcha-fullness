import DesignSystem
import SwiftUI

/// ホーム。主役(今の数)を上に、一覧を中に、主要操作を下部に置く基盤の見本。
struct HomeView: View {
    @Environment(EntryStore.self) private var store
    @State private var selected: Record?
    @State private var stamped = false
    @AppStorage("didOnboard") private var didOnboard = true

    var body: some View {
        DSScreen("Shibui") {
            hero
            SectionHeader("これまでの記録")
            if store.entries.isEmpty {
                EmptyState("まだ記録がありません", message: "下のボタンから、最初のひとつを記録しましょう。", systemImage: "square.and.pencil")
            } else {
                list
            }
        } bottom: {
            VStack(spacing: Theme.Spacing.s) {
                if store.lastDeleted != nil { undoBar }
                PrimaryButton("記録する", systemImage: "plus") { addSample() }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("はじめの説明をもう一度見る", systemImage: "book") { didOnboard = false }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: Theme.Size.minTouch, height: Theme.Size.minTouch)
                }
                .accessibilityLabel("その他")
            }
        }
        .sheet(item: $selected) { entry in
            DetailSheet(entry: entry)
        }
        .animation(.spring(duration: 0.3), value: store.entries)
        .animation(.spring(duration: 0.3), value: store.lastDeleted?.entry)
    }

    private var hero: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("記録の数")
                    .font(.dsCaption)
                    .foregroundStyle(Theme.Palette.secondaryText)
                Text("\(store.entries.count)")
                    .font(.dsHero)
                    .foregroundStyle(Theme.Palette.text)
                    .contentTransition(.numericText())
            }
            Spacer()
            Stamp("済", isStamped: stamped, size: 72)
        }
        .padding(.top, Theme.Spacing.m)
        .accessibilityElement(children: .combine)
    }

    private var list: some View {
        LazyVStack(spacing: 0) {
            ForEach(store.entries) { entry in
                Button { selected = entry } label: {
                    EntryRow(entry: entry)
                }
                .buttonStyle(PressScaleStyle())
                Rectangle().fill(Theme.Palette.separator).frame(height: 1)
            }
        }
    }

    private var undoBar: some View {
        HStack {
            Text("記録を削除しました")
                .font(.dsCaption)
                .foregroundStyle(Theme.Palette.text)
            Spacer()
            Button("元に戻す") {
                Haptics.selection()
                store.undoDelete()
            }
            .font(.dsCaption.weight(.semibold))
            .frame(minHeight: Theme.Size.minTouch)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .background(Theme.Palette.surface, in: .rect(cornerRadius: Theme.Radius.m))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func addSample() {
        let title = MockData.samples.randomElement() ?? "記録"
        store.add(Record(title: title, note: "", date: .now))
        stamped = false
        Task {
            try? await Task.sleep(for: .milliseconds(80))
            stamped = true
            Haptics.success()
        }
    }
}

/// 一覧の1行。押せることが分かるよう右端に山括弧を置く(シグニファイア)。
struct EntryRow: View {
    let entry: Record

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(entry.title)
                    .font(.dsBody)
                    .foregroundStyle(Theme.Palette.text)
                Text(entry.date, format: .relative(presentation: .named))
                    .font(.dsCaption)
                    .foregroundStyle(Theme.Palette.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.Palette.secondaryText)
        }
        .padding(.vertical, Theme.Spacing.m)
        .frame(minHeight: Theme.Size.minTouch)
        .contentShape(.rect)
    }
}

#Preview {
    NavigationStack { HomeView() }
        .environment(EntryStore())
}
