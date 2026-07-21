import SwiftUI
import StoreKit
import WidgetKit

struct SettingsView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false
    @State private var widgetDisplayMode: String = WidgetDataManager.loadDisplayMode()

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
                                 : "7-day free trial, then $2.99/month (or local equivalent).")
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
                    Picker(selection: $widgetDisplayMode) {
                        Text("Rotate Learnings").tag("rotateLearnings")
                        Text("Book Summary").tag("bookSummary")
                    } label: {
                        Label("Display Mode", systemImage: "text.book.closed.fill")
                            .foregroundStyle(.primary)
                    }
                    .onChange(of: widgetDisplayMode) { _, newValue in
                        WidgetDataManager.saveDisplayMode(newValue)
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                } footer: {
                    Text("Book Summary shows the full overview of each book, cycling through your library.")
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    LabeledContent("AI Model", value: "Llama 3.3 70B (Groq)")
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
