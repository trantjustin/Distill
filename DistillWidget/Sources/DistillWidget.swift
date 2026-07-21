import WidgetKit
import SwiftUI
import AppIntents
import UIKit

// MARK: - Configuration Intent

enum WidgetRefreshRate: String, AppEnum {
    case frequent = "frequent"
    case twiceDaily = "twiceDaily"
    case daily = "daily"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Refresh Rate"
    static var caseDisplayRepresentations: [WidgetRefreshRate: DisplayRepresentation] = [
        .frequent:   DisplayRepresentation(title: "Every 8 Hours"),
        .twiceDaily: DisplayRepresentation(title: "Twice Daily"),
        .daily:      DisplayRepresentation(title: "Daily"),
    ]

    var interval: TimeInterval {
        switch self {
        case .frequent:   return 8 * 60 * 60
        case .twiceDaily: return 12 * 60 * 60
        case .daily:      return 24 * 60 * 60
        }
    }
}

enum WidgetDisplayMode: String, AppEnum {
    case rotateLearnings = "rotateLearnings"
    case bookSummary = "bookSummary"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Display Mode"
    static var caseDisplayRepresentations: [WidgetDisplayMode: DisplayRepresentation] = [
        .rotateLearnings: DisplayRepresentation(title: "Rotate Learnings"),
        .bookSummary:     DisplayRepresentation(title: "Book Summary"),
    ]
}

struct DistillWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Distill Widget"
    static var description = IntentDescription("Customize your Distill widget.")

    @Parameter(title: "Display Mode", default: .rotateLearnings)
    var displayMode: WidgetDisplayMode

    @Parameter(title: "Refresh Rate", default: .frequent)
    var refreshRate: WidgetRefreshRate

    @Parameter(title: "Show Book Title", default: true)
    var showBookTitle: Bool

    @Parameter(title: "Show Author", default: true)
    var showAuthor: Bool
}

// MARK: - Timeline

struct LearningEntry: TimelineEntry {
    let date: Date
    let learning: WidgetLearning?
    let configuration: DistillWidgetIntent
    let isSummaryMode: Bool
    var hasSummary: Bool {
        guard let s = learning?.bookSummary else { return false }
        return !s.isEmpty
    }
    var displayText: String? {
        guard let learning else { return nil }
        if isSummaryMode {
            guard let summary = learning.bookSummary, !summary.isEmpty else { return nil }
            return summary
        }
        return learning.text
    }
}

struct LearningProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LearningEntry {
        LearningEntry(
            date: Date(),
            learning: WidgetLearning(
                text: "Habits are the compound interest of self-improvement.",
                bookTitle: "Atomic Habits",
                bookAuthor: "James Clear",
                bookSummary: "Atomic Habits argues that tiny 1% improvements compound into remarkable results over time. The book introduces the Four Laws of Behavior Change as a framework for building good habits and breaking bad ones. By focusing on systems rather than goals, readers transform their identity and achieve lasting change.",
                chapter: "Chapter 1: The Surprising Power of Atomic Habits"
            ),
            configuration: DistillWidgetIntent(),
            isSummaryMode: false
        )
    }

    func snapshot(for configuration: DistillWidgetIntent, in context: Context) async -> LearningEntry {
        let isSummary = configuration.displayMode == .bookSummary
        WidgetDataManager.saveDisplayMode(isSummary ? "bookSummary" : "rotateLearnings")
        let learning = isSummary
            ? WidgetDataManager.loadBooks().first
            : WidgetDataManager.loadTodayLearning()
        return LearningEntry(date: Date(), learning: learning, configuration: configuration, isSummaryMode: isSummary)
    }

    func timeline(for configuration: DistillWidgetIntent, in context: Context) async -> Timeline<LearningEntry> {
        let isSummary = configuration.displayMode == .bookSummary
        WidgetDataManager.saveDisplayMode(isSummary ? "bookSummary" : "rotateLearnings")
        var entries: [LearningEntry] = []
        var date = Date()

        let interval = configuration.refreshRate.interval
        if isSummary {
            // Use the deduplicated per-book store so bookSummary is always populated
            let books = WidgetDataManager.loadBooks()
            let count = max(5, books.count)
            for i in 0..<count {
                let learning: WidgetLearning? = books.isEmpty ? nil : books[i % books.count]
                entries.append(LearningEntry(date: date, learning: learning, configuration: configuration, isSummaryMode: true))
                date = date.addingTimeInterval(interval)
            }
        } else {
            let learnings = WidgetDataManager.loadLearnings()
            for i in 0..<5 {
                let learning: WidgetLearning? = learnings.isEmpty ? nil : learnings[i % learnings.count]
                entries.append(LearningEntry(date: date, learning: learning, configuration: configuration, isSummaryMode: false))
                date = date.addingTimeInterval(interval)
            }
        }

        return Timeline(entries: entries, policy: .atEnd)
    }
}

// MARK: - Text Helpers

func truncateToSentences(_ text: String, maxSentences: Int) -> String {
    let parts = text.components(separatedBy: ". ")
    let selected = parts.prefix(maxSentences)
    let joined = selected.joined(separator: ". ")
    if joined.last == "." || joined.last == "!" || joined.last == "?" { return joined }
    return joined + "."
}

func truncateToCharacters(_ text: String, max: Int) -> String {
    guard text.count > max else { return text }
    let cut = String(text.prefix(max))
    let trimmed = cut.lastIndex(of: " ").map { String(cut[..<$0]) } ?? cut
    return trimmed + "…"
}

// MARK: - Shared Components

struct BookCoverThumbnail: View {
    let imageData: Data?
    let width: CGFloat
    let height: CGFloat

    var uiImage: UIImage? {
        imageData.flatMap { UIImage(data: $0) }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.white.opacity(0.12))
            .frame(width: width, height: height)
            .overlay {
                if let image = uiImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    Image(systemName: "book.closed.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(width: width, height: height)
            .clipped()
    }
}

// MARK: - Widget Views

struct DistillWidgetEntryView: View {
    var entry: LearningEntry
    @Environment(\.widgetFamily) var family

    var showTitle: Bool { entry.configuration.showBookTitle }
    var showAuthor: Bool { entry.configuration.showAuthor }

    var body: some View {
        switch family {
        case .systemSmall:  SmallWidgetView(entry: entry, showTitle: showTitle)
        case .systemMedium: MediumWidgetView(entry: entry, showTitle: showTitle, showAuthor: showAuthor)
        case .systemLarge:  LargeWidgetView(entry: entry, showTitle: showTitle, showAuthor: showAuthor)
        default:            MediumWidgetView(entry: entry, showTitle: showTitle, showAuthor: showAuthor)
        }
    }
}

struct SmallWidgetView: View {
    let entry: LearningEntry
    let showTitle: Bool

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if entry.isSummaryMode && !entry.hasSummary {
                Text("Regenerate your book in Distill to see a summary here.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if let learning = entry.learning, let displayText = entry.displayText {
                if entry.isSummaryMode {
                    Text("SUMMARY")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.bottom, 4)
                } else {
                    Text((learning.chapter ?? "LEARNING").uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 4)
                }
                Text(entry.isSummaryMode
                    ? truncateToCharacters(displayText, max: 220)
                    : truncateToSentences(displayText, maxSentences: 1))
                    .font(entry.isSummaryMode
                        ? .system(size: 10, design: .serif).weight(.regular)
                        : .system(.caption, design: .serif).weight(.medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(entry.isSummaryMode ? 9 : 6)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                if showTitle {
                    attributionText(learning: learning)
                        .padding(.top, 6)
                }
            } else {
                Text("Add a book in Distill to see learnings here.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .containerBackground(for: .widget) {
            widgetBackground(dominantHex: entry.learning?.dominantColorHex, coverColor: entry.learning?.coverColor)
        }
    }

    private func attributionText(learning: WidgetLearning) -> some View {
        Text(learning.bookTitle)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.white.opacity(0.55))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct MediumWidgetView: View {
    let entry: LearningEntry
    let showTitle: Bool
    let showAuthor: Bool

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if entry.isSummaryMode && !entry.hasSummary {
                Text("Regenerate your book in Distill to see a summary here.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if let learning = entry.learning, let displayText = entry.displayText {
                if entry.isSummaryMode {
                    Text("BOOK SUMMARY")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.bottom, 5)
                } else {
                    Text((learning.chapter ?? "LEARNING").uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 5)
                }
                Text(entry.isSummaryMode
                    ? truncateToCharacters(displayText, max: 380)
                    : truncateToSentences(displayText, maxSentences: 2))
                    .font(entry.isSummaryMode
                        ? .system(size: 11, design: .serif).weight(.regular)
                        : .system(.subheadline, design: .serif).weight(.medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(entry.isSummaryMode ? 9 : 6)
                    .minimumScaleFactor(0.55)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                attributionRow(learning: learning)
                    .padding(.top, 8)
            } else {
                Text("Open Distill and add a book to see learnings here.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .containerBackground(for: .widget) {
            widgetBackground(dominantHex: entry.learning?.dominantColorHex, coverColor: entry.learning?.coverColor)
        }
    }

    private func attributionRow(learning: WidgetLearning) -> some View {
        let text: String = {
            switch (showTitle, showAuthor) {
            case (true, true):   return "\(learning.bookTitle)  |  \(learning.bookAuthor)"
            case (true, false):  return learning.bookTitle
            case (false, true):  return learning.bookAuthor
            case (false, false): return ""
            }
        }()
        return Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white.opacity(0.5))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct LargeWidgetView: View {
    let entry: LearningEntry
    let showTitle: Bool
    let showAuthor: Bool

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if entry.isSummaryMode && !entry.hasSummary {
                Text("Regenerate your book in Distill to see a full summary here.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if let learning = entry.learning, let displayText = entry.displayText {
                if entry.isSummaryMode {
                    Text("BOOK SUMMARY")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.bottom, 6)
                } else {
                    Text("\u{201C}")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white.opacity(0.18))
                        .padding(.bottom, -20)
                    Text((learning.chapter ?? "LEARNING").uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 4)
                }

                Text(entry.isSummaryMode
                    ? truncateToCharacters(displayText, max: 700)
                    : truncateToSentences(displayText, maxSentences: 4))
                    .font(entry.isSummaryMode
                        ? .system(size: 13, design: .serif).weight(.regular)
                        : .system(.body, design: .serif).weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(entry.isSummaryMode ? 18 : 12)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                if showTitle || showAuthor {
                    let attribution: String = {
                        switch (showTitle, showAuthor) {
                        case (true, true):   return "\(learning.bookTitle)  |  \(learning.bookAuthor)"
                        case (true, false):  return learning.bookTitle
                        case (false, true):  return learning.bookAuthor
                        default:             return ""
                        }
                    }()
                    Text(attribution)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 10)
                }
            } else {
                Text("Add books in Distill to see core learnings here.")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .containerBackground(for: .widget) {
            widgetBackground(dominantHex: entry.learning?.dominantColorHex, coverColor: entry.learning?.coverColor)
        }
    }
}

@ViewBuilder
func widgetBackground(dominantHex: String?, coverColor: String?) -> some View {
    if let hex = dominantHex, let color = Color(hex: hex) {
        LinearGradient(
            colors: [color.darkened(by: 0.25), color],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    } else {
        LinearGradient(
            colors: [namedColor(coverColor).darkened(by: 0.25), namedColor(coverColor)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

func namedColor(_ name: String?) -> Color {
    switch name {
    case "blue":    return .blue
    case "purple":  return .purple
    case "teal":    return .teal
    case "green":   return .green
    case "orange":  return .orange
    case "pink":    return .pink
    case "red":     return .red
    default:        return .indigo
    }
}

extension Color {
    init?(hex: String) {
        let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            red: Double((val >> 16) & 0xFF) / 255,
            green: Double((val >> 8) & 0xFF) / 255,
            blue: Double(val & 0xFF) / 255
        )
    }

    func darkened(by amount: Double) -> Color {
        let ui = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: h, saturation: min(s + 0.1, 1), brightness: max(b - amount, 0))
    }
}

// MARK: - Widget

@main
struct DistillWidget: Widget {
    let kind: String = "DistillWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: DistillWidgetIntent.self, provider: LearningProvider()) { entry in
            DistillWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Distill")
        .description("See a core learning from your books.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
