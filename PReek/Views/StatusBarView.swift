import SwiftUI

private struct StatusBarButtonView: View {
    var imageSystemName: String
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: imageSystemName)
                .font(.title)
        }
        .buttonStyle(BorderlessButtonStyle())
        .padding(.vertical, 3)
    }
}

struct StatusBarView: View {
    var lastUpdated: Date?
    var hasError: Bool
    var onRefresh: () -> Void
    var isRefreshing: Bool
    var markAllRead: () -> Void
    @Binding var settingsOpen: Bool
    
    var body: some View {
        HStack {
            StatusBarButtonView(imageSystemName: "line.3.horizontal.decrease.circle", action: {})
                .help("Filters")
            StatusBarButtonView(imageSystemName: "eye.circle", action: markAllRead)
                .help("Mark all as read")
            
            Spacer()
            
            if hasError {
                Text("Failed to fetch notifications")
                    .foregroundStyle(.red)
            } else {
                Text("Last updated at \(lastUpdated?.formatted(date: .omitted, time: .shortened) ?? "...")")
                    .foregroundStyle(.secondary)
            }
            Group {
                if isRefreshing && !hasError {
                    ProgressView()
                        .scaleEffect(0.6)
                        .padding(.leading, -4)
                } else {
                    StatusBarButtonView(imageSystemName: "arrow.clockwise.circle", action: onRefresh)
                        .help("Refresh")
                }
            }
            .frame(width: 25, alignment: .leading)
            
            StatusBarButtonView(imageSystemName: "gear", action: {
                settingsOpen = true
            })
            .help("Settings")
        }
        .padding(.horizontal)
        .background(.background.opacity(0.5))
    }
}

#Preview {
    StatusBarView(
        lastUpdated: Date(),
        hasError: false,
        onRefresh: {},
        isRefreshing: false,
        markAllRead: {},
        settingsOpen: .constant(false)
    )
}
