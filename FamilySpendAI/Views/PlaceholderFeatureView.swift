import SwiftUI

struct PlaceholderFeatureView: View {
    let title: String
    let description: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(description)
        }
        .navigationTitle(title)
    }
}
