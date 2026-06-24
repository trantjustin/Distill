import Foundation

struct BookCoverService {
    static let shared = BookCoverService()

    func fetchCoverURL(title: String, author: String) async -> String? {
        // Search Open Library for the work to get an ISBN/cover ID
        let query = "\(title) \(author)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let searchURL = URL(string: "https://openlibrary.org/search.json?q=\(query)&limit=5&fields=isbn,cover_i,title")!

        guard let (data, _) = try? await URLSession.shared.data(from: searchURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let docs = json["docs"] as? [[String: Any]],
              let first = docs.first
        else { return nil }

        // Prefer cover_i (cover ID) — most reliable
        if let coverId = first["cover_i"] as? Int {
            return "https://covers.openlibrary.org/b/id/\(coverId)-L.jpg"
        }

        // Fall back to first ISBN
        if let isbns = first["isbn"] as? [String], let isbn = isbns.first {
            return "https://covers.openlibrary.org/b/isbn/\(isbn)-L.jpg"
        }

        return nil
    }
}
