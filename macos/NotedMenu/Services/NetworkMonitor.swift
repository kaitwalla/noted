import Foundation
import Network
import Combine

/// Monitors network connectivity and publishes status changes
@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    /// Current connectivity status
    @Published private(set) var isConnected: Bool = true

    /// The type of network connection (wifi, cellular, etc.)
    @Published private(set) var connectionType: ConnectionType = .unknown

    /// Publishes when connection is restored after being offline
    let connectionRestored = PassthroughSubject<Void, Never>()

    private var monitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.noted.networkmonitor")
    private var wasConnected = true
    private var isMonitoring = false

    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }

    private init() {}

    /// Start monitoring network changes
    func start() {
        guard !isMonitoring else { return }

        // Create a new monitor (NWPathMonitor can't be restarted after cancel)
        let newMonitor = NWPathMonitor()
        newMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handlePathUpdate(path)
            }
        }
        newMonitor.start(queue: monitorQueue)
        monitor = newMonitor
        isMonitoring = true
    }

    /// Stop monitoring network changes
    func stop() {
        guard isMonitoring else { return }
        monitor?.cancel()
        monitor = nil
        isMonitoring = false
    }

    private func handlePathUpdate(_ path: NWPath) {
        let newConnected = path.status == .satisfied
        let previouslyConnected = wasConnected

        isConnected = newConnected
        connectionType = getConnectionType(from: path)
        wasConnected = newConnected

        // Notify if connection was restored
        if newConnected && !previouslyConnected {
            connectionRestored.send()
        }
    }

    private func getConnectionType(from path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else {
            return .unknown
        }
    }
}
