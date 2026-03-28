import SwiftUI

struct ProfileCardView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.quaternary)
            .frame(height: 120)
            .overlay {
                Text("Profile")
            }
    }
}
