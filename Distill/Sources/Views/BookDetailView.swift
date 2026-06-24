import SwiftUI
import SwiftData
import WidgetKit
import TelemetryDeck

struct BookDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let book: Book

    private var accentColor: Color {
        CoverColors.color(for: book.coverColor)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                learningsList
            }
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    deleteBook()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            BookCoverView(book: book, width: 80, height: 112, cornerRadius: 16)
                .shadow(color: accentColor.opacity(0.4), radius: 10, y: 5)
                .padding(.top, 20)

            VStack(spacing: 4) {
                Text(book.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                Text(book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("\(book.learnings.count) core learnings")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.orange.opacity(0.1), in: Capsule())
        }
        .padding(.bottom, 24)
    }

    private var learningsList: some View {
        LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
            Section {
                ForEach(book.learnings) { learning in
                    LearningCardView(learning: learning, accentColor: accentColor)
                }
            } header: {
                Text("Core Learnings")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.background)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
    }

    private func deleteBook() {
        for learning in book.learnings {
            context.delete(learning)
        }
        context.delete(book)
        try? context.save()
        syncWidget()
        TelemetryDeck.signal("book.deleted")
        dismiss()
    }

    private func syncWidget() {
        let descriptor = FetchDescriptor<Learning>()
        guard let allLearnings = try? context.fetch(descriptor) else { return }
        let widgetLearnings = allLearnings.map {
            WidgetLearning(text: $0.text, bookTitle: $0.bookTitle, bookAuthor: $0.bookAuthor)
        }
        WidgetDataManager.saveLearnings(widgetLearnings)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct LearningCardView: View {
    let learning: Learning
    let accentColor: Color
    @State private var isExpanded = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(accentColor.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(accentColor)
                }

            Text(learning.text)
                .font(.subheadline)
                .lineLimit(isExpanded ? nil : 3)
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        .onTapGesture { isExpanded.toggle() }
    }
}
