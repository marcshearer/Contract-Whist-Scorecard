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
    private var _isNetworkAvailable: Bool?
    public var isNetworkAvailable: Bool { self._isNetworkAvailable ?? false }
    private var _isLoggedIn: Bool?
    public var isLoggedIn: Bool { self._isLoggedIn ?? false }
    public var isConnected: Bool { self.isNetworkAvailable && self.isLoggedIn }
    
    init() {
        self.monitor.pathUpdateHandler = self.pathUpdateHandler
        self.monitor.start(queue: DispatchQueue.main)
        NotificationCenter.default.addObserver(self, selector: #selector(accountStatusUpdateHandler(_:)), name: Notification.Name.CKAccountChanged, object: nil)
    }
    
    private func pathUpdateHandler(path: NWPath) {
        var newNetworkIsAvailable: Bool
        if self._isNetworkAvailable != nil && Utility.isSimulator {
            // Doesn't update status in simulator - just invert it
            newNetworkIsAvailable = !self.isNetworkAvailable
        } else {
            newNetworkIsAvailable = (path.status == .satisfied)
        }
        if newNetworkIsAvailable != self._isNetworkAvailable {
            self._isNetworkAvailable = newNetworkIsAvailable
            if newNetworkIsAvailable {
                self.checkAccountStatus()
            } else {
                self._isLoggedIn = false
            }
            NotificationCenter.default.post(name: .connectivityChanged, object: self, userInfo: ["isConnected" : self.isConnected])
        }
    }
    
    @objc private func accountStatusUpdateHandler(_ sender: Any) {
        self.checkAccountStatus()
    }
    
    private func checkAccountStatus() {
        Sync.cloudKitContainer.accountStatus(completionHandler: { (accountStatus, errorMessage) -> Void in
            let newValue = (accountStatus == .available)
            if newValue != self._isLoggedIn {
                // Changed - update it and reawaken listeners
                self._isLoggedIn = newValue
                NotificationCenter.default.post(name: .connectivityChanged, object: self, userInfo: ["isConnected" : self.isConnected])
            }
        })
    }
        
    public func startMonitor(action: @escaping (Bool)->()) -> NSObjectProtocol? {
        let observer = NotificationCenter.default.addObserver(forName: .connectivityChanged, object: nil, queue: nil) { (notification) in
            let info = notification.userInfo
            let available = info?["isConnected"] as! Bool?
            Utility.mainThread {
                action(available ?? false)
            }
        }
        return observer
    }
    
    public func waitForStatus(completion: @escaping (Bool)->()) {
        self.wait(count: 0, completion: completion)
    }
    
    private func wait(count: Int, completion: @escaping (Bool)->()) {
        if count >= 50 || (self._isNetworkAvailable != nil && self._isLoggedIn != nil) {
            completion(self.isConnected)
        } else {
            Utility.executeAfter(delay: 0.01) {
                self.wait(count: count + 1, completion: completion)
            }
        }
    }
}

extension Notification.Name {
    static let connectivityChanged = Notification.Name("connectivityChanged")
}
