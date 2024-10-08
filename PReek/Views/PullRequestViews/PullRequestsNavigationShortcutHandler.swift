import SwiftUI

class PullRequestsNavigationShortcutHandler: ObservableObject {
    var viewModel: PullRequestsViewModel? = nil

    init() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            self.handleKeyEvent(event)
            return event
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        guard let characters = event.charactersIgnoringModifiers else { return }

        // No modifier pressed
        if event.modifierFlags.isDisjoint(with: .deviceIndependentFlagsMask) {
            switch characters {
            case "j":
                viewModel?.selectNextByOffset(by: 1)
            case "k":
                viewModel?.selectNextByOffset(by: -1)
            case "g":
                viewModel?.selectFirst()
            default:
                break
            }
        }

        // Only shift (i.e. capital letter)
        if event.modifierFlags.contains(.shift) && event.modifierFlags.isDisjoint(with: [.command, .control, .option]) {
            switch characters {
            case "G":
                viewModel?.selectLast()
            default:
                break
            }
        }
    }
}
