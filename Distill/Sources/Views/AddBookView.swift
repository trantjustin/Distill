import SwiftUI
import SwiftData
import WidgetKit
import TelemetryDeck

enum AddBookMode: String, CaseIterable {
    case search = "Search"
    case scan   = "Scan ISBN"

    var icon: String {
        switch self {
        case .search: return "magnifyingglass"
        case .scan:   return "barcode.viewfinder"
        }
    }
}

struct AddBookView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false

    var prefillTitle: String = ""
    var prefillAuthor: String = ""

    @State private var mode: AddBookMode = .search

    @State private var title = ""
    @State private var author = ""
    @State private var selectedColor = "indigo"
    @State private var selectedCoverURL: String? = nil
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var showError = false

    private let colors = ["indigo", "blue", "purple", "teal", "green", "orange", "pink", "red"]

    var canGenerate: Bool {
        !title.isEmpty && !author.isEmpty && subscriptionManager.isSubscribed
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    bookPreviewCard

                    modeSelector

                    switch mode {
                    case .search: SearchInputView(title: $title, author: $author, selectedCoverURL: $selectedCoverURL)
                    case .scan:   BarcodeScanInputView(title: $title, author: $author, selectedCoverURL: $selectedCoverURL)
                    }

                    if selectedCoverURL == nil { colorPicker }

                    if !subscriptionManager.isSubscribed { subscriptionWarning }

                    generateButton
                }
                .padding()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .navigationTitle("Add Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
            .onAppear {
                if !prefillTitle.isEmpty {
                    title = prefillTitle
                    author = prefillAuthor
                }
            }
        }
    }

    private var bookPreviewCard: some View {
        Group {
            if let urlString = selectedCoverURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(radius: 12, y: 6)
                    default:
                        placeholderCard
                    }
                }
            } else {
                placeholderCard
            }
        }
        .padding(.top, 8)
    }

    private var placeholderCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(CoverColors.color(for: selectedColor).gradient)
                .frame(width: 120, height: 160)
                .shadow(color: CoverColors.color(for: selectedColor).opacity(0.4), radius: 12, y: 6)
            VStack(spacing: 8) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.9))
                if !title.isEmpty {
                    Text(title)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .lineLimit(3)
                }
            }
        }
    }

    private var modeSelector: some View {
        HStack(spacing: 0) {
            ForEach(AddBookMode.allCases, id: \.self) { m in
                Button {
                    withAnimation(.spring(duration: 0.25)) { mode = m }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: m.icon)
                            .font(.caption)
                        Text(m.rawValue)
                            .font(.subheadline)
                            .fontWeight(mode == m ? .semibold : .regular)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(mode == m ? Color.indigo : Color.clear)
                    .foregroundStyle(mode == m ? .white : .secondary)
                }
            }
        }
        .background(.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cover Color")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
            HStack(spacing: 12) {
                ForEach(colors, id: \.self) { color in
                    Circle()
                        .fill(CoverColors.color(for: color))
                        .frame(width: 30, height: 30)
                        .overlay {
                            if selectedColor == color {
                                Circle()
                                    .strokeBorder(.white, lineWidth: 2.5)
                                    .padding(2)
                            }
                        }
                        .shadow(color: CoverColors.color(for: color).opacity(0.4), radius: 4, y: 2)
                        .onTapGesture { selectedColor = color }
                }
            }
        }
    }

    private var subscriptionWarning: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "crown.fill")
                    .foregroundStyle(.orange)
                Text("Start 7-day free trial to generate learnings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var generateButton: some View {
        Button {
            if subscriptionManager.isSubscribed {
                Task { await generateLearnings() }
            } else {
                showPaywall = true
            }
        } label: {
            Group {
                if isGenerating {
                    HStack(spacing: 10) {
                        ProgressView().tint(.white)
                        Text("Generating Learnings…")
                    }
                } else if subscriptionManager.isSubscribed {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("Generate Learnings")
                            .fontWeight(.semibold)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                        Text("Subscribe to Generate")
                            .fontWeight(.semibold)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canGenerate ? Color.indigo : Color.orange.opacity(0.2))
            .foregroundStyle(canGenerate ? .white : .orange)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(isGenerating)
    }

    private func generateLearnings() async {
        isGenerating = true
        defer { isGenerating = false }

        do {
            let preselectedCover = selectedCoverURL
            let bookTitle = title
            let bookAuthor = author

            async let texts = AIService.shared.generateLearnings(
                for: bookTitle,
                author: bookAuthor
            )

            let resolved = try await texts
            let resolvedCover: String?
            if let cover = preselectedCover {
                resolvedCover = cover
            } else {
                resolvedCover = await BookCoverService.shared.fetchCoverURL(title: bookTitle, author: bookAuthor)
            }

            await MainActor.run {
                let book = Book(title: title, author: author, coverColor: selectedColor, coverImageURL: resolvedCover, summary: resolved.summary.isEmpty ? nil : resolved.summary, paradigmShiftTitle: resolved.paradigmShift?.title, paradigmShiftBefore: resolved.paradigmShift?.before, paradigmShiftAfter: resolved.paradigmShift?.after)
                context.insert(book)

                for item in resolved.learnings {
                    let learning = Learning(text: item.text, chapter: item.chapter, bookTitle: title, bookAuthor: author)
                    learning.book = book
                    book.learnings.append(learning)
                    context.insert(learning)
                }

                try? context.save()
                syncWidget()
                TelemetryDeck.signal("book.added", parameters: [
                    "mode": mode.rawValue
                ])
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func syncWidget() {
        let descriptor = FetchDescriptor<Learning>()
        guard let allLearnings = try? context.fetch(descriptor) else { return }

        Task {
            var coverCache: [String: (Data, String?)] = [:]
            var widgetLearnings: [WidgetLearning] = []

            for learning in allLearnings {
                let urlString = learning.book?.coverImageURL
                var imageData: Data? = nil
                var colorHex: String? = nil

                if let urlString, let url = URL(string: urlString) {
                    if let cached = coverCache[urlString] {
                        imageData = cached.0
                        colorHex = cached.1
                    } else if let (data, _) = try? await URLSession.shared.data(from: url) {
                        let hex = dominantColorHex(from: data)
                        coverCache[urlString] = (data, hex)
                        imageData = data
                        colorHex = hex
                    }
                }
                widgetLearnings.append(WidgetLearning(
                    text: learning.text,
                    bookTitle: learning.bookTitle,
                    bookAuthor: learning.bookAuthor,
                    coverImageURL: urlString,
                    coverImageData: imageData,
                    dominantColorHex: colorHex,
                    coverColor: learning.book?.coverColor,
                    bookSummary: learning.book?.summary
                ))
            }

            WidgetDataManager.saveLearnings(widgetLearnings)
            await MainActor.run { WidgetCenter.shared.reloadAllTimelines() }
        }
    }

    private func dominantColorHex(from data: Data) -> String? {
        guard let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage else { return nil }

        let width = 8
        let height = 8
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &pixels, width: width, height: height,
                                   bitsPerComponent: 8, bytesPerRow: width * 4,
                                   space: colorSpace,
                                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var r = 0, g = 0, b = 0, count = 0
        for i in 0..<(width * height) {
            let base = i * 4
            let pr = Int(pixels[base]), pg = Int(pixels[base+1]), pb = Int(pixels[base+2])
            // Skip very dark or near-white pixels
            let brightness = (pr + pg + pb) / 3
            guard brightness > 30 && brightness < 230 else { continue }
            r += pr; g += pg; b += pb; count += 1
        }
        guard count > 0 else { return nil }
        r /= count; g /= count; b /= count

        // Boost saturation slightly
        let max = Swift.max(r, g, b), min = Swift.min(r, g, b)
        let sat = max > 0 ? Double(max - min) / Double(max) : 0
        if sat < 0.15 {
            // Desaturated — darken it to at least look intentional
            r = r * 70 / 100; g = g * 70 / 100; b = b * 70 / 100
        }

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Search Mode

struct SearchInputView: View {
    @Binding var title: String
    @Binding var author: String
    @Binding var selectedCoverURL: String?

    @State private var query = ""
    @State private var results: [BookSearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var isSelecting = false
    @State private var hasSearched = false

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search by title or author…", text: $query)
                    .autocorrectionDisabled()
                    .onChange(of: query) { _, new in
                        guard !isSelecting else { isSelecting = false; return }
                        searchTask?.cancel()
                        guard new.count > 2 else { results = []; return }
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 400_000_000)
                            guard !Task.isCancelled else { return }
                            await performSearch(new)
                        }
                    }
                if isSearching {
                    ProgressView().scaleEffect(0.8)
                } else if !query.isEmpty {
                    Button { query = ""; results = []; selectedCoverURL = nil } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator, lineWidth: 1))

            if !results.isEmpty {
                VStack(spacing: 0) {
                    ForEach(results) { result in
                        Button {
                            title = result.title
                            author = result.author
                            selectedCoverURL = result.coverURL.map { $0.absoluteString.replacingOccurrences(of: "-M.jpg", with: "-L.jpg") }
                            results = []
                            isSelecting = true
                            query = result.title
                        } label: {
                            HStack(spacing: 12) {
                                Group {
                                    if let url = result.coverURL {
                                        AsyncImage(url: url) { phase in
                                            if case .success(let img) = phase {
                                                img.resizable().scaledToFill()
                                            } else {
                                                Color.indigo.opacity(0.15)
                                                    .overlay { Image(systemName: "book.closed.fill").font(.caption).foregroundStyle(.indigo) }
                                            }
                                        }
                                    } else {
                                        Color.indigo.opacity(0.15)
                                            .overlay { Image(systemName: "book.closed.fill").font(.caption).foregroundStyle(.indigo) }
                                    }
                                }
                                .frame(width: 40, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(result.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                    Text(result.author)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if let year = result.publishYear {
                                        Text(String(year))
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                Spacer()
                                if title == result.title && author == result.author {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.indigo)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }
                        if result.id != results.last?.id {
                            Divider().padding(.leading, 64)
                        }
                    }
                }
                .background(.background, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator, lineWidth: 1))
            }

            if !title.isEmpty {
                selectedBookBadge
            } else if hasSearched && !isSearching && results.isEmpty && query.count > 2 {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        Text("No results found. Enter details manually.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

                    InputField(title: "Book Title", text: $title, placeholder: "e.g. Atomic Habits")
                    InputField(title: "Author", text: $author, placeholder: "e.g. James Clear")
                }
            }
        }
    }

    private var selectedBookBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.medium)
                Text(author).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { title = ""; author = ""; selectedCoverURL = nil } label: {
                Image(systemName: "xmark").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.green.opacity(0.3), lineWidth: 1))
    }

    @MainActor
    private func performSearch(_ q: String) async {
        isSearching = true
        defer { isSearching = false }
        results = (try? await OpenLibraryService.shared.search(query: q)) ?? []
        hasSearched = true
    }
}

// MARK: - Barcode Scan Mode

struct BarcodeScanInputView: View {
    @Binding var title: String
    @Binding var author: String
    @Binding var selectedCoverURL: String?

    @State private var showScanner = false
    @State private var isLookingUp = false
    @State private var scannedISBN: String?
    @State private var lookupError: String?

    var body: some View {
        VStack(spacing: 16) {
            if let isbn = scannedISBN {
                HStack(spacing: 8) {
                    Image(systemName: "barcode")
                        .foregroundStyle(.indigo)
                    Text("ISBN: \(isbn)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Button {
                        scannedISBN = nil
                        title = ""
                        author = ""
                        selectedCoverURL = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }

            if isLookingUp {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Looking up book…").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if !title.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.subheadline).fontWeight(.medium)
                        Text(author).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            } else {
                Button {
                    showScanner = true
                } label: {
                    VStack(spacing: 14) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 44))
                            .foregroundStyle(.indigo)
                        Text("Scan Book Barcode")
                            .fontWeight(.semibold)
                        Text("Point the camera at the ISBN barcode on the back of any book")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(28)
                    .background(.indigo.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(.indigo.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    )
                }
            }

            if lookupError != nil {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text("Book not found. Enter details below to continue.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

                    InputField(title: "Book Title", text: $title, placeholder: "e.g. Atomic Habits")
                    InputField(title: "Author", text: $author, placeholder: "e.g. James Clear")
                }
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            BarcodeScannerView(
                onScanned: { isbn in
                    showScanner = false
                    scannedISBN = isbn
                    Task { await lookupISBN(isbn) }
                },
                onDismiss: { showScanner = false }
            )
            .ignoresSafeArea()
        }
    }

    @MainActor
    private func lookupISBN(_ isbn: String) async {
        isLookingUp = true
        lookupError = nil
        defer { isLookingUp = false }
        if let result = try? await OpenLibraryService.shared.lookupISBN(isbn) {
            title = result.title
            author = result.author
            selectedCoverURL = result.coverURL.map { $0.absoluteString.replacingOccurrences(of: "-M.jpg", with: "-L.jpg") }
        } else {
            lookupError = "Couldn't find this book. Try entering the title manually."
        }
    }
}

// MARK: - Shared Components

struct InputField: View {
    let title: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
            TextField(placeholder, text: $text)
                .padding()
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.separator, lineWidth: 1)
                )
        }
    }
}
