import SwiftUI

struct HomeView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.palette) private var p
    @State private var confirmFinish = false

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 5 { return "Peaceful night" }
        if h < 12 { return "Good morning" }
        if h < 17 { return "Good afternoon" }
        return "Good evening"
    }

    private var vatOfDay: Vat? {
        let es = store.lib.entries
        guard !es.isEmpty else { return nil }
        let k = Day.today
        var h: UInt64 = 1469598103934665603
        for b in k.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return es[Int(h % UInt64(es.count))]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if store.roundDone { finishBanner }
                    continueCard
                    todayStrip
                    if let v = vatOfDay { vatOfDayCard(v) }
                    chaptersSection
                    topicsSection
                    tagsSection
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .background(p.cBg.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { SittingBar().padding(.horizontal, 18).padding(.bottom, 6) }
            .navigationDestination(for: Int.self) { ChapterView(chapterId: $0) }
            .navigationDestination(for: VatList.self) { VatListView(list: $0) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                .font(Typo.eyebrow).tracking(1.2)
                .foregroundStyle(p.cMuted)
            Text(greeting)
                .font(Typo.display)
                .foregroundStyle(p.cInk)
            Text("જય સ્વામિનારાયણ")
                .font(Typo.gu(store, 17))
                .foregroundStyle(p.cGold)
        }
        .padding(.top, 14)
    }

    private var finishBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Round \(store.s.round.n) is complete")
                .font(Typo.title).foregroundStyle(p.cInk)
            Text("You have read every vat you are tracking.")
                .font(.subheadline).foregroundStyle(p.cMuted)
            Button("Finish and start Round \(store.s.round.n + 1)") { confirmFinish = true }
                .buttonStyle(PrimaryButtonStyle())
        }
        .card()
        .confirmationDialog("Start Round \(store.s.round.n + 1)?", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("Finish Round \(store.s.round.n)") { store.finishRound(); store.toast("Round \(store.s.round.n) begins") }
        } message: {
            Text("Your read marks clear for the new round. Round history, notes and highlights stay.")
        }
    }

    private var continueCard: some View {
        let last = store.s.last.flatMap { store.lib.vat($0.id) }
        let target = last ?? store.nextUnread ?? store.lib.entries.first
        let a = Double(store.lib.entries.filter { store.isTracked($0.c) && store.isRead($0.id) }.count)
        let tv = Double(max(1, store.lib.entries.filter { store.isTracked($0.c) }.count))
        return Button {
            guard let t = target else { return }
            if let l = store.s.last, l.id == t.id { router.open(t.id, off: l.off) } else { router.open(t.id) }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(last != nil ? "CONTINUE READING" : "BEGIN READING")
                        .font(Typo.eyebrow).tracking(1.4)
                        .foregroundStyle(Color.white.opacity(0.75))
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.white.opacity(0.9))
                }
                if let t = target {
                    Text(t.t)
                        .font(Typo.gu(store, 24))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text("Chapter \(t.c) · Vat \(t.n)")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.75))
                    Text(preview(t.x, 120))
                        .font(Typo.gu(store, 15))
                        .foregroundStyle(Color.white.opacity(0.82))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.18))
                            Capsule().fill(Color.white.opacity(0.9)).frame(width: max(6, g.size.width * a / tv))
                        }
                    }
                    .frame(height: 5)
                    Text("Round \(store.s.round.n) · \(Int(a)) of \(Int(tv)) · \(String(format: "%.1f", a / tv * 100))%")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.75))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    LinearGradient(colors: p.isDark ? [Color(uiColor: UIColor(hex: 0x3A2A16)), Color(uiColor: UIColor(hex: 0x14110C))] : [Color(uiColor: UIColor(hex: 0x8E5A24)), Color(uiColor: UIColor(hex: 0x4A2E12))], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Circle().fill(p.cGold.opacity(0.22)).frame(width: 220).offset(x: 140, y: -80).blur(radius: 30)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(p.cGold.opacity(0.35), lineWidth: 0.8))
            .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
        }
        .buttonStyle(.plain)
    }

    private var todayStrip: some View {
        let td = store.s.log[Day.today] ?? 0
        var streak = 0
        let s0 = td > 0 ? 0 : 1
        while (store.s.log[Day.plus(-s0 - streak)] ?? 0) > 0 { streak += 1 }
        return HStack(spacing: 10) {
            statTile("\(td)", "read today", "sun.max")
            statTile("\(streak)", streak == 1 ? "day streak" : "day streak", "flame")
            Button {
                if store.s.sit == nil { store.sitStart(); Haptics.tap() } else { store.sitStop() }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: store.s.sit == nil ? "play.circle" : "stop.circle")
                        .font(.system(size: 17)).foregroundStyle(p.cGold)
                    Text(store.s.sit == nil ? "Start" : "Stop")
                        .font(.system(size: 22, weight: .semibold, design: .rounded)).foregroundStyle(p.cInk)
                    Text("sitting").font(.caption).foregroundStyle(p.cMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(padding: 12)
            }
            .buttonStyle(.plain)
        }
    }

    private func statTile(_ v: String, _ l: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).font(.system(size: 17)).foregroundStyle(p.cGold)
            Text(v).font(.system(size: 22, weight: .semibold, design: .rounded)).foregroundStyle(p.cInk).contentTransition(.numericText())
            Text(l).font(.caption).foregroundStyle(p.cMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 12)
    }

    private func vatOfDayCard(_ v: Vat) -> some View {
        Button { router.open(v.id) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Eyebrow("Vat of the day")
                    Spacer()
                    Text("\(v.c).\(v.n)").font(.caption.monospacedDigit()).foregroundStyle(p.cMuted)
                }
                Text(v.t).font(Typo.gu(store, 19)).foregroundStyle(p.cInk).multilineTextAlignment(.leading)
                Text(preview(v.x, 220))
                    .font(Typo.gu(store, 16))
                    .lineSpacing(6)
                    .foregroundStyle(p.cInk.opacity(0.85))
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private var chaptersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Chapters")
            VStack(spacing: 0) {
                ForEach(store.lib.chapters) { c in
                    let es = store.lib.byChapter[c.id] ?? []
                    let r = store.readCount(es)
                    NavigationLink(value: c.id) {
                        HStack(spacing: 14) {
                            ZStack {
                                ProgressRing(value: es.isEmpty ? 0 : Double(r) / Double(es.count), lineWidth: 3.5)
                                Text("\(c.id)").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(p.cInk)
                            }
                            .frame(width: 38, height: 38)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(c.gu).font(Typo.gu(store, 17)).foregroundStyle(p.cInk).multilineTextAlignment(.leading)
                                Text("\(r) of \(es.count) read" + (store.isTracked(c.id) ? "" : " · not tracked"))
                                    .font(.caption).foregroundStyle(p.cMuted)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(p.cMuted.opacity(0.6))
                        }
                        .padding(.vertical, 11)
                        .padding(.horizontal, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if c.id != store.lib.chapters.last?.id { Divider().overlay(p.cLine).padding(.leading, 66) }
                }
            }
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(p.cSurface))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(p.cLine.opacity(0.7), lineWidth: 0.5))
        }
    }

    private var topicsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Topics")
            ScrollView(.horizontal) {
                LazyHStack(spacing: 8) {
                    ForEach(store.lib.topics) { t in
                        NavigationLink(value: VatList(title: t.gu.isEmpty ? t.ro : t.gu, subtitle: (t.ro.isEmpty ? "" : t.ro + " · ") + "\(t.ids.count) vato", ids: t.ids)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(t.gu).font(Typo.gu(store, 15)).foregroundStyle(p.cInk).lineLimit(2).multilineTextAlignment(.leading)
                                Text("\(t.ids.count) vato").font(.caption2).foregroundStyle(p.cMuted)
                            }
                            .frame(width: 150, height: 70, alignment: .topLeading)
                            .card(padding: 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder private var tagsSection: some View {
        let tags = store.allTags
        if !tags.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("My tags")
                FlowLayout(spacing: 8) {
                    ForEach(tags) { t in
                        let ids = store.lib.entries.filter { (store.s.tags[$0.id] ?? []).contains(t.name) }.map(\.id)
                        NavigationLink(value: VatList(title: "Tag: \(t.name)", subtitle: "\(ids.count) vato", ids: ids)) {
                            Chip(text: "\(t.name) · \(t.count)")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

func preview(_ x: String, _ n: Int) -> String {
    var s = x
    if let r = s.range(of: #"^\(\d+\)\s*"#, options: .regularExpression) { s.removeSubrange(r) }
    s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    return s.count > n ? String(s.prefix(n)) + "…" : s
}

struct VatList: Hashable {
    let title: String
    let subtitle: String
    let ids: [String]
}

// MARK: - Sitting bar (live)

struct SittingBar: View {
    @Environment(Store.self) private var store
    @Environment(\.palette) private var p
    var body: some View {
        if let a = store.s.sit {
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                let secs = max(0, Int(ctx.date.timeIntervalSince1970 - a.s / 1000))
                HStack(spacing: 10) {
                    Circle().fill(p.cGold).frame(width: 8, height: 8)
                    Text(clock(secs)).font(.system(size: 16, weight: .semibold, design: .rounded).monospacedDigit()).foregroundStyle(p.cInk)
                    Text("\(a.n) vato").font(.subheadline).foregroundStyle(p.cMuted)
                    Spacer()
                    Button("Stop") { store.sitStop() }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Capsule().fill(p.cSurface2))
                        .foregroundStyle(p.cInk)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(p.cLine, lineWidth: 0.5))
                .onChange(of: ctx.date) { _, _ in store.closeIdleSitting() }
            }
        }
    }
    private func clock(_ s: Int) -> String {
        let h = s / 3600, m = (s % 3600) / 60, x = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, x) : String(format: "%d:%02d", m, x)
    }
}

// MARK: - Flow layout for chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? 360
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, width: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxW { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
            width = max(width, x)
        }
        return CGSize(width: min(maxW, width), height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}
