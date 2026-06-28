import CopyPathCore
import SwiftUI

private struct ScrollGeometryState: Equatable {
    let contentHeight: CGFloat
    let viewportHeight: CGFloat
    let scrollOffset: CGFloat
}

// swiftlint:disable type_body_length
struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    private let demoState: AppDemoState?
    @State private var extensionEnabled = FinderExtensionManager.isEnabled
    @State private var selectedFormat: PathFormat = .path
    @State private var testPath = "/Users/appleseed/Projects/app/sources/main.swift"
    @State private var hoverFormat: PathFormat? = nil
    @State private var currentTab: Tab = .overview

    // Custom Scrollbar State
    @State private var sidebarContentHeight: CGFloat = 1
    @State private var sidebarViewportHeight: CGFloat = 1
    @State private var sidebarScrollOffset: CGFloat = 0

    // Copy Toast State
    @State private var showToast = false
    @State private var toastPath = ""
    @State private var toastFormat = ""
    @State private var lastSeenTimestamp: Double = 0.0
    @State private var installationStatus: AppInstallationStatus
    private let buildIdentity: BuildIdentity
    private let installationStatusProvider: AppInstallationStatusProviding
    private let doctorActionPerformer: AppDoctorActionPerforming

    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    enum Tab {
        case overview
        case preview
    }

    init(
        demoState: AppDemoState? = nil,
        buildIdentity: BuildIdentity = BuildIdentity(),
        installationStatusProvider: AppInstallationStatusProviding = WorkspaceAppInstallationStatusProvider(),
        doctorActionPerformer: AppDoctorActionPerforming = WorkspaceAppDoctorActionPerformer()
    ) {
        self.demoState = demoState
        self.buildIdentity = buildIdentity
        self.installationStatusProvider = installationStatusProvider
        self.doctorActionPerformer = doctorActionPerformer
        _extensionEnabled = State(initialValue: demoState?.initialExtensionEnabled ?? FinderExtensionManager.isEnabled)
        _installationStatus = State(initialValue: demoState == nil ? installationStatusProvider.currentStatus() : .demoHealthy)
        _selectedFormat = State(initialValue: demoState?.initialFormat ?? .path)
        _testPath = State(
            initialValue: demoState?.initialTestPath
                ?? "/Users/appleseed/Projects/app/sources/main.swift"
        )
        _currentTab = State(initialValue: demoState?.initialTab ?? .overview)
        _showToast = State(initialValue: demoState == .copied)
        _toastPath = State(initialValue: demoState == .copied ? "README.md" : "")
        _toastFormat = State(initialValue: demoState == .copied ? PathFormat.markdownLink.displayName : "")
    }

    var body: some View {
        ZStack {
            // Main Dashboard Container
            VStack(spacing: 12) {
                // Top Hero Area
                heroView

                // Segmented Tab Picker
                Picker("", selection: $currentTab) {
                    Text("Overview").tag(Tab.overview)
                    Text("Formats").tag(Tab.preview)
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
                .padding(.top, -4)

                // Tab Content
                if currentTab == .overview {
                    overviewView
                    Spacer()
                } else {
                    previewTabView
                    Spacer()
                }

                Divider()
                    .padding(.horizontal, 20)

                // Footer (Privacy & Open Source)
                footerView
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    .layoutPriority(1)
            }
            .frame(width: 860, height: 830, alignment: .top)
            .background(Color(nsColor: .windowBackgroundColor))

            // Toast Notification Overlay
            if showToast {
                toastOverlayView
            }
        }
        .frame(width: 860, height: 830)
        .onReceive(timer) { _ in
            guard demoState == nil else { return }
            checkForSharedCopyEvents()
        }
        .onChange(of: scenePhase) { _, phase in
            guard demoState == nil else { return }
            if phase == .active {
                extensionEnabled = FinderExtensionManager.isRecentlyActive
                installationStatus = installationStatusProvider.currentStatus()
                checkForSharedCopyEvents()
            }
        }
    }

    // MARK: - Subviews

    private var heroView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 54, height: 54)
                    .shadow(radius: 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Copy Path As")
                        .font(.system(size: 28, weight: .bold))
                    Text("Copy macOS file paths in the format you actually need.")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text("Right-click any file or folder in Finder and copy paths for AI agents, Terminal, IDEs, scripts, Markdown, JSON, and docs.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            if let warning = installationStatus.warning {
                installationWarningView(warning)
            }

            // Extension Status Card / Banner
            if extensionEnabled {
                HStack(alignment: .center, spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.green)
                        .padding(.leading, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("All set. Extension is active.")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)

                        Text("Runs as a background service. Right-click any file in Finder to format and copy its path.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        Button(action: {
                            FinderExtensionManager.showManagementInterface()
                        }) {
                            Label("Extension Settings", systemImage: "gearshape")
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.18), lineWidth: 1)
                )
            } else {
                HStack(alignment: .center, spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.orange)
                        .padding(.leading, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Extension Not Enabled")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)

                        Text("Go to System Settings → Extensions → Finder Extensions, and enable the Finder extension. Once enabled, it runs in the background even when this window is closed.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        Button(action: {
                            FinderExtensionManager.showManagementInterface()
                        }) {
                            Label("Open Settings", systemImage: "gearshape.fill")
                                .fontWeight(.semibold)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)

                        Button(action: {
                            NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory()))
                        }) {
                            Label("Open Finder", systemImage: "macwindow")
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.18), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private func installationWarningView(_ warning: AppInstallationWarning) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.yellow)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(warning.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Text(warning.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.yellow.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.22), lineWidth: 1)
        )
    }

    private var overviewView: some View {
        HStack(alignment: .top, spacing: 20) {
            // Left Column: Finder Context Menu Mockup
            contextMenuMockupCard
                .frame(width: 360)

            // Right Column: Why not just Finder? + How it works
            VStack(spacing: 16) {
                whyNotFinderCard
                doctorCard
                howItWorksView
            }
        }
        .padding(.horizontal, 20)
    }

    private var previewTabView: some View {
        HStack(alignment: .top, spacing: 20) {
            // Left Column: Presets Library
            formatLibraryView
                .frame(width: 260)
                .frame(maxHeight: .infinity, alignment: .top)

            // Right Column: Live Preview Console
            previewConsoleView
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 20)
    }

    private var formatLibraryView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Supported formats")
                .font(.headline)
                .padding(.horizontal, 4)
                .padding(.bottom, 2)

            ZStack(alignment: .trailing) {
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        formatSection(label: "Shell & Scripts", formats: [.path, .quotedPath, .shellEscapedPath])
                        formatSectionDivider()
                        formatSection(label: "Relative", formats: [.homeRelative, .repoRelative])
                        formatSectionDivider()
                        formatSection(label: "Web & Data", formats: [.fileURL, .jsonString, .jsonArray, .markdownLink])
                        formatSectionDivider()
                        formatSection(label: "File Info", formats: [.filename, .filenameWithoutExtension, .parentFolder])
                    }
                    .padding(.trailing, 10)
                    .padding(.bottom, 8)
                }
                .scrollIndicators(.hidden)
                .onScrollGeometryChange(for: ScrollGeometryState.self) { geo in
                    ScrollGeometryState(
                        contentHeight: geo.contentSize.height,
                        viewportHeight: geo.containerSize.height,
                        scrollOffset: geo.contentOffset.y
                    )
                } action: { _, newValue in
                    sidebarContentHeight = newValue.contentHeight
                    sidebarViewportHeight = newValue.viewportHeight
                    sidebarScrollOffset = newValue.scrollOffset
                }

                if sidebarContentHeight > sidebarViewportHeight {
                    let ratio = sidebarViewportHeight / sidebarContentHeight
                    let thumbHeight = max(ratio * sidebarViewportHeight, 30)
                    let maxScrollableOffset = sidebarContentHeight - sidebarViewportHeight
                    let maxScrollbarOffset = sidebarViewportHeight - thumbHeight
                    let fraction = maxScrollableOffset > 0 ? (sidebarScrollOffset / maxScrollableOffset) : 0
                    let thumbOffset = fraction * maxScrollbarOffset

                    // Track background (extremely subtle)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.04))
                        .frame(width: 6)
                        .padding(.vertical, 2)
                        .padding(.trailing, 2)

                    // Drag thumb (always visible)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 6, height: thumbHeight)
                        .offset(y: thumbOffset + (thumbHeight / 2) - (sidebarViewportHeight / 2))
                        .padding(.trailing, 2)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }

    private func formatSectionDivider() -> some View {
        Divider()
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
    }

    private func formatSection(label: String, formats: [PathFormat]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 10)
                .padding(.bottom, 2)

            ForEach(formats, id: \.self) { format in
                let isSelected = selectedFormat == format
                let isHovered = hoverFormat == format

                Button(action: { selectedFormat = format }) {
                    HStack(spacing: 10) {
                        Image(systemName: iconName(for: format))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(isSelected ? .white : .blue)
                            .frame(width: 26, height: 26)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isSelected ? Color.white.opacity(0.2) : Color.blue.opacity(0.08))
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(format.displayName)
                                .font(.subheadline)
                                .fontWeight(isSelected ? .bold : .medium)
                                .foregroundStyle(isSelected ? .white : .primary)

                            Text(format.destinationHint)
                                .font(.caption)
                                .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected ? Color.blue : (isHovered ? Color.blue.opacity(0.08) : Color.clear))
                    )
                }
                .buttonStyle(.plain)
                .onHover { hovering in hoverFormat = hovering ? format : nil }
            }
        }
    }

    private var previewConsoleView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Format preview")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Sample path")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)

                Text(testPath)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Formatted preview")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(nsColor: .windowBackgroundColor))

                Divider()

                HStack {
                    Text(formattedPreview)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.primary)
                        .padding(10)
                    Spacer()
                }
                .frame(minHeight: 48, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(nsColor: .textBackgroundColor))
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
        .frame(maxHeight: .infinity)
    }

    private var contextMenuMockupCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Finder context menu")
                .font(.headline)

            VStack(alignment: .leading, spacing: 0) {
                Group {
                    mockupMenuItem(title: "Copy", icon: "doc.on.doc")
                    mockupMenuItem(title: "Rename", icon: "pencil")
                    mockupMenuItem(title: "Share…", icon: "square.and.arrow.up")
                }
                .opacity(0.6)

                Divider()
                    .padding(.vertical, 4)

                // Active menu item
                HStack {
                    Image(systemName: "folder.badge.plus")
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                    Text("Copy Path As…")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                // Nested submenu preview simulated inline style
                VStack(alignment: .leading, spacing: 4) {
                    mockupSubmenuItem(title: "Absolute Path", isHighlighted: true)
                    mockupSubmenuItem(title: "Shell Quoted")
                    mockupSubmenuItem(title: "Git Relative")
                    mockupSubmenuItem(title: "Markdown Link")
                    mockupSubmenuItem(title: "JSON String")
                }
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .windowBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .padding(.leading, 24)
                .padding(.top, 4)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }

    private func mockupMenuItem(title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 16, height: 16)
            Text(title)
                .font(.subheadline)
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
    }

    private func mockupSubmenuItem(title: String, isHighlighted: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .fontWeight(isHighlighted ? .bold : .regular)
                .foregroundStyle(isHighlighted ? .white : .primary)
            Spacer()
            if isHighlighted {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .background(isHighlighted ? Color.blue : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private var whyNotFinderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Why not just Finder?")
                .font(.title3)
                .fontWeight(.bold)

            Text("Finder can copy paths, but the option is hidden behind Option + right-click. Copy Path As makes file paths visible, customizable, and formatted for the tool you are using.")
                .font(.body)
                .foregroundStyle(.primary)
                .lineSpacing(4)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }

    private var doctorCard: some View {
        let report = AppDoctorReport(
            installationStatus: installationStatus,
            extensionRecentlyActive: extensionEnabled
        )

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: report.issues.isEmpty ? "checkmark.seal.fill" : "stethoscope")
                    .foregroundStyle(report.issues.isEmpty ? .green : .orange)
                    .frame(width: 18)

                Text("Doctor")
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                Button(action: refreshDoctorStatus) {
                    Label("Refresh Status", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityIdentifier("doctor-refresh-status")
            }

            Text(report.title)
                .font(.subheadline)
                .fontWeight(.semibold)

            Text(report.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !report.issues.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(report.issues, id: \.title) { issue in
                        Label(issue.title, systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help(issue.detail)
                    }
                }
            }

            if !report.recommendedActions.isEmpty {
                HStack(spacing: 8) {
                    ForEach(report.recommendedActions, id: \.self) { action in
                        doctorActionButton(for: action)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func doctorActionButton(for action: AppDoctorAction) -> some View {
        if action == .restartFinder {
            Button(action: {
                performDoctorAction(action)
            }) {
                Label(action.title, systemImage: action.systemImage)
                    .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        } else {
            Button(action: {
                performDoctorAction(action)
            }) {
                Label(action.title, systemImage: action.systemImage)
                    .font(.caption)
            }
            .buttonStyle(.bordered)
        }
    }

    private var howItWorksView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How it works")
                .font(.title3)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                howItWorksStep(num: "1", title: "Enable Extension", desc: "Go to System Settings → Extensions → Finder Extensions and enable 'Copy Path As'.")
                howItWorksStep(num: "2", title: "Right-Click Files", desc: "Right-click any file or folder inside a Finder window.")
                howItWorksStep(num: "3", title: "Select Format", desc: "Choose your format from the 'Copy Path As...' menu.")
                howItWorksStep(num: "4", title: "Paste Output", desc: "Paste clean paths directly into your Terminal, IDE, or AI agent.")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }

    private func howItWorksStep(num: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(num)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.blue))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footerView: some View {
        HStack {
            Text("🔒 Local only. No tracking. No path data leaves your Mac.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            Text(buildIdentity.displayString)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("build-identity")

            Spacer()

            Text("Free and open source.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var toastOverlayView: some View {
        VStack {
            Spacer()

            HStack(spacing: 12) {
                Image(systemName: "clipboard.fill")
                    .font(.title2)
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Copied Path to Clipboard!")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .accessibilityIdentifier("copied-toast-title")

                    Text("\(toastFormat): \(toastPath)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .accessibilityIdentifier("copied-toast-detail")
                }
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.blue.opacity(0.4), radius: 10, y: 4)
            .frame(maxWidth: 400)
            .padding(.bottom, 24)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Helpers

    private func iconName(for format: PathFormat) -> String {
        switch format {
        case .path: return "chevron.right.square"
        case .quotedPath: return "quote.bubble"
        case .shellEscapedPath: return "terminal"
        case .homeRelative: return "house.fill"
        case .repoRelative: return "arrow.triangle.branch"
        case .fileURL: return "link"
        case .jsonString: return "curlybraces"
        case .jsonArray: return "square.stack.3d.up"
        case .markdownLink: return "doc.text"
        case .filename: return "doc"
        case .filenameWithoutExtension: return "doc.plaintext"
        case .parentFolder: return "folder"
        }
    }

    private var formattedPreview: String {
        let formatter = PathFormatter()
        let lines = testPath.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let urls = lines.isEmpty
            ? [URL(fileURLWithPath: "/Users/appleseed/Projects/app/sources/main.swift")]
            : lines.map { URL(fileURLWithPath: $0) }

        return formatter.format(urls, as: selectedFormat)
    }

    private func checkForSharedCopyEvents() {
        let timestamp = FinderExtensionManager.readExtensionPreference(forKey: "lastCopiedTimestamp") as? Double ?? 0.0
        guard timestamp > lastSeenTimestamp else { return }

        let path = FinderExtensionManager.readExtensionPreference(forKey: "lastCopiedPath") as? String ?? ""
        let format = FinderExtensionManager.readExtensionPreference(forKey: "lastCopiedFormat") as? String ?? "Path"

        if lastSeenTimestamp == 0.0 {
            lastSeenTimestamp = timestamp
            return
        }

        lastSeenTimestamp = timestamp
        toastPath = path
        toastFormat = format

        withAnimation(.spring()) {
            showToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                if toastPath == path && toastFormat == format {
                    showToast = false
                }
            }
        }
    }

    private func refreshDoctorStatus() {
        guard demoState == nil else { return }
        extensionEnabled = FinderExtensionManager.isRecentlyActive
        installationStatus = installationStatusProvider.currentStatus()
    }

    private func performDoctorAction(_ action: AppDoctorAction) {
        switch action {
        case .openExtensionSettings:
            doctorActionPerformer.openExtensionSettings()
        case .restartFinder:
            doctorActionPerformer.restartFinder()
        case .revealCurrentApp:
            doctorActionPerformer.revealCurrentApp(installationStatus.currentAppURL)
        case .revealDuplicateApp:
            guard let duplicateURL = installationStatus.duplicateAppURLs.first else { return }
            doctorActionPerformer.revealDuplicateApp(duplicateURL)
        }

        refreshDoctorStatus()
    }
}

private extension AppDemoState {
    var initialExtensionEnabled: Bool {
        switch self {
        case .setup: false
        case .overview, .formats, .copied: true
        }
    }

    var initialFormat: PathFormat {
        switch self {
        case .overview, .setup: .path
        case .formats, .copied: .markdownLink
        }
    }

    var initialTab: SettingsView.Tab {
        switch self {
        case .overview, .setup: .overview
        case .formats, .copied: .preview
        }
    }

    var initialTestPath: String {
        switch self {
        case .overview, .setup:
            "/Users/appleseed/Projects/app/sources/main.swift"
        case .formats, .copied:
            "/Users/appleseed/Projects/Sample Project/README.md"
        }
    }
}
// swiftlint:enable type_body_length
