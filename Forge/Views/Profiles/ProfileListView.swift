import SwiftUI

struct ProfileListView: View {
    var body: some View {
        List {
            Text("No profiles yet")
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Profiles")
    }
}
