//
//  Reachability.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 09/01/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import Foundation
import Network
import CloudKit

public class Reachability {
    
    let monitor = NWPathMonitor()
    private var _connected: Bool?
    public var connected: Bool? { _connected }
    
    init() {
        self.monitor.pathUpdateHandler = self.pathUpdateHandler
        self.monitor.start(queue: DispatchQueue.main)
    }
    
    private func pathUpdateHandler(path: NWPath) {
        var newConnected: Bool
        if self._connected != nil && Utility.isSimulator {
            // Doesn't update status in simulator - just invert it
            newConnected = !self._connected!
        } else {
            newConnected = (path.status == .satisfied)
        }
        if newConnected != self._connected {
            self._connected = newConnected
            Scorecard.shared.isNetworkAvailable = self._connected!
            if self._connected! {
                // Now check icloud asynchronously
                CKContainer.init(identifier: Config.iCloudIdentifier).accountStatus(completionHandler: { (accountStatus, errorMessage) -> Void in
                    let newValue = (accountStatus == .available)
                    if newValue != Scorecard.shared.isLoggedIn {
                        // Changed - update it and reawaken listeners
                        Scorecard.shared.isLoggedIn = newValue
                        NotificationCenter.default.post(name: .connectivityChanged, object: self, userInfo: ["available" : self._connected!])
                    }
                })
            }
            NotificationCenter.default.post(name: .connectivityChanged, object: self, userInfo: ["available" : Scorecard.shared.isNetworkAvailable])
        }
    }
        
    public func startMonitor(action: @escaping (Bool)->()) -> NSObjectProtocol? {
        let observer = NotificationCenter.default.addObserver(forName: .connectivityChanged, object: nil, queue: nil) { (notification) in
            let info = notification.userInfo
            let available = info?["available"] as! Bool?
            action(available ?? false)
        }
        return observer
    }
    
    public func waitForStatus() {
        self.wait(count: 50)
    }
    
    private func wait(count: Int) {
        if count <= 50 && Scorecard.reachability.connected == nil {
            Utility.executeAfter(delay: 0.01) {
                self.wait(count: count + 1)
            }
        }
    }
}

extension Notification.Name {
    static let connectivityChanged = Notification.Name("connectivityChanged")
}
