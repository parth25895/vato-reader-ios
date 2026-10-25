import SwiftUI

// MARK: - Search

struct SearchHit: Identifiable {
    let vat: Vat
    let snippet: String
    var id: String { vat.id }
}

struct SearchView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.palette) private var p
    @State private var query = ""
    @State private var scope = 0
    @State private var results: [SearchHit] = []
    @State private var total = 0

    private let scopes = ["All", "Title", "Text", "Notes"]

    var body: some View {
        NavigationStack {
            List {
                if query.trimmingCharacters(in: .whitespaces).count < 2 {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: "text.magnifyingglass").font(.system(size: 30, weight: .light)).foregroundStyle(p.cGold)
                            Text("Search all 3,825 vato").font(Typo.title).foregroundStyle(p.cInk)
                            Text("Type in Gujarati or in English letters. Titles, text and your own notes are searched.")
                                .font(.subheadline).foregroundStyle(p.cMuted)
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section {
                        ForEach(results) { r in
                            Button { router.open(r.vat.id) } label: { VatRow(v: r.vat, global: true, snippet: r.snippet) }
                                .buttonStyle(.plain)
                                .listRowBackground(p.cSurface)
                        }
                    } header: {
                        Text(total == 0 ? "No matches" : total > results.count ? "Showing \(results.count) of \(total)" : "\(total) match" + (total == 1 ? "" : "es"))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(p.cBg.ignoresSafeArea())
            .navigationTitle("Search")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search vato")
            .safeAreaInset(edge: .top) {
                Picker("Scope", selection: $scope) {
                    ForEach(scopes.indices, id: \.self) { Text(scopes[$0]).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 18)
                .padding(.bottom, 6)
            }
            .task(id: "\(query)|\(scope)") {
                try? await Task.sleep(nanoseconds: 180_000_000)
                if Task.isCancelled { return }
                run()
            }
        }
    }

    private func run() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { results = []; total = 0; return }
        var out: [SearchHit] = []
        var n = 0
        let opts: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        for e in store.lib.entries {
            var hit: String? = nil
            if scope == 0 || scope == 1 {
                if e.t.range(of: q, options: opts) != nil || e.r.range(of: q, options: opts) != nil { hit = preview(e.x, 110) }
            }
            if hit == nil && (scope == 0 || scope == 2), let r = e.x.range(of: q, options: opts) {
                hit = snippetAround(e.x, r)
            }
            if hit == nil && (scope == 0 || scope == 3), let note = store.s.notes[e.id], let r = note.range(of: q, options: opts) {
                hit = "Note: " + snippetAround(note, r)
            }
            if let h = hit {
                n += 1
                if out.count < 300 { out.append(SearchHit(vat: e, snippet: h)) }
            }
        }
        results = out
        total = n
    }

    private func snippetAround(_ s: String, _ r: Range<String.Index>) -> String {
        let start = s.index(r.lowerBound, offsetBy: -40, limitedBy: s.startIndex) ?? s.startIndex
        let end = s.index(r.upperBound, offsetBy: 80, limitedBy: s.endIndex) ?? s.endIndex
        let core = s[start..<end].replacingOccurrences(of: "\n", with: " ")
        return (start > s.startIndex ? "…" : "") + core + (end < s.endIndex ? "…" : "")
    }
}

// MARK: - Saved

struct ReviewItem: Identifiable {
    enum Kind { case highlight, note, bookmark }
    let id = UUID()
    let kind: Kind
    let vat: Vat
    let off: Int
    let text: String
    let color: String
}

@MainActor
func reviewItems(_ store: Store) -> [ReviewItem] {
    var out: [ReviewItem] = []
    for e in store.lib.entries {
        let ns = e.x as NSString
        for h in (store.s.hl[e.id] ?? []).sorted(by: { $0.s < $1.s }) {
            let s = max(0, min(ns.length, h.s)), en = max(s, min(ns.length, h.e))
            out.append(ReviewItem(kind: .highlight, vat: e, off: s, text: ns.substring(with: NSRange(location: s, length: en - s)), color: h.c))
        }
        if let n = store.s.notes[e.id] { out.append(ReviewItem(kind: .note, vat: e, off: 0, text: n, color: "")) }
    }
    for b in store.s.bm {
        if let e = store.lib.vat(b.id) {
            let ns = e.x as NSString
            let s = max(0, min(ns.length, b.off))
            out.append(ReviewItem(kind: .bookmark, vat: e, off: s, text: ns.substring(with: NSRange(location: s, length: min(260, ns.length - s))), color: ""))
        }
    }
    return out
}

struct SavedView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.palette) private var p
    @State private var tab = 0

    var body: some View {
        let items = reviewItems(store)
        NavigationStack {
            List {
                Section {
                    Picker("Saved", selection: $tab) {
                        Text("Favourites").tag(0)
                        Text("Highlights").tag(1)
                        Text("Notes").tag(2)
                        Text("Bookmarks").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    if !items.isEmpty {
                        Button { router.review = true } label: {
                            HStack {
                                Image(systemName: "rectangle.stack")
                                Text("Review one by one")
                                Spacer()
                                Text("\(items.count)").foregroundStyle(p.cMuted)
                            }
                            .font(.body.weight(.semibold))
                            .foregroundStyle(p.cAccent)
                        }
                        .listRowBackground(p.cSurface)
                    }
                }
                Section { content(items) }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(p.cBg.ignoresSafeArea())
            .navigationTitle("Saved")
        }
    }

    @ViewBuilder
    private func content(_ items: [ReviewItem]) -> some View {
        switch tab {
        case 0:
            let favs = store.lib.entries.filter { store.s.fav[$0.id] == true }
            if favs.isEmpty { empty("Tap the star on any vat to keep it here.") }
            ForEach(favs) { v in
                Button { router.open(v.id) } label: { VatRow(v: v, global: true) }
                    .buttonStyle(.plain).listRowBackground(p.cSurface)
            }
        case 1:
            let hs = items.filter { $0.kind == .highlight }
            if hs.isEmpty { empty("Select text in a vat and choose a colour to highlight it.") }
            ForEach(hs) { x in
                Button { router.open(x.vat.id, off: x.off) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(x.text)
                            .font(Typo.gu(store, 16))
                            .foregroundStyle(p.cInk)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color(uiColor: p.hlColor(x.color))))
                            .lineLimit(5)
                        Text("\(x.vat.c).\(x.vat.n) · \(x.vat.t)").font(.caption).foregroundStyle(p.cMuted).lineLimit(1)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain).listRowBackground(p.cSurface)
            }
        case 2:
            let ns = items.filter { $0.kind == .note }
            if ns.isEmpty { empty("Open Tags & notes in any vat to write a note.") }
            ForEach(ns) { x in
                Button { router.open(x.vat.id) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(x.text).font(.body).foregroundStyle(p.cInk).lineLimit(5)
                        Text("\(x.vat.c).\(x.vat.n) · \(x.vat.t)").font(.caption).foregroundStyle(p.cMuted).lineLimit(1)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain).listRowBackground(p.cSurface)
            }
        default:
            let bs = store.s.bm.sorted { $0.t > $1.t }
            if bs.isEmpty { empty("In a vat, choose Bookmark this line, or select text and tap Bookmark.") }
            ForEach(bs, id: \.key) { b in
                if let v = store.lib.vat(b.id) {
                    let ns = v.x as NSString
                    let s = max(0, min(ns.length, b.off))
                    Button { router.open(v.id, off: s) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(preview(ns.substring(from: s), 140)).font(Typo.gu(store, 16)).foregroundStyle(p.cInk).lineLimit(3)
                            Text("\(v.c).\(v.n) · \(v.t) · \(Day.short(Day.key(Date(timeIntervalSince1970: b.t / 1000))))")
                                .font(.caption).foregroundStyle(p.cMuted).lineLimit(1)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(p.cSurface)
                    .swipeActions { Button(role: .destructive) { store.removeBookmark(b) } label: { Label("Remove", systemImage: "trash") } }
                }
            }
        }
    }

    private func empty(_ t: String) -> some View {
        Text(t).font(.subheadline).foregroundStyle(p.cMuted).padding(.vertical, 10).listRowBackground(p.cSurface)
    }
}

// MARK: - Review deck

struct ReviewDeckView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.palette) private var p
    @State private var deck: [ReviewItem] = []
    @State private var page = 0

    var body: some View {
        ZStack {
            p.cBg.ignoresSafeArea()
            VStack(spacing: 14) {
                HStack {
                    Button { router.review = false } label: {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).foregroundStyle(p.cInk)
                            .frame(width: 40, height: 40).background(.ultraThinMaterial, in: Circle())
                    }
                    Spacer()
                    Text(deck.isEmpty ? "" : "\(page + 1) of \(deck.count)").font(.subheadline.monospacedDigit()).foregroundStyle(p.cMuted)
                    Spacer()
                    Button { deck.shuffle(); page = 0 } label: {
                        Image(systemName: "shuffle").font(.system(size: 15, weight: .semibold)).foregroundStyle(p.cInk)
                            .frame(width: 40, height: 40).background(.ultraThinMaterial, in: Circle())
                    }
                }
                .padding(.horizontal, 18)
                if deck.isEmpty {
                    Spacer()
                    Text("Nothing to review yet.").foregroundStyle(p.cMuted)
                    Spacer()
                } else {
                    TabView(selection: $page) {
                        ForEach(deck.indices, id: \.self) { i in
                            card(deck[i]).padding(.horizontal, 18).tag(i)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    Button {
                        let x = deck[page]
                        router.review = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { router.open(x.vat.id, off: x.off) }
                    } label: {
                        Label("Open in vat", systemImage: "book").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 18)
                    .padding(.bottom, 10)
                }
            }
        }
        .onAppear { deck = reviewItems(store).shuffled() }
    }

    private func card(_ x: ReviewItem) -> some View {
        let label = x.kind == .highlight ? "Highlight" : x.kind == .note ? "Note" : "Bookmark"
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Eyebrow(label)
                    Spacer()
                    Text("\(x.vat.c).\(x.vat.n)").font(.caption.monospacedDigit()).foregroundStyle(p.cMuted)
                }
                if x.kind == .note {
                    Text(x.text).font(.system(size: 20, design: .serif)).foregroundStyle(p.cInk).lineSpacing(6)
                } else {
                    Text(x.text)
                        .font(Typo.gu(store, CGFloat(store.s.size)))
                        .lineSpacing(10)
                        .foregroundStyle(p.cInk)
                        .padding(x.kind == .highlight ? 8 : 0)
                        .background(RoundedRectangle(cornerRadius: 10).fill(x.kind == .highlight ? Color(uiColor: p.hlColor(x.color)).opacity(0.6) : .clear))
                }
                Divider().overlay(p.cLine)
                Text(x.vat.t).font(Typo.gu(store, 16)).foregroundStyle(p.cMuted)
            }
            .card(padding: 22)
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
    }
}
