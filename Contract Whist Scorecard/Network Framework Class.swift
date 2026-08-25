//
//  Network Framework Class.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 31/05/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//
//  Class to implement gaming/sharing between devices using Network Framework connectivity

import Foundation
import Network

public class NFPeerID : Codable, Hashable, Equatable {
    var displayName: String
    var id: UUID
    
    init(displayName: String, id: UUID? = nil) {
        self.displayName = displayName
        if let id = id {
            self.id = id
        } else {
            // Try to find a stored ID
            if let archivedId = UserDefaults.standard.string(forKey: "NFPeerID") {
                // Found - use it
                self.id = UUID(uuidString: archivedId)!
            } else {
                // Not found - create a new one and save it
                self.id = UUID()
                UserDefaults.standard.set(self.id.uuidString, forKey: "NFPeerID")
            }
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(displayName)
    }
    
    public static func == (lhs: NFPeerID, rhs: NFPeerID) -> Bool {
        lhs.id == rhs.id && lhs.displayName == rhs.displayName
    }
    
    var serviceName: String {
        "\(displayName)-\(id.uuidString)"
    }
}

class NetworkFrameworkService: NSObject, CommsServiceDelegate {
    
    // Main class variables
    public let connectionMode: CommsConnectionMode
    public let connectionProximity: CommsConnectionProximity = .nearby
    public let connectionType: CommsConnectionType
    public var connectionUUID: String?
    private var _connectionPlayerUUID: String?
    private var _connectionName: String?
    internal var _connectionRemoteDeviceName: String?
    internal var _connectionRemotePlayerUUID: String?
    internal var started = false
    
    public var connectionPlayerUUID: String? {
        get {
            return _connectionPlayerUUID
        }
    }
    public var connectionName: String? {
        get {
            return _connectionName
        }
    }
    public var connectionRemoteDeviceName: String? {
        get {
            return _connectionRemoteDeviceName
        }
    }
    public var connectionRemotePlayerUUID: String? {
        get {
            return _connectionRemotePlayerUUID
        }
    }
    public var connections: Int {
        get {
            return self.connectionList.count
        }
    }
    
    public var tcpParameters: NWParameters {
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveIdle = 5
        tcpOptions.keepaliveInterval = 2
        tcpOptions.keepaliveCount = 3
        let parameters = NWParameters(tls: nil, tcp: tcpOptions)
        parameters.includePeerToPeer = true
        return parameters
    }

    // Delegates
    public weak var stateDelegate: CommsStateDelegate?
    public weak var dataDelegate: CommsDataDelegate?
    public weak var broadcastDelegate: CommsBroadcastDelegate?

    // Other state variables
    internal var serviceID: String
    internal var serviceName: String
    internal var connectionList: [String : NWConnection] = [:]
    internal var broadcastPeerList: [String: NetworkBroadcastPeer] = [:]
    internal var myPeerID: NFPeerID
    
    internal var serviceType: String {
        "_\(serviceID)._tcp"
    }
    
    init(mode: CommsConnectionMode, type: CommsConnectionType, serviceID: String?, deviceName: String) {
        self.connectionMode = mode
        self.connectionType = type
        self.serviceID = serviceID!
        self.serviceName = "whist.sheareronline.com"
        self.myPeerID = NFPeerID(displayName: deviceName)
    }
    
    internal func startService(playerUUID: String!, name: String!, recoveryMode: Bool) {
        self._connectionPlayerUUID = playerUUID
        self._connectionName = name
        self.started = true
    }
    
    internal func stopService() {
        self._connectionPlayerUUID = nil
        self._connectionName = nil
        self.started = false
    }
    
    internal func closeConnections(matchDeviceName: String! = nil) {
        // End all connections - or possibly just for one remote device if specified
        for (deviceName, connection) in self.connectionList {
            if matchDeviceName == nil || matchDeviceName == deviceName {
                closeConnection(connection: connection, deviceName: deviceName)
            }
        }
    }
    
    internal func closeConnection(connection: NWConnection, deviceName: String? = nil) {
        self.debugMessage("End Connection")
        connection.cancel()
        connection.stateUpdateHandler = nil
        if let deviceName = deviceName {
            self.connectionList.removeValue(forKey: deviceName)
        }
    }
    
    internal func disconnect(from commsPeer: CommsPeer? = nil, reason: String = "", reconnect: Bool) {
        self.debugMessage("Disconnect - reconnect: \(reconnect)")
        
        self.send("disconnect", ["reason" : reason], to: commsPeer)
        
        for (deviceName, _) in self.connectionList {
            if commsPeer == nil || commsPeer?.deviceName == deviceName {
                if let broadcastPeer = self.broadcastPeerList[deviceName] {
                    self.debugMessage("disconnect (\(reason))", peerID: broadcastPeer.nfPeer)
                    broadcastPeer.shouldReconnect = reconnect
                    broadcastPeer.reconnect = reconnect
                    broadcastPeer.state = .notConnected
                    self.stateDelegate?.stateChange(for: broadcastPeer.commsPeer, reason: reason)
                }
            }
        }
    }
    
    internal func send(_ descriptor: String, _ dictionary: Dictionary<String, Any?>! = nil, to commsPeer: CommsPeer? = nil, matchPlayerUUID: String? = nil) {
        var toDeviceName: String! = nil
        if let commsPeer = commsPeer {
            toDeviceName = commsPeer.deviceName
        }
        
        var content = ""
        if let dictionary = dictionary {
            content = "(\(Scorecard.serialise(dictionary)))"
        }
        self.debugMessage("Sending \(descriptor)\(content) to \(commsPeer == nil ? "all" : commsPeer!.playerName!)", device: toDeviceName)
            
        for (deviceName, connection) in self.connectionList {
            
            if toDeviceName == nil || deviceName == toDeviceName {
                if let broadcastPeer = broadcastPeerList[deviceName] {
                    if matchPlayerUUID == nil || (broadcastPeer.playerUUID != nil && broadcastPeer.playerUUID! == matchPlayerUUID) {
                        connection.send(content: encode(descriptor: descriptor, dictionary: dictionary), completion: .contentProcessed({ error in
                            // Maybe I should disconnect and reconnect on errors?
                            if let error = error {
                                self.debugMessage("Send error: \(error)")
                            } else {
                                self.debugMessage("Data successfully sent.")
                            }
                        }))
                    }
                }
            }
        }
    }
        
    internal func reset(reason: String? = nil) {
        // Over-ridden in client and server
    }
    
    internal func suspend(reason: String? = nil) {
        // Over-ridden in client and server
    }
    
    internal func resume(reason: String? = nil) {
        // Over-ridden in client and server
    }

    internal func connectionInfo(message: String) {
        var message = message + "\n\nPeers"
        for (deviceName, peer) in self.broadcastPeerList {
            message = message + "\nDevice: \(deviceName), Player: \(peer.playerName!), \(peer.state.rawValue)\n"
        }
        
        message = message + "\nConnections"
        for (deviceName, _) in self.connectionList {
            message = message + "\nDevice: \(deviceName)\n"
        }
        
        Utility.getActiveViewController()?.alertMessage(message, title: "NetworkFramework Connection Info", buttonText: "Close")
    }
    
    internal func debugMessage(_ message: String, device: String? = nil, force: Bool = false) {
        var outputMessage = message
        if let device = device {
            outputMessage = outputMessage + " Device: \(device)"
        }
        Utility.debugMessage((self.serviceID == "whist-logger" ? "logger" : "networkFramework"), message, force: force)
    }
    
    internal func debugMessage(_ message: String, peerID: NFPeerID?) {
        var outputMessage = message
        if let peerID = peerID {
            outputMessage = outputMessage + " Device: \(peerID.displayName)"
        }
        self.debugMessage(outputMessage, device: nil, force: false)
    }
    
    internal func startBrowsingForPeers() {
        // Overridden by client
    }
    
    internal func stopBrowsingForPeers() {
        // Overridden by client
    }

    // MARK: - Connection handlers ========================================================== -
    
    internal func listen(connection: NWConnection, peerID: NFPeerID) {
        connection.stateUpdateHandler = { [self] state in
            connectionState(connection: connection, peerID: peerID, didChangeTo: state)
        }
        persistentListening(connection: connection, peerID: peerID)
    }
    
    func persistentListening(connection: NWConnection, peerID: NFPeerID) {
        debugMessage("Listening", peerID: peerID)
        receivePacket(from: connection) { [self] propertyList, error in
            if error == nil {
                if let propertyList = propertyList {
                    dataReceived(from: connection, peerID: peerID, propertyList: propertyList)
                }
                persistentListening(connection: connection, peerID: peerID)
            } else {
                reset()
            }
        }
    }
    
    internal func connectionState(connection: NWConnection, peerID: NFPeerID, didChangeTo nwState: NWConnection.State) {
        let state = commsConnectionState(nwState)
        debugMessage("Connection change state to \((state == .notConnected ? "Not connected" : (state == .connected ? "Connected" : "Connecting"))) (\(nwState)", peerID: peerID)
        
        let deviceName = peerID.displayName
        if let broadcastPeer = broadcastPeerList[deviceName] {
            let currentState = broadcastPeer.state
            broadcastPeer.state = state
            if broadcastPeer.state == .notConnected {
                if currentState == .reconnecting {
                    // Have done a reconnect and it has now failed - reset connection
                    self.reset()
                }
                if broadcastPeer.reconnect {
                    // Reconnect
                    broadcastPeer.state = .reconnecting
                    self.debugMessage("Reconnecting", device: deviceName)
                } else {
                    // Clear peer
                    broadcastPeerList.removeValue(forKey: deviceName)
                }
            } else if state == .connected {
                // Connected - activate reconnection if selected on connection
                broadcastPeer.reconnect = broadcastPeer.shouldReconnect
            }
            // Call delegate
            stateDelegate?.stateChange(for: broadcastPeer.commsPeer)
        } else {
            // Not in peer list - just ignore it
        }
        
        if state == .notConnected {
            // Clear connection
            connectionList.removeValue(forKey: deviceName)
        } else {
            // Save connection
            connectionList[deviceName] = connection
        }
    }
    
    internal func dataReceived(from connection: NWConnection, peerID: NFPeerID, propertyList: [String : Any?]) {
        Utility.mainThread {
            let deviceName = peerID.displayName
            if let broadcastPeer = self.broadcastPeerList[deviceName] {
                Scorecard.dataLogMessage(propertyList: propertyList, fromDeviceName: peerID.displayName, using: self)
                
                // Process data
                if !propertyList.isEmpty {
                    for (descriptor, values) in propertyList {
                        if descriptor == "disconnect" {
                            var reason = ""
                            if values != nil {
                                let stringValues = values as! [String : String]
                                if stringValues["reason"] != nil {
                                    reason = stringValues["reason"]!
                                }
                            }
                            self.closeConnections(matchDeviceName: deviceName)
                            broadcastPeer.state = .notConnected
                            if reason != "Reset" && reason.left(7) != "Suspend" {
                                // Intentional disconnect
                                self.clearReconnect(commsPeer: broadcastPeer.commsPeer)
                            }
                            if self.stateDelegate != nil {
                                self.stateDelegate?.stateChange(for: broadcastPeer.commsPeer, reason: reason)
                            }
                            if reason == "Reset" || reason.left(7) == "Suspend" {
                                self.reset()
                            }
                        } else if values is NSNull {
                            self.dataDelegate?.didReceiveData(descriptor: descriptor, data: nil, from: broadcastPeer.commsPeer)
                        } else {
                            self.dataDelegate?.didReceiveData(descriptor: descriptor, data: values as! [String : Any]?, from: broadcastPeer.commsPeer)
                        }
                    }
                }
            } else {
                Utility.debugMessage("networkFramework", "Ignoring message for \(deviceName)")
            }
        }
    }
    
    internal func clearReconnect(commsPeer: CommsPeer) {
        // Overridden in client
    }
    
    // MARK: - Utility Methods ========================================================================= -
    
    internal func commsConnectionState(_ nwState: NWConnection.State) -> CommsConnectionState {
        switch nwState {
        case .setup, .waiting, .cancelled, .failed:
            return .notConnected
        case .preparing:
            return .connecting
        case .ready:
            return .connected
        @unknown default:
            return .notConnected
        }
    }
    
    func encode(descriptor: String, dictionary: Dictionary<String, Any?>?) -> Data? {
        let propertyList: [String : [String : Any?]?] = [descriptor : dictionary ?? [:]]
        if let jsonData = try? JSONSerialization.data(withJSONObject: propertyList, options: .prettyPrinted) {
            
            let packetLength = UInt32(jsonData.count)
            var framedData = Data()
            
            var bigEndianLength = packetLength.bigEndian
            withUnsafeBytes(of: &bigEndianLength) { framedData.append(contentsOf: $0) }
            
            // Append the actual JSON payload
            framedData.append(jsonData)
            return framedData
            
        } else {
            return nil
        }
    }
    
    /// Reads exactly the next length-prefixed packet from the stream
    func receivePacket(from connection: NWConnection, completion: @escaping ([String : [String : Any?]?]?, Error?) -> Void) {
        
        // Read the 4-byte length header first
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { data, _, _, error in
            if data == nil {
                // ignore
            } else if let error = error {
                completion(nil, error)
            } else {
                if let data = data, data.count == 4 {
                    
                    // Convert bytes to a UInt32 integer
                    let expectedLength = data.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
                    
                    // Read exactly the number of bytes specified by the header
                    connection.receive(minimumIncompleteLength: Int(expectedLength), maximumLength: Int(expectedLength)) { payloadData, _, _, payloadError in
                        if let payloadError = payloadError {
                            completion(nil, payloadError)
                        } else {
                            if let payloadData = payloadData, payloadData.count == Int(expectedLength) {
                                if let propertyList = try? JSONSerialization.jsonObject(with: payloadData, options: []) as? [String : [String : Any?]?] {
                                    completion(propertyList, nil)
                                } else {
                                    completion(nil, NSError(domain: "NFPacketFramer", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid payload"]))
                                }
                            } else {
                                completion(nil, NSError(domain: "NFPacketFramer", code: -2, userInfo: [NSLocalizedDescriptionKey: "Truncated payload"]))
                            }
                        }
                    }
                } else {
                    completion(nil, NSError(domain: "NFPacketFramer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid header"]))
                }
            }
        }
    }
}


// NetworkFramework Server Service Class ========================================================================= -

class NetworkFrameworkServerService : NetworkFrameworkService, CommsHostServiceDelegate {
    
    private struct ServerConnection {
        var advertiser: NWListener!
    }
    
    internal var handlerState: CommsServiceState = .notStarted
    private var purpose: CommsPurpose
    private var server: ServerConnection!
    
    // Delegates
    public weak var connectionDelegate: CommsConnectionDelegate!
    public weak var handlerStateDelegate: CommsServiceStateDelegate!
    
    required init(mode: CommsConnectionMode, serviceID: String?, deviceName: String, purpose: CommsPurpose) {
        self.purpose = purpose
        super.init(mode: mode, type: .server, serviceID: serviceID, deviceName: deviceName)
    }
    
    // Other variables
    private var playerUUID: String?
    private var name: String?
    private var invite: [String]?
    private var matchGameUUID: String?
    
    // MARK: - Comms Handler Server handlers ========================================================================= -
    
    internal func start(playerUUID: String!, queueUUID: String!, name: String!, invite: [String]!, recoveryMode: Bool, matchGameUUID: String!) {
        self.debugMessage("Start Server (\(self.connectionMode) \(self.serviceType))")
        
        self.playerUUID = playerUUID
        self.name = name
        self.invite = invite
        self.matchGameUUID = matchGameUUID
        
        super.startService(playerUUID: playerUUID, name: name, recoveryMode: recoveryMode)
        self.startAdvertising()
        
    }
    
    internal func startAdvertising() {
        
        var discoveryInfo = NWTXTRecord()
        discoveryInfo["displayName"] = myPeerID.displayName
        discoveryInfo["id"] = myPeerID.id.uuidString
        discoveryInfo["purpose"] = self.purpose.rawValue
        discoveryInfo["playerUUID"] = playerUUID
        discoveryInfo["playerName"] = name ?? self.connectionName ?? self.myPeerID.displayName
        discoveryInfo["gameUUID"] = matchGameUUID
        discoveryInfo["invite"] = invite?.joined(separator: ";")
        
        if let advertiser = try? NWListener(using: tcpParameters) {
            advertiser.service =
            NWListener.Service(name: serviceName, type: serviceType, domain: nil, txtRecord: discoveryInfo)
            
            self.server = ServerConnection(advertiser: advertiser)
            
            self.server.advertiser.newConnectionHandler = advertiserDidReceiveInvitation
            self.server.advertiser.stateUpdateHandler = { [self] state in
                switch state {
                    case .ready:
                    self.debugMessage(("Device network stack is open. Scanning..."), peerID: myPeerID)
                case .waiting(let error):
                    self.debugMessage(("Blocked or waiting on permission payload: \(error)"), peerID: myPeerID)
                case .failed:
                    connectionError()
                default:
                    break
                }
            }
            self.server.advertiser.start(queue: .main)
            changeState(to: .advertising)
        } else {
            changeState(to: .notStarted)
        }
        
    }
    
    internal func stop(completion: (()->())?) {
        if super.started {
            self.debugMessage("Stop Server \(self.connectionMode)")
        }
        
        self.stopAdvertising(reason: "Host has stopped")
        
        // Stop service
        self.stopService()
        
        self.changeState(to: .notStarted)
        completion?()
    }
    
    func stopAdvertising(reason: String? = nil) {
        if self.server != nil {
            // Send disconnects
            self.disconnect(reason: reason ?? "Reset", reconnect: false)
            
            Utility.executeAfter(delay: 0.2) {
                // Slight pause to let disconnects get through
                
                if self.server.advertiser != nil {
                    self.closeConnections()
                    self.server.advertiser.cancel()
                    self.server.advertiser = nil
                    self.broadcastPeerList = [:]
                }
                self.server = nil
            }
        }
    }
    
    override internal func reset(reason: String? = nil) {
        // Just disconnect and wait for client to reconnect
        self.debugMessage("Resetting")
        self.disconnect(reason: reason ?? "Reset", reconnect: true)
        self.suspend(reason: "Reset")
        Utility.executeAfter(delay: 2.0) {
            self.resume(reason: "Reset")
        }
    }
    
    override internal func suspend(reason: String? = nil) {
        // Just disconnect and wait - will reconnect when resume
        self.debugMessage("Suspending")
        self.disconnect(reason: "Suspended: \(reason ?? "Unknown reason")", reconnect: true)
        self.stopAdvertising()
    }
    
    override internal func resume(reason: String? = nil) {
        // Resuming after supspension
        self.debugMessage("Resuming")
        Utility.executeAfter(delay: 1.0) {
            self.startAdvertising()
        }
    }
    
    // MARK: - Comms Handler State handler =================================================================== -
    
    internal func changeState(to state: CommsServiceState) {
        self.handlerState = state
        self.handlerStateDelegate?.controllerStateChange(to: state)
    }
    
    // MARK: - Advertiser delegate handlers ======================================================== - -
    
    func advertiserDidReceiveInvitation(on connection: NWConnection) {
        connection.stateUpdateHandler = { [self] nfState in
            let state = commsConnectionState(nfState)
            if state == .connected {
                receivePacket(from: connection) { [self] propertyList, receiveError in
                    var error: NSError?
                    if receiveError != nil {
                        error = NSError(domain: "ConnectionData", code: -1, userInfo: [NSLocalizedDescriptionKey: "Error parsing data"])
                    } else {
                        if let propertyList = propertyList, let dictionary = propertyList["connectionData"], let dictionary = dictionary, let displayName = dictionary["displayName"] as? String, let id = dictionary["id"] as? String {
                            let peerId = NFPeerID(displayName: displayName, id: UUID(uuidString: id))
                            finaliseConnection(connection: connection, peerID: peerId, dictionary: dictionary)
                        } else {
                            error = NSError(domain: "ConnectionData", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid descriptor"])
                        }
                    }
                    if let error = error {
                        debugMessage("\(error)", peerID: myPeerID)
                        closeConnection(connection: connection)
                    }
                }
            } else if state != .connecting {
                let error = NSError(domain: "ConnectionData", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid state (\(state))"])
                debugMessage("\(error)", peerID: myPeerID)
                connectionError()
                closeConnection(connection: connection)
            }
        }
        connection.start(queue: .main)
    }
    
    private func connectionError() {
        connectionDelegate?.error("Unable to connect. Check that wifi is enabled")
    }
    
    func finaliseConnection(connection: NWConnection, peerID: NFPeerID, dictionary: [String : Any?]) {
        let deviceName = peerID.displayName
        let playerName = dictionary["player"] as? String
        let playerUUID = dictionary["playerUUID"] as? String
        let timestamp = dictionary["timestamp"] as? String
        
        self.debugMessage("Invitation from \(playerName ?? "unknown") (\(peerID.displayName)) @\(timestamp ?? "??")", peerID: peerID)
        
        // End any pre-existing connections since should only have 1 connection at a time
        self.closeConnections(matchDeviceName: deviceName)
        
        // Create / replace peer data
        let broadcastPeer = NetworkBroadcastPeer(parent: self, nfPeer: peerID, deviceName: deviceName, playerUUID: playerUUID, playerName: playerName, purpose: self.purpose)
        broadcastPeer.state = .connected
        self.broadcastPeerList[deviceName] = broadcastPeer
        stateDelegate?.stateChange(for: broadcastPeer.commsPeer)

        // Create and listen on connection
        self.connectionList[deviceName] = connection
        listen(connection: connection, peerID: peerID)
        
        if self.connectionDelegate != nil {
            if self.connectionDelegate.connectionReceived(from: broadcastPeer.commsPeer, info: dictionary) {
                self.debugMessage("Invitiation accepted", peerID: peerID)
            }
        } else {
            self.debugMessage("Invitiation accepted", peerID: peerID)
        }
    }
}


// NetworkFramework Client Service Class ========================================================================= -

class NetworkFrameworkClientServiceFactory {
    private static var existingClients: [NetworkFrameworkClientService] = []
    
    public static func create(mode: CommsConnectionMode, serviceID: String, deviceName: String) -> NetworkFrameworkClientService {
        var result: NetworkFrameworkClientService
        if let existing = existingClients.first(where: {$0.connectionMode == mode && $0.serviceID == serviceID && $0.myPeerID == NFPeerID(displayName: deviceName)}) {
            Utility.debugMessage("networkFramework", "Re-using Client for (\(mode) \(serviceID)) \(deviceName)")
            result = existing
        } else {
            result = NetworkFrameworkClientService(mode: mode, serviceID: serviceID, deviceName: deviceName)
            Utility.debugMessage("networkFramework", "Creating new Client for (\(mode) \(serviceID)) \(deviceName)")
            existingClients.append(result)
        }
        return result
    }
    
    public static func remove(client: NetworkFrameworkClientService) {
        existingClients.removeAll(where: {$0 === client})
    }
}

class NetworkFrameworkClientService : NetworkFrameworkService, CommsClientServiceDelegate {
    
    private struct ClientConnection {
        var browser: NWBrowser!
    }
    
    private var client: ClientConnection!
    private var matchDeviceName: String!
    private var matchGameUUID: String?
    private var invite: Invite!
    private var onlineInviteObserver: NSObjectProtocol?
    private var dormant = false
    private var storedChanges: Set<NWBrowser.Result.Change> = []
    
    // Delegates
    public weak var browserDelegate: CommsBrowserDelegate?
    
    required init(mode: CommsConnectionMode, serviceID: String?, deviceName: String) {
        super.init(mode: mode, type: .client, serviceID: serviceID, deviceName: deviceName)
    }
    
    // Comms Handler Client Service handlers ========================================================================= -
    
    internal func start(playerUUID: String!, name: String!, recoveryMode: Bool, matchDeviceName: String!, matchGameUUID: String!) {
        var new: Bool = false
        
        if client == nil {
            // New client rather than re-using existing
            new = true
            if self.connectionMode != .queue {
                // Don't log start for other since it might be (probably is) the logger starting! While this works on simulator it crashes devices
                self.debugMessage("Start Client (\(self.connectionMode) \(self.serviceType))")
            }
            
            if self.connectionMode != .broadcast {
                fatalError("start(playerUUID: is only valid for broadcast mode in Nearby Connectivity")
            }
            
            super.startService(playerUUID: playerUUID, name: name, recoveryMode: recoveryMode)
        }
        
        self.matchDeviceName = matchDeviceName
        self.matchGameUUID = matchGameUUID
        
        if new {
            self.startBrowsingForPeers()
        } else {
            resumeBrowsing()
        }
    }
    
    internal func start(queue: String, filterPlayerUUID: String!) {
        fatalError("start(queue: is not valid in Multi-peer Connectivity")
    }
    
    internal func stop(suspendOnly: Bool) {
        
        self.closeConnections()
        self.endConnections()
        
        if suspendOnly {
            self.suspendBrowsing()
            
        } else {
            self.debugMessage("Stop Client (\(self.connectionMode) \(self.serviceType))")
            self.broadcastPeerList = [:]
            if self.client != nil {
                if self.client.browser != nil {
                    self.stopBrowsingForPeers()
                    self.client?.browser = nil
                }
                self.client  = nil
            }
            
            if super.started {
                self.debugMessage("Stop Client \(self.connectionMode)")
            }
            
            NetworkFrameworkClientServiceFactory.remove(client: self)
            super.stopService()
        }
    }
    
    enum SuspendBrowsingMode {
        case becomeDormant
        case stopBrowsing
    }
    
    var suspendBrowsingMode = SuspendBrowsingMode.stopBrowsing
    
    private func suspendBrowsing() {
        switch suspendBrowsingMode {
        case .becomeDormant:
            self.debugMessage("Suspend Client \(self.connectionMode)")
            self.dormant = true
            self.broadcastPeerList.forEach { $0.value.dormant = true }
        case .stopBrowsing:
            self.stopBrowsingForPeers()
        }
    }
    
    private func resumeBrowsing() {
        Utility.executeAfter(delay: 2) { [self] in
            switch suspendBrowsingMode {
            case .becomeDormant:
                // Replay any stored browser changes and become non-dormant
                self.debugMessage("Resume Client \(self.connectionMode)")
                dormant = false
                if !storedChanges.isEmpty {
                    browserPeersChanged(results: [], changes: storedChanges)
                    storedChanges.removeAll()
                }
                // Wake up any peers which are still dormant
                broadcastPeerList.filter{$0.value.dormant}.forEach { (_, broadcastPeer) in
                    self.browserPeerChanged(change: .added, broadcastPeer: broadcastPeer)
                }
            case .stopBrowsing:
                self.startBrowsingForPeers()
            }
        }
    }
    
    override internal func clearReconnect(commsPeer: CommsPeer) {
        matchDeviceName = nil
        matchGameUUID = nil
        invite = nil
        if let broadcastPeer = self.broadcastPeerList[commsPeer.deviceName] {
            broadcastPeer.shouldReconnect = false
            broadcastPeer.reconnect = false
        }
    }
    
    /// Connects to a remote device using network framework communication
    /// - parameter to: peer to connect to
    /// - parameter playerUUID: the player playerUUID who is connecting
    /// - parameter playerName: the player name who is connecting
    /// - additional context
    
    internal func connect(to commsPeer: CommsPeer, playerUUID: String?, playerName: String?, context: [String : String]?, reconnect: Bool = true) -> Bool{
        if let broadcastPeer = self.broadcastPeerList[commsPeer.deviceName] {
            self.debugMessage("Connect to ", peerID: broadcastPeer.nfPeer)
            
            // Stop browsing for other peers
            self.stopBrowsingForPeers()
            
            // Set up peer
            broadcastPeer.shouldReconnect = reconnect
            broadcastPeer.state = .connecting
            self.stateDelegate?.stateChange(for: broadcastPeer.commsPeer)
            
            // Start connection
            let connection = NWConnection(to: broadcastPeer.endpoint!, using: tcpParameters)
            self.debugMessage("Connection - peer", peerID: broadcastPeer.nfPeer)
            self._connectionRemoteDeviceName = broadcastPeer.deviceName
            self._connectionRemotePlayerUUID = broadcastPeer.playerUUID
            
            connection.stateUpdateHandler = { [self] state in
                if state == .ready {
                    self.debugMessage("Connection ready - sending connection metadata")
                    connectionState(connection: connection, peerID: broadcastPeer.nfPeer, didChangeTo: .ready)
                    sendConnectionData(connection: connection, broadcastPeer: broadcastPeer, playerUUID: playerUUID, playerName: playerName)
                    listen(connection: connection, peerID: broadcastPeer.nfPeer)
                    broadcastPeer.state = .connected
                    self.stateDelegate?.stateChange(for: broadcastPeer.commsPeer)
                }
            }
            
            // Start and save connection
            connection.start(queue: .main)
            connectionList[broadcastPeer.deviceName] = connection
                        
            return true
            
        } else {
            return false
        }
    }
    
    private func sendConnectionData(connection: NWConnection, broadcastPeer: NetworkBroadcastPeer, playerUUID: String?, playerName: String?) {
        var dictionary = ["displayName" :   myPeerID.displayName,
                          "id" :            myPeerID.id.uuidString,
                          "timestamp":      Utility.dateString(Date(), format: "YYMMDD-HHmmss.SSS", localized: false)]
        if let playerUUID = playerUUID {
            dictionary["playerUUID"] = playerUUID
        }
        if let playerName = playerName {
            dictionary["player"] = playerName
        }
        send("connectionData", dictionary, to: broadcastPeer.commsPeer)
    }
    
    internal override func reset(reason: String? = nil) {
        // Disconnect and then start looking for peers again - should reconnect automatically when find peer
        self.debugMessage("Reset connections")
        self.disconnect(reason: "Reset", reconnect: false)
        self.closeConnections()
        self.suspendBrowsing()
        Utility.executeAfter(delay: 2) {
            self.resumeBrowsing()
        }
    }
    
    internal override func suspend(reason: String? = nil) {
        // Disconnect and wait to reconnect in resume
        self.debugMessage("Suspend nearby peer browsing")
        self.disconnect(reason: "Reset", reconnect: false)
        self.closeConnections()
        self.suspendBrowsing()
    }
    
    internal override func resume(reason: String? = nil) {
        // Resume connecction
        self.debugMessage("Resume nearby peer browsing (no action)")
        self.resumeBrowsing()
    }
    
    override internal func startBrowsingForPeers() {
        let descriptor = NWBrowser.Descriptor.bonjourWithTXTRecord(type: self.serviceType, domain: nil)
        let browser = NWBrowser(for: descriptor, using: tcpParameters)
        browser.browseResultsChangedHandler = browserPeersChanged
        self.client = ClientConnection(browser: browser)
        self.client.browser.stateUpdateHandler = { [self] state in
            switch state {
                case .ready:
                self.debugMessage(("Device network stack is ready. Scanning..."), peerID: myPeerID)
            case .waiting(let error):
                self.debugMessage(("Blocked or waiting on permission payload: \(error)"), peerID: myPeerID)
            case .failed:
                connectionError()
            default:
                break
            }
        }
        self.client.browser.start(queue: .main)
    }
    
    override internal func stopBrowsingForPeers() {
        self.client?.browser?.cancel()
        self.client = nil
    }
    
    func checkOnlineInvites(playerUUID: String, checkExpiry: Bool = true, matchDeviceName: String? = nil) {
        // Not used in broadcast mode
        fatalError("Not relevant in broadcast mode")
    }
    
    // MARK: - Browser delegate handlers ===================================================== -
    
    internal func connectionError() {
        browserDelegate?.error("Unable to connect. Check that wifi is enabled")
    }
    
    internal func browserPeersChanged(results: Set<NWBrowser.Result>, changes: Set< NWBrowser.Result.Change>) {
        Utility.mainThread { [self] in
            if dormant {
                storedChanges.formUnion(changes)
            } else {
                for change in changes {
                    if let broadcastPeer = broadcastPeer(fromChange: change) {
                        browserPeerChanged(change: PeerChange(from: change), broadcastPeer: broadcastPeer)
                    }
                }
            }
        }
    }
    
    enum PeerChange {
        case added
        case removed
        case other
        
        init(from nwChange: NWBrowser.Result.Change) {
            switch nwChange {
            case .added:
                self = .added
            case .removed:
                self = .removed
            default:
                self = .other
            }
        }
    }
    
    internal func browserPeerChanged(change: PeerChange, broadcastPeer: NetworkBroadcastPeer) {
        self.debugMessage("Browser peer changed: \(change)")
        switch change {
        case .added:
            // End any pre-existing connections
            var broadcastPeer = broadcastPeer
            self.closeConnections(matchDeviceName: broadcastPeer.deviceName)
            if let existing = broadcastPeerList[broadcastPeer.deviceName] {
                existing.nfPeer = broadcastPeer.nfPeer
                existing.playerName = broadcastPeer.playerName
                existing.playerUUID = broadcastPeer.playerUUID
                existing.purpose = broadcastPeer.purpose
                existing.dormant = false
                broadcastPeer = existing
            } else {
                broadcastPeerList[broadcastPeer.deviceName] = broadcastPeer
            }
            
            // Notify delegate
            self.browserDelegate?.peerFound(peer: broadcastPeer.commsPeer, reconnect: broadcastPeer.reconnect)
            
            if Scorecard.recovery.recoveryAvailable && Scorecard.recovery.connectionRemoteDeviceName == broadcastPeer.deviceName {
                // If this is a peer we think we are connected to in recovery - reconnect
                broadcastPeer.reconnect = true
                broadcastPeer.shouldReconnect = true
            }
            
            if broadcastPeer.reconnect {
                // Auto-reconnect set - try to connect
                if !self.connect(to: broadcastPeer.commsPeer, playerUUID: self.connectionPlayerUUID, playerName: self.connectionName, reconnect: true) {
                    // Not good - shouldn't happen
                    self.debugMessage("Shouldn't happen - connect failed")
                    broadcastPeer.state = .reconnecting
                    self.stateDelegate?.stateChange(for: broadcastPeer.commsPeer)
                }
            }
        case .removed:
            if broadcastPeer.reconnect {
                if broadcastPeer.state != .reconnecting {
                    // Notify delegate since not already aware we are trying to reconnect
                    broadcastPeer.state = .reconnecting
                    self.stateDelegate?.stateChange(for: broadcastPeer.commsPeer)
                }
                self.debugMessage("Peer lost - reconnecting")
            } else {
                // Notify delegate peer lost
                broadcastPeer.state = .notConnected
                self.stateDelegate?.stateChange(for: broadcastPeer.commsPeer)
                self.browserDelegate?.peerLost(peer: broadcastPeer.commsPeer)
                self.debugMessage("Peer lost")
            }
        default:
            break
        }
    }
    
    internal func broadcastPeer(fromChange change: NWBrowser.Result.Change) -> NetworkBroadcastPeer? {
        var broadcastPeer: NetworkBroadcastPeer? = nil
        
        switch change {
        case .added(let result):
            var peerID: NFPeerID?
            var playerUUID: String?
            var gameUUID: String?
            var invite: [String]?
            var purpose: CommsPurpose?
            var playerName: String?
            
            if case let .service(name, _, _, _) = result.endpoint, name == serviceName {
                // Only consider services we're interested in
                let metadata = result.metadata
                if case let .bonjour(info) = metadata {
                    if let displayName = info["displayName"], let id = info["id"] {
                        peerID = NFPeerID(displayName: displayName, id: UUID(uuidString: id))
                    }
                    playerUUID = info["playerUUID"]
                    gameUUID = info["gameUUID"]
                    invite = info["invite"]?.components(separatedBy: ";")
                    purpose = CommsPurpose(rawValue: info["purpose"] ?? "") ?? CommsPurpose.playing
                    playerName = info["playerName"]
                }
                if peerID != nil {
                    let deviceName = peerID!.displayName
                    if deviceName != self.myPeerID.displayName {
                        // Don't show any advertisers from this device
                        if playerUUID != Scorecard.activeSettings.thisPlayerUUID {
                            // Don't show connections to this player
                            if invite == nil || invite!.isEmpty || invite?.first(where: {$0 == self.connectionPlayerUUID}) != nil {
                                // Ignore if inviting specific players that don't include this player
                                if self.matchGameUUID == nil || self.matchGameUUID! == gameUUID {
                                    // Ignore if inviting to a particular match which isn't this match
                                    broadcastPeer = NetworkBroadcastPeer(parent: self, nfPeer: peerID!, deviceName: deviceName, playerUUID: playerUUID, playerName: playerName, purpose: purpose!, endpoint: result.endpoint)
                                }
                            }
                        }
                    }
                }
            }
        case .removed(let result):
            let endpoint = result.endpoint
            if let broadcastPeer = broadcastPeerList.first(where: {$1.endpoint == endpoint})?.value {
                if broadcastPeer.reconnect {
                    if broadcastPeer.state != .reconnecting {
                        // Notify delegate since not already aware we are trying to reconnect
                        broadcastPeer.state = .reconnecting
                        self.stateDelegate?.stateChange(for: broadcastPeer.commsPeer)
                    }
                } else {
                    // Notify delegate peer lost
                    broadcastPeer.state = .notConnected
                    self.stateDelegate?.stateChange(for: broadcastPeer.commsPeer)
                    self.browserDelegate?.peerLost(peer: broadcastPeer.commsPeer)
                }
            }
        default:
            break
        }
        return broadcastPeer
    }
    
    // MARK: - Connection handlers ========================================================== -

    override internal func connectionState(connection: NWConnection, peerID: NFPeerID, didChangeTo nwState: NWConnection.State) {
        let state = commsConnectionState(nwState)
        Utility.mainThread {
            var saveBroadcastPeer: NetworkBroadcastPeer?
            
            if state == .notConnected {
                if self.client != nil && self.client.browser != nil {
                    // Lost connection (or refused connection) - save peer for later
                    saveBroadcastPeer = self.broadcastPeerList[peerID.displayName]
                }
            }
            
            super.connectionState(connection: connection, peerID: peerID, didChangeTo: nwState)
            
            // Start / stop browsing
            if state == .notConnected {
                if self.client != nil && self.client.browser != nil {
                    // Lost connection (or refused connection)
                    if let broadcastPeer = saveBroadcastPeer {
                        if self.broadcastPeerList[broadcastPeer.deviceName] == nil {
                            // Looks like peer has gone away - notify delegates
                            self.browserDelegate?.peerLost(peer: broadcastPeer.commsPeer)
                        }
                    }
                }
                
                // Need to start browsing for another peer
                self.debugMessage("Start browsing")
                self.startBrowsingForPeers()
            } else if state == .connected {
                // Connected
            }
        }
    }
    
    // MARK: - Utility Methods ======================================================================== -
    
    private func endConnections(matchDeviceName: String! = nil) {
        Utility.debugMessage("networkFramework", "End connections (\(broadcastPeerList.count))")
        for (deviceName, broadcastPeer) in broadcastPeerList {
            if matchDeviceName == nil || matchDeviceName == deviceName {
                if broadcastPeer.state == .connecting {
                    // Change back to not connected and notify
                    broadcastPeer.state = .notConnected
                    self.stateDelegate?.stateChange(for: broadcastPeer.commsPeer)
                }
            }
        }
    }
}



// Broadcast Peer Class ========================================================================= -

public class NetworkBroadcastPeer {
    
    public var nfPeer: NFPeerID        // Multi-peer peer
    public var playerUUID: String?    // Remote player playerUUID
    public var playerName: String?     // Remote playername
    public var state: CommsConnectionState
    public var purpose: CommsPurpose
    public var reason: String?
    public var reconnect: Bool = false // { didSet { Utility.debugMessage("networkFramework", "reconnect changed from \(oldValue) to \(reconnect) on \(deviceName)") }}
    public var shouldReconnect: Bool = false // { didSet { Utility.debugMessage("networkFramework", "shouldReconnect changed from \(oldValue) to \(shouldReconnect) on \(deviceName)") }}
    private var parent: NetworkFrameworkService
    public var endpoint: NWEndpoint?
    public var dormant: Bool = false
    public var deviceName: String {
        get {
            return nfPeer.displayName
        }
    }
    
    init(parent: NetworkFrameworkService, nfPeer: NFPeerID, deviceName: String, playerUUID: String? = "", playerName: String? = "", purpose: CommsPurpose, endpoint: NWEndpoint? = nil) {
        self.parent = parent
        self.nfPeer = nfPeer
        self.playerUUID = playerUUID
        self.playerName = playerName
        self.state = .notConnected
        self.purpose = purpose
        self.endpoint = endpoint
    }
    
    public var commsPeer: CommsPeer {
        get {
            return CommsPeer(parent: self.parent as CommsServiceDelegate, deviceName: self.deviceName, playerUUID: self.playerUUID, playerName: self.playerName, state: self.state, reason: self.reason, autoReconnect: self.reconnect, purpose: self.purpose)
        }
    }
}

// Packet Framer Classes ========================================================================= -


struct NFPacket {
    let descriptor: String
    let displayName: String?
    let peerId: NFPeerID?
    let dictionary: Dictionary<String,Any?>?
    
    init(descriptor:String, displayName: String? = nil, peerId: NFPeerID? = nil, dictionary: Dictionary<String, Any?>! = nil) {
        self.descriptor = descriptor
        self.displayName = displayName
        self.peerId = peerId
        self.dictionary = dictionary
    }
}

struct NFPacketFramer {
    // Converts a packet into length-prefixed binary Data
    
}

