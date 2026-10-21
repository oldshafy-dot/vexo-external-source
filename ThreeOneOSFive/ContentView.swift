
import SwiftUI
import Foundation

struct ContentView: View {
    @State private var selectedGame = "free_fire"
    @State private var patches: [RemotePatchRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastUpdated: Date?

    private let api = VexoPatchAPI()
    private let blue = Color(red: 0.12, green: 0.48, blue: 0.95)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        gameSelector

                        HStack {
                            Text("ONLINE PATCHES")
                                .font(.system(size: 12, weight: .bold))
                                .tracking(1.3)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button {
                                Task { await loadPatches() }
                            } label: {
                                Label("Refresh", systemImage: "arrow.clockwise")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .disabled(isLoading)
                        }

                        if isLoading && patches.isEmpty {
                            ProgressView("Loading online patches…")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)

                        } else if let errorMessage {
                            VStack(spacing: 10) {
                                Image(systemName: "wifi.exclamationmark")
                                    .font(.system(size: 30))
                                    .foregroundStyle(blue)

                                Text("Unable to load online patches")
                                    .font(.headline)

                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)

                                Button("Try Again") {
                                    Task { await loadPatches() }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(24)

                        } else if patches.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 32))
                                    .foregroundStyle(blue)

                                Text("No online patches found")
                                    .font(.headline)

                                Text("Uploaded and active patches will appear here when the API returns them.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(24)

                        } else {
                            ForEach(patches) { patch in
                                patchRow(patch)
                            }
                        }

                        if let lastUpdated {
                            Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                }
                .background(Color.white)
            }
            .background(Color.white.ignoresSafeArea())
            .foregroundStyle(Color.black)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await loadPatches()
            }
        }
        .tint(blue)
        .preferredColorScheme(.light)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("VEXO")
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .foregroundStyle(Color.black)

                Text("EXTERNAL")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(blue)
            }

            Spacer()

            Image(systemName: "cloud.fill")
                .font(.system(size: 19))
                .foregroundStyle(blue)

            Text("ONLINE")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color.white)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1)
        }
    }

    private var gameSelector: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("SELECT VERSION")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.secondary)

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
                .foregroundStyle(selected ? Color.white : Color.black)
                .background(selected ? blue : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            selected ? blue : Color.gray.opacity(0.3),
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
                    .background(blue.opacity(0.09))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 5) {
                    Text(patch.displayName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.black)
                        .lineLimit(2)

                    Text(
                        patch.version.map { "Version \($0)" }
                            ?? "Online package"
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            if let notes = patch.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.10), lineWidth: 1)
        }
    }

    @MainActor
    private func loadPatches() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await api.fetch(game: selectedGame)
            patches = result
            lastUpdated = Date()
        } catch {
            patches = []
            errorMessage = "Please check your internet connection and API settings."
        }

        isLoading = false
    }
}

private struct RemotePatchRecord: Decodable, Identifiable {
    let version: String?
    let download_url: URL?
    let file_path: String?
    let notes: String?

    var id: String {
        file_path ?? download_url?.absoluteString ?? version ?? UUID().uuidString
    }

    var displayName: String {
        let raw = file_path?
            .split(separator: "/")
            .last
            .map(String.init) ?? version ?? "Unnamed Patch"

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

    private let apiKey = "sb_publishable_w4SSt67-eYUVd-YLMKMS7A_J55PowVa"

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
