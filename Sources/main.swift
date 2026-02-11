import AppKit
import Darwin
import Foundation
import SwiftUI

final class GarconPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

struct LocalServer: Hashable, Codable, Identifiable {
    let pid: Int
    let processName: String
    let port: Int
    let scheme: String
    let pageTitle: String?
    let executablePath: String?

    var id: String {
        "\(pid)-\(port)-\(scheme)"
    }

    var urlString: String {
        "\(scheme)://localhost:\(port)"
    }

    var isSystemProcess: Bool {
        let name = processName.lowercased()
        if name == "ipnextension" {
            return true
        }
        if name.contains("figma") {
            return true
        }

        guard let executablePath else {
            return false
        }

        let lower = executablePath.lowercased()
        return lower.hasPrefix("/system/") ||
            lower.hasPrefix("/usr/libexec/") ||
            lower.hasPrefix("/usr/sbin/") ||
            lower.hasPrefix("/sbin/") ||
            lower.hasPrefix("/library/systemextensions/") ||
            lower.contains(".appex/") ||
            lower.contains("figma")
    }

    var serverType: String {
        let lower = processName.lowercased()
        let tokens = lower
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)

        if tokens.contains("node") { return "node" }
        if tokens.contains("python") { return "python" }
        if tokens.contains("ruby") { return "ruby" }
        if tokens.contains("php") { return "php" }
        if tokens.contains("java") { return "java" }
        if tokens.contains("bun") { return "bun" }
        if tokens.contains("deno") { return "deno" }
        if tokens.contains("go") { return "go" }
        if tokens.contains("rust") { return "rust" }
        if tokens.contains("dotnet") { return "dotnet" }
        if isSystemProcess { return "system" }
        return tokens.first ?? lower
    }

    var displayTitle: String {
        if let pageTitle, !pageTitle.isEmpty {
            return pageTitle
        }
        return processName
    }
}

final class Shell {
    @discardableResult
    static func run(_ launchPath: String, _ arguments: [String]) -> (status: Int32, stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        var stdoutData = Data()
        var stderrData = Data()
        let outputGroup = DispatchGroup()

        outputGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            outputGroup.leave()
        }

        outputGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            outputGroup.leave()
        }

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (1, "", "\(error)")
        }

        outputGroup.wait()

        let stdout = String(decoding: stdoutData, as: UTF8.self)
        let stderr = String(decoding: stderrData, as: UTF8.self)
        return (process.terminationStatus, stdout, stderr)
    }
}

final class ServerScanner {
    private struct ServerProbe {
        let scheme: String
        let pageTitle: String?
    }

    private struct HTTPProbe {
        let pageTitle: String?
    }

    func findWebServers() -> [LocalServer] {
        let listeners = listeningSockets()
        guard !listeners.isEmpty else {
            return []
        }

        let workQueue = DispatchQueue(label: "garcon.scan.probe", attributes: .concurrent)
        let lock = NSLock()
        let group = DispatchGroup()
        let limiter = DispatchSemaphore(value: 6)
        var servers: [LocalServer] = []

        for socket in listeners {
            limiter.wait()
            group.enter()
            workQueue.async { [weak self] in
                defer {
                    limiter.signal()
                    group.leave()
                }

                guard let self, let probe = self.probeWebServer(port: socket.port) else {
                    return
                }

                let server = LocalServer(
                    pid: socket.pid,
                    processName: socket.processName,
                    port: socket.port,
                    scheme: probe.scheme,
                    pageTitle: probe.pageTitle,
                    executablePath: socket.executablePath
                )

                lock.lock()
                servers.append(server)
                lock.unlock()
            }
        }

        group.wait()

        return servers.sorted { lhs, rhs in
            if lhs.isSystemProcess != rhs.isSystemProcess {
                return !lhs.isSystemProcess && rhs.isSystemProcess
            }
            if lhs.port == rhs.port {
                return lhs.pid < rhs.pid
            }
            return lhs.port < rhs.port
        }
    }

    private func listeningSockets() -> [(pid: Int, processName: String, port: Int, executablePath: String?)] {
        let result = Shell.run(
            "/usr/sbin/lsof",
            ["-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcn"]
        )

        guard result.status == 0 else {
            return []
        }

        var sockets: [(Int, String, Int, String?)] = []
        var currentPID: Int?
        var currentCommand = ""
        var dedupe = Set<String>()
        var pathCache = [Int: String?]()

        for rawLine in result.stdout.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(rawLine)
            guard let prefix = line.first else {
                continue
            }

            let value = String(line.dropFirst())
            switch prefix {
            case "p":
                currentPID = Int(value)
            case "c":
                currentCommand = value
            case "n":
                guard let pid = currentPID, let port = extractPort(from: value) else {
                    continue
                }
                let key = "\(pid):\(port)"
                if dedupe.contains(key) {
                    continue
                }
                dedupe.insert(key)
                if pathCache[pid] == nil {
                    pathCache[pid] = processExecutablePath(pid: pid)
                }
                sockets.append((pid, currentCommand, port, pathCache[pid] ?? nil))
            default:
                continue
            }
        }

        return sockets
    }

    private func processExecutablePath(pid: Int) -> String? {
        let result = Shell.run("/bin/ps", ["-p", "\(pid)", "-o", "comm="])
        guard result.status == 0 else {
            return nil
        }
        let value = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func extractPort(from raw: String) -> Int? {
        let withoutState = raw.components(separatedBy: " ").first ?? raw
        guard let lastColon = withoutState.lastIndex(of: ":") else {
            return nil
        }

        let portText = withoutState[withoutState.index(after: lastColon)...]
        return Int(portText)
    }

    private func probeWebServer(port: Int) -> ServerProbe? {
        if let http = probe(urlString: "http://127.0.0.1:\(port)", insecureTLS: false) {
            return ServerProbe(scheme: "http", pageTitle: http.pageTitle)
        }

        if let https = probe(urlString: "https://127.0.0.1:\(port)", insecureTLS: true) {
            return ServerProbe(scheme: "https", pageTitle: https.pageTitle)
        }

        return nil
    }

    private func probe(urlString: String, insecureTLS: Bool) -> HTTPProbe? {
        var arguments = [
            "-sS",
            "-L",
            "--max-time", "0.7",
            "--range", "0-32767",
            "-o", "-",
            "-w", "\n__GARSON_STATUS__:%{http_code}"
        ]
        if insecureTLS {
            arguments.append("-k")
        }
        arguments.append(urlString)

        let result = Shell.run("/usr/bin/curl", arguments)
        guard let markerRange = result.stdout.range(of: "\n__GARSON_STATUS__:") else {
            return nil
        }

        let body = String(result.stdout[..<markerRange.lowerBound])
        let statusText = String(result.stdout[markerRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let statusCode = Int(statusText), (100...599).contains(statusCode) else {
            return nil
        }

        let title = extractTitle(from: body)
        return HTTPProbe(pageTitle: title)
    }

    private func extractTitle(from html: String) -> String? {
        let pattern = "<title[^>]*>(.*?)</title>"
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return nil
        }

        let fullRange = NSRange(location: 0, length: html.utf16.count)
        guard
            let match = regex.firstMatch(in: html, options: [], range: fullRange),
            let titleRange = Range(match.range(at: 1), in: html)
        else {
            return nil
        }

        let rawTitle = String(html[titleRange])
        let flattened = decodeHTMLEntities(rawTitle)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return flattened.isEmpty ? nil : flattened
    }

    private func decodeHTMLEntities(_ text: String) -> String {
        var decoded = text
        let replacements: [(String, String)] = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&nbsp;", " ")
        ]

        for (entity, replacement) in replacements {
            decoded = decoded.replacingOccurrences(of: entity, with: replacement)
        }

        return decoded
    }
}

final class ServerStore: ObservableObject {
    @Published var servers: [LocalServer] = []
    @Published var isRefreshing = false
    @Published var lastRefreshDate: Date?

    private let scanner = ServerScanner()
    private let cacheKey = "garcon.cachedServers.v1"

    var primaryServers: [LocalServer] {
        servers.filter { !$0.isSystemProcess }
    }

    var systemServers: [LocalServer] {
        servers.filter(\.isSystemProcess)
    }

    init() {
        loadCachedServers()
        refreshServers()
    }

    func refreshServers() {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let latest = self.scanner.findWebServers()

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.servers = latest
                self.lastRefreshDate = Date()
                self.saveCachedServers()
                self.isRefreshing = false
            }
        }
    }

    func kill(_ server: LocalServer) {
        _ = Darwin.kill(pid_t(server.pid), SIGTERM)
        servers.removeAll(where: { $0.pid == server.pid })
        saveCachedServers()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.refreshServers()
        }
    }

    private func loadCachedServers() {
        guard
            let data = UserDefaults.standard.data(forKey: cacheKey),
            let decoded = try? JSONDecoder().decode([LocalServer].self, from: data)
        else {
            return
        }

        servers = decoded
    }

    private func saveCachedServers() {
        guard let data = try? JSONEncoder().encode(servers) else {
            return
        }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }
}

struct ServerCardView: View {
    let server: LocalServer
    let openServer: (LocalServer) -> Void
    let killServer: (LocalServer) -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Button(action: { openServer(server) }) {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(server.displayTitle)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Text(server.serverType)
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .foregroundStyle(typeBadgeColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(typeBadgeColor.opacity(0.18))
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                            Text(server.urlString)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: { killServer(server) }) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0)
            .allowsHitTesting(isHovering)
            .animation(.easeInOut(duration: 0.12), value: isHovering)
            .help("Kill server")
        }
        .padding(.vertical, 8)
        .padding(.leading, 9)
        .padding(.trailing, 10)
        .background(Color.white.opacity(isHovering ? 0.10 : 0.0))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }

    private var typeBadgeColor: Color {
        switch server.serverType {
        case "node":
            return Color(red: 0.54, green: 0.82, blue: 0.47)
        case "python":
            return Color(red: 0.50, green: 0.73, blue: 0.95)
        case "ruby":
            return Color(red: 0.95, green: 0.53, blue: 0.56)
        case "php":
            return Color(red: 0.72, green: 0.66, blue: 0.96)
        case "java":
            return Color(red: 0.94, green: 0.72, blue: 0.44)
        case "bun":
            return Color(red: 0.97, green: 0.83, blue: 0.50)
        case "deno":
            return Color(red: 0.52, green: 0.84, blue: 0.80)
        case "go":
            return Color(red: 0.49, green: 0.80, blue: 0.96)
        case "rust":
            return Color(red: 0.88, green: 0.66, blue: 0.49)
        case "dotnet":
            return Color(red: 0.68, green: 0.60, blue: 0.96)
        case "system":
            return Color.secondary
        default:
            return Color.secondary
        }
    }
}

struct GarconPopoverView: View {
    @ObservedObject var store: ServerStore
    let quitAction: () -> Void

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private var updateStatusText: String? {
        if let lastRefreshDate = store.lastRefreshDate {
            return "Updated \(Self.formatter.string(from: lastRefreshDate))"
        }
        if !store.servers.isEmpty {
            return "Cached"
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.leading, 19)
                .padding(.trailing, 14)
                .padding(.top, 10)
                .padding(.bottom, 10)

            Divider()
                .opacity(0.55)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        if store.primaryServers.isEmpty {
                            EmptyStateRow(text: "No active local servers")
                        } else {
                            ForEach(Array(store.primaryServers.enumerated()), id: \.element.id) { index, server in
                                VStack(spacing: 0) {
                                    ServerCardView(
                                        server: server,
                                        openServer: open,
                                        killServer: store.kill
                                    )
                                    if index < store.primaryServers.count - 1 {
                                        Divider()
                                            .opacity(0.55)
                                            .padding(.horizontal, 10)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 11)

                    if !store.systemServers.isEmpty {
                        Divider()
                            .opacity(0.55)
                            .padding(.vertical, 8)

                        VStack(alignment: .leading, spacing: 0) {
                            Text("System (\(store.systemServers.count))")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.bottom, 4)

                            ForEach(Array(store.systemServers.enumerated()), id: \.element.id) { index, server in
                                VStack(spacing: 0) {
                                    ServerCardView(
                                        server: server,
                                        openServer: open,
                                        killServer: store.kill
                                    )
                                    if index < store.systemServers.count - 1 {
                                        Divider()
                                            .opacity(0.55)
                                            .padding(.horizontal, 10)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 11)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 410, height: 500, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 16, x: 0, y: 8)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Garçon!")
                .font(.system(size: 13, weight: .regular))

            Spacer(minLength: 12)

            if let updateStatusText {
                Text(updateStatusText)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Button(action: store.refreshServers) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .disabled(store.isRefreshing)
            .font(.system(size: 12, weight: .regular))
            .help("Refresh")
            .padding(.trailing, 6)

            Menu {
                Button("Quit Garçon!", role: .destructive, action: quitAction)
            } label: {
                Image(systemName: "gearshape")
                .font(.system(size: 13, weight: .regular))
                .padding(.leading, 4)
                .padding(.trailing, 0)
            }
            .menuIndicator(.hidden)
            .menuStyle(.borderlessButton)
            .help("Settings")
        }
    }

    private func open(_ server: LocalServer) {
        guard let url = URL(string: server.urlString) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

struct EmptyStateRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: NSColor(calibratedWhite: 1.0, alpha: 0.08)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panel: GarconPanel?
    private let store = ServerStore()
    private var outsideClickMonitor: Any?
    private var localClickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        let rootView = GarconPopoverView(
            store: store,
            quitAction: { NSApplication.shared.terminate(nil) }
        )

        let hostingController = NSHostingController(rootView: rootView)
        let panel = GarconPanel(
            contentRect: NSRect(x: 0, y: 0, width: 410, height: 500),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.transient, .moveToActiveSpace]
        panel.isMovableByWindowBackground = false
        panel.contentViewController = hostingController
        self.panel = panel

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "network",
                accessibilityDescription: "Garçon!"
            )
            button.image?.isTemplate = true
            button.toolTip = "Garçon!"
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button, let panel else {
            return
        }

        if panel.isVisible {
            closePanel()
            return
        }

        guard let buttonWindow = button.window else {
            return
        }

        let buttonFrameInScreen = buttonWindow.convertToScreen(button.frame)
        let x = buttonFrameInScreen.maxX - panel.frame.width
        let y = buttonFrameInScreen.minY - panel.frame.height + 2
        panel.setContentSize(NSSize(width: 410, height: 500))
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.makeKeyAndOrderFront(nil)

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.closePanel()
        }

        localClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self, let panel = self.panel else {
                return event
            }
            if let eventWindow = event.window, eventWindow == panel {
                return event
            }
            self.closePanel()
            return event
        }
    }

    private func closePanel() {
        panel?.orderOut(nil)
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
            self.localClickMonitor = nil
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
