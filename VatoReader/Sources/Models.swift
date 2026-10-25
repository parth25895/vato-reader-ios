import Foundation

// MARK: - Library (bundled text)

struct Chapter: Identifiable, Hashable {
    let id: Int
    let name: String
    let gu: String
}

struct Topic: Identifiable, Hashable {
    let id: Int
    let ro: String
    let gu: String
    var ids: [String]
}

struct Vat: Identifiable, Hashable {
    let id: String
    let c: Int
    let n: Int
    let t: String
    let r: String
    let x: String
    let tp: [Int]
    var len: Int { (x as NSString).length }
}

private struct RawLibrary: Decodable {
    struct RC: Decodable { let id: Int; let name: String?; let gu: String? }
    struct RT: Decodable { let id: Int; let ro: String?; let gu: String? }
    struct RE: Decodable { let id: Int; let c: Int; let n: Int; let t: String?; let r: String?; let x: String?; let tp: [Int]? }
    let chapters: [RC]
    let topics: [RT]
    let entries: [RE]
}

final class Library {
    let chapters: [Chapter]
    let topics: [Topic]
    let entries: [Vat]
    let index: [String: Int]
    let byChapter: [Int: [Vat]]
    let chapterById: [Int: Chapter]
    let topicById: [Int: Topic]

    init(chapters: [Chapter], topics: [Topic], entries: [Vat]) {
        var idx: [String: Int] = [:]
        var byCh: [Int: [Vat]] = [:]
        var tIds: [Int: [String]] = [:]
        for (i, e) in entries.enumerated() {
            idx[e.id] = i
            byCh[e.c, default: []].append(e)
            for t in e.tp { tIds[t, default: []].append(e.id) }
        }
        var tps: [Topic] = []
        for t in topics {
            var tt = t
            tt.ids = tIds[t.id] ?? []
            tps.append(tt)
        }
        self.chapters = chapters
        self.topics = tps
        self.entries = entries
        self.index = idx
        self.byChapter = byCh
        self.chapterById = Dictionary(uniqueKeysWithValues: chapters.map { ($0.id, $0) })
        self.topicById = Dictionary(uniqueKeysWithValues: tps.map { ($0.id, $0) })
    }

    static func loadBundled() -> Library {
        guard let url = Bundle.main.url(forResource: "swamini-vato", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode(RawLibrary.self, from: data) else {
            return Library(chapters: [], topics: [], entries: [])
        }
        let ch = raw.chapters.map { Chapter(id: $0.id, name: $0.name ?? "Chapter \($0.id)", gu: ($0.gu ?? "").trimmingCharacters(in: .whitespacesAndNewlines)) }
        let tp = raw.topics.map { Topic(id: $0.id, ro: $0.ro ?? "", gu: ($0.gu ?? "").trimmingCharacters(in: .whitespacesAndNewlines), ids: []) }
        let en = raw.entries.map { Vat(id: "v\($0.id)", c: $0.c, n: $0.n, t: ($0.t ?? "").trimmingCharacters(in: .whitespacesAndNewlines), r: ($0.r ?? "").trimmingCharacters(in: .whitespacesAndNewlines), x: ($0.x ?? "").trimmingCharacters(in: .whitespacesAndNewlines), tp: $0.tp ?? []) }
        return Library(chapters: ch, topics: tp, entries: en)
    }

    func vat(_ id: String) -> Vat? {
        guard let i = index[id] else { return nil }
        return entries[i]
    }
}

// MARK: - User state (same shape as the web reader's backup, so backups move across)

struct Highlight: Codable, Hashable {
    var s: Int
    var e: Int
    var c: String
}

struct LastPos: Codable, Hashable {
    var id: String
    var off: Int
}

struct RoundInfo: Codable, Hashable {
    var n: Int = 1
    var start: String? = nil
    var target: String? = nil
}

struct RoundHist: Codable, Hashable, Identifiable {
    var n: Int
    var start: String
    var end: String
    var count: Int
    var id: Int { n }
}

struct ActiveSitting: Codable, Hashable {
    var s: Double   // ms since 1970
    var last: Double
    var n: Int
}

struct SittingRecord: Codable, Hashable {
    var s: Double
    var e: Double
    var n: Int
}

struct TodaySittings: Codable, Hashable {
    var d: String
    var list: [SittingRecord]
}

struct SitDay: Codable, Hashable {
    var c: Int = 0
    var m: Int = 0
    var v: Int = 0
    var b: [Int] = [0, 0, 0]
}

struct Bookmark: Codable, Hashable, Identifiable {
    var id: String
    var off: Int
    var t: Double
    var key: String { "\(id)-\(Int(t))" }
}

struct AppState: Codable {
    var fav: [String: Bool] = [:]
    var tags: [String: [String]] = [:]
    var notes: [String: String] = [:]
    var hl: [String: [Highlight]] = [:]
    var read: [String: String] = [:]
    var track: [String: Bool] = [:]
    var last: LastPos? = nil
    var resume: Bool = true
    var size: Double = 21
    var theme: String = "auto"        // auto | light | dark
    var rfont: String = "serif"
    var rbg: String = "app"           // app | paper | sepia | grey | dusk | night
    var lineSpacing: Double = 1.0     // multiplier on comfortable default
    var round: RoundInfo = RoundInfo()
    var hist: [RoundHist] = []
    var log: [String: Int] = [:]
    var sit: ActiveSitting? = nil
    var todaySit: TodaySittings? = nil
    var sitDays: [String: SitDay] = [:]
    var bm: [Bookmark] = []
    var autoSit: Bool = true
    var reminderOn: Bool = false
    var reminderHour: Int = 6
    var reminderMinute: Int = 30
    var keepAwake: Bool = false

    init() {}

    enum CodingKeys: String, CodingKey {
        case fav, tags, notes, hl, read, track, last, resume, size, theme, rfont, rbg, lineSpacing, round, hist, log, sit, todaySit, sitDays, bm, autoSit, reminderOn, reminderHour, reminderMinute, keepAwake
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppState()
        fav = (try? c.decodeIfPresent([String: Bool].self, forKey: .fav)) ?? d.fav
        tags = (try? c.decodeIfPresent([String: [String]].self, forKey: .tags)) ?? d.tags
        notes = (try? c.decodeIfPresent([String: String].self, forKey: .notes)) ?? d.notes
        hl = (try? c.decodeIfPresent([String: [Highlight]].self, forKey: .hl)) ?? d.hl
        read = (try? c.decodeIfPresent([String: String].self, forKey: .read)) ?? d.read
        track = (try? c.decodeIfPresent([String: Bool].self, forKey: .track)) ?? d.track
        last = (try? c.decodeIfPresent(LastPos.self, forKey: .last)) ?? nil
        resume = (try? c.decodeIfPresent(Bool.self, forKey: .resume)) ?? d.resume
        size = (try? c.decodeIfPresent(Double.self, forKey: .size)) ?? d.size
        theme = (try? c.decodeIfPresent(String.self, forKey: .theme)) ?? d.theme
        rfont = (try? c.decodeIfPresent(String.self, forKey: .rfont)) ?? d.rfont
        rbg = (try? c.decodeIfPresent(String.self, forKey: .rbg)) ?? d.rbg
        lineSpacing = (try? c.decodeIfPresent(Double.self, forKey: .lineSpacing)) ?? d.lineSpacing
        round = (try? c.decodeIfPresent(RoundInfo.self, forKey: .round)) ?? d.round
        hist = (try? c.decodeIfPresent([RoundHist].self, forKey: .hist)) ?? d.hist
        log = (try? c.decodeIfPresent([String: Int].self, forKey: .log)) ?? d.log
        sit = (try? c.decodeIfPresent(ActiveSitting.self, forKey: .sit)) ?? nil
        todaySit = (try? c.decodeIfPresent(TodaySittings.self, forKey: .todaySit)) ?? nil
        sitDays = (try? c.decodeIfPresent([String: SitDay].self, forKey: .sitDays)) ?? d.sitDays
        bm = (try? c.decodeIfPresent([Bookmark].self, forKey: .bm)) ?? d.bm
        autoSit = (try? c.decodeIfPresent(Bool.self, forKey: .autoSit)) ?? d.autoSit
        reminderOn = (try? c.decodeIfPresent(Bool.self, forKey: .reminderOn)) ?? d.reminderOn
        reminderHour = (try? c.decodeIfPresent(Int.self, forKey: .reminderHour)) ?? d.reminderHour
        reminderMinute = (try? c.decodeIfPresent(Int.self, forKey: .reminderMinute)) ?? d.reminderMinute
        keepAwake = (try? c.decodeIfPresent(Bool.self, forKey: .keepAwake)) ?? d.keepAwake
    }
}

/// The web reader exports `{ "version": 2, "data": { ... } }`.
struct BackupFile: Codable {
    var version: Int
    var data: AppState
}
