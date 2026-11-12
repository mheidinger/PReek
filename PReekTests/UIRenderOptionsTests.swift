#if os(macOS)
    import Foundation
    import Testing

    struct UIRenderOptionsTests {
        @Test func acceptsSettingsMinimumAndRejectsClippedSizes() throws {
            let options = try UIRenderOptions.parse([
                "--render-ui", "settings", "--section", "github", "--width", "780", "--height", "560", "--output", "/tmp/settings.png",
            ])
            #expect(options.width == 780 && options.height == 560)
            for (width, height) in [(779, 560), (780, 559)] {
                #expect(throws: UIRenderOptions.InvalidRequest.self) {
                    try UIRenderOptions.parse([
                        "--render-ui", "settings", "--width", "\(width)", "--height", "\(height)", "--output", "/tmp/settings.png",
                    ])
                }
            }
        }

        @Test func rejectsInvalidAndUnboundedRasterSizes() {
            for (option, value) in [("--width", "0"), ("--height", "4097"), ("--scale", "4"), ("--scale", "1.5")] {
                #expect(throws: UIRenderOptions.InvalidRequest.self) {
                    try UIRenderOptions.parse(["--render-ui", "main", option, value, "--output", "/tmp/main.png"])
                }
            }
        }

        @Test func rejectsUnknownAndIncompatibleScenarios() {
            let requests = [
                ["--render-ui", "main", "--section", "github"],
                ["--render-ui", "settings", "--state", "error"],
                ["--render-ui", "settings", "--section", "missing"],
                ["--render-ui", "main", "--state", "missing"],
                ["--render-ui", "main", "--appearance", "missing"],
                ["--render-ui", "unknown"],
            ]
            for request in requests {
                #expect(throws: UIRenderOptions.InvalidRequest.self) {
                    try UIRenderOptions.parse(request + ["--output", "/tmp/probe.png"])
                }
            }
        }

        @Test func rejectsAmbiguousOrIncompleteCommands() {
            let requests = [
                ["--render-ui=main", "--output", "/tmp/probe.png"],
                ["--render-ui", "main"],
                ["--render-ui", "main", "--output"],
                ["--render-ui", "main", "--output", "/tmp/probe.png", "--output", "/tmp/other.png"],
                ["--render-ui", "main", "--unknown", "value", "--output", "/tmp/probe.png"],
            ]
            for request in requests {
                #expect(throws: UIRenderOptions.InvalidRequest.self) {
                    try UIRenderOptions.parse(request)
                }
            }
        }
    }
#endif
