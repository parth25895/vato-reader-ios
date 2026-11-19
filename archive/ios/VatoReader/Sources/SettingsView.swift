import SwiftUI
import UniformTypeIdentifiers

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

struct SettingsView: View {
    @Environment(Store.self) private var store
    @Environment(\.palette) private var p
    @State private var showStyle = false
    @State private var pasteText = ""
    @State private var showPaste = false
    @State private var exporting = false
    @State private var importing = false
    @State private var confirmErase = false

    var body: some View {
        @Bindable var store = store
        let reminderBinding = Binding<Date>(
            get: { Calendar.current.date(from: DateComponents(hour: store.s.reminderHour, minute: store.s.reminderMinute)) ?? Date() },
            set: { d in
                let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                store.s.reminderHour = c.hour ?? 6
                store.s.reminderMinute = c.minute ?? 30
                store.scheduleReminder()
            }
        )
        NavigationStack {
            Form {
                Section("Reading") {
                    Button { showStyle = true } label: {
                        HStack {
                            Label("Font, size and background", systemImage: "textformat")
                            Spacer()
                            Text(Typo.readingFont(store.s.rfont).name).foregroundStyle(p.cMuted)
                        }
                    }
                    .foregroundStyle(p.cInk)
                    Toggle("Open where I left off", isOn: $store.s.resume)
                    Toggle("Start a sitting when I mark a vat read", isOn: $store.s.autoSit)
                }
                .listRowBackground(p.cSurface)

                Section {
                    Toggle("Daily reminder", isOn: Binding(get: { store.s.reminderOn }, set: { store.s.reminderOn = $0; store.scheduleReminder() }))
                    if store.s.reminderOn {
                        DatePicker("Time", selection: reminderBinding, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Reminder")
                } footer: {
                    Text("A gentle notification once a day to read a few vato.")
                }
                .listRowBackground(p.cSurface)

                Section {
                    Button { exporting = true } label: { Label("Export backup file", systemImage: "square.and.arrow.up") }
                    Button { UIPasteboard.general.string = store.exportBackup(); store.toast("Backup copied") } label: { Label("Copy backup as text", systemImage: "doc.on.doc") }
                    Button { importing = true } label: { Label("Import backup file", systemImage: "square.and.arrow.down") }
                    Button { showPaste = true } label: { Label("Paste backup text", systemImage: "doc.on.clipboard") }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Moves your progress, notes, highlights and bookmarks. It also accepts backups copied from the Vato Reader web page (More → Backup → Export).")
                }
                .listRowBackground(p.cSurface)

                Section {
                    Button(role: .destructive) { confirmErase = true } label: { Label("Erase all my data", systemImage: "trash") }
                } footer: {
                    Text("Vato Reader · \(store.lib.entries.count.formatted()) vato in \(store.lib.chapters.count) chapters. Text is stored on this device and works offline.")
                }
                .listRowBackground(p.cSurface)
            }
            .scrollContentBackground(.hidden)
            .background(p.cBg.ignoresSafeArea())
            .navigationTitle("Settings")
            .tint(p.cAccent)
            .sheet(isPresented: $showStyle) {
                ReaderStyleSheet()
                    .environment(store)
                    .environment(\.palette, p)
                    .presentationDetents([.medium, .large])
                    .presentationBackground(.regularMaterial)
            }
            .sheet(isPresented: $showPaste) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Paste the backup text below. This replaces the progress on this phone.")
                            .font(.footnote).foregroundStyle(p.cMuted)
                        TextEditor(text: $pasteText)
                            .font(.system(.footnote, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 12).fill(p.cSurface2))
                    }
                    .padding(18)
                    .background(p.cBg.ignoresSafeArea())
                    .navigationTitle("Paste backup")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showPaste = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Import") {
                                if store.importBackup(pasteText) { store.toast("Backup restored"); pasteText = ""; showPaste = false }
                                else { store.toast("That is not a valid backup") }
                            }
                        }
                        ToolbarItem(placement: .bottomBar) {
                            Button("Paste from clipboard") { pasteText = UIPasteboard.general.string ?? "" }
                        }
                    }
                }
                .environment(\.palette, p)
            }
            .fileExporter(isPresented: $exporting, document: BackupDocument(text: store.exportBackup()), contentType: .json, defaultFilename: "vato-backup-\(Day.today)") { result in
                if case .success = result { store.toast("Backup saved") }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .plainText, .text]) { result in
                guard case .success(let url) = result else { return }
                let ok = url.startAccessingSecurityScopedResource()
                defer { if ok { url.stopAccessingSecurityScopedResource() } }
                if let d = try? Data(contentsOf: url), let t = String(data: d, encoding: .utf8), store.importBackup(t) {
                    store.toast("Backup restored")
                } else {
                    store.toast("That file is not a valid backup")
                }
            }
            .confirmationDialog("Erase all your data?", isPresented: $confirmErase, titleVisibility: .visible) {
                Button("Erase everything", role: .destructive) { store.eraseAll(); store.toast("Erased") }
            } message: {
                Text("Read marks, rounds, notes, highlights, tags, bookmarks and favourites are removed. Export a backup first if you might want them back.")
            }
        }
    }
}
