import SwiftUI
import Combine

final class SwipeGuard: ObservableObject {
    @Published var blockedRegions: [CGRect] = []
}
