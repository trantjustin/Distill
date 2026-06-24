import Foundation

struct BookSearchResult: Identifiable {
    let id: String
    let title: String
    let author: String
    let isbn: String?
    let publishYear: Int?
    let coverURL: URL?
}

struct OpenLibraryService {
    static let shared = OpenLibraryService()

    func search(query: String) async throws -> [BookSearchResult] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "https://openlibrary.org/search.json?q=\(encoded)&limit=10&fields=key,title,author_name,isbn,first_publish_year,cover_i")!

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(OLSearchResponse.self, from: data)

        return response.docs.compactMap { doc in
            guard let title = doc.title else { return nil }
            let author = doc.author_name?.first ?? "Unknown Author"
            let isbn = doc.isbn?.first
            var coverURL: URL?
            if let coverId = doc.cover_i {
                coverURL = URL(string: "https://covers.openlibrary.org/b/id/\(coverId)-M.jpg")
            }
            return BookSearchResult(
                id: doc.key ?? UUID().uuidString,
                title: title,
                author: author,
                isbn: isbn,
                publishYear: doc.first_publish_year,
                coverURL: coverURL
            )
        }
    }

    func lookupISBN(_ isbn: String) async throws -> BookSearchResult? {
        let url = URL(string: "https://openlibrary.org/api/books?bibkeys=ISBN:\(isbn)&format=json&jscmd=data")!
        let (data, _) = try await URLSession.shared.data(from: url)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let bookData = json["ISBN:\(isbn)"] as? [String: Any] else {
            return nil
        }

        let title = bookData["title"] as? String ?? "Unknown Title"
        let authors = bookData["authors"] as? [[String: Any]]
        let author = authors?.first?["name"] as? String ?? "Unknown Author"
        let coverURLString = (bookData["cover"] as? [String: String])?["medium"]
        let coverURL = coverURLString.flatMap { URL(string: $0) }

        return BookSearchResult(
            id: isbn,
            title: title,
            author: author,
            isbn: isbn,
            publishYear: nil,
            coverURL: coverURL
        )
    }
}

private struct OLSearchResponse: Decodable {
    let docs: [OLDoc]
}

private struct OLDoc: Decodable {
    let key: String?
    let title: String?
    let author_name: [String]?
    let isbn: [String]?
    let first_publish_year: Int?
    let cover_i: Int?
}
