import SwiftUI
import SwiftData
import WidgetKit
import TelemetryDeck

struct BookDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    let book: Book

    @State private var isRegenerating = false
    @State private var showError = false
    @State private var errorMessage: String?
    @State private var showPaywall = false
    @State private var shareURL: URL?
    @State private var showShareSheet = false

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
                HStack(spacing: 16) {
                    Button {
                        if subscriptionManager.isSubscribed {
                            Task { await regenerateLearnings() }
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        if isRegenerating {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isRegenerating)

                    Button {
                        exportPDF()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(isRegenerating || book.learnings.isEmpty)

                    Button(role: .destructive) {
                        deleteBook()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .disabled(isRegenerating)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showShareSheet, onDismiss: { shareURL = nil }) {
            if let url = shareURL {
                ShareSheet(url: url)
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

    private var sortedLearnings: [Learning] {
        book.learnings.sorted { a, b in
            chapterSortKey(a.chapter) < chapterSortKey(b.chapter)
        }
    }

    private func chapterSortKey(_ chapter: String) -> Int {
        let digits = chapter.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .first(where: { !$0.isEmpty })
        return Int(digits ?? "") ?? Int.max
    }

    private var learningsList: some View {
        LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
            Section {
                ForEach(sortedLearnings) { learning in
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

    private func regenerateLearnings() async {
        isRegenerating = true
        defer { isRegenerating = false }
        do {
            let texts = try await AIService.shared.generateLearnings(for: book.title, author: book.author)
            await MainActor.run {
                for learning in book.learnings { context.delete(learning) }
                book.learnings.removeAll()
                for item in texts {
                    let learning = Learning(text: item.text, chapter: item.chapter, bookTitle: book.title, bookAuthor: book.author)
                    learning.book = book
                    book.learnings.append(learning)
                    context.insert(learning)
                }
                try? context.save()
                syncWidget()
                TelemetryDeck.signal("book.regenerated")
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
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

    private func exportPDF() {
        guard let url = LearningsPDFRenderer.render(
            book: book,
            accentColor: accentColor,
            learnings: sortedLearnings
        ) else { return }
        shareURL = url
        showShareSheet = true
        TelemetryDeck.signal("book.exported")
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

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct LearningCardView: View {
    let learning: Learning
    let accentColor: Color
    @State private var isExpanded = false

    private var headline: String {
        let parts = learning.text.components(separatedBy: ". ")
        return parts.count > 1 ? parts[0] + "." : learning.text
    }

    private var detail: String? {
        let parts = learning.text.components(separatedBy: ". ")
        guard parts.count > 1 else { return nil }
        return parts.dropFirst().joined(separator: ". ")
    }

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

            VStack(alignment: .leading, spacing: 6) {
                if !learning.chapter.isEmpty {
                    Text(learning.chapter)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(accentColor)
                        .textCase(.uppercase)
                }
                Text(headline)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .fixedSize(horizontal: false, vertical: true)

                if isExpanded, let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if detail != nil {
                    Label(isExpanded ? "Show less" : "Read more", systemImage: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(accentColor)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        .onTapGesture {
            guard detail != nil else { return }
            withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
        }
    }
}
