import SwiftUI
import Charts

struct StatsView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.palette) private var p
    @State private var tab = 0

    var body: some View {
        let a = Analytics(store: store)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("View", selection: $tab) {
                        Text("Overview").tag(0)
                        Text("Chapters").tag(1)
                        Text("History").tag(2)
                    }
                    .pickerStyle(.segmented)
                    switch tab {
                    case 1: StatsChapters()
                    case 2: StatsHistory(a: a)
                    default: StatsOverview(a: a)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .background(p.cBg.ignoresSafeArea())
            .navigationTitle("Progress")
            .safeAreaInset(edge: .bottom) { SittingBar().padding(.horizontal, 18).padding(.bottom, 6) }
        }
    }
}

// MARK: - Overview

struct StatsOverview: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.palette) private var p
    let a: Analytics
    @State private var confirmFinish = false

    var body: some View {
        let pct = a.tv > 0 ? Double(a.rd) / Double(a.tv) : 0
        let pace = a.pace(store: store)
        VStack(alignment: .leading, spacing: 16) {
            if store.roundDone {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Round \(store.s.round.n) is complete").font(Typo.title).foregroundStyle(p.cInk)
                    Button("Finish and start Round \(store.s.round.n + 1)") { confirmFinish = true }.buttonStyle(PrimaryButtonStyle())
                }
                .card()
                .confirmationDialog("Start Round \(store.s.round.n + 1)?", isPresented: $confirmFinish, titleVisibility: .visible) {
                    Button("Finish Round \(store.s.round.n)") { store.finishRound() }
                }
            }

            // Hero
            HStack(spacing: 18) {
                ZStack {
                    ProgressRing(value: pct, lineWidth: 11)
                    VStack(spacing: 2) {
                        Text(pct >= 0.1 ? "\(Int((pct * 100).rounded()))%" : String(format: "%.1f%%", pct * 100))
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .foregroundStyle(p.cInk)
                        Text("Round \(store.s.round.n)").font(.caption).foregroundStyle(p.cMuted)
                    }
                }
                .frame(width: 118, height: 118)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(a.rd)").font(.system(size: 30, weight: .semibold, design: .rounded)).foregroundStyle(p.cInk)
                        Text("of \(a.tv)").font(.subheadline).foregroundStyle(p.cMuted)
                    }
                    Text("\(a.rem) vato left" + (store.s.round.start.map { " · since \(Day.short($0))" } ?? ""))
                        .font(.footnote).foregroundStyle(p.cMuted)
                    if a.rem == 0 {
                        Text("Round complete").font(.subheadline.weight(.semibold)).foregroundStyle(p.cAccent)
                    } else if let l = a.likely {
                        (Text("Finish around ").foregroundStyle(p.cInk) + Text(Day.long(l.key)).bold().foregroundStyle(p.cInk))
                            .font(.subheadline)
                        if let f = a.fast, let s = a.slow, s.days - f.days >= 3 {
                            Text("Between \(Day.short(f.key)) and \(Day.short(s.key))").font(.caption).foregroundStyle(p.cMuted)
                        }
                    } else {
                        Text("Read a few days and a finish date appears here.").font(.caption).foregroundStyle(p.cMuted)
                    }
                }
                Spacer(minLength: 0)
            }
            .card(padding: 18)

            // Today
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Eyebrow("Today")
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(a.td)").font(.system(size: 30, weight: .semibold, design: .rounded)).foregroundStyle(p.cInk)
                            Text("vato").font(.subheadline).foregroundStyle(p.cMuted)
                        }
                    }
                    Spacer()
                    if let nx = store.nextUnread {
                        Button("Continue · \(nx.c).\(nx.n)") { router.open(nx.id) }.buttonStyle(PrimaryButtonStyle())
                    }
                }
                if let pc = pace, pc.need > 0, let target = store.s.round.target {
                    Text(pc.moreToday > 0 ? "\(pc.moreToday) more today to stay on pace for \(Day.short(target))" : "Today's share for \(Day.short(target)) is done")
                        .font(.footnote).foregroundStyle(p.cMuted)
                }
                HStack(spacing: 10) {
                    tile("\(a.cur)", "day streak")
                    tile("\(a.act30)/30", "days read")
                    tile(Fmt.rate(a.ewma), "a day, recent")
                }
            }
            .card()

            // This week
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Eyebrow("This week")
                    Spacer()
                    let d = a.thisWeek - a.lastWeek
                    Text("\(a.thisWeek) vato" + (a.lastWeek > 0 ? " · \(d >= 0 ? "+" : "")\(d) vs last week" : ""))
                        .font(.caption).foregroundStyle(p.cMuted)
                }
                Chart(a.week) { w in
                    BarMark(x: .value("Day", "\(w.id)"), y: .value("Vato", w.n), width: .ratio(0.62))
                        .foregroundStyle(w.key == Day.today ? p.cAccent : p.cGold.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .annotation(position: .top) {
                            if !w.future && w.n > 0 { Text("\(w.n)").font(.caption2.monospacedDigit()).foregroundStyle(p.cMuted) }
                        }
                }
                .chartXAxis {
                    AxisMarks(values: a.week.map { "\($0.id)" }) { v in
                        AxisValueLabel {
                            if let s = v.as(String.self), let i = Int(s) {
                                Text(a.week[i].label).font(.caption2.weight(.semibold)).foregroundStyle(a.week[i].key == Day.today ? p.cAccent : p.cMuted)
                            }
                        }
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 130)
            }
            .card()

            // Target date
            TargetCard(a: a, pace: pace)

            // Sittings
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Eyebrow("Sittings today")
                    Spacer()
                    if store.s.sit == nil {
                        Button("Start") { store.sitStart(); Haptics.tap() }.buttonStyle(SoftButtonStyle())
                    } else {
                        Button("Stop") { store.sitStop() }.buttonStyle(SoftButtonStyle())
                    }
                }
                let list = store.todaySittings
                if list.isEmpty && store.s.sit == nil {
                    Text("A sitting starts on its own when you mark a vat read.").font(.footnote).foregroundStyle(p.cMuted)
                } else {
                    ForEach(Array(list.reversed().enumerated()), id: \.offset) { _, x in
                        HStack {
                            Text(Date(timeIntervalSince1970: x.s / 1000).formatted(date: .omitted, time: .shortened))
                                .font(.subheadline.monospacedDigit()).foregroundStyle(p.cInk)
                            Spacer()
                            Text("\(max(1, Int(((x.e - x.s) / 60000).rounded()))) min · \(x.n) vato").font(.footnote).foregroundStyle(p.cMuted)
                        }
                    }
                }
            }
            .card()

            // Patterns
            let ins = insights
            if !ins.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow("Your patterns")
                    ForEach(ins, id: \.self) { s in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "sparkle").font(.caption).foregroundStyle(p.cGold).padding(.top, 3)
                            Text(LocalizedStringKey(s)).font(.subheadline).foregroundStyle(p.cInk)
                        }
                    }
                }
                .card()
            }
        }
    }

    private var insights: [String] {
        let days = ["Sundays", "Mondays", "Tuesdays", "Wednesdays", "Thursdays", "Fridays", "Saturdays"]
        let tod = ["mornings", "afternoons", "evenings"]
        var out: [String] = []
        if a.anyWeekday { out.append("You read most on **\(days[a.bestWeekday])**.") }
        if a.anyTime { out.append("Your best time is **\(tod[a.bestTime])**.") }
        if a.best > 0, let k = a.bestKey { out.append("Your best day was **\(a.best) vato** on \(Day.short(k)).") }
        return out
    }

    private func tile(_ v: String, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(v).font(.system(size: 21, weight: .semibold, design: .rounded)).foregroundStyle(p.cInk).lineLimit(1).minimumScaleFactor(0.7)
            Text(l).font(.caption).foregroundStyle(p.cMuted).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(p.cSurface2))
    }
}

struct TargetCard: View {
    @Environment(Store.self) private var store
    @Environment(\.palette) private var p
    let a: Analytics
    let pace: PaceInfo?

    var body: some View {
        let has = store.s.round.target != nil
        let binding = Binding<Date>(
            get: { store.s.round.target.map { Day.date($0) } ?? Calendar.current.date(byAdding: .month, value: 6, to: Date())! },
            set: { store.s.round.target = Day.key($0) }
        )
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow("Finish this round by")
                Spacer()
                if has {
                    Button("Clear") { store.s.round.target = nil }.font(.footnote.weight(.semibold)).foregroundStyle(p.cAccent)
                }
            }
            if has {
                DatePicker("Target date", selection: binding, in: Date()..., displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(p.cAccent)
                if let pc = pace {
                    if pc.done {
                        Text("Round complete.").font(.subheadline)
                    } else if pc.late {
                        Text("That date has passed with \(pc.rem) vato unread. Pick a new date.").font(.subheadline).foregroundStyle(p.cDanger)
                    } else {
                        (Text("\(pc.need) vato a day").bold() + Text(" for \(pc.left) day\(pc.left == 1 ? "" : "s"). You are ")
                         + (pc.diff >= 0 ? Text("\(pc.diff) ahead of").bold().foregroundColor(p.cAccent) : Text("\(-pc.diff) behind").bold().foregroundColor(p.cDanger))
                         + Text(" an even pace" + (pc.onTrack ? ", and at your recent pace you finish in time." : ".")))
                            .font(.subheadline)
                            .foregroundStyle(p.cInk)
                    }
                }
            } else {
                Text("Set a date to see how many vato a day it takes, and whether you are ahead or behind.")
                    .font(.footnote).foregroundStyle(p.cMuted)
                Button("Set a finish date") {
                    store.s.round.target = Day.key(Calendar.current.date(byAdding: .month, value: 6, to: Date())!)
                }
                .buttonStyle(SoftButtonStyle())
            }
        }
        .card()
    }
}

// MARK: - Chapters

struct StatsChapters: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.palette) private var p

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Turn a chapter off to leave it out of your totals.").font(.footnote).foregroundStyle(p.cMuted)
            ForEach(store.lib.chapters) { c in
                let es = store.lib.byChapter[c.id] ?? []
                let r = store.readCount(es)
                let tracked = store.isTracked(c.id)
                let frac = es.isEmpty ? 0 : Double(r) / Double(es.count)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Chapter \(c.id)").font(.caption.weight(.semibold)).foregroundStyle(p.cMuted)
                            Text(c.gu).font(Typo.gu(store, 18)).foregroundStyle(p.cInk)
                        }
                        Spacer()
                        Toggle("Track", isOn: Binding(
                            get: { tracked },
                            set: { on in if on { store.s.track.removeValue(forKey: String(c.id)) } else { store.s.track[String(c.id)] = false } }
                        ))
                        .labelsHidden()
                        .tint(p.cAccent)
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(p.cLine)
                            Capsule().fill(LinearGradient(colors: [p.cGold, p.cAccent], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(frac > 0 ? 6 : 0, g.size.width * frac))
                        }
                    }
                    .frame(height: 6)
                    HStack {
                        Text("\(r) of \(es.count) · \(Int((frac * 100).rounded()))%" + (r == es.count && !es.isEmpty ? " · Complete" : r == 0 ? " · Not started" : ""))
                            .font(.caption).foregroundStyle(p.cMuted)
                        Spacer()
                        if tracked, r > 0, let nx = store.nextUnread(inChapter: c.id) {
                            Button("Next · \(nx.n)") { router.open(nx.id) }.font(.caption.weight(.semibold)).foregroundStyle(p.cAccent)
                        }
                    }
                }
                .card(padding: 14)
                .opacity(tracked ? 1 : 0.55)
            }
        }
    }
}

// MARK: - History

struct StatsHistory: View {
    @Environment(Store.self) private var store
    @Environment(\.palette) private var p
    let a: Analytics
    @State private var dayCaption: String? = nil
    @State private var confirmReset = false
    @State private var logChapter = 1
    @State private var logFrom = ""
    @State private var logTo = ""
    @State private var logDate = Date()
    @State private var logNoDate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            heatmap
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("Last 28 days")
                Chart(a.last28) { d in
                    BarMark(x: .value("Day", Day.date(d.key), unit: .day), y: .value("Vato", d.n))
                        .foregroundStyle(d.key == Day.today ? p.cAccent : p.cGold.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated)).foregroundStyle(p.cMuted)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(p.cLine)
                        AxisValueLabel().foregroundStyle(p.cMuted)
                    }
                }
                .frame(height: 150)
            }
            .card()

            HStack(spacing: 10) {
                bigTile("\(store.s.hist.count)", "rounds finished")
                bigTile(a.allTime.formatted(), "vato, all time")
                bigTile("\(a.longest)", "best streak (days)")
            }

            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("Milestones")
                FlowLayout(spacing: 8) {
                    ForEach(milestones, id: \.0) { m in
                        HStack(spacing: 5) {
                            Image(systemName: m.1 ? "checkmark.seal.fill" : "seal").font(.caption)
                            Text(m.0).font(.caption.weight(m.1 ? .semibold : .regular))
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .foregroundStyle(m.1 ? p.cAccent : p.cMuted)
                        .background(Capsule().fill(m.1 ? p.cAccent.opacity(0.12) : p.cSurface2))
                        .opacity(m.1 ? 1 : 0.7)
                    }
                }
            }
            .card()

            if !store.s.hist.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow("Finished rounds")
                    ForEach(store.s.hist.reversed()) { r in
                        let days = Day.diff(r.start, r.end) + 1
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Round \(r.n)").font(.subheadline.weight(.semibold)).foregroundStyle(p.cInk)
                                Text("\(Day.long(r.start)) → \(Day.long(r.end))").font(.caption).foregroundStyle(p.cMuted)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(days) days").font(.subheadline).foregroundStyle(p.cInk)
                                Text("\(Fmt.rate(Double(r.count) / Double(max(1, days)))) a day").font(.caption).foregroundStyle(p.cMuted)
                            }
                        }
                    }
                }
                .card()
            }

            logCard

            Button(role: .destructive) { confirmReset = true } label: {
                Label("Reset this round", systemImage: "arrow.counterclockwise")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(p.cDanger)
            .padding(.top, 4)
            .confirmationDialog("Reset Round \(store.s.round.n)?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset this round", role: .destructive) { store.resetRound(); store.toast("Round reset") }
            } message: {
                Text("This clears every read mark in the current round. Finished rounds, notes, highlights and tags stay.")
            }
        }
    }

    private var milestones: [(String, Bool)] {
        [("100 vato", a.allTime >= 100), ("500 vato", a.allTime >= 500), ("1,000 vato", a.allTime >= 1000), ("2,500 vato", a.allTime >= 2500),
         ("7-day streak", a.longest >= 7), ("30-day streak", a.longest >= 30), ("100-day streak", a.longest >= 100),
         ("First round", store.s.hist.count >= 1), ("3 rounds", store.s.hist.count >= 3), ("A chapter finished", a.chaptersDone >= 1)]
    }

    private func bigTile(_ v: String, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(v).font(.system(size: 22, weight: .semibold, design: .rounded)).foregroundStyle(p.cInk).lineLimit(1).minimumScaleFactor(0.6)
            Text(l).font(.caption).foregroundStyle(p.cMuted).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 12)
    }

    private var heatmap: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let back = cal.date(byAdding: .day, value: -364, to: today)!
        let wd = cal.component(.weekday, from: back) - 1
        let start = cal.date(byAdding: .day, value: -wd, to: back)!
        let total = (cal.dateComponents([.day], from: start, to: today).day ?? 0) + 1
        let keys: [String] = (0..<total).map { Day.key(cal.date(byAdding: .day, value: $0, to: start)!) }
        let mx = max(1, keys.map { store.s.log[$0] ?? 0 }.max() ?? 1)
        let weeks = (keys.count + 6) / 7
        let yearTotal = keys.reduce(0) { $0 + (store.s.log[$1] ?? 0) }
        return VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Reading calendar")
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 3) {
                    ForEach(0..<weeks, id: \.self) { w in
                        VStack(spacing: 3) {
                            let firstKey = keys[min(keys.count - 1, w * 7)]
                            let isNewMonth = w == 0 || Day.date(firstKey).formatted(.dateTime.month()) != Day.date(keys[max(0, w * 7 - 7)]).formatted(.dateTime.month())
                            Text(isNewMonth ? Day.date(firstKey).formatted(.dateTime.month(.abbreviated)) : " ")
                                .font(.system(size: 9)).foregroundStyle(p.cMuted)
                                .frame(width: 13, height: 12, alignment: .leading)
                                .fixedSize()
                            ForEach(0..<7, id: \.self) { d in
                                let i = w * 7 + d
                                if i < keys.count {
                                    let n = store.s.log[keys[i]] ?? 0
                                    let lvl = n == 0 ? 0 : min(4, Int(ceil(Double(n) / Double(mx) * 4)))
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(lvl == 0 ? p.cLine : p.cAccent.opacity([0, 0.3, 0.5, 0.75, 1][lvl]))
                                        .frame(width: 13, height: 13)
                                        .onTapGesture { dayCaption = "\(Day.long(keys[i])): \(n) vato" }
                                } else {
                                    Color.clear.frame(width: 13, height: 13)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .defaultScrollAnchor(.trailing)
            .scrollIndicators(.hidden)
            Text(dayCaption ?? "\(yearTotal.formatted()) vato in the last 12 months. Tap a day for its count.")
                .font(.footnote).foregroundStyle(p.cMuted)
        }
        .card()
    }

    private var logCard: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                Text("Mark a range of vato as read on a date you pick, to catch up on reading done before this app.")
                    .font(.footnote).foregroundStyle(p.cMuted)
                Picker("Chapter", selection: $logChapter) {
                    ForEach(store.lib.chapters) { c in Text("\(c.id). \(c.gu)").tag(c.id) }
                }
                .tint(p.cAccent)
                HStack {
                    TextField("From vat", text: $logFrom).keyboardType(.numberPad)
                        .padding(10).background(RoundedRectangle(cornerRadius: 10).fill(p.cSurface2))
                    TextField("To vat", text: $logTo).keyboardType(.numberPad)
                        .padding(10).background(RoundedRectangle(cornerRadius: 10).fill(p.cSurface2))
                }
                Toggle("No date (counts as earlier)", isOn: $logNoDate).tint(p.cAccent)
                if !logNoDate {
                    DatePicker("Date read", selection: $logDate, in: ...Date(), displayedComponents: .date).tint(p.cAccent)
                }
                HStack {
                    Button("Mark as read") { applyLog(mark: true) }.buttonStyle(PrimaryButtonStyle())
                    Button("Mark as unread") { applyLog(mark: false) }.buttonStyle(SoftButtonStyle())
                }
            }
            .padding(.top, 10)
        } label: {
            Text("Log earlier reading").font(.subheadline.weight(.semibold)).foregroundStyle(p.cInk)
        }
        .tint(p.cMuted)
        .card()
    }

    private func applyLog(mark: Bool) {
        guard let f = Int(logFrom), let t = Int(logTo), f >= 1, t >= f else { store.toast("Enter a vat range, for example 1 to 10"); return }
        let es = store.lib.byChapter[logChapter] ?? []
        let k = logNoDate ? "earlier" : Day.key(logDate)
        var n = 0
        for e in es where e.n >= f && e.n <= t {
            if mark { store.markRead(e.id, on: k, quiet: true) } else { store.unmarkRead(e.id) }
            n += 1
        }
        if n == 0 { store.toast("Chapter \(logChapter) has vato 1 to \(es.count) only"); return }
        store.toast("\(n) vato " + (mark ? "marked as read" : "marked as unread"))
        logFrom = ""; logTo = ""
    }
}
