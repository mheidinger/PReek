import SwiftUI

class PullRequestsNavigationShortcutHandler: ObservableObject {
    var viewModel: PullRequestsViewModel

    #if os(macOS)
        init(viewModel: PullRequestsViewModel) {
            self.viewModel = viewModel

            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if self.handleKeyEvent(event) {
                    return nil
                } else {
                    return event
                }
            }
        }

        private func handleKeyEvent(_ event: NSEvent) -> Bool {
            guard let characters = event.charactersIgnoringModifiers else { return false }

            // No modifier pressed
            if event.modifierFlags.isDisjoint(with: .deviceIndependentFlagsMask) {
                switch characters {
                case "j":
                    viewModel.setFocus(.next)
                    return true
                case "k":
                    viewModel.setFocus(.previous)
                    return true
                case "g":
                    viewModel.setFocus(.first)
                    return true
                default:
                    break
                }
            }

            // Only shift (i.e. capital letter)
            if event.modifierFlags.contains(.shift) && event.modifierFlags.isDisjoint(with: [.command, .control, .option]) {
                switch characters {
                case "G":
                    viewModel.setFocus(.last)
                    return true
                default:
                    break
                }
            }

            return false
        }
    #else
        init(viewModel: PullRequestsViewModel) {
            self.viewModel = viewModel
        }
    #endif
}
