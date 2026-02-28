import Network
import Combine

/// Observes network status and basic quality signals.
public enum NetworkStatus {
    case connected, disconnected
}

public enum NetworkQuality: String {
    case excellent
    case good
    case poor
    case offline
}

@MainActor
public final class NetworkMonitor: ObservableObject {
    public static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    @Published public private(set) var status: NetworkStatus = .connected
    @Published public private(set) var isConstrained: Bool = false
    @Published public private(set) var isExpensive: Bool = false
    @Published public private(set) var interfaceType: NWInterface.InterfaceType? = nil
    @Published public private(set) var quality: NetworkQuality = .excellent

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            let isConstrained = path.isConstrained
            let isExpensive = path.isExpensive
            let iface = path.availableInterfaces
                .filter { path.usesInterfaceType($0.type) }
                .map { $0.type }
                .first

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.status = connected ? .connected : .disconnected
                self.isConstrained = isConstrained
                self.isExpensive = isExpensive
                self.interfaceType = iface
                self.quality = Self.deriveQuality(
                    connected: connected,
                    isConstrained: isConstrained,
                    isExpensive: isExpensive,
                    interfaceType: iface
                )
            }
        }
        monitor.start(queue: queue)
    }

    /// Classifies expected network quality from coarse path characteristics.
    nonisolated public static func deriveQuality(
        connected: Bool,
        isConstrained: Bool,
        isExpensive: Bool,
        interfaceType: NWInterface.InterfaceType?
    ) -> NetworkQuality {
        guard connected else { return .offline }
        if isConstrained { return .poor }
        if isExpensive, interfaceType == .cellular { return .good }
        if interfaceType == .wifi || interfaceType == .wiredEthernet { return .excellent }
        return .good
    }
}
