// Whether the iPhone is online, so Lockedmind can show it. Lockedmind itself
// never connects to anything: it only watches the iPhone's network state
// (Network framework path monitoring, which sends nothing) to tell the
// person that, online or not, their words stay here.

import SwiftUI
import Network
import Observation

@MainActor @Observable
final class Connection {
    private(set) var isOnline = true
    /// "Wi-Fi", "mobile data", "Ethernet" or "".
    private(set) var via = ""

    @ObservationIgnored private let monitor = NWPathMonitor()
    #if PREVIEW
    /// Screenshots and tests can pretend.
    var forced: Bool? { didSet { if let forced { isOnline = forced; via = forced ? "Wi-Fi" : "" } } }
    #endif

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            let via = path.usesInterfaceType(.wifi) ? "Wi-Fi"
                : path.usesInterfaceType(.cellular) ? "mobile data"
                : path.usesInterfaceType(.wiredEthernet) ? "Ethernet" : ""
            Task { @MainActor in
                guard let self else { return }
                #if PREVIEW
                if self.forced != nil { return }
                #endif
                self.isOnline = online
                self.via = online ? via : ""
            }
        }
        monitor.start(queue: DispatchQueue(label: "lockedmind.connection", qos: .utility))
    }

    var label: String { isOnline ? "Online" : "Offline" }
}

/// The little status line under the chat's title: a dot, online or offline,
/// and a reminder that it doesn't matter. Tap it to read why.
struct ConnectionStatus: View {
    @Environment(Connection.self) private var connection
    @State private var explain = false

    var body: some View {
        Button { explain = true } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(connection.isOnline ? Theme.online : Theme.violet)
                    .frame(width: 6, height: 6)
                    .overlay(Circle().stroke((connection.isOnline ? Theme.online : Theme.violet).opacity(0.35), lineWidth: 3))
                Text(connection.isOnline ? "Online · nothing sent" : "Offline · still works")
                    .font(Theme.ui(.caption2, .medium))
                    .foregroundStyle(.secondary)
            }
            .contentTransition(.opacity)
            .animation(.smooth, value: connection.isOnline)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(connection.isOnline ? "Online. Nothing is sent." : "Offline. Lockedmind still works.")
        .popover(isPresented: $explain) {
            ConnectionExplainer()
                .presentationCompactAdaptation(.popover)
        }
    }
}

struct ConnectionExplainer: View {
    @Environment(Connection.self) private var connection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: connection.isOnline ? "wifi" : "wifi.slash")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(connection.isOnline ? Theme.online : Theme.violet)
                Text(connection.isOnline ? "Your iPhone is online\(connection.via.isEmpty ? "" : " (\(connection.via))")" : "Your iPhone is offline")
                    .font(Theme.ui(.headline, .semibold))
            }
            Text(connection.isOnline
                 ? "Lockedmind doesn't use it. Every answer is worked out on this iPhone, and nothing you write is sent anywhere."
                 : "Lockedmind works exactly the same. Every answer is worked out on this iPhone, so it never needs the internet.")
                .font(Theme.ui(.subheadline))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(width: 300)
    }
}
