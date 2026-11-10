#if os(macOS)
    import Testing

    struct LocalEditorTests {
        @Test func preservesUnavailableChoiceInsteadOfOpeningAnotherEditor() {
            #expect(LocalEditor.preferredID(savedID: "com.microsoft.VSCode", installedIDs: ["dev.zed.Zed"]) == "com.microsoft.VSCode")
        }

        @Test func freshSelectionPrefersZedRegardlessOfDiscoveryOrder() {
            #expect(LocalEditor.preferredID(savedID: nil, installedIDs: ["com.microsoft.VSCode", "dev.zed.Zed"]) == "dev.zed.Zed")
        }

        @Test func freshSelectionUsesAvailableEditorOrRemainsUnavailable() {
            #expect(LocalEditor.preferredID(savedID: nil, installedIDs: ["com.microsoft.VSCode"]) == "com.microsoft.VSCode")
            #expect(LocalEditor.preferredID(savedID: nil, installedIDs: []) == nil)
        }
    }
#endif
