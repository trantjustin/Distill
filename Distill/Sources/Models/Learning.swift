import Foundation
import SwiftData

@Model
final class Learning {
    var id: UUID
    var text: String
    var bookTitle: String
    var bookAuthor: String
    var dateAdded: Date
    var lastReviewed: Date?
    var reviewCount: Int
    var book: Book?

    init(text: String, bookTitle: String, bookAuthor: String) {
        self.id = UUID()
        self.text = text
        self.bookTitle = bookTitle
        self.bookAuthor = bookAuthor
        self.dateAdded = Date()
        self.lastReviewed = nil
        self.reviewCount = 0
    }
}
