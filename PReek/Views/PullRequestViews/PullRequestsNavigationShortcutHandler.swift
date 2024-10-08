import SwiftUI

class PullRequestsNavigationShortcutHandler: ObservableObject {
    var viewModel: PullRequestsViewModel

    init(viewModel: PullRequestsViewModel) {
        self.viewModel = viewModel

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
                viewModel.setFocus(.next)
            case "k":
                viewModel.setFocus(.previous)
            case "g":
                viewModel.setFocus(.first)
            default:
                break
            }
        }

        // Only shift (i.e. capital letter)
        if event.modifierFlags.contains(.shift) && event.modifierFlags.isDisjoint(with: [.command, .control, .option]) {
            switch characters {
            case "G":
                viewModel.setFocus(.last)
            default:
                break
            }
        }
    }
}
