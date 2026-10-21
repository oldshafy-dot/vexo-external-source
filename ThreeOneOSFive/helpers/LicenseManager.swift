import Combine
import Foundation
import Security

@MainActor
final class LicenseManager: ObservableObject {
    @Published private(set) var expirationDate: Date?
    @Published private(set) var isActive = false
    @Published private(set) var isBusy = false
    @Published private(set) var message: String?
    @Published private(set) var contactOwner: String?
    @Published var rememberKey = true

    private let service = "com.vexo.external.activation"
    private let keyAccount = "license-key"

    private let endpoint = URL(
        string: "https://c--46026e77-f295-431b-b24d-5d0b34c299d0-prod.lovable.cloud/rest/v1/rpc/verify_key"
    )!

    private let apiKey = "sb_publishable_w4SSt67-eYUVd-YLMKMS7A_J55PowVa"
    private var lastAttemptAt: Date?

    init() {
        isActive = false
    }

    var hasRememberedKey: Bool {
        string(for: keyAccount) != nil
    }

    func beginLaunchSession() {
        guard let key = rememberedKey() else {
            isActive = false
            message = "Please enter your key to continue."
            return
        }

        verify(key: key, saveIfValid: false)
    }

    func activate(key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty, !isBusy else { return }

        if let lastAttemptAt,
           Date().timeIntervalSince(lastAttemptAt) < 1 {
            message = "Please wait a moment before trying again"
            return
        }

        lastAttemptAt = Date()
        verify(key: trimmed, saveIfValid: rememberKey)
    }

    private func verify(key: String, saveIfValid: Bool) {
        guard !isBusy else { return }

        isBusy = true
        isActive = false
        message = "Verifying key…"

        Task {
            do {
                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.timeoutInterval = 20
                request.setValue(apiKey, forHTTPHeaderField: "apikey")
                request.setValue(
                    "application/json",
                    forHTTPHeaderField: "Content-Type"
                )
                request.setValue(
                    "application/json",
                    forHTTPHeaderField: "Accept"
                )

                request.httpBody = try JSONSerialization.data(
                    withJSONObject: ["check_key": key]
                )

                let (data, response) = try await URLSession.shared.data(
                    for: request
                )

                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }

                let parsed = try JSONSerialization.jsonObject(with: data)

                let object: [String: Any]?
                if let array = parsed as? [[String: Any]] {
                    object = array.first
                } else {
                    object = parsed as? [String: Any]
                }

                let valid = (object?["valid"] as? Bool) ?? false
                let expiryText = object?["expires_at"] as? String

                await MainActor.run {
                    self.isBusy = false

                    guard valid else {
                        self.isActive = false
                        self.message = "Invalid, expired, or inactive key"
                        self.delete(self.keyAccount)
                        return
                    }

                    self.isActive = true
                    self.expirationDate = expiryText.flatMap(Self.parseDate)

                    if saveIfValid {
                        self.save(key, for: self.keyAccount)
                    }

                    self.message = "Key verified successfully"
                }
            } catch {
                await MainActor.run {
                    self.isBusy = false
                    self.isActive = false
                    self.message =
                        "Could not verify key. Check your internet and try again."
                }
            }
        }
    }

    func rememberedKey() -> String? {
        string(for: keyAccount)
    }

    func refresh() {
        beginLaunchSession()
    }

    func deactivate() {
        delete(keyAccount)
        isActive = false
        message = "Activation removed from this device"
    }

    private static func parseDate(_ value: String) -> Date? {
        let iso = ISO8601DateFormatter()

        if let date = iso.date(from: value) {
            return date
        }

        iso.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        return iso.date(from: value)
    }

    private func string(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?

        guard SecItemCopyMatching(
            query as CFDictionary,
            &result
        ) == errSecSuccess,
        let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private func save(_ value: String, for account: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(base as CFDictionary)

        var item = base
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] =
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        SecItemAdd(item as CFDictionary, nil)
    }

    private func delete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }
}
