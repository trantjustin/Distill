import Foundation
import StoreKit

enum ReceiptProvider {
    /// Returns the current App Store receipt as a base64-encoded string.
    /// Falls back to refreshing the receipt if the file is not present.
    static func receiptBase64() async throws -> String {
        if let receiptURL = Bundle.main.appStoreReceiptURL,
           FileManager.default.fileExists(atPath: receiptURL.path),
           let data = try? Data(contentsOf: receiptURL) {
            return data.base64EncodedString()
        }

        return try await refreshReceiptBase64()
    }

    private static func refreshReceiptBase64() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = SKReceiptRefreshRequest()
            request.delegate = ReceiptRefreshDelegate.shared
            ReceiptRefreshDelegate.shared.continuation = continuation
            request.start()
        }
    }
}

private final class ReceiptRefreshDelegate: NSObject, SKRequestDelegate {
    static let shared = ReceiptRefreshDelegate()
    var continuation: CheckedContinuation<String, Error>?

    func requestDidFinish(_ request: SKRequest) {
        guard let continuation else { return }
        self.continuation = nil

        if let receiptURL = Bundle.main.appStoreReceiptURL,
           FileManager.default.fileExists(atPath: receiptURL.path),
           let data = try? Data(contentsOf: receiptURL) {
            continuation.resume(returning: data.base64EncodedString())
        } else {
            continuation.resume(throwing: ReceiptError.missingReceipt)
        }
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(throwing: error)
    }
}

enum ReceiptError: LocalizedError {
    case missingReceipt

    var errorDescription: String? {
        switch self {
        case .missingReceipt:
            return "Unable to read App Store receipt."
        }
    }
}
