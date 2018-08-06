//
//  Comms.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 10/08/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import Foundation

public enum CommsHandlerState {
    case notStarted
    case inviting
    case invited
    case reconnecting
    case broadcasting
    case browsing
}

public enum CommsConnectionState {
    case notConnected
    case connecting
    case connected
    case reconnecting
}

public enum CommsConnectionMode: String {
    case broadcast = "broadcast"
    case invite = "invite"
    case loopback = "loopback"
}

public enum CommsConnectionFramework {
    case multipeer
    case rabbitMQ
    case loopback
}

public enum CommsConnectionProximity {
    case nearby
    case online
    case loopback
}

public enum CommsConnectionType: String {
    case client = "client"
    case server = "server"
    case queue = "queue"
}

public enum CommsConnectionPurpose: String {
    case playing = "playing"
    case sharing = "sharing"
    case other = "other"
}

public class CommsPeer {
    // Note that this is just a construct built from other data structures - therefore it's contents are not mutable
    public let deviceName: String
    public let playerEmail: String?
    public let playerName: String?
    public let state: CommsConnectionState
    public let reason: String?
    private var parent: CommsHandlerDelegate
    
    public var mode: CommsConnectionMode {
        get {
            return self.parent.connectionMode
        }
    }
    public var framework: CommsConnectionFramework {
        get {
            return self.parent.connectionFramework
        }
    }
    public var proximity: CommsConnectionProximity {
        get {
            return self.parent.connectionProximity
        }
    }
    public var type: CommsConnectionType {
        get {
            return self.parent.connectionType
        }
    }
    public var purpose: CommsConnectionPurpose {
        get {
            return self.parent.connectionPurpose
        }
    }
    
    public var fromDeviceName: String? {
        get {
            return self.parent.connectionDevice
        }
    }

    init(parent: CommsHandlerDelegate, deviceName: String, playerEmail: String? = "", playerName: String? = "", state: CommsConnectionState = .notConnected, reason: String? = nil) {
        self.parent = parent
        self.deviceName = deviceName
        self.playerEmail = playerEmail
        self.playerName = playerName
        self.state = state
        self.reason = reason
    }
    
    func setParent(to parent: CommsHandlerDelegate) {
        self.parent = parent
    }
}

// MARK: - Protocols from communication handlers to views ==================================== -

public protocol CommsBrowserDelegate : class {
    
    func peerFound(peer: CommsPeer)
    
    func peerLost(peer: CommsPeer)
    
    func error(_ message: String)
    
}

public protocol CommsStateDelegate : class {
    
    func stateChange(for peer: CommsPeer, reason: String?)
    
}

extension CommsStateDelegate{
    
    func stateChange(for peer: CommsPeer) {
        stateChange(for: peer, reason: nil)
    }
    
}

public protocol CommsDataDelegate : class {
    
    func didReceiveData(descriptor: String, data: [String : Any?]?, from peer: CommsPeer)
    
}

public protocol CommsConnectionDelegate : class {
    
    func connectionReceived(from peer: CommsPeer, info: [String : Any?]?) -> Bool
    
}

extension CommsConnectionDelegate {
    
    func connectionReceived(from peer: CommsPeer) -> Bool {
        return connectionReceived(from: peer, info: nil)
    }
}

public protocol CommsHandlerStateDelegate : class {
    
    func handlerStateChange(to state: CommsHandlerState)
}

// MARK: - Protocols from views to communication handlers ==================================== -

protocol CommsHandlerDelegate : class {
    
    var connectionMode: CommsConnectionMode { get }
    var connectionFramework: CommsConnectionFramework { get }
    var connectionProximity: CommsConnectionProximity { get }
    var connectionType: CommsConnectionType { get }
    var connectionPurpose: CommsConnectionPurpose { get }
    var handlerState: CommsHandlerState { get }
    var connections: Int { get }
    var connectionUUID: String? { get }
    var connectionEmail: String? { get }
    var connectionDevice: String? { get }
    
    var browserDelegate: CommsBrowserDelegate! { get set }
    var stateDelegate: CommsStateDelegate! { get set }
    var dataDelegate: CommsDataDelegate! { get set }
    var connectionDelegate: CommsConnectionDelegate! { get set }
    var handlerStateDelegate: CommsHandlerStateDelegate! { get set }
    
    init(purpose: CommsConnectionPurpose, type: CommsConnectionType, serviceID: String?, deviceName: String)
    
    func start(email: String!, queueUUID: String!, name: String!, invite: [String]!, recoveryMode: Bool, matchDeviceName: String!)
    
    func stop()
    
    func connect(to commsPeer: CommsPeer, playerEmail: String?, playerName: String?, reconnect: Bool) -> Bool

    func disconnect(from commsPeer: CommsPeer, reason: String)
    
    func send(_ descriptor: String, _ dictionary: Dictionary<String, Any?>!, to commsPeer: CommsPeer?, matchEmail: String?)
    
    func connectionInfo()
    
    func debugMessage(_ message: String, device: String?, force: Bool)
}

extension CommsHandlerDelegate {
    
    init(purpose: CommsConnectionPurpose, type: CommsConnectionType, serviceID: String?) {
        self.init(purpose: purpose, type: type, serviceID: serviceID, deviceName: "")
    }
    
    func start() {
        start(email: nil, queueUUID: nil, name: nil, invite: nil, recoveryMode: false, matchDeviceName: nil)
    }
    
    func start(email: String!) {
        start(email: email, queueUUID: nil, name: nil, invite: nil, recoveryMode: false, matchDeviceName: nil)
    }
    
    func start(email: String!, name: String!) {
        start(email: email, queueUUID: nil, name: name, invite: nil, recoveryMode: false, matchDeviceName: nil)
    }
    
    func start(email: String!, recoveryMode: Bool, matchDeviceName: String!) {
        start(email: email, queueUUID: nil, name: nil, invite: nil, recoveryMode: recoveryMode, matchDeviceName: matchDeviceName)
    }
    func start(email: String!, name: String!, invite: [String]!) {
        start(email: email, queueUUID: nil, name: name, invite: invite, recoveryMode: false, matchDeviceName: nil)
    }
    
    func start(email: String!, queueUUID: String!, recoveryMode: Bool) {
        start(email: email, queueUUID: queueUUID, name: nil, invite: nil, recoveryMode: recoveryMode, matchDeviceName : nil)
    }
    
    func send(_ descriptor: String, _ dictionary: Dictionary<String, Any?>!, to commsPeer: CommsPeer?) {
        send(descriptor, dictionary, to: commsPeer, matchEmail: nil)
    }
    
    func send(_ descriptor: String, _ dictionary: Dictionary<String, Any?>!, matchEmail: String?) {
        send(descriptor, dictionary, to: nil, matchEmail: matchEmail)
    }
    
    func send(_ descriptor: String, _ dictionary: Dictionary<String, Any?>!) {
        send(descriptor, dictionary, to: nil, matchEmail: nil)
    }
    
    func debugMessage(_ message: String) {
        debugMessage(message, device: nil, force: false)
    }
}
