import SwiftUI

struct CountdownTimerView: View {
    let endDate: Date

    var body: some View {
        Text(endDate, style: .timer)
            .font(.system(.largeTitle, design: .monospaced))
    }
}
