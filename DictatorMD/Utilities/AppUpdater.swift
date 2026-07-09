import AppKit
import CryptoKit
import Foundation

@MainActor
final class AppUpdater: ObservableObject {
    static let shared = AppUpdater()

    enum State: Equatable {
        case idle
        case checking
        case available(version: String)
        case upToDate
        case downloading(progress: Double)
        case installing
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private let repositoryAPI = URL(string: "https://api.github.com/repos/AdSaver-Labs/Dictator-md/releases/latest")!
    private let appName = "Dictator-md.app"
    private var latestRelease: GitHubRelease?
    private var checkTask: Task<Void, Never>?

    private init() {}

    var isUpdateAvailable: Bool {
        if case .available = state { return true }
        return false
    }

    var statusText: String {
        switch state {
        case .idle:
            return "Check for updates"
        case .checking:
            return "Checking updates..."
        case .available(let version):
            return "New version \(version)"
        case .upToDate:
            return "Up to date"
        case .downloading(let progress):
            return "Downloading \(Int((progress * 100).rounded()))%"
        case .installing:
            return "Installing update..."
        case .failed:
            return "Update check failed"
        }
    }

    func checkForUpdates(force: Bool = false) {
        if !force, case .checking = state { return }
        checkTask?.cancel()
        checkTask = Task { [weak self] in
            await self?.performCheck()
        }
    }

    func installAvailableUpdate() {
        guard case .available = state, let latestRelease else {
            checkForUpdates(force: true)
            return
        }

        Task { [weak self] in
            await self?.downloadAndInstall(release: latestRelease)
        }
    }

    private func performCheck() async {
        state = .checking
        do {
            var request = URLRequest(url: repositoryAPI)
            request.setValue("Dictator-md/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.cachePolicy = .reloadIgnoringLocalCacheData

            let (data, response) = try await URLSession.shared.data(for: request)
            try Self.validateHTTP(response)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            latestRelease = release

            if Self.isRemoteVersion(release.version, newerThan: Self.currentVersion) {
                state = .available(version: release.version)
            } else {
                state = .upToDate
            }
        } catch {
            state = .failed(Self.cleanError(error))
        }
    }

    private func downloadAndInstall(release: GitHubRelease) async {
        guard let dmgAsset = release.dmgAsset else {
            state = .failed("No Dictator-md DMG is attached to the latest release.")
            return
        }

        do {
            state = .downloading(progress: 0.02)
            let workDirectory = AppPaths.supportSubdirectory("Updates")
            try? FileManager.default.removeItem(at: workDirectory)
            try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)

            let dmgURL = workDirectory.appendingPathComponent("Dictator-md-\(release.version).dmg")
            try await download(asset: dmgAsset, to: dmgURL)

            if let checksumAsset = release.checksumAsset {
                let checksumURL = workDirectory.appendingPathComponent("Dictator-md-\(release.version).dmg.sha256")
                try await download(asset: checksumAsset, to: checksumURL, progressBase: 0.94, progressSpan: 0.03)
                try Self.verifyChecksum(dmgURL: dmgURL, checksumURL: checksumURL)
            }

            state = .installing
            try launchInstallerScript(for: dmgURL)
        } catch {
            state = .failed(Self.cleanError(error))
        }
    }

    private func download(
        asset: GitHubRelease.Asset,
        to destination: URL,
        progressBase: Double = 0.04,
        progressSpan: Double = 0.90
    ) async throws {
        var request = URLRequest(url: asset.browserDownloadURL)
        request.setValue("Dictator-md/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")
        let (tempURL, response) = try await URLSession.shared.download(for: request)
        try Self.validateHTTP(response)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: tempURL, to: destination)
        state = .downloading(progress: min(0.97, progressBase + progressSpan))
    }

    private func launchInstallerScript(for dmgURL: URL) throws {
        let scriptURL = AppPaths.supportSubdirectory("Updates").appendingPathComponent("install-update-\(UUID().uuidString).zsh")
        let appPath = Bundle.main.bundleURL.path
        let pid = ProcessInfo.processInfo.processIdentifier
        let script = """
        #!/bin/zsh
        set -euo pipefail

        DMG_PATH='\(Self.shellEscaped(dmgURL.path))'
        APP_PATH='\(Self.shellEscaped(appPath))'
        APP_NAME='\(Self.shellEscaped(appName))'
        OLD_PID='\(pid)'
        MOUNT_DIR="$(mktemp -d /tmp/dictator-md-update.XXXXXX)"

        while kill -0 "$OLD_PID" 2>/dev/null; do
            sleep 0.2
        done

        cleanup() {
            hdiutil detach "$MOUNT_DIR" -quiet >/dev/null 2>&1 || true
            rmdir "$MOUNT_DIR" >/dev/null 2>&1 || true
        }
        trap cleanup EXIT

        hdiutil attach "$DMG_PATH" -mountpoint "$MOUNT_DIR" -nobrowse -quiet

        if [[ ! -d "$MOUNT_DIR/$APP_NAME" ]]; then
            osascript -e 'display alert "Dictator-md update failed" message "The downloaded release did not contain Dictator-md.app."'
            exit 1
        fi

        rm -rf "$APP_PATH"
        ditto "$MOUNT_DIR/$APP_NAME" "$APP_PATH"
        xattr -dr com.apple.quarantine "$APP_PATH" >/dev/null 2>&1 || true
        open "$APP_PATH"
        """

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [scriptURL.path]
        try process.run()

        NSApplication.shared.terminate(nil)
    }

    private static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    private static func isRemoteVersion(_ remote: String, newerThan local: String) -> Bool {
        compareVersions(remote, local) == .orderedDescending
    }

    private static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = versionParts(lhs)
        let right = versionParts(rhs)
        let count = max(left.count, right.count)
        for index in 0..<count {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            if a > b { return .orderedDescending }
            if a < b { return .orderedAscending }
        }
        return .orderedSame
    }

    private static func versionParts(_ version: String) -> [Int] {
        version
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            .split { !$0.isNumber }
            .map { Int($0) ?? 0 }
    }

    private static func verifyChecksum(dmgURL: URL, checksumURL: URL) throws {
        let checksumText = try String(contentsOf: checksumURL, encoding: .utf8)
        guard let expected = checksumText.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" }).first else {
            throw UpdaterError.invalidChecksumFile
        }
        let data = try Data(contentsOf: dmgURL)
        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard actual.caseInsensitiveCompare(String(expected)) == .orderedSame else {
            throw UpdaterError.checksumMismatch
        }
    }

    private static func validateHTTP(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            throw UpdaterError.httpStatus(http.statusCode)
        }
    }

    private static func shellEscaped(_ text: String) -> String {
        text.replacingOccurrences(of: "'", with: "'\\''")
    }

    private static func cleanError(_ error: Error) -> String {
        if let updaterError = error as? UpdaterError {
            return updaterError.localizedDescription
        }
        return error.localizedDescription
    }
}

private struct GitHubRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL

        private enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    let tagName: String
    let assets: [Asset]

    var version: String {
        tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }

    var dmgAsset: Asset? {
        assets.first { $0.name == "Dictator-md.dmg" || $0.name.hasSuffix(".dmg") }
    }

    var checksumAsset: Asset? {
        assets.first { $0.name == "Dictator-md.dmg.sha256" || $0.name.hasSuffix(".sha256") }
    }

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case assets
    }
}

private enum UpdaterError: LocalizedError {
    case httpStatus(Int)
    case invalidChecksumFile
    case checksumMismatch

    var errorDescription: String? {
        switch self {
        case .httpStatus(let status):
            return "GitHub returned HTTP \(status)."
        case .invalidChecksumFile:
            return "The release checksum file is invalid."
        case .checksumMismatch:
            return "The downloaded update failed checksum verification."
        }
    }
}
