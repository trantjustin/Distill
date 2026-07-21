import Foundation

public struct WidgetLearning: Codable, Sendable {
    public let text: String
    public let bookTitle: String
    public let bookAuthor: String
    public let coverImageURL: String?
    public let coverImageData: Data?
    public let dominantColorHex: String?
    public let coverColor: String?
    public let bookSummary: String?
    public let chapter: String?

    public init(text: String, bookTitle: String, bookAuthor: String, coverImageURL: String? = nil, coverImageData: Data? = nil, dominantColorHex: String? = nil, coverColor: String? = nil, bookSummary: String? = nil, chapter: String? = nil) {
        self.text = text
        self.bookTitle = bookTitle
        self.bookAuthor = bookAuthor
        self.coverImageURL = coverImageURL
        self.coverImageData = coverImageData
        self.dominantColorHex = dominantColorHex
        self.coverColor = coverColor
        self.bookSummary = bookSummary
        self.chapter = chapter
    }
}

public struct WidgetDataManager {
    public static let appGroupID = "group.com.jtrant.distill"
    public static let learningsKey = "widget_learnings"
    public static let todayLearningKey = "widget_today_learning"
    public static let booksKey = "widget_books"

    public static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    public static func saveLearnings(_ learnings: [WidgetLearning]) {
        guard let defaults = sharedDefaults else { return }
        if let data = try? JSONEncoder().encode(learnings) {
            defaults.set(data, forKey: learningsKey)
        }
        // Deduplicate to one representative entry per book (preserves summary)
        var seen = Set<String>()
        var books: [WidgetLearning] = []
        for l in learnings {
            if seen.insert(l.bookTitle).inserted { books.append(l) }
        }
        if let data = try? JSONEncoder().encode(books) {
            defaults.set(data, forKey: booksKey)
        }
        rotateTodayLearning(from: learnings)
    }

    public static func loadBooks() -> [WidgetLearning] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: booksKey),
              let books = try? JSONDecoder().decode([WidgetLearning].self, from: data) else {
            return []
        }
        return books
    }

    public static func loadLearnings() -> [WidgetLearning] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: learningsKey),
              let learnings = try? JSONDecoder().decode([WidgetLearning].self, from: data) else {
            return []
        }
        return learnings
    }

    public static func saveTodayLearning(_ learning: WidgetLearning) {
        guard let defaults = sharedDefaults else { return }
        if let data = try? JSONEncoder().encode(learning) {
            defaults.set(data, forKey: todayLearningKey)
        }
    }

    public static func loadTodayLearning() -> WidgetLearning? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: todayLearningKey),
              let learning = try? JSONDecoder().decode(WidgetLearning.self, from: data) else {
            return nil
        }
        return learning
    }

    public static func rotateTodayLearning(from learnings: [WidgetLearning]) {
        guard !learnings.isEmpty else { return }
        let random = learnings.randomElement()!
        saveTodayLearning(random)
    }
}
