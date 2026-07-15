import SwiftUI
import StoreKit

private let eulaURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
private let privacyURL = URL(string: "https://distillapp.com/privacy")!
private let productID = "com.jtrant.distill.subscription.monthly"

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SubscriptionStoreView(productIDs: [productID]) {
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 56))
                    .foregroundStyle(.indigo)

                Text("Distill")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 12) {
                    featureRow(icon: "brain.head.profile", text: "AI-powered learnings for every book")
                    featureRow(icon: "barcode.viewfinder", text: "Search or scan to add books")
                    featureRow(icon: "square.grid.2x2.fill", text: "Home screen widgets for daily review")
                    featureRow(icon: "icloud.slash", text: "No account required — private by default")
                }
                .padding(.horizontal, 8)
            }
            .containerBackground(.indigo.gradient, for: .subscriptionStoreFullHeight)
        }
        .subscriptionStoreButtonLabel(.multiline)
        .subscriptionStorePolicyDestination(url: privacyURL, for: .privacyPolicy)
        .subscriptionStorePolicyDestination(url: eulaURL, for: .termsOfService)
        .onInAppPurchaseCompletion { _, result in
            if case .success = result { dismiss() }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close") { dismiss() }
            }
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
