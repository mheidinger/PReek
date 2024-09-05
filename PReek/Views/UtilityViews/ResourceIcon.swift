import SwiftUI

struct ResourceIcon: View {
    let image: ImageResource

    var body: some View {
        Image(image)
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

#Preview {
    ResourceIcon(image: .fileDiff)
        .frame(width: 50)
        .padding()
}
