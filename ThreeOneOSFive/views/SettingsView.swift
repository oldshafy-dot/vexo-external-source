
import SwiftUI

struct SettingsView: View {
    @AppStorage("vexo_theme_mode") private var themeMode = "light"

    private var isBlackMode: Bool {
        themeMode == "black"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Appearance", selection: $themeMode) {
                        Text("Light").tag("light")
                        Text("Black").tag("black")
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 12) {
                        Image(systemName: isBlackMode ? "moon.fill" : "sun.max.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(isBlackMode ? "Black Mode" : "Light Mode")
                                .font(.headline)

                            Text(
                                isBlackMode
                                    ? "Black background with light text"
                                    : "White background with blue accents"
                            )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Choose the app appearance you prefer.")
                }

                Section("About") {
                    HStack {
                        Text("App")
                        Spacer()
                        Text("Vexo External")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Version")
                        Spacer()
                        Text(
                            Bundle.main.infoDictionary?["CFBundleShortVersionString"]
                                as? String ?? "1.0"
                        )
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(AppTheme.pageBackground)
        }
        .tint(AppTheme.accent)
        .preferredColorScheme(isBlackMode ? .dark : .light)
    }
}

#Preview {
    SettingsView()
}
