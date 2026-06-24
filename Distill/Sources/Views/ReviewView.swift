import SwiftUI
import SwiftData
import TelemetryDeck

struct ReviewView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Learning.dateAdded, order: .reverse) private var learnings: [Learning]

    @State private var currentIndex = 0
    @State private var dragOffset: CGFloat = 0
    @State private var cardRotation: Double = 0
    @State private var sessionCount = 0
    @State private var showCompleted = false

    private var reviewQueue: [Learning] {
        learnings.shuffled()
    }

    var body: some View {
        NavigationStack {
            Group {
                if learnings.isEmpty {
                    emptyState
                } else if showCompleted {
                    completedState
                } else {
                    reviewStack
                }
            }
            .navigationTitle("Daily Review")
        }
        .onAppear {
            guard !learnings.isEmpty else { return }
            TelemetryDeck.signal("review.session.started", parameters: [
                "learningCount": String(learnings.count)
            ])
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundStyle(.indigo.opacity(0.4))
            Text("Nothing to review")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Add books to your library\nto start reviewing learnings")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    private var completedState: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
            Text("Session Complete!")
                .font(.title)
                .fontWeight(.bold)
            Text("You reviewed \(sessionCount) learnings")
                .foregroundStyle(.secondary)
            Button {
                currentIndex = 0
                sessionCount = 0
                showCompleted = false
            } label: {
                Text("Review Again")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.indigo)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 40)
            }
        }
    }

    private var reviewStack: some View {
        VStack(spacing: 24) {
            progressBar

            Spacer()

            if currentIndex < learnings.count {
                reviewCard(for: learnings[currentIndex])
            }

            Spacer()

            HStack(spacing: 20) {
                skipButton
                knewItButton
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .padding(.top)
    }

    private var progressBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(min(currentIndex + 1, learnings.count)) of \(learnings.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(sessionCount) reviewed today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.secondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.indigo)
                        .frame(width: geo.size.width * CGFloat(currentIndex) / CGFloat(max(learnings.count, 1)))
                        .animation(.spring(duration: 0.4), value: currentIndex)
                }
            }
            .frame(height: 6)
            .padding(.horizontal)
        }
    }

    private func reviewCard(for learning: Learning) -> some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(learning.bookTitle)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.indigo)
                    Text(learning.bookAuthor)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.orange)
            }

            Text(learning.text)
                .font(.title3)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer()

            if learning.reviewCount > 0 {
                Text("Reviewed \(learning.reviewCount)×")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .background(.background, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
        .padding(.horizontal, 20)
        .offset(x: dragOffset)
        .rotationEffect(.degrees(cardRotation))
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width
                    cardRotation = value.translation.width / 20
                }
                .onEnded { value in
                    if abs(value.translation.width) > 100 {
                        advanceCard(dismissed: true)
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = 0
                            cardRotation = 0
                        }
                    }
                }
        )
        .animation(.interactiveSpring(), value: dragOffset)
    }

    private var skipButton: some View {
        Button {
            advanceCard(dismissed: false)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.right")
                Text("Skip")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.secondary.opacity(0.1))
            .foregroundStyle(.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var knewItButton: some View {
        Button {
            markReviewed()
            advanceCard(dismissed: true)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                Text("Got it!")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.indigo)
            .foregroundStyle(.white)
            .fontWeight(.semibold)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func advanceCard(dismissed: Bool) {
        if dismissed {
            sessionCount += 1
            if currentIndex + 1 >= learnings.count {
                TelemetryDeck.signal("review.session.completed", parameters: [
                    "reviewed": String(sessionCount)
                ])
            }
        }
        withAnimation(.spring(duration: 0.35)) {
            dragOffset = dismissed ? (dragOffset > 0 ? 400 : -400) : 0
            cardRotation = dismissed ? (dragOffset > 0 ? 15 : -15) : 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            dragOffset = 0
            cardRotation = 0
            if currentIndex + 1 >= learnings.count {
                showCompleted = true
            } else {
                currentIndex += 1
            }
        }
    }

    private func markReviewed() {
        guard currentIndex < learnings.count else { return }
        let learning = learnings[currentIndex]
        learning.reviewCount += 1
        learning.lastReviewed = Date()
        TelemetryDeck.signal("review.learning.marked")
    }
}
