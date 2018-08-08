//
//  Loopback Class.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 31/07/2018.
//  Copyright © 2018 Marc Shearer. All rights reserved.
//

import Foundation

protocol LoopbackServiceDelegate {
    
    func addConnection(from deviceName: String, to commsPeer: CommsPeer)

}

class LoopbackService: NSObject, CommsHandlerDelegate, CommsDataDelegate, CommsConnectionDelegate, CommsStateDelegate, LoopbackServiceDelegate {
    
    // Delegate properties
    public let connectionMode: CommsConnectionMode = .loopback
    public let connectionFramework: CommsConnectionFramework = .loopback
    public let connectionProximity: CommsConnectionProximity = .loopback
    public var connectionType: CommsConnectionType
    public var connectionPurpose: CommsConnectionPurpose
    public var handlerState: CommsHandlerState = .notStarted
    public var connections = 0
    public var connectionUUID: String?
    public var connectionEmail: String?
    public var connectionDevice: String?
    
    // Delegates
    public var browserDelegate: CommsBrowserDelegate!
    public var stateDelegate: CommsStateDelegate!
    public var dataDelegate: CommsDataDelegate!
    public var connectionDelegate: CommsConnectionDelegate!
    public var handlerStateDelegate: CommsHandlerStateDelegate!
    public var loopbackServiceDelegate: LoopbackServiceDelegate!
    
    // Internal state
    private static var peerList: [String : LoopbackDelegates] = [ : ]
    private var connectionList: [String : CommsPeer] = [ : ]
    private var myPeer: LoopbackPeer!
    
    // MARK: - Comms Handler delegate implementation ======================================================== -

    required init(purpose: CommsConnectionPurpose, type: CommsConnectionType, serviceID: String?, deviceName: String) {
        self.connectionPurpose = purpose
        self.connectionType = type
        self.connectionDevice = deviceName
        super.init()
    }
    
    public func start(email: String!, queueUUID: String!, name: String!, invite: [String]!, recoveryMode: Bool, matchDeviceName: String!) {
        self.myPeer = LoopbackPeer(parent: self, deviceName: self.connectionDevice!, playerEmail: email, playerName: name)
        
        // Add myself to the shared peer list
        LoopbackService.peerList[self.myPeer.deviceName] = LoopbackDelegates(peer: self.myPeer , connectionDelegate: self.connectionDelegate, stateDelegate: self.stateDelegate, dataDelegate: self.dataDelegate, loopbackServiceDelegate: self)
    }
 
    public func stop() {
        // Remove myself from the shared peer list
        LoopbackService.peerList.removeValue(forKey: self.myPeer.deviceName)
    }

    public func connect(to commsPeer: CommsPeer, playerEmail: String?, playerName: String?, reconnect: Bool) -> Bool {
        if let loopbackDelegates = LoopbackService.peerList[commsPeer.deviceName] {
            
            // Add to local list of connected peers
            self.addConnection(from: commsPeer.deviceName, to: commsPeer)
            
            // Check if connection OK and then send state change
            if (loopbackDelegates.connectionDelegate?.connectionReceived(from: self.myPeer.commsPeer))! {
                
                // Set this peer to connected
                self.myPeer.state = .connected
                
                // Add to remote list of peers
                loopbackDelegates.loopbackServiceDelegate?.addConnection(from: self.myPeer.deviceName, to: self.myPeer.commsPeer)
                
                // And call remote state change
                loopbackDelegates.stateDelegate?.stateChange(for: self.myPeer.commsPeer)
            }
            return true
        } else {
            return false
        }
    }
    
    public func disconnect(from commsPeer: CommsPeer, reason: String) {
        
        // Pass across state change and remove from connection list
        if let loopbackDelegates = LoopbackService.peerList[commsPeer.deviceName] {
            loopbackDelegates.peer.state = .notConnected
            loopbackDelegates.stateDelegate?.stateChange(for: loopbackDelegates.peer.commsPeer, reason: reason)
            self.connectionList.removeValue(forKey: commsPeer.deviceName)
        }
    }
    
    public func send(_ descriptor: String, _ dictionary: Dictionary<String, Any?>!, to commsPeer: CommsPeer?, matchEmail: String?) {
        
        for (deviceName, commsPeer) in self.connectionList {
            if commsPeer.deviceName == deviceName {
                if matchEmail == nil || matchEmail == commsPeer.playerEmail {
                    // Want to send message to this peer
                    if let lookbackDelegates = LoopbackService.peerList[deviceName] {
                        lookbackDelegates.dataDelegate?.didReceiveData(descriptor: descriptor, data: dictionary, from: self.myPeer.commsPeer)
                    }
                }
            }
        }
    }
    
    public func connectionInfo() {
    }
    
    public func debugMessage(_ message: String, device: String?, force: Bool = false) {
        var outputMessage = message
        if let device = device {
            outputMessage = outputMessage + " Device: \(device)"
        }
        Utility.debugMessage("loopback", outputMessage, force: force)
    }
    
    private func remotePeer(of peer: CommsPeer, as newState: CommsConnectionState? = nil) -> CommsPeer? {
        // Get the peer at the other end of the connection
        let deviceName = peer.fromDeviceName!
        let lookupDelegate = LoopbackService.peerList[deviceName]
        let remotePeer = lookupDelegate?.peer
        if newState != nil {
            remotePeer?.state = newState!
        }
        return remotePeer?.commsPeer
    }
    
    // MARK: - Connection delegate handlers =================================================================== -
    
    func connectionReceived(from peer: CommsPeer, info: [String : Any?]?) -> Bool {
        // Pass it on
        return self.connectionDelegate?.connectionReceived(from: peer) ?? true
    }
    
    // MARK: - State delegate handlers ======================================================================== -
    
    func stateChange(for peer: CommsPeer, reason: String?) {
        switch peer.state {
        case .connected:
            // Already added to connection list
            break
        case .notConnected:
            // Remove from connection list
            self.connectionList.removeValue(forKey: peer.deviceName)
        default:
            break
        }
        // Pass it on
        self.stateDelegate?.stateChange(for: peer)
    }
    
    // MARK: - Data delegate handlers ========================================================================= -
    
    func didReceiveData(descriptor: String, data: [String : Any?]?, from peer: CommsPeer) {
        self.dataDelegate?.didReceiveData(descriptor: descriptor, data: data, from: peer)
    }
    
    // MARK: - Data delegate handlers ========================================================================= -
    
    func addConnection(from deviceName: String, to commsPeer: CommsPeer) {
        self.connectionList[deviceName] = commsPeer
    }
    
}

class LoopbackPeer {
    
    public let parent: CommsHandlerDelegate
    public var playerEmail: String?
    public var playerName: String?
    public var state: CommsConnectionState
    public let deviceName: String
    
    init(parent: CommsHandlerDelegate, deviceName: String, playerEmail: String? = "", playerName: String? = "") {
        self.parent = parent
        self.deviceName = deviceName
        self.playerEmail = playerEmail
        self.playerName = playerName
        self.state = .notConnected
    }
    
    public var commsPeer: CommsPeer {
        get {
            return CommsPeer(parent: self.parent, deviceName: self.deviceName, playerEmail: self.playerEmail, playerName: self.playerName, state: self.state, reason: "")
        }
    }
    
}

class LoopbackDelegates {
    public var peer: LoopbackPeer
    public var connectionDelegate: CommsConnectionDelegate?
    public var stateDelegate: CommsStateDelegate?
    public var dataDelegate: CommsDataDelegate?
    public var loopbackServiceDelegate: LoopbackServiceDelegate?

    init(peer: LoopbackPeer, connectionDelegate: CommsConnectionDelegate?, stateDelegate: CommsStateDelegate?, dataDelegate: CommsDataDelegate?, loopbackServiceDelegate: LoopbackServiceDelegate) {
        self.peer = peer
        self.connectionDelegate = connectionDelegate
        self.stateDelegate = stateDelegate
        self.dataDelegate = dataDelegate
        self.loopbackServiceDelegate = loopbackServiceDelegate
    }
}