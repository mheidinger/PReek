import SwiftUI

struct BulletPointView: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top) {
            Text("•")
            Text(text)
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        BulletPointView("short")
        BulletPointView("long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long ")
    }
    .frame(width: 400)
    .padding()
}
