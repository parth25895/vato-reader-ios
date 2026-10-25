import Foundation
import SwiftUI
import UserNotifications
import UIKit
import Observation

// MARK: - Day keys ("YYYY-MM-DD", local time), same format as the web reader

enum Day {
    static var cal: Calendar { Calendar.current }

    static func key(_ d: Date) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 2000, c.month ?? 1, c.day ?? 1)
    }
    static var today: String { key(Date()) }

    static func date(_ k: String) -> Date {
        let p = k.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return Date() }
        return cal.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: 12)) ?? Date()
    }
    static func plus(_ n: Int, from k: String = Day.today) -> String {
        key(cal.date(byAdding: .day, value: n, to: date(k)) ?? Date())
    }
    static func diff(_ a: String, _ b: String) -> Int {
        cal.dateComponents([.day], from: cal.startOfDay(for: date(a)), to: cal.startOfDay(for: date(b))).day ?? 0
    }
    static func short(_ k: String) -> String {
        if k == "earlier" { return "earlier" }
        return date(k).formatted(.dateTime.day().month(.abbreviated))
    }
    static func long(_ k: String) -> String {
        date(k).formatted(.dateTime.day().month(.abbreviated).year())
    }
}

// MARK: - Store

@MainActor
@Observable
final class Store {
    var lib: Library = Library(chapters: [], topics: [], entries: [])
    var loaded = false
    var s: AppState = AppState() { didSet { scheduleSave() } }
    var toastText: String? = nil

    @ObservationIgnored private var saveTask: Task<Void, Never>? = nil
    @ObservationIgnored private var toastTask: Task<Void, Never>? = nil

    static let idleLimit: Double = 20 * 60 * 1000

    init() {
        s = Store.readState() ?? AppState()
    }

    func load() async {
        let l = await Task.detached(priority: .userInitiated) { Library.loadBundled() }.value
        lib = l
        if s.log.isEmpty { rebuildLog() }
        if s.round.start == nil, let first = s.log.keys.sorted().first, !s.read.isEmpty { s.round.start = first }
        closeIdleSitting()
        loaded = true
    }

    // MARK: persistence
    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("vato-state.json")
    }
    private static func readState() -> AppState? {
        guard let d = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(AppState.self, from: d)
    }
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            if Task.isCancelled { return }
            self?.saveNow()
        }
    }
    func saveNow() {
        saveTask?.cancel()
        if let d = try? JSONEncoder().encode(s) {
            try? d.write(to: Store.fileURL, options: .atomic)
        }
    }

    // MARK: toast
    func toast(_ t: String) {
        toastText = t
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            if Task.isCancelled { return }
            withAnimation(.easeOut(duration: 0.25)) { self?.toastText = nil }
        }
    }

    // MARK: tracking helpers
    func isTracked(_ c: Int) -> Bool { s.track[String(c)] != false }
    func isRead(_ id: String) -> Bool { s.read[id] != nil }

    var nextUnread: Vat? {
        lib.entries.first { isTracked($0.c) && s.read[$0.id] == nil }
    }
    func nextUnread(inChapter c: Int) -> Vat? {
        (lib.byChapter[c] ?? []).first { s.read[$0.id] == nil }
    }
    func readCount(_ es: [Vat]) -> Int { es.reduce(0) { $0 + (s.read[$1.id] != nil ? 1 : 0) } }

    private func dayCount(_ k: String, _ d: Int) {
        let n = (s.log[k] ?? 0) + d
        if n > 0 { s.log[k] = n } else { s.log.removeValue(forKey: k) }
    }

    func rebuildLog() {
        var log: [String: Int] = [:]
        for (_, k) in s.read where k != "earlier" { log[k, default: 0] += 1 }
        s.log = log
    }

    func markRead(_ id: String, on k: String = Day.today, quiet: Bool = false) {
        let old = s.read[id]
        if old == k { return }
        if let o = old, o != "earlier" { dayCount(o, -1) }
        s.read[id] = k
        if k != "earlier" {
            dayCount(k, 1)
            if s.round.start == nil { s.round.start = k }
        }
        if !quiet && k == Day.today { sitTick() }
    }

    func unmarkRead(_ id: String) {
        guard let old = s.read[id] else { return }
        if old != "earlier" { dayCount(old, -1) }
        s.read.removeValue(forKey: id)
    }

    func toggleRead(_ id: String) {
        if isRead(id) { unmarkRead(id) } else { markRead(id); afterMark(id) }
        Haptics.tap()
    }

    var roundDone: Bool {
        var tv = 0, rd = 0
        for e in lib.entries where isTracked(e.c) {
            tv += 1
            if s.read[e.id] != nil { rd += 1 }
        }
        return tv > 0 && rd == tv
    }

    func afterMark(_ id: String) {
        guard let e = lib.vat(id), s.read[id] != nil, isTracked(e.c) else { return }
        let es = lib.byChapter[e.c] ?? []
        if es.allSatisfy({ s.read[$0.id] != nil }) {
            toast("Chapter \(e.c) complete" + (roundDone ? " · Round \(s.round.n) complete" : ""))
            Haptics.success()
        }
    }

    func finishRound() {
        let tv = lib.entries.filter { isTracked($0.c) }.count
        let t = Day.today
        s.hist.append(RoundHist(n: s.round.n, start: s.round.start ?? t, end: t, count: tv))
        s.round = RoundInfo(n: s.round.n + 1, start: nil, target: nil)
        s.read = [:]
        Haptics.success()
    }

    func resetRound() {
        for id in Array(s.read.keys) { unmarkRead(id) }
        s.round.start = nil
    }

    func markAllUpTo(_ id: String) -> Int {
        guard let i = lib.index[id] else { return 0 }
        var cnt = 0
        for j in 0...i {
            let e = lib.entries[j]
            if isTracked(e.c) && s.read[e.id] == nil { markRead(e.id, on: "earlier", quiet: true); cnt += 1 }
        }
        return cnt
    }

    func unreadUpTo(_ id: String) -> Int {
        guard let i = lib.index[id] else { return 0 }
        var n = 0
        for j in 0...i where isTracked(lib.entries[j].c) && s.read[lib.entries[j].id] == nil { n += 1 }
        return n
    }

    // MARK: sittings
    static func nowMs() -> Double { Date().timeIntervalSince1970 * 1000 }

    func sitStart() {
        guard s.sit == nil else { return }
        let n = Store.nowMs()
        s.sit = ActiveSitting(s: n, last: n, n: 0)
    }
    func sitTick() {
        if s.sit == nil && s.autoSit { sitStart() }
        if s.sit != nil {
            s.sit!.n += 1
            s.sit!.last = Store.nowMs()
        }
    }
    func activity() {
        if s.sit != nil { s.sit!.last = Store.nowMs() }
    }
    func sitStop(endAt: Double? = nil) {
        guard let a = s.sit else { return }
        let e = endAt ?? Store.nowMs()
        let start = Date(timeIntervalSince1970: a.s / 1000)
        let d = Day.key(start)
        let mins = max(1, Int(((e - a.s) / 60000).rounded()))
        if s.todaySit == nil || s.todaySit!.d != d { s.todaySit = TodaySittings(d: d, list: []) }
        s.todaySit!.list.append(SittingRecord(s: a.s, e: e, n: a.n))
        var rec = s.sitDays[d] ?? SitDay()
        rec.c += 1; rec.m += mins; rec.v += a.n
        let h = Calendar.current.component(.hour, from: start)
        let b = (h >= 5 && h < 12) ? 0 : (h >= 12 && h < 17) ? 1 : 2
        if rec.b.count < 3 { rec.b = [0, 0, 0] }
        rec.b[b] += a.n
        s.sitDays[d] = rec
        s.sit = nil
        if endAt == nil { toast("Sitting saved · \(mins) min · \(a.n) vato") }
    }
    func closeIdleSitting() {
        if let a = s.sit, Store.nowMs() - a.last > Store.idleLimit { sitStop(endAt: a.last) }
    }
    var todaySittings: [SittingRecord] {
        guard let t = s.todaySit, t.d == Day.today else { return [] }
        return t.list
    }

    // MARK: last position / bookmarks / highlights
    func setLast(_ id: String, off: Int) {
        if s.last?.id == id && s.last?.off == off { return }
        s.last = LastPos(id: id, off: off)
    }
    func addBookmark(_ id: String, off: Int) {
        s.bm.append(Bookmark(id: id, off: off, t: Store.nowMs()))
        toast("Bookmarked this line")
        Haptics.tap()
    }
    func removeBookmark(_ b: Bookmark) {
        s.bm.removeAll { $0.id == b.id && $0.t == b.t }
    }
    func applyHighlight(_ id: String, range: NSRange, color: String?) {
        let st = range.location, en = range.location + range.length
        guard en > st else { return }
        var out: [Highlight] = []
        for h in s.hl[id] ?? [] {
            if h.e <= st || h.s >= en { out.append(h); continue }
            if h.s < st { out.append(Highlight(s: h.s, e: st, c: h.c)) }
            if h.e > en { out.append(Highlight(s: en, e: h.e, c: h.c)) }
        }
        if let c = color { out.append(Highlight(s: st, e: en, c: c)) }
        out.sort { $0.s < $1.s }
        if out.isEmpty { s.hl.removeValue(forKey: id) } else { s.hl[id] = out }
        Haptics.tap()
    }
    func toggleFav(_ id: String) {
        if s.fav[id] == true { s.fav.removeValue(forKey: id) } else { s.fav[id] = true }
        Haptics.tap()
    }
    func addTag(_ id: String, _ raw: String) {
        let v = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !v.isEmpty else { return }
        var a = s.tags[id] ?? []
        if !a.contains(v) { a.append(v) }
        s.tags[id] = a
    }
    func removeTag(_ id: String, _ t: String) {
        var a = s.tags[id] ?? []
        a.removeAll { $0 == t }
        if a.isEmpty { s.tags.removeValue(forKey: id) } else { s.tags[id] = a }
    }
    func setNote(_ id: String, _ text: String) {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { s.notes.removeValue(forKey: id) } else { s.notes[id] = text }
    }
    var allTags: [TagCount] {
        var m: [String: Int] = [:]
        for (_, ts) in s.tags { for t in ts { m[t, default: 0] += 1 } }
        return m.sorted { $0.key < $1.key }.map { TagCount(name: $0.key, count: $0.value) }
    }

    // MARK: backup
    func exportBackup() -> String {
        let b = BackupFile(version: 2, data: s)
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        guard let d = try? enc.encode(b) else { return "" }
        return String(data: d, encoding: .utf8) ?? ""
    }
    func importBackup(_ text: String) -> Bool {
        guard let d = text.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8) else { return false }
        if let b = try? JSONDecoder().decode(BackupFile.self, from: d) {
            var n = b.data
            // keep this device's reminder settings
            n.reminderOn = s.reminderOn; n.reminderHour = s.reminderHour; n.reminderMinute = s.reminderMinute
            n.sit = nil
            s = n
            if s.log.isEmpty { rebuildLog() }
            saveNow()
            return true
        }
        return false
    }
    func eraseAll() {
        let keep = s
        var n = AppState()
        n.reminderOn = keep.reminderOn; n.reminderHour = keep.reminderHour; n.reminderMinute = keep.reminderMinute
        s = n
        saveNow()
    }

    // MARK: reminder
    func scheduleReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily-vato"])
        guard s.reminderOn else { return }
        let hour = s.reminderHour, minute = s.reminderMinute
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let c = UNMutableNotificationContent()
            c.title = "Time for vato"
            c.body = "A few minutes of reading keeps your streak going."
            c.sound = .default
            var dc = DateComponents()
            dc.hour = hour
            dc.minute = minute
            let trig = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
            center.add(UNNotificationRequest(identifier: "daily-vato", content: c, trigger: trig))
        }
    }
}

struct TagCount: Identifiable, Hashable {
    let name: String
    let count: Int
    var id: String { name }
}

// MARK: - Haptics

enum Haptics {
    @MainActor static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    @MainActor static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}
