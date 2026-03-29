import SwiftUI
import ForgeKit

struct DomainListEditor: View {
    @Binding var domains: [String]
    @State private var newDomain = ""
    @State private var showingPasteSheet = false
    @State private var pasteText = ""

    var body: some View {
        Section("Domains") {
            ForEach(domains, id: \.self) { domain in
                HStack {
                    Text(domain)
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Button(role: .destructive) {
                        domains.removeAll { $0 == domain }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                TextField("example.com", text: $newDomain)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { addDomain() }

                Button("Add") { addDomain() }
                    .disabled(newDomain.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Button("Paste Multiple...") {
                pasteText = ""
                showingPasteSheet = true
            }
        }
        .sheet(isPresented: $showingPasteSheet) {
            VStack(spacing: 16) {
                Text("Paste Domains")
                    .font(.headline)
                Text("One domain per line")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $pasteText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
                    .border(.separator)

                HStack {
                    Button("Cancel") {
                        showingPasteSheet = false
                    }
                    Spacer()
                    Button("Add Domains") {
                        let lines = pasteText.components(separatedBy: .newlines)
                        let validated = DomainValidator.validateList(lines)
                        let existing = Set(domains)
                        let newDomains = validated.filter { !existing.contains($0) }
                        domains.append(contentsOf: newDomains)
                        showingPasteSheet = false
                    }
                }
            }
            .padding()
            .frame(minWidth: 400, minHeight: 300)
        }
    }

    private func addDomain() {
        guard let validated = DomainValidator.validate(newDomain),
              !domains.contains(validated) else {
            newDomain = ""
            return
        }
        domains.append(validated)
        newDomain = ""
    }
}
