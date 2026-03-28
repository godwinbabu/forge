import SwiftUI

struct ProgressBarView: View {
    let progress: Double

    var body: some View {
        ProgressView(value: progress)
            .progressViewStyle(.linear)
    }
}
