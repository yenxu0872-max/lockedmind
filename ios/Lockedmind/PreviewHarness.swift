// Only in builds made with the PREVIEW flag (tools/preview.sh on the Mac,
// tools/screenshots.sh in the Simulator); compiles to nothing in the real app.
// Keeps data in a scratch folder (LM_DATA) and follows a small script
// (LM_SCRIPT) so screens can be checked and captured automatically.
//
// Script lines: wait 2 · send Hello · idle · shot name · new · open · log ·
// light · dark · welcome show|done · screen chats|settings|none · quit
//
// `shot` draws the window into LM_OUT/name.png; with LM_SHOTS=external it
// instead leaves LM_OUT/name.ready and waits for the script outside to take
// a real screenshot and delete it.

#if PREVIEW
import SwiftUI
import UIKit

struct PreviewHarness: ViewModifier {
    let model: AppModel
    static let showChats = Notification.Name("preview.showChats")
    /// Screens shown over everything: on the Mac, sheets open as separate
    /// windows that a snapshot can't see, so they are shown here instead.
    @State private var screen = ""

    static var dataFolder: URL? {
        ProcessInfo.processInfo.environment["LM_DATA"].map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                Group {
                    switch screen {
                    case "chats": ChatsView()
                    case "settings": NavigationStack { SettingsView() }
                    case "not-eligible": UnavailableView(availability: .unavailable(.deviceNotEligible))
                    case "ai-off": UnavailableView(availability: .unavailable(.appleIntelligenceNotEnabled))
                    case "downloading": UnavailableView(availability: .unavailable(.modelNotReady))
                    case "locked": LockScreen(unlock: {})
                    default: EmptyView()
                    }
                }
                .background(screen.isEmpty ? Color.clear : Theme.paper)
                .environment(model)
                .environment(Guard())
            }
            .task { await run() }
    }

    @MainActor private func run() async {
        let env = ProcessInfo.processInfo.environment
        #if targetEnvironment(macCatalyst)
        let size = CGSize(width: Double(env["LM_W"] ?? "") ?? 402, height: Double(env["LM_H"] ?? "") ?? 874)
        for scene in UIApplication.shared.connectedScenes {
            guard let scene = scene as? UIWindowScene else { continue }
            scene.sizeRestrictions?.minimumSize = size
            scene.sizeRestrictions?.maximumSize = size
        }
        #endif
        guard let path = env["LM_SCRIPT"], let script = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        let out = URL(fileURLWithPath: env["LM_OUT"] ?? NSTemporaryDirectory(), isDirectory: true)
        try? await Task.sleep(for: .seconds(1.5))

        for line in script.split(separator: "\n").map(String.init) {
            let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
            guard let command = parts.first else { continue }
            let rest = parts.count > 1 ? parts[1] : ""
            log("» \(line)")
            switch command {
            case "wait": try? await Task.sleep(for: .seconds(Double(rest) ?? 1))
            case "send": model.send(rest)
            case "idle":
                while model.isResponding { try? await Task.sleep(for: .milliseconds(200)) }
                try? await Task.sleep(for: .seconds(1.2))
            case "shot":
                if env["LM_SHOTS"] == "external" {
                    let flag = out.appending(path: "\(rest).ready")
                    FileManager.default.createFile(atPath: flag.path, contents: nil)
                    while FileManager.default.fileExists(atPath: flag.path) { try? await Task.sleep(for: .milliseconds(150)) }
                } else {
                    shot(to: out.appending(path: "\(rest).png"))
                }
            case "dark", "light": style(command == "dark" ? .dark : .light)
            case "chats": NotificationCenter.default.post(name: Self.showChats, object: nil)
            case "welcome": UserDefaults.standard.set(rest == "done", forKey: "welcomed")
            case "new": model.newChat()
            case "set":
                let kv = rest.split(separator: " ").map(String.init)
                if kv.count == 2 { UserDefaults.standard.set(kv[1] == "true", forKey: kv[0]) }
            case "open": if let first = model.library.chats.first { model.open(first.id) }
            case "screen": screen = rest == "none" ? "" : rest
            case "sendlong":
                let filler = "The quick brown fox jumps over the lazy dog while the sun sets slowly behind the hills. "
                model.send("Summarise this in one sentence: " + String(repeating: filler, count: (Int(rest) ?? 1000) / filler.count + 1))
            case "log": log(model.current.messages.map { "[\($0.role.rawValue)] \($0.problem ?? $0.text)" }.joined(separator: "\n"))
            case "tree":
                for w in windows() {
                    var vc = w.rootViewController
                    var chain: [String] = []
                    while let c = vc { chain.append(String(describing: type(of: c))); vc = c.presentedViewController }
                    log("window \(w.bounds.size) key=\(w.isKeyWindow): \(chain.joined(separator: " → "))")
                }
            case "quit":
                UserDefaults.standard.synchronize()
                FileManager.default.createFile(atPath: out.appending(path: "finished").path, contents: nil)
                exit(0)
            default: log("unknown: \(line)")
            }
        }
    }

    private func windows() -> [UIWindow] {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
    }

    private func style(_ style: UIUserInterfaceStyle) {
        windows().forEach { $0.overrideUserInterfaceStyle = style }
    }

    private func shot(to url: URL) {
        guard let window = windows().first(where: \.isKeyWindow) ?? windows().first else { return }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            for w in windows() where !w.isHidden { w.drawHierarchy(in: w.bounds, afterScreenUpdates: true) }
        }
        try? image.pngData()?.write(to: url)
        log("saved \(url.path)")
    }

    private func log(_ text: String) {
        FileHandle.standardError.write(Data((text + "\n").utf8))
    }
}
#endif
