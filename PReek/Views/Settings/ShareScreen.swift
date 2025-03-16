import SwiftUI

struct ShareScreen: View {
    @ObservedObject var configViewModel: ConfigViewModel

    var body: some View {
        ShareView(configViewModel: configViewModel, onDismiss: {})
            .padding()
            .navigationTitle("Share Configuration")
    }
}
