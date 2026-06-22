import CopyPathCore
import SwiftUI

struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var extensionEnabled = FinderExtensionManager.isEnabled

    var body: some View {
        Form {
            Section("Finder Extension") {
                Label(
                    extensionEnabled ? "Copy Path As is enabled" : "Copy Path As is disabled",
                    systemImage: extensionEnabled ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
                )
                .foregroundStyle(extensionEnabled ? .green : .orange)

                Text("Select one or more items in Finder, right-click, then choose Copy Path As and a copy format.")
                    .foregroundStyle(.secondary)

                Button("Open Finder Extension Settings") {
                    FinderExtensionManager.showManagementInterface()
                }
            }

            Section("Available Formats") {
                ForEach(PathFormat.allCases, id: \.self) { format in
                    Label(format.displayName, systemImage: "doc.on.doc")
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 500, minHeight: 520)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { extensionEnabled = FinderExtensionManager.isEnabled }
        }
    }
}
