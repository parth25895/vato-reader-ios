import SwiftUI
import UIKit

struct ReaderView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.palette) private var p

    let start: ReaderTarget
    @State private var curId: String
    @State private var scrollReq: ScrollRequest?
    @State private var curOff: Int = 0
    @State private var chrome = true
    @State private var showStyle = false
    @State private var showNotes = false
    @State private var confirmUpTo = false
    @State private var confirmClear = false

    init(start: ReaderTarget) {
        self.start = start
        _curId = State(initialValue: start.vatId)
        _scrollReq = State(initialValue: ScrollRequest(off: start.off))
        _curOff = State(initialValue: start.off)
    }

    private var vat: Vat? { store.lib.vat(curId) }
    private var idx: Int { store.lib.index[curId] ?? 0 }

    var body: some View {
        GeometryReader { geo in
            let safeTop = geo.safeAreaInsets.top
            let safeBottom = geo.safeAreaInsets.bottom
            ZStack {
                p.cBg.ignoresSafeArea()
                if let v = vat {
                    let built = buildContent(v)
                    ReaderTextView(
                        vatId: v.id,
                        content: built.0,
                        prefixLen: built.1,
                        contentKey: contentKey(v),
                        scrollRequest: scrollReq,
                        palette: p,
                        topInset: safeTop + 70,
                        bottomInset: safeBottom + 150,
                        onOffset: { off in
                            curOff = off
                            store.setLast(curId, off: off)
                        },
                        onActivity: { store.activity() },
                        onHighlight: { r, c in store.applyHighlight(curId, range: r, color: c) },
                        onBookmark: { off in store.addBookmark(curId, off: off) },
                        onTap: { withAnimation(.easeInOut(duration: 0.2)) { chrome.toggle() } }
                    )
                    .ignoresSafeArea()
                }
                VStack(spacing: 0) {
                    topBar
                        .padding(.top, safeTop)
                        .background(alignment: .top) {
                            LinearGradient(colors: [p.cBg, p.cBg.opacity(0.92), p.cBg.opacity(0)], startPoint: .top, endPoint: .bottom)
                                .frame(height: safeTop + 90)
                                .allowsHitTesting(false)
                        }
                    Spacer()
                    VStack(spacing: 10) {
                        SittingBar()
                        bottomBar
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, max(safeBottom, 10))
                    .background(alignment: .bottom) {
                        LinearGradient(colors: [p.cBg.opacity(0), p.cBg.opacity(0.92), p.cBg], startPoint: .top, endPoint: .bottom)
                            .frame(height: safeBottom + 130)
                            .allowsHitTesting(false)
                    }
                }
                .ignoresSafeArea()
                .opacity(chrome ? 1 : 0)
                .allowsHitTesting(chrome)
            }
            .toasts()
        }
        .statusBarHidden(!chrome)
        .onAppear { store.setLast(curId, off: start.off) }
        .sheet(isPresented: $showStyle) {
            ReaderStyleSheet()
                .environment(store)
                .environment(\.palette, p)
                .presentationDetents([.medium, .large])
                .presentationBackground(.regularMaterial)
        }
        .sheet(isPresented: $showNotes) {
            NotesSheet(vatId: curId)
                .environment(store)
                .environment(router)
                .environment(\.palette, p)
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog("Mark all up to here as read?", isPresented: $confirmUpTo, titleVisibility: .visible) {
            Button("Mark \(store.unreadUpTo(curId)) vato as read") {
                let n = store.markAllUpTo(curId)
                store.toast("\(n) vato marked as read (earlier)")
            }
        } message: {
            Text("Every unread vat before this one, and this one, is marked read with no date, so it does not count toward a day.")
        }
        .confirmationDialog("Clear highlights in this vat?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear highlights", role: .destructive) { store.s.hl.removeValue(forKey: curId) }
        }
    }

    // MARK: bars

    private var topBar: some View {
        let v = vat
        let count = v.map { (store.lib.byChapter[$0.c] ?? []).count } ?? 0
        let progress = v.map { Double(curOff) / Double(max(1, $0.len)) } ?? 0
        return VStack(spacing: 8) {
            HStack(spacing: 10) {
                circleButton("chevron.down") { router.reader = nil }
                Spacer()
                VStack(spacing: 1) {
                    Text(v.map { "Chapter \($0.c)" } ?? "")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(p.cInk)
                    Text(v.map { "Vat \($0.n) of \(count)" } ?? "")
                        .font(.caption2)
                        .foregroundStyle(p.cMuted)
                }
                Spacer()
                circleButton("textformat.size") { showStyle = true }
                Menu {
                    if let v {
                        Button { store.toggleFav(v.id) } label: {
                            Label(store.s.fav[v.id] == true ? "Remove from favourites" : "Add to favourites", systemImage: store.s.fav[v.id] == true ? "star.slash" : "star")
                        }
                        Button { store.addBookmark(v.id, off: curOff) } label: { Label("Bookmark this line", systemImage: "bookmark") }
                        Button { showNotes = true } label: { Label("Tags & notes", systemImage: "note.text") }
                        ShareLink(item: v.t + "\n\n" + v.x) { Label("Share vat", systemImage: "square.and.arrow.up") }
                        Button { UIPasteboard.general.string = v.t + "\n\n" + v.x; store.toast("Copied") } label: { Label("Copy text", systemImage: "doc.on.doc") }
                        Divider()
                        Button { confirmUpTo = true } label: { Label("Mark all up to here as read", systemImage: "checkmark.circle.badge.questionmark") }
                        if !(store.s.hl[v.id] ?? []).isEmpty {
                            Button(role: .destructive) { confirmClear = true } label: { Label("Clear highlights", systemImage: "eraser") }
                        }
                    }
                } label: {
                    circleLabel("ellipsis")
                }
            }
            .padding(.horizontal, 14)
            GeometryReader { g in
                Capsule().fill(p.cGold.opacity(0.85))
                    .frame(width: max(0, min(1, progress)) * g.size.width, height: 2)
                    .animation(.easeOut(duration: 0.3), value: progress)
            }
            .frame(height: 2)
            .padding(.horizontal, 18)
        }
        .padding(.top, 6)
    }

    private var bottomBar: some View {
        let v = vat
        let isRead = v.map { store.isRead($0.id) } ?? false
        let hasNext = idx < store.lib.entries.count - 1
        let hasPrev = idx > 0
        return HStack(spacing: 10) {
            circleButton("chevron.left", disabled: !hasPrev) { go(idx - 1) }
            Button {
                guard let v else { return }
                store.toggleRead(v.id)
            } label: {
                Image(systemName: isRead ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(isRead ? p.cAccent : p.cMuted)
                    .frame(width: 46, height: 46)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(p.cLine, lineWidth: 0.5))
            }
            .accessibilityLabel(isRead ? "Mark as unread" : "Mark as read")
            Button { readAndNext() } label: {
                HStack(spacing: 8) {
                    Text(isRead ? (v.flatMap { store.s.read[$0.id] }.map { "Read \(Day.short($0)) · Next" } ?? "Next") : "Mark read & next")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!hasNext && isRead)
            circleButton("chevron.right", disabled: !hasNext) { go(idx + 1) }
        }
    }

    private func circleLabel(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(p.cInk)
            .frame(width: 42, height: 42)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().strokeBorder(p.cLine, lineWidth: 0.5))
    }

    private func circleButton(_ icon: String, disabled: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { circleLabel(icon) }
            .disabled(disabled)
            .opacity(disabled ? 0.4 : 1)
    }

    // MARK: actions

    private func go(_ i: Int) {
        guard i >= 0, i < store.lib.entries.count else { return }
        let id = store.lib.entries[i].id
        curId = id
        curOff = 0
        scrollReq = ScrollRequest(off: 0)
        store.setLast(id, off: 0)
        Haptics.tap()
    }

    private func readAndNext() {
        guard let v = vat else { return }
        let wasRead = store.isRead(v.id)
        if !wasRead {
            store.markRead(v.id)
            store.afterMark(v.id)
        }
        let n = store.s.log[Day.today] ?? 0
        if idx < store.lib.entries.count - 1 { go(idx + 1) }
        if !wasRead { store.toast("Marked read · \(n) today") }
    }

    // MARK: content

    private func contentKey(_ v: Vat) -> String {
        let h = (store.s.hl[v.id] ?? []).map { "\($0.s)-\($0.e)-\($0.c)" }.joined(separator: ",")
        return "\(v.id)|\(h)|\(store.s.rfont)|\(store.s.size)|\(store.s.lineSpacing)|\(store.s.rbg)|\(p.isDark)"
    }

    private func buildContent(_ v: Vat) -> (NSAttributedString, Int) {
        let size = CGFloat(store.s.size)
        let font = Typo.uiFont(store.s.rfont, size: size)
        let titleFont = Typo.uiFont(store.s.rfont, size: size * 1.32)

        let body = NSMutableParagraphStyle()
        body.lineHeightMultiple = 1.32 * CGFloat(store.s.lineSpacing)
        body.paragraphSpacing = size * 0.7

        let tStyle = NSMutableParagraphStyle()
        tStyle.lineHeightMultiple = 1.15
        tStyle.paragraphSpacing = 4

        let out = NSMutableAttributedString()
        out.append(NSAttributedString(string: v.t + "\n", attributes: [.font: titleFont, .foregroundColor: p.ink, .paragraphStyle: tStyle]))
        var meta = "CHAPTER \(v.c) · VAT \(v.n)"
        if !v.r.isEmpty { meta = v.r + "   ·   " + meta }
        let metaStyle = NSMutableParagraphStyle()
        metaStyle.paragraphSpacing = size * 1.1
        out.append(NSAttributedString(string: meta + "\n", attributes: [.font: UIFont.systemFont(ofSize: 12.5, weight: .medium), .foregroundColor: p.muted, .paragraphStyle: metaStyle, .kern: 0.4]))
        let prefixLen = out.length

        let bodyStr = NSMutableAttributedString(string: v.x, attributes: [.font: font, .foregroundColor: p.ink, .paragraphStyle: body])
        let L = bodyStr.length
        for h in store.s.hl[v.id] ?? [] {
            let s = max(0, min(L, h.s)), e = max(s, min(L, h.e))
            if e > s { bodyStr.addAttribute(.backgroundColor, value: p.hlColor(h.c), range: NSRange(location: s, length: e - s)) }
        }
        out.append(bodyStr)

        // Ornament at the end
        let endStyle = NSMutableParagraphStyle()
        endStyle.alignment = .center
        endStyle.paragraphSpacingBefore = size * 1.2
        out.append(NSAttributedString(string: "\n❦", attributes: [.font: UIFont.systemFont(ofSize: 18), .foregroundColor: p.gold, .paragraphStyle: endStyle]))
        return (out, prefixLen)
    }
}

// MARK: - Reading style sheet

struct ReaderStyleSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.palette) private var p

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Reading style").font(Typo.title).foregroundStyle(p.cInk).padding(.top, 20)

                Eyebrow("Font")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(readingFonts) { f in
                        let on = store.s.rfont == f.id
                        Button { store.s.rfont = f.id; Haptics.tap() } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ભગવાન ને સાધુ").font(Typo.font(f.id, size: 19)).foregroundStyle(p.cInk)
                                Text(f.name).font(.caption).foregroundStyle(p.cMuted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(p.cSurface))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(on ? p.cAccent : p.cLine, lineWidth: on ? 2 : 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Eyebrow("Background")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(backgroundOptions) { b in
                        let on = store.s.rbg == b.id
                        Button { store.s.rbg = b.id; Haptics.tap() } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    if let bg = b.bg, let ink = b.ink {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(uiColor: UIColor(hex: bg)))
                                        Text("અ").font(.system(size: 20)).foregroundStyle(Color(uiColor: UIColor(hex: ink)))
                                    } else {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(LinearGradient(colors: [Color(uiColor: UIColor(hex: 0xF6F1E7)), Color(uiColor: UIColor(hex: 0x0D0E11))], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        Text("અ").font(.system(size: 20)).foregroundStyle(Color(uiColor: UIColor(hex: 0xB88A3E)))
                                    }
                                }
                                .frame(height: 54)
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(on ? p.cAccent : p.cLine, lineWidth: on ? 2 : 0.5))
                                Text(b.name).font(.caption2).foregroundStyle(p.cMuted).lineLimit(1).minimumScaleFactor(0.8)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack { Eyebrow("Text size"); Spacer(); Text("\(Int(store.s.size))").font(.caption.monospacedDigit()).foregroundStyle(p.cMuted) }
                    HStack {
                        Image(systemName: "textformat.size.smaller").foregroundStyle(p.cMuted)
                        Slider(value: $store.s.size, in: 15...34, step: 1)
                        Image(systemName: "textformat.size.larger").foregroundStyle(p.cMuted)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow("Line spacing")
                    Picker("Line spacing", selection: $store.s.lineSpacing) {
                        Text("Compact").tag(0.9)
                        Text("Comfortable").tag(1.0)
                        Text("Airy").tag(1.15)
                    }
                    .pickerStyle(.segmented)
                }
                if store.s.rbg == "app" {
                    VStack(alignment: .leading, spacing: 6) {
                        Eyebrow("Appearance")
                        Picker("Appearance", selection: $store.s.theme) {
                            Text("System").tag("auto")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }
}

// MARK: - Tags & notes

struct NotesSheet: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let vatId: String
    @State private var tagText = ""
    @State private var note = ""

    var body: some View {
        let v = store.lib.vat(vatId)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let v, !v.tp.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow("Topics")
                            FlowLayout(spacing: 8) {
                                ForEach(v.tp, id: \.self) { t in
                                    if let tt = store.lib.topicById[t] { Chip(text: tt.gu.isEmpty ? tt.ro : tt.gu) }
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("My tags")
                        FlowLayout(spacing: 8) {
                            ForEach(store.s.tags[vatId] ?? [], id: \.self) { t in
                                Button { store.removeTag(vatId, t) } label: { Chip(text: t + "  ×", on: true) }
                                    .buttonStyle(.plain)
                            }
                        }
                        HStack {
                            TextField("Add a tag", text: $tagText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .submitLabel(.done)
                                .onSubmit(addTag)
                                .padding(.horizontal, 12).padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 12).fill(p.cSurface2))
                            Button("Add", action: addTag).buttonStyle(SoftButtonStyle())
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("My notes")
                        TextEditor(text: $note)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 180)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 14).fill(p.cSurface2))
                            .onChange(of: note) { _, n in store.setNote(vatId, n) }
                    }
                }
                .padding(20)
            }
            .background(p.cBg.ignoresSafeArea())
            .navigationTitle(v?.t ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .onAppear { note = store.s.notes[vatId] ?? "" }
    }

    private func addTag() {
        store.addTag(vatId, tagText)
        tagText = ""
    }
}
