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
    var connected: Bool!
    
    init() {
        self.monitor.pathUpdateHandler = self.pathUpdateHandler
        self.monitor.start(queue: DispatchQueue.main)
    }
    
    private func pathUpdateHandler(path: NWPath) {
        var newConnected: Bool
        if self.connected != nil && Utility.isSimulator {
            // Doesn't update status in simulator - just invert it
            newConnected = !self.connected
        } else {
            newConnected = (path.status == .satisfied)
        }
        if newConnected != self.connected {
            self.connected = newConnected
            Scorecard.shared.isNetworkAvailable = self.connected
            if self.connected {
                // Now check icloud asynchronously
                CKContainer.init(identifier: Config.iCloudIdentifier).accountStatus(completionHandler: { (accountStatus, errorMessage) -> Void in
                    let newValue = (accountStatus == .available)
                    if newValue != Scorecard.shared.isLoggedIn {
                        // Changed - update it and reawaken listeners
                        Scorecard.shared.isLoggedIn = newValue
                        NotificationCenter.default.post(name: .connectivityChanged, object: self, userInfo: ["available" : self.connected!])
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
}

extension Notification.Name {
    static let connectivityChanged = Notification.Name("connectivityChanged")
}
