//
//  Loopback Class.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 31/07/2018.
//  Copyright © 2018 Marc Shearer. All rights reserved.
//

import Foundation

protocol LoopbackServiceDelegate : class {
    
    func addConnection(from deviceName: String, to commsPeer: CommsPeer)

}

class LoopbackService: NSObject, CommsServiceDelegate, CommsHostServiceDelegate, CommsConnectionDelegate, LoopbackServiceDelegate {
    
    // Delegate properties
    public let connectionMode: CommsConnectionMode
    public let connectionProximity: CommsConnectionProximity = .loopback
    public var connectionType: CommsConnectionType
    public var handlerState: CommsServiceState = .notStarted
    public var connections = 0
    public var connectionUUID: String?
    public var connectionEmail: String?
    public var connectionRemoteDeviceName: String?
    public var connectionRemoteEmail: String?
    
    // Delegates
    public weak var browserDelegate: CommsBrowserDelegate!
    public weak var stateDelegate: CommsStateDelegate!
    public weak var dataDelegate: CommsDataDelegate!
    public weak var connectionDelegate: CommsConnectionDelegate!
    public weak var broadcastDelegate: CommsBroadcastDelegate!
    public weak var handlerStateDelegate: CommsServiceStateDelegate!
    public weak var loopbackServiceDelegate: LoopbackServiceDelegate!
    
    // Internal state
    private static var peerList: [String : LoopbackDelegates] = [ : ]
    private var connectionList: [String : CommsPeer] = [ : ]
    private var myPeer: LoopbackPeer!
    
    // MARK: - Comms Handler delegate implementation ======================================================== -

    init(mode: CommsConnectionMode, type: CommsConnectionType, serviceID: String?, deviceName: String) {
        self.connectionMode = mode
        self.connectionType = type
        if mode != .loopback {
            fatalError("Loopback protocol only supports loopback mode")
        }
        self.connectionType = .server
        self.connectionRemoteDeviceName = deviceName
        super.init()

    }
    
    convenience required init(mode: CommsConnectionMode, serviceID: String?, deviceName: String) {
        self.init(mode: mode, type: .server, serviceID: serviceID, deviceName: deviceName)
    }
    
    public func start(email: String!, queueUUID: String!, name: String!, invite: [String]!, recoveryMode: Bool, matchGameUUID: String!) {
        self.myPeer = LoopbackPeer(parent: self, deviceName: self.connectionRemoteDeviceName!, playerEmail: email, playerName: name)
        
        self.connectionEmail = email
        
        // Add myself to the shared peer list
        LoopbackService.peerList[self.myPeer.deviceName] = LoopbackDelegates(peer: self.myPeer , connectionDelegate: self.connectionDelegate, stateDelegate: self.stateDelegate, dataDelegate: self.dataDelegate, loopbackServiceDelegate: self)
    }
 
    public func stop(completion: (()->())?) {
        // Remove myself from the shared peer list
        LoopbackService.peerList.removeValue(forKey: self.myPeer.deviceName)
        completion?()
    }
    
    func reset(reason: String?) {
        // Not implemented
    }

    public func connect(to commsPeer: CommsPeer, playerEmail: String?, playerName: String?, context: [String : String]? = nil, reconnect: Bool) -> Bool {
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
    
    public func disconnect(from commsPeer: CommsPeer? = nil, reason: String, reconnect: Bool) {
        
        // Pass across state change and remove from connection list
        for (deviceName, loopbackDelegates) in LoopbackService.peerList {
            if commsPeer == nil || commsPeer?.deviceName == deviceName {
                loopbackDelegates.peer.state = .notConnected
                loopbackDelegates.stateDelegate?.stateChange(for: loopbackDelegates.peer.commsPeer, reason: reason)
                self.connectionList.removeValue(forKey: deviceName)
            }
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
    
    public func connectionInfo(message: String) {
    }
    
    public func debugMessage(_ message: String, device: String?, force: Bool = false) {
        var outputMessage = message
        if let device = device {
            outputMessage = outputMessage + " Device: \(device)"
        }
        Utility.debugMessage("loopback", outputMessage, force: force)
    }
    
    func recoveryInProgress(_ recovering: Bool, message: String?) {
    }
    
    private func remotePeer(of peer: CommsPeer, as newState: CommsConnectionState? = nil) -> CommsPeer? {
        // Get the peer at the other end of the connection
        let deviceName = peer.deviceName
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
    
    public let parent: CommsServiceDelegate
    public var playerEmail: String?
    public var playerName: String?
    public var state: CommsConnectionState
    public let deviceName: String
    
    init(parent: CommsServiceDelegate, deviceName: String, playerEmail: String? = "", playerName: String? = "") {
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
