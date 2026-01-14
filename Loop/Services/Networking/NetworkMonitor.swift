//
//  NetworkMonitor.swift
//  Loop
//
//  Created by Architecture Blueprint v6.3
//

import Network
import Observation

@Observable @MainActor
final class NetworkMonitor {
    var isReachable: Bool = true
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isReachable = (path.status == .satisfied)
            }
        }
        monitor.start(queue: queue)
    }
}
