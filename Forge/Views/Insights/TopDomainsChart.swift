import SwiftUI
import Charts
import ForgeKit

struct TopDomainsChart: View {
    let domains: [DomainCount]

    var body: some View {
        if domains.isEmpty {
            Text("No blocked domains yet")
                .foregroundStyle(.secondary)
                .frame(height: 150)
        } else {
            Chart(domains, id: \.domain) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Domain", item.domain)
                )
                .foregroundStyle(.orange.gradient)
            }
            .frame(height: CGFloat(max(domains.count, 1) * 36))
        }
    }
}
