//
//  Reachability.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 09/01/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import Foundation
import SystemConfiguration

public class Reachability {
    
    init(uri: String) {

        if let reachability = SCNetworkReachabilityCreateWithName(nil, uri) {
            
            var context = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
            context.info = UnsafeMutableRawPointer(Unmanaged<Reachability>.passUnretained(self).toOpaque())

            SCNetworkReachabilitySetCallback(reachability, { (_, flags, info) in
                if let info = info {
                    let instance = Unmanaged<Reachability>.fromOpaque(UnsafeMutableRawPointer(OpaquePointer(info))!).takeUnretainedValue()
                    instance.reachabilityChanged(flags)
                }
            }, &context)
            
            SCNetworkReachabilitySetDispatchQueue(reachability, DispatchQueue.main)
        }
    }
    
    private func reachabilityChanged(_ flags: SCNetworkReachabilityFlags) {
        // Notify observers
        NotificationCenter.default.post(name: .connectivityChanged, object: self, userInfo: ["available" : Reachability.isConnectedToNetwork()])
    }
    
    public static func startMonitor(action: @escaping (Bool)->()) -> NSObjectProtocol? {
        let observer = NotificationCenter.default.addObserver(forName: .connectivityChanged, object: nil, queue: nil) { (notification) in
            let info = notification.userInfo
            let available = info?["available"] as! Bool?
            action(available ?? false)
        }
        return observer
    }
    
    class func isConnectedToNetwork() -> Bool {
        
        var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, $0)
            }
        }
        
        var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags(rawValue: 0)
        if SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) == false {
            return false
        }
        
        let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        
        return isReachable && !needsConnection
        
    }
}

extension Notification.Name {
    static let connectivityChanged = Notification.Name("connectivityChanged")
}
