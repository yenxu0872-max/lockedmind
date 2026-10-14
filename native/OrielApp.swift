// Lockedmind — the Mac app (called oriel.ai until October 2026; internal names keep "oriel").
//
// A native window around the Lockedmind interface, which the oriel server on
// this Mac serves at http://127.0.0.1:7171. The app:
//   - starts that server if it isn't running (the login item normally has it
//     up already) and shows a native "Starting…" screen meanwhile
//   - gives the page what a browser tab can't: a menu bar (⌘N, ⌘,), the
//     microphone for dictation, the system file picker, and links that open
//     in your browser instead of inside the app
//   - frees the model's memory when you quit
//   - can lock itself (Lockedmind menu › Lock with Touch ID): the chats hide
//     when the Mac sleeps or locks, when the app is hidden or minimised, or
//     after five minutes away, and come back with Touch ID or the password.
//
// Built by `oriel app` / `oriel install` with swiftc — no Xcode needed.

import AppKit
import WebKit
import LocalAuthentication

let port = 7171
let home = URL(string: "http://127.0.0.1:\(port)/")!
let serviceLabel = "ai.oriel.server"
let bundleInfo = Bundle.main.infoDictionary ?? [:]
let orielHome = bundleInfo["OrielHome"] as? String ?? NSHomeDirectory() + "/oriel.ai"
let orielPython = bundleInfo["OrielPython"] as? String ?? "/opt/homebrew/bin/python3"
let stripHeight: CGFloat = 28   // matches --titlebar in the page

/// The strip along the top of the window where the traffic lights sit: drags
/// the window, and a double-click zooms or minimises as System Settings says.
final class TitlebarStrip: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
    override func mouseDown(with event: NSEvent) {
        guard event.clickCount == 2 else { window?.performDrag(with: event); return }
        switch UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") ?? "Maximize" {
        case "Minimize": window?.performMiniaturize(nil)
        case "None": break
        default: window?.performZoom(nil)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate {
    var window: NSWindow!
    var web: WKWebView!
    var strip: TitlebarStrip!
    var cover: NSView!               // shown until the page is up
    var status: NSTextField!
    var detail: NSTextField!
    var spinner: NSProgressIndicator!
    var retry: NSButton!
    var spawned: Process?            // a server we started ourselves (no login item)
    var connecting = false
    var lockView: NSVisualEffectView!
    var lockItem: NSMenuItem!
    var locked = false
    var asking = false
    var awaySince: Date?
    static let lockKey = "lockWithTouchID"
    var lockOn: Bool { UserDefaults.standard.bool(forKey: Self.lockKey) }

    // MARK: launch

    func applicationDidFinishLaunching(_ note: Notification) {
        buildMenu()
        buildWindow()
        watchForLocking()
        if lockOn { setLocked(true) }
        connect()
    }

    func applicationDidResignActive(_ note: Notification) { awaySince = Date() }

    func applicationDidBecomeActive(_ note: Notification) {
        // Five minutes away is long enough to lock.
        if lockOn, let away = awaySince, Date().timeIntervalSince(away) > 300 { setLocked(true) }
        awaySince = nil
        if locked { unlock() }
    }

    func applicationDidHide(_ note: Notification) { lockIfOn() }
    func windowDidMiniaturize(_ note: Notification) { lockIfOn() }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ note: Notification) {
        releaseModels()
        if let p = spawned, p.isRunning { p.terminate(); p.waitUntilExit() }
    }

    // MARK: window

    func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 780),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        window.title = "Lockedmind"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.minSize = NSSize(width: 720, height: 480)
        window.backgroundColor = NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.09, green: 0.09, blue: 0.10, alpha: 1) : .white }
        window.delegate = self
        window.center()
        window.setFrameAutosaveName("oriel.ai main window")

        let config = WKWebViewConfiguration()
        config.userContentController.addUserScript(WKUserScript(
            source: "document.documentElement.dataset.app='mac';",
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = self
        web.uiDelegate = self
        web.setValue(false, forKey: "drawsBackground")   // no white flash in dark mode
        web.allowsBackForwardNavigationGestures = false
        web.pageZoom = CGFloat(UserDefaults.standard.double(forKey: "zoom").clamped(0.5, 2.5, or: 1))
        web.isHidden = true

        let root = NSView()
        window.contentView = root
        web.frame = root.bounds
        web.autoresizingMask = [.width, .height]
        root.addSubview(web)

        strip = TitlebarStrip(frame: NSRect(x: 0, y: root.bounds.height - stripHeight, width: root.bounds.width, height: stripHeight))
        strip.autoresizingMask = [.width, .minYMargin]
        root.addSubview(strip)

        buildCover(in: root)
        buildLock(in: root)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// The native screen shown while the server starts (or if it can't).
    func buildCover(in root: NSView) {
        cover = NSView(frame: root.bounds)
        cover.autoresizingMask = [.width, .height]
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        status = NSTextField(labelWithString: "Starting Lockedmind…")
        status.font = .systemFont(ofSize: 17, weight: .semibold)
        detail = NSTextField(wrappingLabelWithString: "")
        detail.font = .systemFont(ofSize: 13)
        detail.textColor = .secondaryLabelColor
        detail.alignment = .center
        spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.startAnimation(nil)
        retry = NSButton(title: "Try Again", target: self, action: #selector(tryAgain))
        retry.bezelStyle = .rounded
        retry.isHidden = true
        let stack = NSStackView(views: [icon, status, detail, spinner, retry])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.setCustomSpacing(18, after: icon)
        stack.translatesAutoresizingMaskIntoConstraints = false
        cover.addSubview(stack)
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 88), icon.heightAnchor.constraint(equalToConstant: 88),
            detail.widthAnchor.constraint(lessThanOrEqualToConstant: 380),
            stack.centerXAnchor.constraint(equalTo: cover.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: cover.centerYAnchor, constant: -20),
        ])
        root.addSubview(cover, positioned: .below, relativeTo: strip)
    }

    func showCover(_ title: String, _ text: String = "", failed: Bool = false) {
        cover.isHidden = false
        web.isHidden = true
        status.stringValue = title
        detail.stringValue = text
        spinner.isHidden = failed
        retry.isHidden = !failed
    }

    // MARK: server

    /// Get the page on screen: if the server isn't answering, start it —
    /// through the login item if there is one, otherwise ourselves.
    func connect() {
        guard !connecting else { return }
        connecting = true
        showCover("Starting Lockedmind…")
        Task {
            var up = await serverUp()
            if !up {
                startServer()
                let deadline = Date().addingTimeInterval(60)
                while !up && Date() < deadline {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    if let p = spawned, !p.isRunning { break }
                    up = await serverUp()
                }
            }
            connecting = false
            if up {
                web.load(URLRequest(url: home))
            } else {
                showCover("Lockedmind couldn't start",
                          "Its server didn't come up. In Terminal, `oriel logs` shows why, and `oriel restart` tries again.",
                          failed: true)
            }
        }
    }

    @objc func tryAgain() { connect() }

    func serverUp() async -> Bool {
        var req = URLRequest(url: home.appendingPathComponent("oriel/info"))
        req.timeoutInterval = 1.5
        guard let (_, resp) = try? await URLSession.shared.data(for: req) else { return false }
        return (resp as? HTTPURLResponse)?.statusCode == 200
    }

    func startServer() {
        let kick = Process()
        kick.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        kick.arguments = ["kickstart", "gui/\(getuid())/\(serviceLabel)"]
        kick.standardOutput = FileHandle.nullDevice
        kick.standardError = FileHandle.nullDevice
        if (try? kick.run()) != nil { kick.waitUntilExit(); if kick.terminationStatus == 0 { return } }
        // No login item: run the server for as long as the app is open.
        guard spawned?.isRunning != true else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: orielPython)
        p.arguments = [orielHome + "/oriel", "--service"]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        if (try? p.run()) != nil { spawned = p }
    }

    /// On quit, unload the models the page kept warm, so their memory is
    /// free right away instead of 20 minutes later.
    func releaseModels() {
        let done = DispatchSemaphore(value: 0)
        var req = URLRequest(url: home.appendingPathComponent("api/ps"))
        req.timeoutInterval = 1.5
        URLSession.shared.dataTask(with: req) { data, _, _ in
            let names = ((try? JSONSerialization.jsonObject(with: data ?? Data())) as? [String: Any])?["models"]
                .flatMap { $0 as? [[String: Any]] }?.compactMap { $0["name"] as? String } ?? []
            let group = DispatchGroup()
            for name in names {
                var post = URLRequest(url: home.appendingPathComponent("api/generate"))
                post.httpMethod = "POST"
                post.timeoutInterval = 2
                post.setValue("application/json", forHTTPHeaderField: "Content-Type")
                post.httpBody = try? JSONSerialization.data(withJSONObject: ["model": name, "keep_alive": 0])
                group.enter()
                URLSession.shared.dataTask(with: post) { _, _, _ in group.leave() }.resume()
            }
            group.wait()
            done.signal()
        }.resume()
        _ = done.wait(timeout: .now() + 3)
    }

    // MARK: page

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        applyStrip()
        cover.isHidden = true
        web.isHidden = false
        window.makeFirstResponder(web)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        connect()   // the server went away: bring it back
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { webView.reload() }

    /// oriel's own pages stay in the app; every other link opens in the browser.
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { return decisionHandler(.cancel) }
        if (url.host == "127.0.0.1" && url.port == port) || ["about", "blob", "data"].contains(url.scheme ?? "") {
            return decisionHandler(.allow)
        }
        if ["http", "https", "mailto"].contains(url.scheme ?? "") { NSWorkspace.shared.open(url) }
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url, ["http", "https", "mailto"].contains(url.scheme ?? "") { NSWorkspace.shared.open(url) }
        return nil
    }

    /// Dictation: the page asks for the microphone; macOS then asks you once.
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping @MainActor (WKPermissionDecision) -> Void) {
        decisionHandler(origin.host == "127.0.0.1" && type == .microphone ? .grant : .deny)
    }

    /// The + button's file picker.
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.beginSheetModal(for: window) { completionHandler($0 == .OK ? panel.urls : nil) }
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor () -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.beginSheetModal(for: window) { _ in completionHandler() }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { completionHandler($0 == .alertFirstButtonReturn) }
    }

    // MARK: the lock

    /// What this Mac unlocks with, for the menu and the button.
    var unlockName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType == .touchID ? "Touch ID" : "Password"
    }

    /// The screen over everything while locked: the logo, a word, one button.
    func buildLock(in root: NSView) {
        lockView = NSVisualEffectView(frame: root.bounds)
        lockView.autoresizingMask = [.width, .height]
        lockView.material = .underWindowBackground
        lockView.blendingMode = .withinWindow
        lockView.state = .active
        lockView.isHidden = true
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        let title = NSTextField(labelWithString: "Locked")
        title.font = .systemFont(ofSize: 26, weight: .bold)
        let text = NSTextField(labelWithString: "Your chats stay hidden until you unlock.")
        text.font = .systemFont(ofSize: 14)
        text.textColor = .secondaryLabelColor
        let button = NSButton(title: "Unlock with \(unlockName)", target: self, action: #selector(unlockPressed))
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.keyEquivalent = "\r"
        let stack = NSStackView(views: [icon, title, text, button])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.setCustomSpacing(22, after: icon)
        stack.setCustomSpacing(26, after: text)
        stack.translatesAutoresizingMaskIntoConstraints = false
        lockView.addSubview(stack)
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 112), icon.heightAnchor.constraint(equalToConstant: 112),
            stack.centerXAnchor.constraint(equalTo: lockView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: lockView.centerYAnchor, constant: -10),
        ])
        root.addSubview(lockView, positioned: .below, relativeTo: strip)
    }

    func watchForLocking() {
        let ws = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.lockIfOn() }
            }
        }
        DistributedNotificationCenter.default().addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.lockIfOn() }
        }
    }

    func lockIfOn() { if lockOn { setLocked(true) } }

    func setLocked(_ on: Bool) {
        locked = on
        lockView.isHidden = !on
        if on { window.makeFirstResponder(nil) }
    }

    @objc func unlockPressed() { unlock() }

    /// Asks macOS to check it's the owner: Touch ID, or the password.
    func unlock() {
        guard locked, !asking else { return }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            setLocked(false)          // nothing to check against: never shut someone out of their own chats
            return
        }
        asking = true
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "unlock your chats") { ok, _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.asking = false
                    if ok { self.setLocked(false) }
                }
            }
        }
    }

    @objc func toggleLock(_ sender: NSMenuItem) {
        let on = !lockOn
        UserDefaults.standard.set(on, forKey: Self.lockKey)
        sender.state = on ? .on : .off
    }

    @objc func lockNow(_ sender: Any?) {
        if !lockOn {
            UserDefaults.standard.set(true, forKey: Self.lockKey)
            lockItem.state = .on
        }
        setLocked(true)
    }

    // MARK: the strip under the traffic lights

    /// Keep the page's reserved strip exactly as tall as the native one at any
    /// zoom, and drop it in full screen, where there are no traffic lights.
    func applyStrip() {
        let full = window.styleMask.contains(.fullScreen)
        strip.isHidden = full
        let css = full ? 0 : stripHeight / web.pageZoom
        web.evaluateJavaScript("document.documentElement.style.setProperty('--titlebar','\(css)px')")
    }

    func windowDidEnterFullScreen(_ note: Notification) { applyStrip() }
    func windowDidExitFullScreen(_ note: Notification) { applyStrip() }

    // MARK: menu bar

    func page(_ js: String) { web.evaluateJavaScript("window.oriel && window.oriel.\(js)") }
    @objc func newChat(_ sender: Any?) { page("newChat()") }
    @objc func openSettings(_ sender: Any?) { page("openSettings()") }
    @objc func toggleSidebar(_ sender: Any?) { page("toggleSidebar()") }
    @objc func reloadPage(_ sender: Any?) { if web.isHidden { connect() } else { web.reload() } }
    @objc func zoomIn(_ sender: Any?) { setZoom(web.pageZoom * 1.1) }
    @objc func zoomOut(_ sender: Any?) { setZoom(web.pageZoom / 1.1) }
    @objc func actualSize(_ sender: Any?) { setZoom(1) }
    func setZoom(_ z: CGFloat) {
        web.pageZoom = min(max(z, 0.5), 2.5)
        UserDefaults.standard.set(Double(web.pageZoom), forKey: "zoom")
        applyStrip()
    }

    func buildMenu() {
        let bar = NSMenu()
        func menu(_ title: String, _ items: [NSMenuItem]) -> NSMenu {
            let m = NSMenu(title: title)
            items.forEach { m.addItem($0) }
            let holder = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            holder.submenu = m
            bar.addItem(holder)
            return m
        }
        func item(_ title: String, _ action: Selector?, _ key: String = "", _ mods: NSEvent.ModifierFlags = .command) -> NSMenuItem {
            let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
            i.keyEquivalentModifierMask = mods
            return i
        }
        lockItem = item("Lock with \(unlockName)", #selector(toggleLock(_:)))
        lockItem.state = lockOn ? .on : .off
        _ = menu("Lockedmind", [
            item("About Lockedmind", #selector(NSApplication.orderFrontStandardAboutPanel(_:))),
            .separator(),
            item("Settings…", #selector(openSettings(_:)), ","),
            .separator(),
            lockItem,
            item("Lock Now", #selector(lockNow(_:)), "l", [.command, .control]),
            .separator(),
            item("Hide Lockedmind", #selector(NSApplication.hide(_:)), "h"),
            item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]),
            item("Show All", #selector(NSApplication.unhideAllApplications(_:))),
            .separator(),
            item("Quit Lockedmind", #selector(NSApplication.terminate(_:)), "q"),
        ])
        _ = menu("File", [
            item("New Chat", #selector(newChat(_:)), "n"),
            .separator(),
            item("Close Window", #selector(NSWindow.performClose(_:)), "w"),
        ])
        _ = menu("Edit", [
            item("Undo", Selector(("undo:")), "z"),
            item("Redo", Selector(("redo:")), "z", [.command, .shift]),
            .separator(),
            item("Cut", #selector(NSText.cut(_:)), "x"),
            item("Copy", #selector(NSText.copy(_:)), "c"),
            item("Paste", #selector(NSText.paste(_:)), "v"),
            item("Paste and Match Style", #selector(NSTextView.pasteAsPlainText(_:)), "v", [.command, .option, .shift]),
            item("Delete", #selector(NSText.delete(_:))),
            item("Select All", #selector(NSText.selectAll(_:)), "a"),
        ])
        _ = menu("View", [
            item("Toggle Sidebar", #selector(toggleSidebar(_:)), "s", [.command, .control]),
            .separator(),
            item("Reload", #selector(reloadPage(_:)), "r"),
            .separator(),
            item("Actual Size", #selector(actualSize(_:)), "0"),
            item("Zoom In", #selector(zoomIn(_:)), "="),
            item("Zoom Out", #selector(zoomOut(_:)), "-"),
            .separator(),
            item("Enter Full Screen", #selector(NSWindow.toggleFullScreen(_:)), "f", [.command, .control]),
        ])
        let windowMenu = menu("Window", [
            item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"),
            item("Zoom", #selector(NSWindow.performZoom(_:))),
            .separator(),
            item("Bring All to Front", #selector(NSApplication.arrangeInFront(_:))),
        ])
        NSApp.mainMenu = bar
        NSApp.windowsMenu = windowMenu
    }
}

extension Double {
    func clamped(_ lo: Double, _ hi: Double, or fallback: Double) -> Double { self == 0 ? fallback : Swift.min(Swift.max(self, lo), hi) }
}

@main
enum Main {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}
