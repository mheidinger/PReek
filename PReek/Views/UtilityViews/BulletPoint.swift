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
                .multilineTextAlignment(.leading)
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        BulletPoint("short")
        BulletPoint("my first commit has a really long commit message long long")
    }
    .frame(width: 400)
    .padding()
}
