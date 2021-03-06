//
//  Comms Handler.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 10/08/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//
//  This contains the generic communications class which should be used by applications
//  It also contains the protocol definitions that calling applications should (can) implement

import Foundation

// MARK: - Type declarations =============================================== -

public enum CommsServiceState {
    case notStarted
    case advertising
    case inviting
    case invited
    case reconnecting
}

public enum CommsConnectionState: String {
    case notConnected = "Not connected"
    case connecting = "Connecting"
    case connected = "Connected"
    case reconnecting = "Re-connecting" // After a failure
    case recovering = "Recovering"      // Error encountered - recovering
}

public enum CommsConnectionMode: String {
    case broadcast = "broadcast"
    case invite = "invite"
    case queue = "queue"
    case loopback = "loopback"
}

public enum CommsConnectionProximity: String {
    case nearby = "local"
    case online = "online"
    case loopback = "loopback"
}

public enum CommsConnectionType: String {
    case client = "client"
    case server = "server"
    case queue = "queue"
}

// MARK: - Communications peer class =========================================== -

// Peers are basically used to identify yourself and the other party to a communication connection

public class CommsPeer {
    // Note that this is just a construct built from other data structures - therefore it's contents are not mutable
    public let deviceName: String      // Remote device name
    public let playerUUID: String?    // Remote player playerUUID
    public let playerName: String?     // Remote player name
    public let state: CommsConnectionState
    public let reason: String?
    private weak var parent: CommsServiceDelegate!
    private var _autoReconnect: Bool
    public var autoReconnect: Bool { get { return _autoReconnect } }
    private var _purpose: CommsPurpose!
    public var purpose: CommsPurpose! { get {return _purpose } }
    
    public var mode: CommsConnectionMode { get { return self.parent.connectionMode } }
    public var proximity: CommsConnectionProximity { get { return self.parent.connectionProximity } }
    public var type: CommsConnectionType { get { return self.parent.connectionType } }
    

    init(parent: CommsServiceDelegate, deviceName: String, playerUUID: String? = "", playerName: String? = "", state: CommsConnectionState = .notConnected, reason: String? = nil, autoReconnect: Bool = false, purpose: CommsPurpose = .playing) {
        self.parent = parent
        self.deviceName = deviceName
        self.playerUUID = playerUUID
        self.playerName = playerName
        self.state = state
        self.reason = reason
        self._autoReconnect = autoReconnect
        self._purpose = purpose
    }
}

// MARK: - Protocols from communication handlers to applications ==================================== -

// Applications must/should implement the following protocols to receive updates from the communications layer

public protocol CommsBrowserDelegate : class {
    
    // Must be implemented by clients to allow them to initiate connections
    
    func peerFound(peer: CommsPeer, reconnect: Bool)
    
    func peerLost(peer: CommsPeer)
    
    func error(_ message: String)
    
}

extension CommsBrowserDelegate {

    func peerFound(peer: CommsPeer) {
        peerFound(peer: peer, reconnect: true)
    }
}

public protocol CommsStateDelegate : class {
    
    // Must be implemented by clients & servers to allow them to react to changes in the state of a connection
    
    func stateChange(for peer: CommsPeer, reason: String?)
    
}

extension CommsStateDelegate {
    
    func stateChange(for peer: CommsPeer) {
        stateChange(for: peer, reason: nil)
    }
    
}

public protocol CommsDataDelegate : class {
    
    // Should be implemented by clients and servers to allow them to receive data on a connection (unless they only send data)
    
    func didReceiveData(descriptor: String, data: [String : Any?]?, from peer: CommsPeer)
    
}

public protocol CommsBroadcastDelegate : class {
    
    // Should be implemented by clients and server to receive broadcasts on a service running in queue mode
    
    func didReceiveBroadcast(descriptor: String, data: Any?, from: String)
    
}


public protocol CommsConnectionDelegate : class {
    
    // Must be implemented by servers to allow them to receive connection requests from clients
    
    func connectionReceived(from peer: CommsPeer, info: [String : Any?]?) -> Bool
    
    func error(_ message: String)
    
}

extension CommsConnectionDelegate {
    
    func connectionReceived(from peer: CommsPeer) -> Bool {
        return connectionReceived(from: peer, info: nil)
    }
}

public protocol CommsServiceStateDelegate : class {
    
    // Can be implemented by controllers to allow them to detect a change in the state of the service
    
    func controllerStateChange(to state: CommsServiceState)
    
}

// MARK: - Protocols from abstraction layer to communication handlers ==================================== -

// These protocols must be implemented by communication handlers to allow the abstraction layer to communicate with them

public protocol CommsServiceDelegate : class {
    
    // This is an abstract class protocol and classes which implement it should never be instantiated
    // Instead either a client or server extension class should be instantiated

    var connectionMode: CommsConnectionMode { get }
    var connectionProximity: CommsConnectionProximity { get }
    var connectionType: CommsConnectionType { get }
    var connections: Int { get }
    var connectionUUID: String? { get }
    var connectionPlayerUUID: String? { get }
    var connectionRemoteDeviceName: String? { get }
    var connectionRemotePlayerUUID: String? { get }
    var stateDelegate: CommsStateDelegate! { get set }
    var dataDelegate: CommsDataDelegate! { get set }
    var broadcastDelegate: CommsBroadcastDelegate! { get set}

    func send(_ descriptor: String, _ dictionary: Dictionary<String, Any?>!, to commsPeer: CommsPeer?, matchPlayerUUID: String?)

    func disconnect(from commsPeer: CommsPeer?, reason: String, reconnect: Bool)
    
    func reset(reason: String?)

    func connectionInfo(message: String)
    
    func debugMessage(_ message: String, device: String?, force: Bool)
}

extension CommsServiceDelegate {
    
    func send(_ descriptor: String, _ dictionary: Dictionary<String, Any?>!, to commsPeer: CommsPeer?) {
        send(descriptor, dictionary, to: commsPeer, matchPlayerUUID: nil)
    }
    
    func send(_ descriptor: String, _ dictionary: Dictionary<String, Any?>!, matchPlayerUUID: String?) {
        send(descriptor, dictionary, to: nil, matchPlayerUUID: matchPlayerUUID)
    }
    
    func send(_ descriptor: String, _ dictionary: Dictionary<String, Any?>!) {
        send(descriptor, dictionary, to: nil, matchPlayerUUID: nil)
    }
    
    func disconnect(from commsPeer: CommsPeer, reason: String) {
        disconnect(from: commsPeer, reason: reason, reconnect: false)
    }
    
    func disconnect(reason: String, reconnect: Bool) {
        disconnect(from: nil, reason: reason, reconnect: reconnect)
    }
    
    func reset() {
        reset(reason: nil)
    }
    
    func debugMessage(_ message: String) {
        debugMessage(message, device: nil, force: false)
    }   
}

public protocol CommsHostServiceDelegate : CommsServiceDelegate {
    
    var handlerState: CommsServiceState { get }
    var connectionDelegate: CommsConnectionDelegate! { get set }
    var handlerStateDelegate: CommsServiceStateDelegate! { get set }
    
    init(mode: CommsConnectionMode, serviceID: String?, deviceName: String, purpose: CommsPurpose)
    
    func start(playerUUID: String!, queueUUID: String!, name: String!, invite: [String]!, recoveryMode: Bool, matchGameUUID: String!)
    
    func stop(completion: (()->())?)
}

extension CommsHostServiceDelegate {
    
    init(mode: CommsConnectionMode, serviceID: String?, purpose: CommsPurpose) {
        self.init(mode: mode, serviceID: serviceID, deviceName: "", purpose: purpose)
    }
    
    func start() {
        start(playerUUID: nil, queueUUID: nil, name: nil, invite: nil, recoveryMode: false, matchGameUUID: nil)
    }
    
    func start(playerUUID: String!) {
        start(playerUUID: playerUUID, queueUUID: nil, name: nil, invite: nil, recoveryMode: false, matchGameUUID: nil)
    }
    
    func start(playerUUID: String!, name: String!) {
        start(playerUUID: playerUUID, queueUUID: nil, name: name, invite: nil, recoveryMode: false, matchGameUUID: nil)
    }
    
    func start(playerUUID: String!, recoveryMode: Bool) {
        start(playerUUID: playerUUID, queueUUID: nil, name: nil, invite: nil, recoveryMode: recoveryMode, matchGameUUID: nil)
    }
    
    func start(playerUUID: String!, name: String!, invite: [String]!) {
        start(playerUUID: playerUUID, queueUUID: nil, name: name, invite: invite, recoveryMode: false, matchGameUUID: nil)
    }
    
    func start(playerUUID: String!, queueUUID: String!, recoveryMode: Bool) {
        start(playerUUID: playerUUID, queueUUID: queueUUID, name: nil, invite: nil, recoveryMode: recoveryMode, matchGameUUID: nil)
    }
    
    func stop() {
        stop(completion: nil)
    }

}

public protocol CommsClientServiceDelegate : CommsServiceDelegate {
    
    var browserDelegate: CommsBrowserDelegate! { get set }
    
    init(mode: CommsConnectionMode, serviceID: String?, deviceName: String)
    
    func start(playerUUID: String!, name: String!, recoveryMode: Bool, matchDeviceName: String!, matchGameUUID: String!)
    
    func start(queue: String, filterPlayerUUID: String!)
    
    func stop()
    
    func connect(to commsPeer: CommsPeer, playerUUID: String?, playerName: String?, context: [String : String]?, reconnect: Bool) -> Bool
    
    func checkOnlineInvites(playerUUID: String, checkExpiry: Bool, matchDeviceName: String?)
}

extension CommsClientServiceDelegate {
    
  func start() {
    start(playerUUID: nil, name: nil, recoveryMode: false, matchDeviceName: nil, matchGameUUID: nil)
    }
    
    func start(playerUUID: String!) {
        start(playerUUID: playerUUID, name: nil, recoveryMode: false, matchDeviceName: nil, matchGameUUID: nil)
    }
    
    func start(playerUUID: String!, name: String!) {
        start(playerUUID: playerUUID, name: name, recoveryMode: false, matchDeviceName: nil, matchGameUUID: nil)
    }
    
    func start(playerUUID: String!, name: String!, recoveryMode: Bool) {
        start(playerUUID: playerUUID, name: name, recoveryMode: recoveryMode, matchDeviceName: nil, matchGameUUID: nil)
    }
    
    func start(playerUUID: String!, recoveryMode: Bool) {
        start(playerUUID: playerUUID, name: nil, recoveryMode: recoveryMode, matchDeviceName: nil, matchGameUUID: nil)
    }
    
    func start(playerUUID: String!, recoveryMode: Bool, matchDeviceName: String!) {
        start(playerUUID: playerUUID, name: nil, recoveryMode: recoveryMode, matchDeviceName: matchDeviceName, matchGameUUID: nil)
    }
    
    func connect(to commsPeer: CommsPeer, playerUUID: String?, playerName: String?, reconnect: Bool) -> Bool {
        return connect(to: commsPeer, playerUUID: playerUUID, playerName: playerName, context: nil, reconnect: reconnect)
    }
    
    func checkOnlineInvites(playerUUID: String) {
        checkOnlineInvites(playerUUID: playerUUID, checkExpiry: true, matchDeviceName: nil)
    }    
}

// MARK: - Comms handler wrapper to get relevant comms class

public class CommsHandler {
    
    public static func client(proximity: CommsConnectionProximity,
                              mode: CommsConnectionMode,
                              serviceID: String?,
                              deviceName: String = "") -> CommsClientServiceDelegate? {
        
        if proximity == .nearby && mode == .broadcast {
            // Nearby broadcast = Multi-peer connectivity
            return MultipeerClientService(mode: mode, serviceID: serviceID, deviceName: deviceName)
        } else if proximity == .online && (mode == .invite || mode == .queue) {
            // Online invite or online queue = RabbitMQ connectivity
            return RabbitMQClientService(mode: mode, serviceID: serviceID, deviceName: deviceName)
        } else {
            return nil
        }
    }
    
    public static func server(proximity: CommsConnectionProximity,
                              mode: CommsConnectionMode,
                              serviceID: String?,
                              deviceName: String = "",
                              purpose: CommsPurpose) -> CommsHostServiceDelegate? {
        
        if proximity == .nearby && mode == .broadcast {
            // Nearby broadcast = Multi-peer connectivity
            return MultipeerServerService(mode: mode, serviceID: serviceID, deviceName: deviceName, purpose: purpose)
        } else if proximity == .online && (mode == .invite || mode == .queue) {
            // Online invite or online queue = RabbitMQ connectivity
            return RabbitMQServerService(mode: mode, serviceID: serviceID, deviceName: deviceName, purpose: purpose)
        } else if proximity == .loopback && mode == .loopback {
            // Loopback = loopback
            return LoopbackService(mode: mode, type: .server, serviceID: serviceID, deviceName: deviceName, purpose: purpose)
        } else {
            return nil
        }
    }
}
