import Foundation

/// Every web address the app opens, in one place. Hosted on GitHub Pages from `website/`
/// (`.github/workflows/pages.yml`). With a custom domain later, change `base` only.
enum AppLinks {
    static let base = URL(string: "https://iliescub.github.io/tinyhabitsios/")!
    static let privacy = base.appendingPathComponent("privacy/")
    static let terms = base.appendingPathComponent("terms/")
    static let support = base.appendingPathComponent("support/")
}
