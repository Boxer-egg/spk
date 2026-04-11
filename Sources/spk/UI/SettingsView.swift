import SwiftUI

enum SettingsTab: String, CaseIterable {
    case general, api, prompt, shortcuts

    var title: String {
        switch self {
        case .general: return localized("settings.tab.general")
        case .api: return localized("settings.tab.api")
        case .prompt: return localized("settings.tab.prompt")
        case .shortcuts: return localized("settings.tab.shortcuts")
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .api: return "network"
        case .prompt: return "text.bubble.fill"
        case .shortcuts: return "keyboard.fill"
        }
    }
}

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 4) {
                Text("Spk")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                Text(localized("settings.title"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 12)

                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        HStack(spacing: 8) {
                            Image(systemName: tab.icon)
                                .frame(width: 18)
                            Text(tab.title)
                                .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(selectedTab == tab ? .primary : .secondary)
                    .background(
                        selectedTab == tab
                            ? Color(nsColor: .selectedContentBackgroundColor)
                            : Color.clear
                    )
                    .cornerRadius(6)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 28)
            .padding(.bottom, 12)
            .frame(width: 160)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Content
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .api:
                    APISettingsView()
                case .prompt:
                    PromptSettingsView()
                case .shortcuts:
                    ShortcutSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 640, height: 840)
    }
}
