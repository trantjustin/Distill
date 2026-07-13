import Foundation

enum BackendConfig {
    /// Set this to your deployed Cloudflare Worker URL before shipping.
    static var baseURL: URL = URL(string: "https://distill-backend.justin-trant.workers.dev")!

    static let extractPath = "/extract"
    static let statusPath = "/status"
}
