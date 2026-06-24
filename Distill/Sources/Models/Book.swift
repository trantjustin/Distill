import Foundation
import SwiftData

@Model
final class Book {
    var id: UUID
    var title: String
    var author: String
    var coverColor: String
    var coverImageURL: String?
    var dateAdded: Date
    var learnings: [Learning]

    init(title: String, author: String, coverColor: String = "blue", coverImageURL: String? = nil) {
        self.id = UUID()
        self.title = title
        self.author = author
        self.coverColor = coverColor
        self.coverImageURL = coverImageURL
        self.dateAdded = Date()
        self.learnings = []
    }
}
