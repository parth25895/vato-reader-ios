import SwiftUI

struct ReaderTarget: Identifiable, Equatable {
    let id = UUID()
    var vatId: String
    var off: Int
}

@MainActor
@Observable
final class Router {
    var reader: ReaderTarget? = nil
    var tab: Int = 0
    var review = false

    func open(_ vatId: String, off: Int = 0) {
        reader = ReaderTarget(vatId: vatId, off: off)
    }
}

@main
struct VatoReaderApp: App {
    @State private var store = Store()
    @State private var router = Router()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(router)
                .task {
                    await store.load()
                    if store.s.resume, let l = store.s.last, store.lib.vat(l.id) != nil {
                        router.open(l.id, off: l.off)
                    }
                }
        }
        .onChange(of: phase) { _, p in
            if p == .background || p == .inactive { store.saveNow() }
            if p == .active { store.closeIdleSitting() }
        }
    }
}

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.colorScheme) private var systemScheme

    var forcedScheme: ColorScheme? {
        switch store.s.rbg {
        case "paper", "sepia", "grey": return .light
        case "dusk", "night": return .dark
        default:
            switch store.s.theme {
            case "light": return .light
            case "dark": return .dark
            default: return nil
            }
        }
    }

    var body: some View {
        @Bindable var router = router
        let scheme = forcedScheme ?? systemScheme
        let p = Palette.resolve(rbg: store.s.rbg, scheme: scheme)
        Group {
            if store.loaded {
                TabView(selection: $router.tab) {
                    HomeView().tabItem { Label("Home", systemImage: "book.closed") }.tag(0)
                    SearchView().tabItem { Label("Search", systemImage: "magnifyingglass") }.tag(1)
                    SavedView().tabItem { Label("Saved", systemImage: "bookmark") }.tag(2)
                    StatsView().tabItem { Label("Progress", systemImage: "chart.bar.xaxis") }.tag(3)
                    SettingsView().tabItem { Label("Settings", systemImage: "slider.horizontal.3") }.tag(4)
                }
                .tint(p.cAccent)
            } else {
                SplashView()
            }
        }
        .environment(\.palette, p)
        .preferredColorScheme(forcedScheme)
        .toasts()
        .fullScreenCover(item: $router.reader) { t in
            ReaderView(start: t)
                .environment(store)
                .environment(router)
                .environment(\.palette, p)
                .preferredColorScheme(forcedScheme)
        }
        .fullScreenCover(isPresented: $router.review) {
            ReviewDeckView()
                .environment(store)
                .environment(router)
                .environment(\.palette, p)
                .preferredColorScheme(forcedScheme)
        }
    }
}

struct SplashView: View {
    @Environment(\.palette) private var p
    var body: some View {
        ZStack {
            p.cBg.ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(p.cGold)
                Text("Vato")
                    .font(Typo.display)
                    .foregroundStyle(p.cInk)
                ProgressView().tint(p.cMuted)
            }
        }
    }
}
