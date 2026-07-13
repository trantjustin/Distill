import SwiftUI
import StoreKit

struct SettingsView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: subscriptionManager.isSubscribed ? "checkmark.shield.fill" : "crown.fill")
                            .foregroundStyle(subscriptionManager.isSubscribed ? .green : .orange)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(subscriptionManager.isSubscribed ? "Subscribed" : "Distill Subscription")
                                .font(.headline)
                            Text(subscriptionManager.isSubscribed
                                 ? "You have unlimited access."
                                 : "7-day free trial, then $4.99/month (or local equivalent).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    if !subscriptionManager.isSubscribed {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.open.fill")
                                Text("Start Free Trial")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.indigo)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        Button {
                            Task { await subscriptionManager.restore() }
                        } label: {
                            Text("Restore Purchases")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Subscription")
                } footer: {
                    Text("Subscription is anonymous — no account required. Auto-renews monthly until cancelled.")
                }

                Section("Widget") {
                    HStack {
                        Image(systemName: "square.grid.2x2.fill")
                            .foregroundStyle(.indigo)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Home Screen Widget")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Long-press your home screen → + → Distill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Image(systemName: "paintpalette.fill")
                            .foregroundStyle(.indigo)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Customise the Widget")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Long-press the widget → Edit Widget to change refresh rate and attribution")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("AI Summaries", value: "Groq")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .task {
                await subscriptionManager.loadProducts()
            }
        }
    }
}
