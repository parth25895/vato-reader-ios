import SwiftUI

struct VatRow: View {
    @Environment(Store.self) private var store
    @Environment(\.palette) private var p
    let v: Vat
    var global = false
    var snippet: String? = nil

    var body: some View {
        let read = store.isRead(v.id)
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(read ? p.cAccent.opacity(0.15) : p.cSurface2).frame(width: 34, height: 34)
                if read {
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(p.cAccent)
                } else {
                    Text(global ? "\(v.c).\(v.n)" : "\(v.n)")
                        .font(.system(size: global ? 10.5 : 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(p.cMuted)
                        .minimumScaleFactor(0.6)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if store.s.fav[v.id] == true { Image(systemName: "star.fill").font(.caption2).foregroundStyle(p.cGold) }
                    Text(v.t).font(Typo.gu(store, 17)).foregroundStyle(p.cInk).multilineTextAlignment(.leading)
                }
                Text(snippet ?? preview(v.x, 110))
                    .font(Typo.gu(store, 14))
                    .foregroundStyle(p.cMuted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 8) {
                    if global { Text("Chapter \(v.c) · Vat \(v.n)").font(.caption2).foregroundStyle(p.cMuted) }
                    if !(store.s.hl[v.id] ?? []).isEmpty { Image(systemName: "highlighter").font(.caption2).foregroundStyle(p.cMuted) }
                    if store.s.notes[v.id] != nil { Image(systemName: "note.text").font(.caption2).foregroundStyle(p.cMuted) }
                    if let r = store.s.read[v.id] { Text("Read \(Day.short(r))").font(.caption2).foregroundStyle(p.cMuted) }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

struct VatsList: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.palette) private var p
    let vats: [Vat]
    var global = false

    var body: some View {
        List {
            ForEach(vats) { v in
                Button { router.open(v.id) } label: { VatRow(v: v, global: global) }
                    .buttonStyle(.plain)
                    .listRowBackground(p.cSurface)
                    .listRowSeparatorTint(p.cLine)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button { store.toggleRead(v.id) } label: {
                            Label(store.isRead(v.id) ? "Unread" : "Read", systemImage: store.isRead(v.id) ? "circle" : "checkmark.circle")
                        }
                        .tint(p.cAccent)
                    }
                    .swipeActions(edge: .trailing) {
                        Button { store.toggleFav(v.id) } label: {
                            Label(store.s.fav[v.id] == true ? "Unsave" : "Save", systemImage: "star")
                        }
                        .tint(p.cGold)
                    }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(p.cBg.ignoresSafeArea())
    }
}

struct ChapterView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.palette) private var p
    let chapterId: Int

    var body: some View {
        let c = store.lib.chapterById[chapterId]
        let es = store.lib.byChapter[chapterId] ?? []
        let r = store.readCount(es)
        VatsList(vats: es)
            .safeAreaInset(edge: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(c?.gu ?? "").font(Typo.gu(store, 24)).foregroundStyle(p.cInk)
                    HStack(spacing: 10) {
                        ProgressRing(value: es.isEmpty ? 0 : Double(r) / Double(es.count), lineWidth: 4).frame(width: 26, height: 26)
                        Text("\(r) of \(es.count) read").font(.subheadline).foregroundStyle(p.cMuted)
                        Spacer()
                        if let nx = store.nextUnread(inChapter: chapterId) {
                            Button("Next unread · \(nx.n)") { router.open(nx.id) }
                                .buttonStyle(SoftButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.bar)
            }
            .navigationTitle(c?.name ?? "")
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct VatListView: View {
    @Environment(Store.self) private var store
    @Environment(\.palette) private var p
    let list: VatList

    var body: some View {
        let vats = list.ids.compactMap { store.lib.vat($0) }
        VatsList(vats: vats, global: true)
            .safeAreaInset(edge: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(list.title).font(Typo.gu(store, 22)).foregroundStyle(p.cInk)
                    Text(list.subtitle).font(.subheadline).foregroundStyle(p.cMuted)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.bar)
            }
            .navigationBarTitleDisplayMode(.inline)
    }
}
