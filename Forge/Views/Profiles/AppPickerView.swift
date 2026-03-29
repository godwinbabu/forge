import SwiftUI
import AppKit

struct AppPickerView: View {
    @Binding var selectedBundleIDs: [String]
    @State private var installedApps: [InstalledApp] = []
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Select Apps")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()

            TextField("Search apps...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.bottom, 8)

            List(filteredApps) { app in
                HStack(spacing: 12) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.path.path))
                        .resizable()
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading) {
                        Text(app.displayName)
                            .font(.body)
                        Text(app.id)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if selectedBundleIDs.contains(app.id) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleSelection(app.id)
                }
            }
        }
        .frame(minWidth: 450, minHeight: 500)
        .task {
            installedApps = InstalledAppScanner.scan()
        }
    }

    private var filteredApps: [InstalledApp] {
        guard !searchText.isEmpty else { return installedApps }
        return installedApps.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func toggleSelection(_ bundleID: String) {
        if let index = selectedBundleIDs.firstIndex(of: bundleID) {
            selectedBundleIDs.remove(at: index)
        } else {
            selectedBundleIDs.append(bundleID)
        }
    }
}
