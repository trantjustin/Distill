import SwiftUI
import SwiftData
import TelemetryDeck

@main
struct DistillApp: App {
    init() {
        let config = TelemetryDeck.Config(appID: "9400970A-7730-4CC7-99B5-37A7E6C9C96F")
        TelemetryDeck.initialize(config: config)

        Task {
            await SubscriptionManager.shared.loadProducts()
            await SubscriptionManager.shared.updateSubscriptionStatus()
        }
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Book.self, Learning.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @Environment(\.scenePhase) private var scenePhase
    @State private var pendingTitle: String = ""
    @State private var pendingAuthor: String = ""
    @State private var showAddBook = false

    private let appGroupID = "group.com.jtrant.distill"
    private let pendingBookKey = "pending_shared_book"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .sheet(isPresented: $showAddBook) {
                    AddBookView(prefillTitle: pendingTitle, prefillAuthor: pendingAuthor)
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                checkForSharedBook()
            }
        }
    }

    private func checkForSharedBook() {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let pending = defaults.dictionary(forKey: pendingBookKey) as? [String: String],
              let title = pending["title"], !title.isEmpty else { return }
        defaults.removeObject(forKey: pendingBookKey)
        pendingTitle = title
        pendingAuthor = pending["author"] ?? ""
        showAddBook = true
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "distill",
              url.host == "add" else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        pendingTitle = components?.queryItems?.first(where: { $0.name == "title" })?.value ?? ""
        pendingAuthor = components?.queryItems?.first(where: { $0.name == "author" })?.value ?? ""
        showAddBook = true
    }
}
