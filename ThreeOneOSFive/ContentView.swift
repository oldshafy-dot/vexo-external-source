import SwiftUI
import UIKit
import AVFoundation

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var patchStore = PatchProjectStore()
    @State private var selectedTab = 0
    @State private var selectedGame = "FF NORMAL"
    @State private var showSettings = false
    @State private var showCleaner = false
    @State private var busyPatchID: UUID?
    @State private var activeIDs = Set<UUID>()
    @State private var status = "READY — SELECT A PATCH"
    @State private var remoteVersionText = "Connecting to patch catalogue…"

    private let sky = Color(red: 0.015, green: 0.025, blue: 0.065)
    private let patchAPI = VexoPatchAPI()

    var body: some View {
        ZStack {
            AnimatedHyperBackdrop().ignoresSafeArea()
            VStack(spacing: 0) {
                if selectedTab == 0 { homeScreen } else { infoScreen }
                bottomBar
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showCleaner) { CleanerView() }
        .sheet(item: $patchStore.passwordRequest, onDismiss: patchStore.cancelUnlock) { _ in
            PatchUnlockPrompt(store: patchStore)
        }
        .onAppear {
            syncStates()
            Task { await refreshCatalogue() }
        }
        .alert(item: $patchStore.alert) { alert in
            Alert(title: Text(alert.titleKey), message: Text(alert.message(language: .english)), dismissButton: .default(Text("OK")))
        }
    }

    private var homeScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 17) {
                header
                BannerVideoView()
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(alignment: .bottomLeading) {
                        HStack(spacing: 7) {
                            Circle().fill(.red).frame(width: 7, height: 7)
                            Text("LIVE").font(.system(size: 11, weight: .black, design: .rounded)).tracking(1.5)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.black.opacity(0.72), in: Capsule()).padding(12)
                    }
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("SELECT GAME")
                    HStack(spacing: 10) {
                        gameCard(title: "FF NORMAL", subtitle: "Normal Edition", selected: selectedGame == "FF NORMAL") { selectedGame = "FF NORMAL" }
                        gameCard(title: "FF MAX", subtitle: "MAX Edition", selected: selectedGame == "FF MAX") { selectedGame = "FF MAX" }
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        sectionTitle("\(selectedGame) PATCHES")
                        Spacer()
                        Button { patchStore.reload(); syncStates() } label: {
                            Image(systemName: "arrow.clockwise").font(.system(size: 14, weight: .bold)).foregroundStyle(AppTheme.accent)
                        }
                    }
                    if patchStore.items.isEmpty {
                        infoCard("No local patch packages found. Check the packaged .3105 resources and build workflow.")
                    } else {
                        ForEach(displayItems) { item in
                            patchRow(item)
                        }
                    }
                    Text(status).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(AppTheme.secondaryAccent.opacity(0.82)).padding(.horizontal, 4)
                    Text(remoteVersionText).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.48)).padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 22)
        }
    }

    private var infoScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header
                sectionTitle("DEVICE STATUS")
                VStack(spacing: 0) {
                    statusRow("iOS Version", AppInfo.osVersion)
                    statusRow("Device", AppInfo.displayMachineName)
                    statusRow("Support", appState.isSupported ? "SUPPORTED" : "UNSUPPORTED")
                    statusRow("Local Packages", "\(patchStore.items.count)")
                }.padding(15).background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.accent.opacity(0.24), lineWidth: 1))
                sectionTitle("TOOLS & SETTINGS")
                Button { showCleaner = true } label: { infoAction("Clean Cache & Temp", icon: "trash.slash") }
                Button { showSettings = true } label: { infoAction("Settings", icon: "gearshape") }
                sectionTitle("ABOUT VEXO EXTERNAL")
                infoCard("Vexo external\nPatch manager interface")
                Button {
                    if let url = URL(string: "https://t.me/shafaycheatsff") { UIApplication.shared.open(url) }
                } label: { infoAction("Developer Shafey", icon: "paperplane.fill") }
            }.padding(16).padding(.top, 14).padding(.bottom, 24)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Vexo").font(.system(size: 29, weight: .black, design: .rounded)).foregroundStyle(.white)
                Text("external").font(.system(size: 13, weight: .semibold, design: .rounded)).tracking(2.4).foregroundStyle(AppTheme.accent)
            }
            Spacer()
            Text("READY").font(.system(size: 10, weight: .black, design: .rounded)).tracking(1).foregroundStyle(AppTheme.accent).padding(.horizontal, 12).padding(.vertical, 8).background(AppTheme.accent.opacity(0.12), in: Capsule()).overlay(Capsule().stroke(AppTheme.accent.opacity(0.3), lineWidth: 1))
        }.padding(.bottom, 2)
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            tabButton(title: "Home", icon: "house.fill", index: 0)
            tabButton(title: "Info", icon: "info.circle.fill", index: 1)
        }
        .padding(.top, 9).padding(.bottom, 5).background(.black.opacity(0.88)).overlay(alignment: .top) { Rectangle().fill(AppTheme.accent.opacity(0.2)).frame(height: 1) }
    }

    private func tabButton(title: String, icon: String, index: Int) -> some View {
        Button { selectedTab = index } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold))
                Text(title).font(.system(size: 10, weight: .bold))
            }.foregroundStyle(selectedTab == index ? AppTheme.accent : .white.opacity(0.48)).frame(maxWidth: .infinity).padding(.bottom, 3)
        }.buttonStyle(.plain)
    }

    private var displayItems: [PatchLibraryItem] {
        let normalFiles: Set<String> = [
            "OGIOS File (6).OGIOS", "OGIOS File (7).OGIOS", "OGIOS File (8).OGIOS",
            "OGIOS File (10).OGIOS", "OGIOS File (12).OGIOS", "OGIOS File (2).OGIOS",
            "OGIOS File (14).OGIOS"
        ]
        return patchStore.items.filter { item in
            let isNormal = normalFiles.contains(item.packageURL.lastPathComponent)
            return selectedGame == "FF NORMAL" ? isNormal : !isNormal
        }
    }

    private func gameCard(title: String, subtitle: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.system(size: 14, weight: .black, design: .rounded)).foregroundStyle(.white)
                Text(subtitle).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.56))
                Text(selected ? "SELECTED" : "SELECT").font(.system(size: 9, weight: .black)).tracking(1).foregroundStyle(selected ? AppTheme.accent : .white.opacity(0.45)).padding(.top, 3)
            }.frame(maxWidth: .infinity, minHeight: 82, alignment: .leading).padding(13).background(.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 17)).overlay(RoundedRectangle(cornerRadius: 17).stroke(selected ? AppTheme.accent.opacity(0.9) : .white.opacity(0.12), lineWidth: selected ? 1.5 : 1))
        }.buttonStyle(.plain)
    }

    private func patchRow(_ item: PatchLibraryItem) -> some View {
        let enabled = activeIDs.contains(item.id)
        let name = cleanName(item.packageURL.deletingPathExtension().lastPathComponent)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white).lineLimit(1)
                Text(item.isLocked ? "PACKAGE LOCKED" : (enabled ? "PATCH ACTIVE" : "READY TO APPLY"))
                    .font(.system(size: 9, weight: .bold, design: .rounded)).tracking(0.7)
                    .foregroundStyle(enabled ? .green : .white.opacity(0.48))
            }
            Spacer(minLength: 6)
            if busyPatchID == item.id { ProgressView().tint(AppTheme.accent) }
            else {
                Toggle("", isOn: Binding(get: { enabled }, set: { _ in toggle(item) }))
                    .labelsHidden().tint(AppTheme.accent).disabled(item.isLocked || busyPatchID != nil)
            }
        }.padding(.horizontal, 14).padding(.vertical, 12)
            .background(.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(enabled ? AppTheme.accent.opacity(0.55) : .white.opacity(0.10), lineWidth: 1))
    }

    private func cleanName(_ raw: String) -> String {
        let known: [String: String] = [
            "OGIOS File (6)": "Aim Drag", "OGIOS File (7)": "Aim Neck",
            "OGIOS File (8)": "Antenna", "OGIOS File (10)": "144 FPS",
            "OGIOS File (12)": "Aim Body", "OGIOS File (2)": "Aim Chest",
            "OGIOS File (14)": "Magic"
        ]
        if let name = known[raw] { return name }
        if raw.hasPrefix("OGIOS File (") { return "Patch " + raw.replacingOccurrences(of: "OGIOS File (", with: "").replacingOccurrences(of: ")", with: "") }
        return raw
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.system(size: 11, weight: .black, design: .rounded)).tracking(1.4).foregroundStyle(AppTheme.accent)
    }

    private func infoCard(_ message: String) -> some View {
        Text(message).font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.72)).frame(maxWidth: .infinity, alignment: .leading).padding(15).background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(0.10), lineWidth: 1))
    }

    private func infoAction(_ title: String, icon: String) -> some View {
        HStack(spacing: 12) { Image(systemName: icon).foregroundStyle(AppTheme.accent).frame(width: 23); Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(.white); Spacer(); Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.35)) }
            .padding(14).background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.10), lineWidth: 1))
    }

    private func statusRow(_ title: String, _ value: String) -> some View {
        HStack { Text(title).foregroundStyle(.white.opacity(0.58)); Spacer(); Text(value).fontWeight(.bold).foregroundStyle(.white) }.font(.system(size: 12)).padding(.vertical, 9)
    }

    private func syncStates() {
        activeIDs = Set(patchStore.items.compactMap { item in DevicePatchService.latestReceipt(projectID: item.id) == nil ? nil : item.id })
    }

    private func toggle(_ item: PatchLibraryItem) {
        guard busyPatchID == nil else { return }
        if item.isLocked { patchStore.requestUnlock(for: item); status = "PASSWORD REQUIRED"; return }
        busyPatchID = item.id
        let wasOn = activeIDs.contains(item.id)
        let project = item.project
        let projectID = item.id
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                if wasOn {
                    guard let receipt = DevicePatchService.latestReceipt(projectID: projectID) else { throw PatchPackageError.invalidProject }
                    try DevicePatchService.restore(receipt: receipt)
                } else {
                    guard let project else { throw PatchPackageError.invalidProject }
                    _ = try DevicePatchService.apply(project: project)
                }
                DispatchQueue.main.async {
                    if wasOn { activeIDs.remove(projectID); status = "RESTORE SUCCESSFUL" }
                    else { activeIDs.insert(projectID); status = "PATCH APPLIED SUCCESSFULLY" }
                    busyPatchID = nil
                }
            } catch {
                DispatchQueue.main.async { status = "FAILED — \(error.localizedDescription)"; busyPatchID = nil; syncStates() }
            }
        }
    }

    private func refreshCatalogue() async {
        do {
            let normal = try await patchAPI.fetch(game: "free_fire")
            let max = try await patchAPI.fetch(game: "free_fire_max")
            await MainActor.run { remoteVersionText = "Online catalogue: FF NORMAL \(normal.count) • FF MAX \(max.count)" }
        } catch {
            await MainActor.run { remoteVersionText = "Online catalogue unavailable — local packages remain visible" }
        }
    }
}

private struct RemotePatchRecord: Decodable {
    let version: String?
    let download_url: URL?
    let file_path: String?
    let notes: String?
}

private struct VexoPatchAPI {
    private let base = URL(string: "https://c--46026e77-f295-431b-b24d-5d0b34c299d0-prod.lovable.cloud/rest/v1/patches")!
    private let apiKey = "sb_publishable_w4SSt67-eYUVd-YLMKMS7A_J55PowVa"
    func fetch(game: String) async throws -> [RemotePatchRecord] {
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "game", value: "eq.\(game)"), URLQueryItem(name: "active", value: "eq.true"), URLQueryItem(name: "select", value: "version,download_url,file_path,notes")]
        var request = URLRequest(url: components.url!)
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode([RemotePatchRecord].self, from: data)
    }
}

private struct BannerVideoView: UIViewRepresentable {
    func makeUIView(context: Context) -> LoopingVideoUIView {
        let view = LoopingVideoUIView()
        view.play()
        return view
    }
    func updateUIView(_ uiView: LoopingVideoUIView, context: Context) { uiView.play() }
}

private final class LoopingVideoUIView: UIView {
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var layerPlayer: AVPlayerLayer { layer as! AVPlayerLayer }
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    override init(frame: CGRect) {
        super.init(frame: frame)
        guard let url = Bundle.main.url(forResource: "Create external video", withExtension: "mov") else { return }
        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer()
        queue.isMuted = false
        queue.volume = 1
        looper = AVPlayerLooper(player: queue, templateItem: item)
        player = queue
        layerPlayer.player = queue
        layerPlayer.videoGravity = .resizeAspectFill
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func play() { player?.play() }
}


private struct PatchUnlockPrompt: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PatchProjectStore
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Package password", text: $password)
                        .textContentType(.password)
                        .submitLabel(.done)
                        .onSubmit(unlock)
                        .onChange(of: password) { _ in store.clearUnlockError() }
                    if let errorKey = store.unlockErrorKey {
                        Text(AppLanguage.english.text(errorKey))
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text("Enter the password once to unlock this patch package on this device.")
                }
            }
            .navigationTitle("Unlock package")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Unlock", action: unlock)
                        .disabled(password.isEmpty || store.isBusy)
                }
            }
        }
    }

    private func unlock() {
        guard !password.isEmpty else { return }
        store.unlock(password: password)
    }
}

struct AnimatedHyperBackdrop: View {
    @State private var animate = false
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppTheme.pageBackground
                Circle()
                    .fill(AppTheme.accent.opacity(0.12))
                    .frame(width: 280, height: 280)
                    .blur(radius: 70)
                    .offset(x: animate ? 120 : -120, y: -proxy.size.height * 0.23)
                Circle()
                    .fill(AppTheme.secondaryAccent.opacity(0.08))
                    .frame(width: 260, height: 260)
                    .blur(radius: 80)
                    .offset(x: animate ? -100 : 100, y: proxy.size.height * 0.22)
                GridOverlay()
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) { animate = true }
            }
        }
    }
}

private struct GridOverlay: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            let spacing: CGFloat = 44
            stride(from: CGFloat(0), through: size.width, by: spacing).forEach { x in
                path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
            }
            stride(from: CGFloat(0), through: size.height, by: spacing).forEach { y in
                path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(AppTheme.accent.opacity(0.055)), lineWidth: 1)
        }
    }
}
