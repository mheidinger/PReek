//
//  StatusBarView.swift
//  GitHub Notifications
//
//  Created by Max Heidinger on 26.05.24.
//

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
    @Binding var settingsOpen: Bool
    
    var body: some View {
        HStack {
            Group {
                if isRefreshing && !hasError {
                    ProgressView()
                        .scaleEffect(0.6)
                } else {
                    StatusBarButtonView(imageSystemName: "arrow.clockwise.circle", action: onRefresh)
                }
            }
            .frame(width: 30)
            
            if hasError {
                Text("Failed to fetch notifications")
                    .foregroundStyle(.red)
            } else {
                Text("Last updated at \(lastUpdated?.formatted(date: .omitted, time: .shortened) ?? "?")")
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            StatusBarButtonView(imageSystemName: "gear", action: {
                settingsOpen = true
            })
        }
        .padding(.horizontal)
        .background(.background)
    }
}

#Preview {
    StatusBarView(
        lastUpdated: Date(),
        hasError: false,
        onRefresh: {},
        isRefreshing: false,
        settingsOpen: .constant(false)
    )
}
