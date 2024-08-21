import SwiftUI

struct IconView: View {
    let image: ImageResource

    var body: some View {
        Image(image)
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

#Preview {
    IconView(image: .fileDiff)
        .frame(width: 50)
        .padding()
}
