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
    var summary: String?
    var paradigmShiftTitle: String?
    var paradigmShiftBefore: String?
    var paradigmShiftAfter: String?

    init(title: String, author: String, coverColor: String = "blue", coverImageURL: String? = nil, summary: String? = nil, paradigmShiftTitle: String? = nil, paradigmShiftBefore: String? = nil, paradigmShiftAfter: String? = nil) {
        self.id = UUID()
        self.title = title
        self.author = author
        self.coverColor = coverColor
        self.coverImageURL = coverImageURL
        self.dateAdded = Date()
        self.learnings = []
        self.summary = summary
        self.paradigmShiftTitle = paradigmShiftTitle
        self.paradigmShiftBefore = paradigmShiftBefore
        self.paradigmShiftAfter = paradigmShiftAfter
    }
}
