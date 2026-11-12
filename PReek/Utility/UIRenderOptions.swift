#if os(macOS)
    import Foundation

    struct UIRenderOptions {
        enum Screen: String { case settings, main }
        enum MainState: String { case loaded, empty, loading, error }
        enum Appearance: String { case light, dark }

        let screen: Screen
        let section: SettingsSection
        let state: MainState
        let appearance: Appearance
        let width: Int
        let height: Int
        let scale: Int
        let output: URL

        static let usage = """
        Usage:
          PReek --render-ui settings --section general|github|pull-requests|local-actions|about --output PATH.png
          PReek --render-ui main --state loaded|empty|loading|error --output PATH.png
          PReek --render-ui --help

        Options: --appearance light|dark, --width POINTS, --height POINTS, --scale 1|2|3
        Defaults: light appearance, 2x scale; settings 900x680, main 600x400 points.
        Settings require at least 780x560 points. Dimensions must be at most 4096 points.
        Debug/macOS only. Renders synthetic data off-screen; never launches the normal app.
        Native materials are not compositor screenshots: sidebar selection and switch tint can differ.
        Use an isolated macOS desktop to verify those effects, focus, menus, and dismissal.
        """

        struct InvalidRequest: LocalizedError {
            let message: String
            var errorDescription: String? {
                message
            }
        }

        static func parse(_ arguments: [String]) throws -> UIRenderOptions {
            guard arguments.count >= 2, arguments[0] == "--render-ui",
                  let screen = Screen(rawValue: arguments[1])
            else {
                throw InvalidRequest(message: usage)
            }
            let allowed = Set(["--section", "--state", "--appearance", "--width", "--height", "--scale", "--output"])
            var values: [String: String] = [:]
            var index = 2
            while index < arguments.count {
                let key = arguments[index]
                guard allowed.contains(key), values[key] == nil else {
                    throw InvalidRequest(message: "Unknown or repeated option: \(key)")
                }
                guard index + 1 < arguments.count, !arguments[index + 1].hasPrefix("--") else {
                    throw InvalidRequest(message: "Missing value for \(key)")
                }
                values[key] = arguments[index + 1]
                index += 2
            }
            guard let path = values["--output"], !path.isEmpty else {
                throw InvalidRequest(message: "--output PATH.png is required.")
            }
            guard screen == .settings || values["--section"] == nil,
                  screen == .main || values["--state"] == nil
            else {
                throw InvalidRequest(message: "--section is only for settings; --state is only for main.")
            }
            guard let section = SettingsSection(rawValue: values["--section"] ?? "general"),
                  let state = MainState(rawValue: values["--state"] ?? "loaded"),
                  let appearance = Appearance(rawValue: values["--appearance"] ?? "light")
            else {
                throw InvalidRequest(message: "Unknown section, state, or appearance.\n\(usage)")
            }
            func number(_ key: String, fallback: Int, range: ClosedRange<Int>) throws -> Int {
                guard let string = values[key] else { return fallback }
                guard let value = Int(string), range.contains(value) else {
                    throw InvalidRequest(message: "\(key) must be an integer in \(range).")
                }
                return value
            }
            let width = try number("--width", fallback: screen == .settings ? 900 : 600, range: (screen == .settings ? 780 : 1) ... 4096)
            let height = try number("--height", fallback: screen == .settings ? 680 : 400, range: (screen == .settings ? 560 : 1) ... 4096)
            let scale = try number("--scale", fallback: 2, range: 1 ... 3)
            return UIRenderOptions(
                screen: screen, section: section, state: state, appearance: appearance,
                width: width, height: height, scale: scale,
                output: URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            )
        }
    }
#endif
