import Foundation
import Observation

/// Global state for filtering content by download status
@Observable @MainActor
final class DownloadFilter {
    var showDownloadedOnly: Bool = false {
        didSet {
            print("🔍 DownloadFilter: showDownloadedOnly = \(showDownloadedOnly)")
        }
    }
}