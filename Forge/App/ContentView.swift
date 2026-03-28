import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            List {
                NavigationLink("Dashboard", value: "dashboard")
                NavigationLink("Profiles", value: "profiles")
                NavigationLink("Settings", value: "settings")
            }
            .navigationTitle("Forge")
        } detail: {
            Text("Select an item")
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}
