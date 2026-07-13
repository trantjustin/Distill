import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 64))
                        .foregroundStyle(.indigo)

                    Text("Distill Subscription")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Start your 7-day free trial, then US$4.99/month (or local equivalent). Unlock unlimited AI-powered learnings from every book you read.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 32)
                }

                VStack(alignment: .leading, spacing: 16) {
                    featureRow(icon: "brain.head.profile", text: "8 concise, actionable learnings per book, powered by Groq")
                    featureRow(icon: "barcode.viewfinder", text: "Search, scan, or add books manually")
                    featureRow(icon: "square.grid.2x2.fill", text: "Daily review widgets for your home screen")
                    featureRow(icon: "icloud.slash", text: "No account required — anonymous & private")
                }
                .padding(.horizontal, 24)

                Spacer()

                if subscriptionManager.isLoading {
                    ProgressView()
                } else if let product = subscriptionManager.products.first {
                    VStack(spacing: 12) {
                        Button {
                            Task { await purchase(product) }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.open.fill")
                                Text("Start 7-Day Free Trial")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.indigo)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        Button {
                            Task { await subscriptionManager.restore() }
                        } label: {
                            Text("Restore Purchases")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 24)
                } else {
                    Text("Subscription products are not available right now.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("7-day free trial, then $4.99/month (or local equivalent). Auto-renews until cancelled. You can cancel anytime in Settings.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.vertical, 32)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Purchase Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
            .task {
                await subscriptionManager.loadProducts()
            }
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.indigo)
                .frame(width: 32)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func purchase(_ product: Product) async {
        do {
            let success = try await subscriptionManager.purchase(product)
            if success {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
