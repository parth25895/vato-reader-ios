import Foundation

struct ETA {
    let days: Int
    let key: String
}

struct WeekDay: Identifiable {
    let id: Int
    let key: String
    let n: Int
    let future: Bool
    let label: String
}

struct DayCount: Identifiable {
    let key: String
    let n: Int
    var id: String { key }
}

struct PaceInfo {
    var done = false
    var late = false
    var need = 0
    var moreToday = 0
    var left = 0
    var diff = 0
    var onTrack = false
    var rem = 0
}

/// Reading analytics. Same maths as the web reader's Progress page.
struct Analytics {
    var tv = 0, rd = 0, cT = 0, cR = 0, rem = 0, remC = 0, td = 0
    var ewma = 0.0, m30 = 0.0, l7 = 0.0
    var likely: ETA? = nil, slow: ETA? = nil, fast: ETA? = nil
    var cur = 0, longest = 0, act30 = 0
    var week: [WeekDay] = []
    var thisWeek = 0, lastWeek = 0
    var weekdayTotals = [Int](repeating: 0, count: 7)
    var bestWeekday = 0
    var timeBuckets = [0, 0, 0]
    var bestTime = 0
    var best = 0
    var bestKey: String? = nil
    var allTime = 0
    var chaptersDone = 0, chaptersTracked = 0
    var avgLen = 1.0
    var last28: [DayCount] = []

    @MainActor
    init(store: Store) {
        let s = store.s
        let lib = store.lib
        let t = Day.today
        let log = s.log
        let keys = log.keys.sorted()
        let first = keys.first

        var cDay: [String: Int] = [:]
        var cDaysCount = 0
        for e in lib.entries where store.isTracked(e.c) {
            tv += 1
            let L = e.len
            cT += L
            if let k = s.read[e.id] {
                rd += 1
                cR += L
                if k != "earlier" {
                    if cDay[k] == nil { cDay[k] = 0; if k != t { cDaysCount += 1 } }
                    cDay[k]! += L
                }
            }
        }
        td = log[t] ?? 0
        rem = tv - rd
        remC = cT - cR

        // Pace: recency-weighted average over completed days (half-life 7 days)
        let span = first.map { Day.diff($0, t) } ?? 0
        let maxAge = min(28, span)
        var num = 0.0, den = 0.0
        if maxAge >= 1 {
            for a in 1...maxAge {
                let w = pow(0.5, Double(a - 1) / 7)
                num += w * Double(log[Day.plus(-a)] ?? 0)
                den += w
            }
        }
        ewma = den > 0 ? num / den : Double(td)
        let n30 = max(1, min(30, span + 1))
        var sum30 = 0
        for a in 0..<n30 { sum30 += log[Day.plus(-a)] ?? 0 }
        m30 = Double(sum30) / Double(n30)
        var sum7 = 0
        for a in 0..<7 { sum7 += log[Day.plus(-a)] ?? 0 }
        l7 = Double(sum7) / Double(max(1, min(7, span + 1)))

        let avgAll = tv > 0 ? Double(cT) / Double(tv) : 1
        avgLen = rd > 0 ? Double(cR) / Double(rd) : avgAll

        // Characters read per day this round (recency weighted)
        var cn = 0.0, cd = 0.0
        let cspan = s.round.start.map { min(28, Day.diff($0, t)) } ?? 0
        if cspan >= 1 {
            for a in 1...cspan {
                let w = pow(0.5, Double(a - 1) / 7)
                cn += w * Double(cDay[Day.plus(-a)] ?? 0)
                cd += w
            }
        }
        let cRate: Double? = (cDaysCount >= 3 && cd > 0) ? cn / cd : nil

        let ewmaV = ewma, remV = rem, remCV = remC
        func eta(_ rate: Double) -> ETA? {
            if remV <= 0 || rate < 0.05 { return nil }
            let cpd: Double
            if let cr = cRate {
                cpd = cr * min(1.5, max(0.5, rate / max(ewmaV, 0.05)))
            } else {
                cpd = rate * avgAll
            }
            let dC = Double(remCV) / max(cpd, 1)
            let dV = Double(remV) / rate
            let d = Int(((dC + dV) / 2).rounded(.up))
            return ETA(days: d, key: Day.plus(d))
        }
        likely = eta(ewma)
        slow = eta(min(ewma, m30))
        fast = eta(max(ewma, l7))

        // Streaks
        var c = 0
        let s0 = (log[t] ?? 0) > 0 ? 0 : 1
        while (log[Day.plus(-s0 - c)] ?? 0) > 0 { c += 1 }
        cur = c
        var run = 0
        var prev: String? = nil
        for k in keys {
            if let p = prev, Day.diff(p, k) == 1 { run += 1 } else { run = 1 }
            longest = max(longest, run)
            prev = k
        }
        for a in 0..<30 where (log[Day.plus(-a)] ?? 0) > 0 { act30 += 1 }

        // This week, Monday first
        let wdNow = Calendar.current.component(.weekday, from: Date()) // 1 = Sunday
        let dow = (wdNow + 5) % 7
        let labels = ["M", "T", "W", "T", "F", "S", "S"]
        for a in 0..<7 {
            let k = Day.plus(-dow + a)
            let n = log[k] ?? 0
            week.append(WeekDay(id: a, key: k, n: n, future: -dow + a > 0, label: labels[a]))
            thisWeek += n
            lastWeek += log[Day.plus(-dow - 7 + a)] ?? 0
        }

        for a in 0..<90 {
            let k = Day.plus(-a)
            if let n = log[k], n > 0 {
                let wd = Calendar.current.component(.weekday, from: Day.date(k)) - 1
                weekdayTotals[wd] += n
            }
        }
        bestWeekday = weekdayTotals.indices.max { weekdayTotals[$0] < weekdayTotals[$1] } ?? 0
        for a in 0..<30 {
            if let r = s.sitDays[Day.plus(-a)], r.b.count == 3 {
                for q in 0..<3 { timeBuckets[q] += r.b[q] }
            }
        }
        bestTime = timeBuckets.indices.max { timeBuckets[$0] < timeBuckets[$1] } ?? 0

        for k in keys {
            if let n = log[k], n > best { best = n; bestKey = k }
        }
        allTime = s.hist.reduce(0) { $0 + $1.count } + rd
        for ch in lib.chapters where store.isTracked(ch.id) {
            chaptersTracked += 1
            let es = lib.byChapter[ch.id] ?? []
            if !es.isEmpty && es.allSatisfy({ s.read[$0.id] != nil }) { chaptersDone += 1 }
        }
        for a in stride(from: 27, through: 0, by: -1) {
            let k = Day.plus(-a)
            last28.append(DayCount(key: k, n: log[k] ?? 0))
        }
    }

    var anyTime: Bool { timeBuckets.reduce(0, +) > 0 }
    var anyWeekday: Bool { weekdayTotals[bestWeekday] > 0 }

    @MainActor
    func pace(store: Store) -> PaceInfo? {
        let r = store.s.round
        guard let target = r.target else { return nil }
        var p = PaceInfo()
        if rem == 0 { p.done = true; return p }
        let t = Day.today
        let left = Day.diff(t, target) + 1
        if left < 1 { p.late = true; p.rem = rem; return p }
        p.left = left
        p.need = Int((Double(rem + td) / Double(left)).rounded(.up))
        p.moreToday = max(0, p.need - td)
        let st = r.start ?? t
        let total = max(1, Day.diff(st, target) + 1)
        let el = min(total, max(0, Day.diff(st, t) + 1))
        let expected = Double(tv) * Double(el) / Double(total)
        p.diff = Int((Double(rd) - expected).rounded())
        if let l = likely { p.onTrack = Day.diff(t, l.key) <= left - 1 }
        return p
    }
}

enum Fmt {
    static func rate(_ x: Double) -> String {
        x >= 10 ? String(Int(x.rounded())) : String(format: "%.1f", x)
    }
}
