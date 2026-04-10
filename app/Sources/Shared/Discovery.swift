import Foundation
import Network

/// Bonjour browser for `_pikeyboard._tcp` services on the local network.
@MainActor
final class Discovery: ObservableObject {
    @Published var devices: [PiDevice] = []
    @Published var isScanning = false

    private var browser: NWBrowser?

    struct PiDevice: Identifiable, Hashable {
        let id: String       // service name
        let name: String
        let endpoint: NWEndpoint
    }

    func start() {
        guard browser == nil else { return }
        isScanning = true

        let params = NWParameters()
        params.includePeerToPeer = true

        let b = NWBrowser(
            for: .bonjour(type: "_pikeyboard._tcp", domain: nil),
            using: params
        )

        b.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                guard let self else { return }
                self.devices = results.map { result in
                    let name: String
                    if case let .service(svcName, _, _, _) = result.endpoint {
                        name = svcName
                    } else {
                        name = "Pi"
                    }
                    return PiDevice(id: name, name: name, endpoint: result.endpoint)
                }
            }
        }

        b.stateUpdateHandler = { _ in }
        b.start(queue: .main)
        self.browser = b
    }

    func stop() {
        browser?.cancel()
        browser = nil
        isScanning = false
    }
}
