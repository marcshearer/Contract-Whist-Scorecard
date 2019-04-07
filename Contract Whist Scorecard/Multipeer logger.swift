//
//  Multipeer logger.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 07/04/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import Foundation

class MultipeerLogger : CommsBrowserDelegate, CommsStateDelegate {
    
    static let logger = MultipeerLogger()
    private var service: CommsClientHandlerDelegate?
    private var peerList: [String : CommsPeer] = [:]
    
    init() {
        
        self.service = MultipeerClientService(purpose: .other, serviceID: Config.multiPeerLogService, deviceName: Scorecard.deviceName)
        self.service?.browserDelegate = self
        self.service?.stateDelegate = self
        self.service?.start()
    }
    
    func peerFound(peer: CommsPeer) {
        self.peerList[peer.deviceName] = peer
        _ = self.service?.connect(to: peer, playerEmail: nil, playerName: nil, reconnect: true)
    }
    
    func peerLost(peer: CommsPeer) {
        self.peerList[peer.deviceName] = nil
    }
    
    func error(_ message: String) {
    }
    
    func write(timestamp: String, message: String) {
        if peerList.count > 0 {
            let data = ["timestamp" : timestamp,
                        "message"   : message   ]
            for (_, peer) in peerList {
                if peer.state == .connected {
                    self.service?.send("log", data, to: peer)
                }
            }
        }
    }
    
    func stateChange(for peer: CommsPeer, reason: String?) {
        self.peerList[peer.deviceName] = peer
    }
}
