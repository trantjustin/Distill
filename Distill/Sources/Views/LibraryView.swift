import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Book.dateAdded, order: .reverse) private var books: [Book]
    @State private var showingAddBook = false

    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty {
                    emptyState
                } else {
                    bookList
                }
            }
            .navigationTitle("My Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddBook = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingAddBook) {
                AddBookView()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundStyle(.indigo.opacity(0.4))
            Text("No books yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Add a book to generate\ncore learnings with AI")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button {
                showingAddBook = true
            } label: {
                Label("Add Your First Book", systemImage: "plus")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.indigo)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding()
    }

    private var bookList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(books) { book in
                    NavigationLink(destination: BookDetailView(book: book)) {
                        BookCardView(book: book)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}

struct BookCoverView: View {
    let book: Book
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    private var accentColor: Color { CoverColors.color(for: book.coverColor) }

    var body: some View {
        if let urlString = book.coverImageURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: height)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                default:
                    fallbackCover
                }
            }
        } else {
            fallbackCover
        }
    }

    private var fallbackCover: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(accentColor.gradient)
            .frame(width: width, height: height)
            .overlay {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: width * 0.35))
                    .foregroundStyle(.white.opacity(0.8))
            }
    }
}

struct BookCardView: View {
    let book: Book

    private var accentColor: Color {
        CoverColors.color(for: book.coverColor)
    }

    var body: some View {
        HStack(spacing: 16) {
            BookCoverView(book: book, width: 56, height: 80, cornerRadius: 8)
                .shadow(color: accentColor.opacity(0.4), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 6) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text("\(book.learnings.count) learnings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}
