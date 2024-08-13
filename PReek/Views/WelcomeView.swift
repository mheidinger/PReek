import SwiftUI

struct WelcomeView: View {
    @ObservedObject var configViewModel: ConfigViewModel
    
    var body: some View {
        VStack(spacing: 50) {
            HStack(spacing: 30) {
                Image(.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50)
                VStack {
                    Text("Welcome to PReek")
                        .font(.title)
                    Text("Let's get you started!")
                        .font(.title2)
                }
            }
            
            ConnectionSettingsView(configViewModel: configViewModel)
        }
        .padding()
    }
}

#Preview {
    WelcomeView(configViewModel: ConfigViewModel())
        .frame(width: 600, height: 400)
}
