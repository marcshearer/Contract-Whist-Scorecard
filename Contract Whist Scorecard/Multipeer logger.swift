//
//  Multipeer logger.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 07/04/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation

class MultipeerLogger : CommsBrowserDelegate, CommsStateDelegate, CommsConnectionDelegate, CommsDataDelegate {
    func didReceiveData(descriptor: String, data: [String : Any?]?, from peer: CommsPeer) {
        
    }
    
    func connectionReceived(from peer: CommsPeer, info: [String : Any?]?) -> Bool {
        return true
    }
    
    
    static let logger = MultipeerLogger()
    private var service: CommsClientHandlerDelegate?
    private var loggerList: [String : MultipeerLoggerEntry] = [:]
    
    init() {
        
        self.service = MultipeerClientService(purpose: .other, serviceID: Config.multiPeerLogService, deviceName: Scorecard.deviceName)
        self.service?.browserDelegate = self
        self.service?.stateDelegate = self
        self.service?.start()
    }
    
    func peerFound(peer: CommsPeer) {
        
        var logger = self.loggerList[peer.deviceName]
        var new = false
        var connect = false
        
        if logger == nil {
            // New peer - add to list
            logger = MultipeerLoggerEntry(peer: peer)
            self.loggerList[peer.deviceName] = logger
            new = true
            connect = true
            
        } else if logger?.peer.state == .notConnected {
            connect = true
            
        }
        
        logger!.peer = peer
        
        if connect {
            Utility.getActiveViewController()?.alertDecision(if: new, "A nearby device (\(peer.deviceName)) is logging Contract Whist. Would you like to connect?\n\nNote: this could expose otherwise hidden information to the logging device.", title: "Logging", okHandler: {
                logger!.accepted = true
                _ = self.service?.connect(to: peer, playerEmail: nil, playerName: nil, reconnect: true)
            })
        }
    }
    
    func peerLost(peer: CommsPeer) {
        self.loggerList[peer.deviceName]?.peer = peer
    }
    
    func error(_ message: String) {
    }
    
    func write(timestamp: String, message: String) {
        if loggerList.count > 0 {
            let data = ["timestamp" : timestamp,
                        "message"   : message   ]
            for (_, logger) in loggerList {
                if logger.peer.state == .connected && logger.accepted {
                    self.service?.send("log", data, to: logger.peer)
                }
            }
        }
    }
    
    func stateChange(for peer: CommsPeer, reason: String?) {
        self.loggerList[peer.deviceName]?.peer = peer
    }
}

fileprivate class MultipeerLoggerEntry {
    public var peer: CommsPeer
    public var accepted = false
    
    init(peer: CommsPeer) {
        self.peer = peer
    }
}
