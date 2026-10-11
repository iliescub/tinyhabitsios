import SwiftUI
import WidgetKit

@main
struct FledgeWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NestWidget()
        NestLockScreenWidget()
        HabitRingWidget()
        HabitControl()
    }
}
