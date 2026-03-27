import SwiftUI

struct CommandPalette: View {
    @State private var searchText = ""

    var body: some View {
        VStack {
            TextField("Search commands...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding()
        }
        .frame(width: 400)
    }
}
