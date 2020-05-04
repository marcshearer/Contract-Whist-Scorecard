//
//  Multipeer Class.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 31/05/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//
//  Class to implement gaming/sharing between devices using Multipeer connectivity

import Foundation
import MultipeerConnectivity

class MultipeerService: NSObject, CommsHandlerDelegate, MCSessionDelegate {
    
    // Main class variables
    public let connectionMode: CommsConnectionMode
    public let connectionProximity: CommsConnectionProximity = .nearby
    public let connectionType: CommsConnectionType
    public var connectionUUID: String?
    private var _connectionEmail: String?
    private var _connectionName: String?
    internal var _connectionDevice: String?
    internal var started = false
    public var connectionEmail: String? {
        get {
            return _connectionEmail
        }
    }
    public var connectionName: String? {
        get {
            return _connectionName
        }
    }
    public var connectionDeviceName: String? {
        get {
            return _connectionDevice
        }
    }
    public var connections: Int {
        get {
            return self.sessionList.count
        }
    }

    // Delegates
    public var stateDelegate: CommsStateDelegate!
    public var dataDelegate: CommsDataDelegate!
    public var broadcastDelegate: CommsBroadcastDelegate!

    // Other state variables
    internal var serviceID: String
    internal var sessionList: [String : MCSession] = [:]
    internal var broadcastPeerList: [String: BroadcastPeer] = [:]
    internal var myPeerID: MCPeerID
    
    init(mode: CommsConnectionMode, type: CommsConnectionType, serviceID: String?, deviceName: String) {
        self.connectionMode = mode
        self.connectionType = type
        self.serviceID = serviceID!
        self.myPeerID = MCPeerID(displayName: deviceName)
        // Create my peer ID to be consistent over time - apparently helps stability!
        var archivedPeerID = UserDefaults.standard.data(forKey: "MCPeerID")
        if archivedPeerID == nil {
            self.myPeerID = MCPeerID(displayName: Scorecard.deviceName)
            archivedPeerID = NSKeyedArchiver.archivedData(withRootObject: myPeerID)
            UserDefaults.standard.set(archivedPeerID, forKey: "MCPeerID")
            UserDefaults.standard.synchronize()
        } else {
            self.myPeerID = NSKeyedUnarchiver.unarchiveObject(with: archivedPeerID!) as! MCPeerID
        }
    }
    
    internal func startService(email: String!, name: String!, recoveryMode: Bool, matchDeviceName: String! = nil) {
        self._connectionEmail = email
        self._connectionName = name
        self.started = true
    }
    
    internal func stopService() {
        self._connectionEmail = nil
        self._connectionName = nil
        self.started = false
    }
    
    internal func endSessions(matchDeviceName: String! = nil) {
        // End all connections - or possibly just for one remote device if specified
        for (deviceName, session) in self.sessionList {
            if matchDeviceName == nil || matchDeviceName == deviceName {
                self.sessionList.removeValue(forKey: deviceName)
                endSession(session: session)
            }
        }
    }
    
    internal func endSession(session: MCSession) {
        self.debugMessage("End Session")
        session.disconnect()
        session.delegate = nil
    }
    
    internal func disconnect(from commsPeer: CommsPeer? = nil, reason: String = "", reconnect: Bool) {
        for (deviceName, _) in self.sessionList {
            if commsPeer == nil || commsPeer?.deviceName == deviceName {
                if let broadcastPeer = broadcastPeerList[deviceName] {
                    self.debugMessage("disconnect (\(reason))", peerID: broadcastPeer.mcPeer)
                    broadcastPeer.shouldReconnect = reconnect
                    broadcastPeer.reconnect = reconnect
                    broadcastPeer.state = .notConnected
                    self.stateDelegate?.stateChange(for: broadcastPeer.commsPeer, reason: reason)
                }
                self.send("disconnect", ["reason" : reason], to: commsPeer)
            }
        }
    }
    
    internal func send(_ descriptor: String, _ dictionary: Dictionary<String, Any?>! = nil, to commsPeer: CommsPeer? = nil, matchEmail: String? = nil) {
        var toDeviceName: String! = nil
        if let commsPeer = commsPeer {
            toDeviceName = commsPeer.deviceName
        }
        if descriptor != "log" {
            var content = ""
            if let dictionary = dictionary {
                content = "(\(Scorecard.serialise(dictionary)))"
            }
            self.debugMessage("Sending \(descriptor)\(content) to \(commsPeer == nil ? "all" : commsPeer!.playerName!)", device: toDeviceName)
        }
        
        let data = prepareData(descriptor, dictionary)
        if data != nil {
            
            for (deviceName, session) in self.sessionList {
                
                if toDeviceName == nil || deviceName == toDeviceName {
                    do {
                        if let broadcastPeer = broadcastPeerList[deviceName] {
                            if matchEmail == nil || (broadcastPeer.playerEmail != nil && broadcastPeer.playerEmail! == matchEmail) {
                                try session.send(data!, toPeers: [broadcastPeer.mcPeer], with: .reliable)
                            }
                        }
                    } catch {
                        // Ignore errors
                        self.debugMessage("Error sending data (\(error.localizedDescription))")
                    }
                }
            }
        }
    }
    
    private func prepareData(_ descriptor: String, _ dictionary: Dictionary<String, Any?>! = nil) -> Data? {
        let propertyList: [String : [String : Any?]?] = [descriptor : dictionary]
        var data: Data
        
        do {
            data = try JSONSerialization.data(withJSONObject: propertyList, options: .prettyPrinted)
        } catch {
            // Ignore errors
            return nil
        }
        
        return data
    }
    	
    internal func reset(reason: String? = nil) {
        // Over-ridden in client and server
    }

    internal func connectionInfo(message: String) {
        var message = message + "\n\nPeers"
        for (deviceName, peer) in self.broadcastPeerList {
            message = message + "\nDevice: \(deviceName), Player: \(peer.playerName ?? ""), \(peer.state.rawValue)\n"
        }
        
        message = message + "\nSessions"
        for (deviceName, _) in self.sessionList {
            message = message + "\nDevice: \(deviceName)\n"
        }
        
        Utility.getActiveViewController()?.alertMessage(message, title: "Multipeer Connection Info", buttonText: "Close")
    }
    
    internal func debugMessage(_ message: String, device: String? = nil, force: Bool = false) {
        var outputMessage = message
        if let device = device {
            outputMessage = outputMessage + " Device: \(device)"
        }
        Utility.debugMessage((self.serviceID == "whist-logger" ? "logger" : "multipeer"), message, force: force)
    }
    
    internal func debugMessage(_ message: String, peerID: MCPeerID?) {
        var outputMessage = message
        if let peerID = peerID {
            outputMessage = outputMessage + " Device: \(peerID.displayName)"
        }
        self.debugMessage(outputMessage, device: nil, force: false)
    }
    
    internal func startBrowsingForPeers() {
        // Overridden by client
    }

    // MARK: - Session delegate handlers ========================================================== -
    
    internal func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        debugMessage("Session change state to \((state == MCSessionState.notConnected ? "Not connected" : (state == .connected ? "Connected" : "Connecting")))", peerID: peerID)
        
        let deviceName = peerID.displayName
        if let broadcastPeer = broadcastPeerList[deviceName] {
            let currentState = broadcastPeer.state
            broadcastPeer.state = commsConnectionState(state)
            if broadcastPeer.state == .notConnected{
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
            // Not in peer list - can't carry on
            self.disconnect(from: BroadcastPeer(parent: self, mcPeer: peerID, deviceName: deviceName).commsPeer, reason: "Unexpected connection")
        }
        
        if state == .notConnected {
            // Clear session
            sessionList.removeValue(forKey: deviceName)
        } else {
            // Save session
            sessionList[deviceName] = session
        }
    }
    
    internal func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Utility.mainThread {
            do {
                let deviceName = peerID.displayName
                if let broadcastPeer = self.broadcastPeerList[deviceName] {
                    let propertyList: [String : Any?] = try JSONSerialization.jsonObject(with: data, options: []) as! [String : Any]
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
                                self.endSessions(matchDeviceName: deviceName)
                                broadcastPeer.state = .notConnected
                                if reason != "Reset" {
                                    broadcastPeer.reconnect = false
                                }
                                if self.stateDelegate != nil {
                                    self.stateDelegate?.stateChange(for: broadcastPeer.commsPeer, reason: reason)
                                }
                                // Need to restart browsing for peers
                                self.startBrowsingForPeers()
                            } else if values is NSNull {
                                self.dataDelegate?.didReceiveData(descriptor: descriptor, data: nil, from: broadcastPeer.commsPeer)
                            } else {
                                self.dataDelegate?.didReceiveData(descriptor: descriptor, data: values as! [String : Any]?, from: broadcastPeer.commsPeer)
                            }
                        }
                    }
                } else {
                    Utility.debugMessage("multipeer", "Ignoring message for \(deviceName)")
                }
            } catch {
            }
        }
    }
    
    func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
        Utility.mainThread {
            self.debugMessage("Certificate", peerID: peerID)
            certificateHandler(true)
        }
    }
    
    internal func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Not implemented
    }
    
    internal func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Not implemented
    }
    
    internal func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // Not implemented
    }
    
    // MARK: - Utility Methods ========================================================================= -
    
    private func commsConnectionState(_ state: MCSessionState) -> CommsConnectionState {
        switch state {
        case .notConnected:
            return .notConnected
        case .connecting:
            return .connecting
        case .connected:
            return .connected
        @unknown default:
            return .notConnected
        }
    }
}


// Multipeer Server Service Class ========================================================================= -

class MultipeerServerService : MultipeerService, CommsServerHandlerDelegate, MCNearbyServiceAdvertiserDelegate {
        
    private struct ServerConnection {
        var advertiser: MCNearbyServiceAdvertiser!
    }
    
    internal var handlerState: CommsServerHandlerState = .notStarted
    private var server: ServerConnection!

    // Delegates
    public weak var connectionDelegate: CommsConnectionDelegate!
    public weak var handlerStateDelegate: CommsServerHandlerStateDelegate!
    
    required init(mode: CommsConnectionMode, serviceID: String?, deviceName: String) {
        super.init(mode: mode, type: .server, serviceID: serviceID, deviceName: deviceName)
    }
    
    // MARK: - Comms Handler Server handlers ========================================================================= -
    
    internal func start(email: String!, queueUUID: String!, name: String!, invite: [String]!, recoveryMode: Bool) {
        self.debugMessage("Start Server \(self.connectionMode)")
        
        super.startService(email: email, name: name, recoveryMode: recoveryMode)
        
        var discoveryInfo: [String : String] = [:]
        discoveryInfo["playerEmail"] = email
        discoveryInfo["playerName"] = name
        
        let advertiser = MCNearbyServiceAdvertiser(peer: self.myPeerID, discoveryInfo: discoveryInfo, serviceType: self.serviceID)
        self.server = ServerConnection(advertiser: advertiser)
        self.server.advertiser.delegate = self
        self.server.advertiser.startAdvertisingPeer()
        changeState(to: .advertising)
        
    }
    
    internal func stop(completion: (()->())?) {
        if super.started {
            self.debugMessage("Stop Server \(self.connectionMode)")
        }
        
        super.stopService()
        
        self.broadcastPeerList = [:]
        if self.server != nil {
            if self.server.advertiser != nil {
                self.server.advertiser.stopAdvertisingPeer()
                self.server.advertiser.delegate = nil
                self.server.advertiser = nil
            }
            self.server = nil
        }
        self.endSessions()
        changeState(to: .notStarted)
        completion?()
    }
    
    override internal func reset(reason: String? = nil) {
        // Just disconnect and wait for client to reconnect
        self.debugMessage("Resetting")
        self.disconnect(reason: reason ?? "Reset", reconnect: true)
        self.server.advertiser.stopAdvertisingPeer()
        Utility.executeAfter(delay: 1.0) {
            self.server.advertiser.startAdvertisingPeer()
        }
    }
    
    
    // MARK: - Comms Handler State handler =================================================================== -

    internal func changeState(to state: CommsServerHandlerState) {
        self.handlerState = state
        self.handlerStateDelegate?.handlerStateChange(to: state)
    }
    
    // MARK: - Advertiser delegate handlers ======================================================== - -
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        
        Utility.mainThread {
            var playerName: String?
            var playerEmail: String?
            var timestamp: String?
            let deviceName = peerID.displayName
            var propertyList: [String : String]! = nil
            if context != nil {
                do {
                    propertyList = try JSONSerialization.jsonObject(with: context!, options: []) as? [String : String]
                } catch {
                }
                playerName = propertyList["player"]
                playerEmail = propertyList["email"]
                timestamp = propertyList["timestamp"]
            }
            
            self.debugMessage("Invitation from \(playerName ?? "unknown") (\(peerID)) @\(timestamp ?? "??")", peerID: peerID)
            
            // End any pre-existing sessions since should only have 1 connection at a time
            self.endSessions(matchDeviceName: deviceName)
            
            // Create / replace peer data
            let broadcastPeer = BroadcastPeer(parent: self, mcPeer: peerID, deviceName: deviceName, playerEmail: playerEmail, playerName: playerName)
            self.broadcastPeerList[deviceName] = broadcastPeer
            
            // Create session
            let session = MCSession(peer: self.myPeerID, securityIdentity: nil, encryptionPreference: .none)
            self.sessionList[deviceName] = session
            session.delegate = self
            
            if self.connectionDelegate != nil {
                if self.connectionDelegate.connectionReceived(from: broadcastPeer.commsPeer, info: propertyList) {
                    invitationHandler(true, session)
                    self.debugMessage("Invitiation accepted", peerID: peerID)
                }
            } else {
                invitationHandler(true, session)
                self.debugMessage("Invitiation accepted", peerID: peerID)
            }
        }
    }
}


// Multipeer Client Service Class ========================================================================= -

class MultipeerClientService : MultipeerService, CommsClientHandlerDelegate, MCNearbyServiceBrowserDelegate {
    
    private struct ClientConnection {
        var browser: MCNearbyServiceBrowser!
    }
    
    private var client: ClientConnection!
    private var matchDeviceName: String!
    private var invite: Invite!
    private var inviteEmail: String! = nil
    private var onlineInviteObserver: NSObjectProtocol?
    
    // Delegates
    public weak var browserDelegate: CommsBrowserDelegate!
    
    required init(mode: CommsConnectionMode, serviceID: String?, deviceName: String) {
        super.init(mode: mode, type: .client, serviceID: serviceID, deviceName: deviceName)
    }
    
    // Comms Handler Client Service handlers ========================================================================= -
    
    internal func start(email: String!, name: String!, recoveryMode: Bool, matchDeviceName: String!) {
        if self.connectionMode != .queue {
            // Don't log start for other since it might be (probably is) the logger starting! While this works on simulator it crashes devices
            self.debugMessage("Start Client \(self.connectionMode)")
        }
        
        if self.connectionMode != .broadcast {
            fatalError("start(email: is only valid for broadcast mode in Multi-peer Connectivity")
        }
        
        super.startService(email: email, name: name, recoveryMode: recoveryMode, matchDeviceName: matchDeviceName)
        
        let browser = MCNearbyServiceBrowser(peer: self.myPeerID, serviceType: serviceID)
        self.client = ClientConnection(browser: browser)
        self.client?.browser?.delegate = self
        self.client?.browser?.startBrowsingForPeers()
    }
    
    internal func start(queue: String, filterEmail: String!) {
        fatalError("start(queue: is not valid in Multi-peer Connectivity")
    }
    
    internal func stop() {
        if super.started {
            self.debugMessage("Stop Client \(self.connectionMode)")
        }
        
        super.stopService()
        
        self.endSessions()
        self.endConnections()
        
        self.broadcastPeerList = [:]
        if self.client != nil {
            if self.client.browser != nil {
                self.client?.browser?.stopBrowsingForPeers()
                self.client?.browser?.delegate = nil
                self.client?.browser = nil
            }
            self.client  = nil
        }
    }
    
    /// Connects to a remote device using multipeer communication
    /// - parameter to: peer to connect to
    /// - parameter playerEmail: the player email who is connecting
    /// - parameter playerName: the player name who is connecting
    /// - additional context
    
    internal func connect(to commsPeer: CommsPeer, playerEmail: String?, playerName: String?, context: [String : String]?, reconnect: Bool = true) -> Bool{
        if let broadcastPeer = self.broadcastPeerList[commsPeer.deviceName] {
            self.debugMessage("Connect to ", peerID: broadcastPeer.mcPeer)
            
            // Stop browsing for other peers
            self.client?.browser?.stopBrowsingForPeers()
            
            // Set up peer
            broadcastPeer.shouldReconnect = reconnect
            
            // Set up context data
            var data: Data! = nil
            do {
                var context = context
                if context == nil {
                    context = [:]
                }
                if let playerEmail = playerEmail {
                    context!["email"] = playerEmail
                }
                if let playerName = playerName {
                    context!["player"] = playerName
                }
                context!["timestamp"] = Utility.dateString(Date(), format: "YYMMDD-HHmmss.SSS", localized: false)
                data = try JSONSerialization.data(withJSONObject: context!, options: .prettyPrinted)
            } catch {
                Utility.getActiveViewController()?.alertMessage("Error connecting to device", title: "Error")
                return false
            }
            
            // Create session
            let session = MCSession(peer: self.myPeerID, securityIdentity: nil, encryptionPreference: .none)
            session.delegate = self
            self.sessionList[broadcastPeer.deviceName] = session
            
            // Invite server to accept connection
            let timeout = 3.0
            self.client?.browser?.invitePeer(broadcastPeer.mcPeer, to: session, withContext: data, timeout: timeout)
            self.debugMessage("Connection - peer \(broadcastPeer.mcPeer) timeout \(timeout)")
            self._connectionDevice = broadcastPeer.deviceName
            
            return true
            
        } else {
            Utility.getActiveViewController()?.alertMessage("Device not recognized", title: "Error")
            return false
        }
    }
    
    internal override func reset(reason: String? = nil) {
        // Disconnect and then start looking for peers again - should reconnect automatically when find peer
        self.debugMessage("Restart nearby peer browsing")
        self.endSessions()
        self.client?.browser?.stopBrowsingForPeers()
        self.client?.browser?.startBrowsingForPeers()
    }
    
    override internal func startBrowsingForPeers() {
        self.client?.browser?.startBrowsingForPeers()
    }
    
    func checkOnlineInvites(email: String, checkExpiry: Bool = true) {
        // Not used in broadcast mode
        fatalError("Not relevant in broadcast mode")
    }
    
    // MARK: - Browser delegate handlers ===================================================== -
    
    internal func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        browserDelegate?.error("Unable to connect. Check that wifi is enabled")
    }
    
    internal func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        Utility.mainThread {
            let deviceName = peerID.displayName
            if deviceName != self.myPeerID.displayName {
                
                self.debugMessage("Found peer \(peerID.displayName)", peerID: peerID)
                
                // End any pre-existing sessions
                self.endSessions(matchDeviceName: deviceName)
                
                var broadcastPeer = self.broadcastPeerList[deviceName]
                if broadcastPeer == nil {
                    broadcastPeer = BroadcastPeer(parent: self, mcPeer: peerID, deviceName: deviceName)
                    self.broadcastPeerList[deviceName] = broadcastPeer
                } else {
                    broadcastPeer?.mcPeer = peerID
                }
                broadcastPeer?.playerName = info?["playerName"]
                broadcastPeer?.playerEmail = info?["playerEmail"]
                
                // Notify delegate
                self.browserDelegate?.peerFound(peer: broadcastPeer!.commsPeer)
                
                if broadcastPeer!.reconnect {
                    // Auto-reconnect set - try to connect
                    if !self.connect(to: broadcastPeer!.commsPeer, playerEmail: self.connectionEmail, playerName: self.connectionName, reconnect: true) {
                        // Not good - shouldn't happen - try stopping browsing and restarting - will retry when find peer again
                        self.debugMessage("Shouldn't happen - connect failed")
                        self.client?.browser?.stopBrowsingForPeers()
                        self.client?.browser?.startBrowsingForPeers()
                        broadcastPeer!.state = .reconnecting
                        self.stateDelegate?.stateChange(for: broadcastPeer!.commsPeer)
                    }
                }
            }
        }
    }
    
    internal func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Utility.mainThread {
            let deviceName = peerID.displayName
            if deviceName != self.myPeerID.displayName {
                
                self.debugMessage("Lost peer \(peerID.displayName)", device: peerID.displayName)
                
                if let broadcastPeer = self.broadcastPeerList[deviceName] {
                    if broadcastPeer.reconnect {
                        if broadcastPeer.state != .reconnecting {
                            // Notify delegate since not already aware we are trying to reconnect
                            broadcastPeer.state = .reconnecting
                            self.stateDelegate?.stateChange(for: broadcastPeer.commsPeer)
                        }
                    } else {
                        // Notify delegate peer lost
                        self.browserDelegate?.peerLost(peer: broadcastPeer.commsPeer)
                    }
                }
            }
        }
    }
    
    // MARK: - Session delegate handlers ========================================================== -

    internal override func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Utility.mainThread {
            super.session(session, peer: peerID, didChange: state)
            
            // Start / stop browsing
            if self.client != nil && self.client.browser != nil {
                if state == .notConnected {
                    // Lost connection - need to start browsing for another one
                    self.debugMessage("Start browsing")
                    self.client?.browser?.startBrowsingForPeers()
                } else if state == .connected {
                    // Connected
                }
            }
        }
    }
    
    // MARK: - Utility Methods ======================================================================== -
    
    private func endConnections(matchDeviceName: String! = nil) {
        Utility.debugMessage("multipeer", "End connections (\(broadcastPeerList.count))")
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

public class BroadcastPeer {
    
    public var mcPeer: MCPeerID        // Multi-peer peer
    public var playerEmail: String?    // Remote player email
    public var playerName: String?     // Remote playername
    public var state: CommsConnectionState
    public var reason: String?
    public var reconnect: Bool = false
    public var shouldReconnect: Bool = false
    private var parent: MultipeerService
    public var deviceName: String {
        get {
            return mcPeer.displayName
        }
    }
    
    init(parent: MultipeerService, mcPeer: MCPeerID, deviceName: String, playerEmail: String? = "", playerName: String? = "") {
        self.parent = parent
        self.mcPeer = mcPeer
        self.playerEmail = playerEmail
        self.playerName = playerName
        self.state = .notConnected
    }
    
    public var commsPeer: CommsPeer {
        get {
            return CommsPeer(parent: self.parent as CommsHandlerDelegate, deviceName: self.deviceName, playerEmail: self.playerEmail, playerName: self.playerName, state: self.state, reason: reason, autoReconnect: reconnect)
        }
    }
    
}
