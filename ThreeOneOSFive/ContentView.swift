
import SwiftUI
import AVKit
import Foundation

struct ContentView: View {
    @AppStorage("vexo.darkTheme") private var darkTheme = false
    @State private var selectedGame = "free_fire"
    @State private var selectedTab: MainTab = .home
    @State private var patches: [RemotePatchRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastUpdated: Date?
    @State private var videoPlayer: AVPlayer?

    private let api = VexoPatchAPI()
    private let blue = Color(red: 0.12, green: 0.48, blue: 0.95)

    private var page: Color {
        darkTheme ? .black : .white
    }

    private var card: Color {
        darkTheme
            ? Color(red: 0.055, green: 0.075, blue: 0.11)
            : Color(red: 0.96, green: 0.98, blue: 1.0)
    }

    private var primaryText: Color {
        darkTheme ? .white : .black
    }

    private var secondaryText: Color {
        darkTheme ? .white.opacity(0.65) : .black.opacity(0.58)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Group {
                if selectedTab == .home {
                    homeContent
                } else {
                    infoContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            bottomNavigation
        }
        .background(page.ignoresSafeArea())
        .foregroundStyle(primaryText)
        .tint(blue)
        .preferredColorScheme(darkTheme ? .dark : .light)
        .task {
            configureVideoIfNeeded()
            await loadPatches()
        }
        .onDisappear {
            videoPlayer?.pause()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("VEXO")
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .foregroundStyle(primaryText)

                Text("EXTERNAL")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(blue)
            }

            Spacer()

            Image(systemName: "cloud.fill")
                .font(.system(size: 18))
                .foregroundStyle(blue)

            Text("ONLINE")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .background(page)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(primaryText.opacity(0.10))
                .frame(height: 1)
        }
    }

    private var homeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                videoBanner
                gameSelector

                HStack {
                    Text("ONLINE PATCHES")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.3)
                        .foregroundStyle(secondaryText)

                    Spacer()

                    Button {
                        Task {
                            await loadPatches()
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .disabled(isLoading)
                }

                if isLoading && patches.isEmpty {
                    ProgressView("Loading online patches…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 35)

                } else if let errorMessage {
                    VStack(spacing: 10) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 30))
                            .foregroundStyle(blue)

                        Text("Unable to load online patches")
                            .font(.headline)

                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                            .multilineTextAlignment(.center)

                        Button("Try Again") {
                            Task {
                                await loadPatches()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(22)
                    .background(
                        card,
                        in: RoundedRectangle(cornerRadius: 14)
                    )

                } else if patches.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundStyle(blue)

                        Text("No online patches found")
                            .font(.headline)

                        Text("Uploaded and active patches will appear here when the API returns them.")
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(22)
                    .background(
                        card,
                        in: RoundedRectangle(cornerRadius: 14)
                    )

                } else {
                    ForEach(patches) { patch in
                        patchRow(patch)
                    }
                }

                if let lastUpdated {
                    Text(
                        "Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))"
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(secondaryText)
                }
            }
            .padding(16)
        }
        .background(page)
    }

    private var videoBanner: some View {
        Group {
            if let videoPlayer {
                VideoPlayer(player: videoPlayer)
                    .frame(height: 176)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(blue.opacity(0.35), lineWidth: 1)
                    }
            } else {
                ZStack {
                    LinearGradient(
                        colors: [blue.opacity(0.22), page],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    VStack(spacing: 8) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(blue)

                        Text("VEXO EXTERNAL")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(primaryText)

                        Text("Video banner unavailable")
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                    }
                }
                .frame(height: 176)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var gameSelector: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("SELECT VERSION")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(secondaryText)

            HStack(spacing: 10) {
                gameButton(title: "FF NORMAL", value: "free_fire")
                gameButton(title: "FF MAX", value: "free_fire_max")
            }
        }
    }

    private func gameButton(title: String, value: String) -> some View {
        let selected = selectedGame == value

        return Button {
            guard selectedGame != value else { return }

            selectedGame = value
            patches = []
            errorMessage = nil
            lastUpdated = nil

            Task {
                await loadPatches()
            }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(selected ? Color.white : primaryText)
                .background(selected ? blue : card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            selected ? blue : primaryText.opacity(0.18),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
    }

    private func patchRow(_ patch: RemotePatchRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(blue)
                    .frame(width: 42, height: 42)
                    .background(blue.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 5) {
                    Text(patch.displayName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(primaryText)
                        .lineLimit(2)

                    Text(
                        patch.version.map { "Version \($0)" }
                            ?? "Online package"
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(secondaryText)
                }

                Spacer(minLength: 0)

                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            if let notes = patch.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 12))
                    .foregroundStyle(secondaryText)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(primaryText.opacity(0.12), lineWidth: 1)
        }
    }

    private var infoContent: some View {
        Form {
            Section("Appearance") {
                Toggle("Black / Dark Theme", isOn: $darkTheme)

                Text(
                    darkTheme
                        ? "Dark theme is enabled."
                        : "White and light-blue theme is enabled."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("App", value: "VEXO EXTERNAL")
                LabeledContent("Patch source", value: "Online API")

                LabeledContent(
                    "Selected version",
                    value: selectedGame == "free_fire"
                        ? "FF NORMAL"
                        : "FF MAX"
                )

                Text("Use Refresh on the Home tab to reload the online patch list.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(page)
        .tint(blue)
    }

    private var bottomNavigation: some View {
        HStack(spacing: 0) {
            tabButton(.home, title: "Home", symbol: "house.fill")
            tabButton(.info, title: "Info", symbol: "info.circle.fill")
        }
        .padding(.top, 9)
        .padding(.bottom, 5)
        .background(page)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(primaryText.opacity(0.12))
                .frame(height: 1)
        }
    }

    private func tabButton(
        _ tab: MainTab,
        title: String,
        symbol: String
    ) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))

                Text(title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(
                selectedTab == tab ? blue : secondaryText
            )
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func configureVideoIfNeeded() {
        guard videoPlayer == nil,
              let url = Bundle.main.url(
                forResource: "Create external video",
                withExtension: "mov"
              ) else {
            return
        }

        let player = AVPlayer(url: url)
        player.isMuted = true
        videoPlayer = player
        player.play()

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
    }

    @MainActor
    private func loadPatches() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            patches = try await api.fetch(game: selectedGame)
            lastUpdated = Date()
        } catch {
            patches = []
            errorMessage =
                "Please check your internet connection and API settings."
        }

        isLoading = false
    }
}

private enum MainTab {
    case home
    case info
}

private struct RemotePatchRecord: Decodable, Identifiable {
    let version: String?
    let download_url: URL?
    let file_path: String?
    let notes: String?

    var id: String {
        file_path
            ?? download_url?.absoluteString
            ?? version
            ?? "unnamed-patch"
    }

    var displayName: String {
        let raw = file_path?
            .split(separator: "/")
            .last
            .map(String.init)
            ?? version
            ?? "Unnamed Patch"

        if raw.lowercased().hasSuffix(".3105") {
            return String(raw.dropLast(5))
        }

        return URL(fileURLWithPath: raw)
            .deletingPathExtension()
            .lastPathComponent
    }
}

private struct VexoPatchAPI {
    private let base = URL(
        string: "https://c--46026e77-f295-431b-b24d-5d0b34c299d0-prod.lovable.cloud/rest/v1/patches"
    )!

    private let apiKey =
        "sb_publishable_w4SSt67-eYUVd-YLMKMS7A_J55PowVa"

    func fetch(game: String) async throws -> [RemotePatchRecord] {
        var components = URLComponents(
            url: base,
            resolvingAgainstBaseURL: false
        )!

        components.queryItems = [
            URLQueryItem(name: "game", value: "eq.\(game)"),
            URLQueryItem(name: "active", value: "eq.true"),
            URLQueryItem(
                name: "select",
                value: "version,download_url,file_path,notes"
            )
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(
            [RemotePatchRecord].self,
            from: data
        )
    }
}
