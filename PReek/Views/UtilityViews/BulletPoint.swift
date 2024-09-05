import SwiftUI

struct BulletPoint: View {
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
        BulletPoint("short")
        BulletPoint("long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long long ")
    }
    .frame(width: 400)
    .padding()
}
