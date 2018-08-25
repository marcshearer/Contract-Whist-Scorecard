//
//  RabbitMQ Class.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 19/09/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//
//  Class to implement gaming/sharing between devices using Multipeer connectivity

import Foundation
import RMQClient

class RabbitMQService: NSObject, CommsHandlerDelegate, CommsDataDelegate, CommsConnectionDelegate, CommsStateDelegate, RabbitMQBroadcastDelegate {
    
    // Main class variables
    public let connectionMode: CommsConnectionMode = .invite
    public let connectionFramework: CommsConnectionFramework = .rabbitMQ
    public let connectionProximity: CommsConnectionProximity = .online
    public let connectionType: CommsConnectionType
    public let connectionPurpose: CommsConnectionPurpose = .playing
    private var _connectionEmail: String?
    private var _connectionDevice: String?
    private var _handlerState: CommsHandlerState = .notStarted
    public var handlerState: CommsHandlerState {
        get {
            return _handlerState
        }
    }
    public var connections: Int {
        get {
            var count = 0
            self.forEachPeer { (rabbitMQPeer) in
                if rabbitMQPeer.state == .connected {
                    count += 1
                }
            }
            return count
        }
    }
    public var connectionUUID: String? {
        get {
            return rabbitMQQueueList.first?.key
        }
    }
    public var connectionEmail: String? {
        get {
            return _connectionEmail
        }
    }
    public var connectionDevice: String? {
        get {
            return _connectionDevice
        }
    }
    
    // Delegates
    public weak var browserDelegate: CommsBrowserDelegate!
    public weak var stateDelegate: CommsStateDelegate!
    public weak var dataDelegate: CommsDataDelegate!
    public weak var connectionDelegate: CommsConnectionDelegate!
    public weak var handlerStateDelegate: CommsHandlerStateDelegate!
    
    // Other state variables
    private var rabbitMQQueueList: [String : RabbitMQQueue] = [:]           // [ queueUUID : rabbitMQQueue ]
    private let myDeviceName = Scorecard.deviceName
    private var invite: Invite!
    private var inviteEmail: String! = nil
    public var serverInviteUUID: String!
    private var onlineInviteObserver: NSObjectProtocol?
    private var recoveryMode = false
    private var matchDeviceName: String!
    
    // MARK: - Comms Handler delegate implementation ======================================================== -

    required init(purpose: CommsConnectionPurpose, type: CommsConnectionType, serviceID: String?, deviceName: String) {
        self.connectionType = type
    }
    
    public func start(email: String!, queueUUID: String!, name: String!, invite: [String]!, recoveryMode: Bool, matchDeviceName: String!) {
        _connectionEmail = email
        self.recoveryMode = recoveryMode
        self.matchDeviceName = matchDeviceName
        switch self.connectionType {
        case .server:
            self.startServer(email: email, name: name, invite: invite, serverInviteUUID: queueUUID)
        case .client:
            self.startClient(email: email)
        default:
            break
        }
    }
    
    public func stop() {
        _connectionEmail = nil
        switch self.connectionType {
        case .server:
            self.stopServer()
        case .client:
            self.stopClient()
        default:
            break
        }
    }
    
    public func reset() {
        if self.connectionType == .server || self.connectionType == .client {
            self.debugMessage("Resetting RabbitMQ")
            // Disconnect from any existing peers - they should reconnect
            self.sendReset(mode: "reset")
        }
    }
            

    
    public func connect(to commsPeer: CommsPeer, playerEmail: String?, playerName: String?, context: [String : String]? = nil, reconnect: Bool = true) -> Bool{
        var connectSuccess = false
        self.debugMessage("Connect to \(commsPeer.deviceName)")
        let deviceName = commsPeer.deviceName
        if let rabbitMQPeer = self.findRabbitMQPeer(deviceName: deviceName) {
            connectSuccess = rabbitMQPeer.connect(to : commsPeer, playerEmail: playerEmail, playerName: playerName, context: context, reconnect: reconnect)
        }
        if connectSuccess {
            self._connectionDevice = commsPeer.deviceName
        } else {
            Utility.getActiveViewController()?.alertMessage("Error connecting to device", title: "Error")
        }
        return connectSuccess
    }
    
    internal func handlerStateChange(to state: CommsHandlerState) {
        self._handlerState = state
        self.handlerStateDelegate?.handlerStateChange(to: state)
    }
    
    public func disconnect(from commsPeer: CommsPeer, reason: String = "", reconnect: Bool) {
        if let rabbitMQPeer = findRabbitMQPeer(deviceName: commsPeer.deviceName) {
            rabbitMQPeer.disconnect(reason: reason, reconnect: reconnect)
        }
    }
   
    public func send(_ descriptor: String, _ dictionary: Dictionary<String, Any?>!, to commsPeer: CommsPeer?, matchEmail: String?) {
        self.debugMessage("Send \(descriptor) to \(commsPeer == nil ? "all" : commsPeer!.deviceName)", device: commsPeer?.deviceName)
        self.forEachPeer { (rabbitMQPeer) in
            if let email = rabbitMQPeer.playerEmail {
                if matchEmail == nil || matchEmail! == email {
                    if commsPeer == nil || commsPeer!.deviceName == rabbitMQPeer.deviceName {
                        _ = rabbitMQPeer.send(descriptor:"data", dictionary: [descriptor : dictionary], to: rabbitMQPeer.commsPeer)
                    }
                }
            }
        }
    }
    
    func connectionReceived(from peer: CommsPeer, info: [String : Any?]?) -> Bool {
        if let connectionDelegate = self.connectionDelegate {
            return connectionDelegate.connectionReceived(from: peer, info: info)
        } else {
            return true
        }
    }
    
    func stateChange(for peer: CommsPeer, reason: String?) {
        self.stateDelegate?.stateChange(for: peer, reason: reason)
    }
    
    public func didReceiveBroadcast(descriptor: String, data: Any?, from queue: RabbitMQQueue) {
        // Reset received on queue - need to close any connections, re-check invitations and reconnect
        var connected = false
        if descriptor == "reset" {
            queue.forEachPeer { (rabbitMQPeer) in
                if rabbitMQPeer.state == .connected {
                    rabbitMQPeer.disconnect(reason: "Connection reset", reconnect: true)
                    connected = true
                }
            }
            if !connected {
                // Wasn't connected so reload invites
                self.checkOnlineInvites(email: self.inviteEmail, checkExpiry: !self.recoveryMode)
            }
            if let mode = data as? String {
                if mode != "stop" {
                    queue.forEachPeer { (rabbitMQPeer) in
                        if rabbitMQPeer.reconnect {
                            let playerName = Scorecard.nameFromEmail(self.inviteEmail)
                            _ = rabbitMQPeer.connect(to: rabbitMQPeer.commsPeer,
                                                 playerEmail: self.inviteEmail,
                                                 playerName: playerName,
                                                 reconnect: true)
                        }
                    }
                }
            }
        }
    }
    
    internal func didReceiveData(descriptor: String, data: [String : Any?]?, from peer: CommsPeer) {
        // Just pass it on
       let content = data as [String : Any?]?
        if self.findRabbitMQPeer(deviceName: peer.deviceName) != nil {
            dataDelegate?.didReceiveData(descriptor: descriptor, data: content, from: peer)
        }
    }
    
    public func connectionInfo() {
        var message = "Peers"
        self.forEachPeer { (rabbitMQPeer) in
            message = message + "\nDevice: \(rabbitMQPeer.deviceName), Player: \(rabbitMQPeer.playerName!), state: \(rabbitMQPeer.state), sessionUUID: \((rabbitMQPeer.sessionUUID == nil ? "nil" : rabbitMQPeer.sessionUUID!))"
        }
    
        message = message + "\nQueues"
        for (_, queue) in self.rabbitMQQueueList {
            message = message + "\nQueueUUID: \(queue.queueUUID!)\n"
        }
        
        Utility.getActiveViewController()?.alertMessage(message, title: "RabbitMQ Connection Info", buttonText: "Close")
    }
    
    internal func debugMessage(_ message: String, device: String? = nil, force: Bool = false) {
        var outputMessage = message
        if let device = device {
            outputMessage = outputMessage + " Device: \(device)"
        }
        Utility.debugMessage("rabbitMQ", outputMessage, force: force)
    }
    
    // MARK: - Queue Reset Routines ================================================================= -
    
    public class func reset(queueUUIDs: [String]) {
        // Stop and start a list of queues (to notify anyone listening on them to stop)
        let service = RabbitMQService(purpose: .other, type: CommsConnectionType.queue, serviceID: nil, deviceName: Scorecard.deviceName)
        for queueUUID in queueUUIDs {
            _ = service.startQueue(delegate: service, queueUUID: queueUUID, email: nil)
            service.sendReset(mode: "stop")
            service.stopQueue()
        }
    }
    
    // MARK: - Start/Stop Routines ================================================================= -

    private func startServer(email: String, name: String, invite: [String]?, serverInviteUUID: String! = nil) {
        self.debugMessage("Start Server \(self.connectionPurpose) \(serverInviteUUID!)")
        self.serverInviteUUID = serverInviteUUID
        if self.serverInviteUUID == nil {
            // New connection
            self.serverInviteUUID = self.rabbitMQConnectionUUID
        }
        let queue = createRabbitMQQueue(queueUUID: self.serverInviteUUID!)
        queue.messageDelegate = self
        
        if let invite = invite {
            // Need to send invitations
            self.invite = Invite()
            self.invite.sendInvitation(from: email,
                                       withName: name,
                                       to: invite,
                                       inviteUUID: self.serverInviteUUID,
                                       completion: self.sendInvitationCompletion)
            self.inviteEmail = email
        }
        if  self.recoveryMode {
            // Reconnecting to old connection
            self.handlerStateChange(to: .reconnecting)
            // Send a reset for any other devices already listening
            self.sendReset(mode: "start")
        } else {
            self.handlerStateChange(to: .inviting)
        }
    }
    
    internal func sendInvitationCompletion(_ success: Bool, _ message: String?, _ invited: [InviteReceived]?) {
        if success {
            self.handlerStateChange(to: .invited)
        } else {
            self.handlerStateChange(to: .notStarted)
        }
    }
    
    private func stopServer() {
        self.debugMessage("Stop Server \(self.connectionPurpose)")
        if let from = self.inviteEmail {
            // Invitation sent - cancel it
            self.invite = Invite()
            self.invite.cancelInvitation(from: from, completion: self.cancelInvitationCompletion)
        } else {
            self.stopServerEnd()
        }
    }
    
    internal func cancelInvitationCompletion(_ success: Bool, _ message: String?, _ invited: [InviteReceived]?) {
        self.stopServerEnd()
    }
    
    private func stopServerEnd() {
        // Disconnecting queues will disconnect all peers
        self.sendReset(mode: "stop")
        for (deviceName, queue) in self.rabbitMQQueueList {
            queue.disconnect()
            rabbitMQQueueList[deviceName] = nil
        }
        self.rabbitMQQueueList = [:]
        self.handlerStateChange(to: .notStarted)
    }
    
    private func startClient(email: String! = nil) {
        self.debugMessage("Start Client \(self.connectionPurpose)")
        // Set observer to handle online invitation notification
        self.clearOnlineInviteNotifications(observer: self.onlineInviteObserver)
        self.onlineInviteObserver = self.onlineInviteNotification()
        // Check current invites
        self.checkOnlineInvites(email: email, checkExpiry: !self.recoveryMode)
        // Notify state change
        self.handlerStateChange(to: .browsing)
    }
    
    private func stopClient() {
        // Disconnecting queues will disconnect all peers
        self.debugMessage("Stop Client \(self.connectionPurpose)")
        // Disable observer
        self.clearOnlineInviteNotifications(observer: self.onlineInviteObserver)
        // Disconnect peers
        for (deviceName, queue) in self.rabbitMQQueueList {
            queue.disconnect()
            rabbitMQQueueList[deviceName] = nil
        }
        // Remove queue from list - hence closing it
        self.rabbitMQQueueList = [:]
        self.handlerStateChange(to: .notStarted)
    }
    
    public func startQueue(delegate: RabbitMQBroadcastDelegate, queueUUID: String, email: String! = nil) -> RabbitMQQueue {
        // Start a simple queue which will filter incoming messages (optionally) by email
        self.debugMessage("Start Queue")
        let queue = createRabbitMQQueue(queueUUID: queueUUID, filterEmail: email)
        queue.messageDelegate = delegate
        return queue
    }
    
    private func stopQueue() {
        // Disconnecting queues will disconnect all peers
        self.debugMessage("Stop Queue")
        self.rabbitMQQueueList = [:]
    }
    
    // MARK: - Online Invites ========================================================================== -
    
    private func checkOnlineInvites(email: String, checkExpiry: Bool = true) {
        self.inviteEmail = email
        self.invite = Invite()
        self.invite.checkInvitations(to: self.inviteEmail, checkExpiry: checkExpiry, completion: self.checkInvitationsCompletion)
    }
    
    internal func checkInvitationsCompletion(_ success: Bool, _ message: String?, _ invited: [InviteReceived]?) {
        // Response to check for invitations in client
        if !success {
            // Error - need to remove all peers
            self.stopClient()
        } else {
            // Update / create any new peers
            if let invited = invited {
                for invite in invited {
                    if !self.recoveryMode || invite.deviceName == self.matchDeviceName {
                        // Only accept peers who match the match device name if recovering
                        var peerFound = false
                        var rabbitMQPeer: RabbitMQPeer!
                        rabbitMQPeer = findRabbitMQPeer(deviceName: invite.deviceName)
                        if rabbitMQPeer != nil {
                            // We already have this peer in the list - check if anything has changed
                            if rabbitMQPeer.playerEmail != invite.email || rabbitMQPeer.playerName != invite.name || rabbitMQPeer.queueUUID != invite.inviteUUID {
                                // Notify delegate have lost old peer
                                self.browserDelegate?.peerLost(peer: rabbitMQPeer.commsPeer)
                                // Now update peer and notify delegate
                                rabbitMQPeer.playerEmail = invite.email
                                rabbitMQPeer.playerName = invite.name
                                if rabbitMQPeer.queueUUID != invite.inviteUUID {
                                    rabbitMQPeer.detach()
                                    let queue = self.createRabbitMQQueue(queueUUID: invite.inviteUUID)
                                    rabbitMQPeer.attach(queue)
                                }
                                peerFound = true
                            }
                        } else {
                            // New peer - add to our list and notify delegate
                            let queue = self.createRabbitMQQueue(queueUUID: invite.inviteUUID)
                            rabbitMQPeer = RabbitMQPeer(from: self, queue: queue, deviceName: invite.deviceName, playerEmail: invite.email, playerName: invite.name, shouldReconnect: true)
                            peerFound = true
                            
                        }
                        if peerFound {
                            // Notify delegate
                            self.browserDelegate?.peerFound(peer: rabbitMQPeer.commsPeer)
                            // Auto-reconnect if reconnect flag is set or recovering
                            if rabbitMQPeer.reconnect || self.recoveryMode {
                                let playerName = Scorecard.nameFromEmail(self.inviteEmail)
                                _ = self.connect(to: rabbitMQPeer.commsPeer,
                                                 playerEmail: self.inviteEmail,
                                                 playerName: playerName,
                                                 reconnect: true)
                            }
                        }
                    }
                }
                
                // Remove any peers no longer in invite
                    self.forEachPeer { (rabbitMQPeer) in
                    if invited.index(where: { $0.deviceName == rabbitMQPeer.deviceName }) == nil {
                        // Not in new list - close and delete
                        self.browserDelegate?.peerLost(peer: rabbitMQPeer.commsPeer)
                        rabbitMQPeer.disconnect()
                        rabbitMQPeer.detach()
                    }
                }
            }
        }
    }
    
    private func onlineInviteNotification() -> NSObjectProtocol? {
        // Add new observer
        let observer = NotificationCenter.default.addObserver(forName: .onlineInviteReceived, object: nil, queue: nil) {
            (notification) in
            // Refresh online games - give iCloud a second to catch up!
            Utility.executeAfter(delay: 2, completion: { [unowned self] in
                self.debugMessage("Notification received")
                self.checkOnlineInvites(email: self.inviteEmail)
            })
        }
        return observer
    }
    
    private func clearOnlineInviteNotifications(observer: NSObjectProtocol?) {
        if observer != nil {
            // Remove any previous notification handler
            NotificationCenter.default.removeObserver(observer!)
        }
    }
    
    // MARK: - Utility Routines ================================================================ -
    
    private func sendReset(mode: String) {
        for (_, queue) in self.rabbitMQQueueList {
            queue.sendBroadcast(data: ["reset" : mode])
        }
    }
    
    private func findRabbitMQPeer(deviceName: String) -> RabbitMQPeer? {
        var rabbitMQPeer: RabbitMQPeer?
        
        for (_, queue) in self.rabbitMQQueueList {
            rabbitMQPeer = queue.findPeer(deviceName: deviceName)
            if rabbitMQPeer != nil {
                break
            }
        }
        return rabbitMQPeer
    }
    
    private func forEachPeer(do execute: (RabbitMQPeer)->()) {
        for (_, queue) in rabbitMQQueueList {
            queue.forEachPeer { (rabbitMQPeer) in
                execute(rabbitMQPeer)
            }
        }
    }
    
    private func createRabbitMQQueue(queueUUID: String, filterEmail: String? = nil) -> RabbitMQQueue {
        if self.rabbitMQQueueList[queueUUID] == nil {
            self.rabbitMQQueueList[queueUUID] = RabbitMQQueue(from: self, queueUUID: queueUUID, filterBroadcast: filterEmail)
            self.rabbitMQQueueList[queueUUID]?.messageDelegate = self
        }
        return self.rabbitMQQueueList[queueUUID]!
    }
    
    public var rabbitMQConnectionUUID: String {
        get {
            if Config.debugNoICloudOnline {
                return Config.debugNoICloudOnline_QueueUUID
            } else {
                return Scorecard.descriptiveUUID("queue")
            }
        }
    }
}

// MARK: RabbitMQQueue Class ==========================================================

public protocol RabbitMQBroadcastDelegate : class {
    func didReceiveBroadcast(descriptor: String, data: Any?, from queue: RabbitMQQueue)
}

public class RabbitMQQueue: NSObject, RMQConnectionDelegate {
    
    private weak var connection: RMQConnection!
    private weak var channel: RMQChannel!
    private weak var queue: RMQQueue!
    private weak var exchange: RMQExchange!
    private var rabbitMQUri: String = Config.rabbitMQUri
    private weak var parent: RabbitMQService!
    private let myDeviceName = Scorecard.deviceName
    private let filterBroadcast: String!

    private var rabbitMQPeerList: [String: RabbitMQPeer] = [:]               // [deviceName: RabbitMQPeer]
    private var connectionDelegate: [String : CommsConnectionDelegate] = [:] // [deviceName : CommsConnectionDelegate]
    private var dataDelegate: [String : CommsDataDelegate?] = [:]            // [deviceName : CommsDataDelegate]
    public weak var messageDelegate: RabbitMQBroadcastDelegate?
 
    private var _queueUUID: String!
    public var queueUUID: String! {
        get {
            return _queueUUID
        }
    }
    
    init(from parent: RabbitMQService, queueUUID: String, filterBroadcast: String! = nil) {
        self.parent = parent
        self.filterBroadcast = filterBroadcast
        self._queueUUID = queueUUID
        super.init()
        self.connection = RMQConnection(uri: self.rabbitMQUri, delegate: self)
        connection.start()
        self.channel = self.connection.createChannel()
        self.queue = self.channel.queue("", options: .exclusive)
        self.exchange = self.channel.fanout(queueUUID)
        self.queue.bind(self.exchange)
        self.queue.subscribe({ [weak self] (_ message: RMQMessage) -> Void in
            Utility.mainThread {
                self?.didReceiveData(message.body)
            }
        })
    }
    
    public func disconnect() {
        for (deviceName, rabbitMQPeer) in self.rabbitMQPeerList {
            rabbitMQPeer.disconnect()
            rabbitMQPeer.detach()
            rabbitMQPeerList[deviceName] = nil
        }
        self.queue.unbind(self.exchange)
        self.connection.close()
        self.queue.subscribe(nil)
        self.queue = nil
        self.exchange = nil
        self.channel = nil
        self.connection = nil
        self.messageDelegate = nil
        self.connectionDelegate = [:]
        self.dataDelegate = [:]
        self.rabbitMQPeerList = [:]
    }
    
    public func attach(from rabbitMQPeer: RabbitMQPeer) {
        // Set up delegates
        self.dataDelegate[rabbitMQPeer.deviceName] = rabbitMQPeer
        self.connectionDelegate[rabbitMQPeer.deviceName] = rabbitMQPeer
        // Add to list of peers
        self.rabbitMQPeerList[rabbitMQPeer.deviceName] = rabbitMQPeer
    }
    
    public func detach(from rabbitMQPeer: RabbitMQPeer) {
        self.dataDelegate[rabbitMQPeer.deviceName] = nil
        self.connectionDelegate[rabbitMQPeer.deviceName] = nil
        self.rabbitMQPeerList[rabbitMQPeer.deviceName] = nil
    }
    
    public func sendBroadcast(data: Any? = nil, filterBroadcast: String! = nil) {
        let propertyList: [String : Any?] = ["type" : "broadcast",
                                             "filter" : filterBroadcast,
                                             "fromDeviceName" : self.myDeviceName,
                                             "content" : data]
        do {
            let data: Data? = try JSONSerialization.data(withJSONObject: propertyList, options: .prettyPrinted)
            self.publish(data)
        } catch {
        }
    }
    
    public func publish(_ data: Data!) {
        self.exchange.publish(data)
    }
    
    private func didReceiveData(_ data: Data) {
        Utility.mainThread {
            do {
                let propertyList: [String : Any?] = try JSONSerialization.jsonObject(with: data, options: []) as! [String : Any]
                if let type = propertyList["type"] as! String? {
                    if let fromDeviceName = propertyList["fromDeviceName"] as! String? {
                        switch type {
                        case "connectRequest":
                            if self.parent.connectionType == .server {
                                // Connections only accepted by servers
                                var rabbitMQPeer: RabbitMQPeer!
                                rabbitMQPeer = self.rabbitMQPeerList[fromDeviceName]
                                if rabbitMQPeer == nil {
                                        // No such peer - need to create it
                                    rabbitMQPeer = RabbitMQPeer(from: self.parent, queue: self, deviceName: fromDeviceName)
                                    self.rabbitMQPeerList[fromDeviceName] = rabbitMQPeer
                                }
                                // Now pass it through to peer delegate
                                _ = self.connectionDelegate[fromDeviceName]?.connectionReceived(
                                        from: rabbitMQPeer!.commsPeer,
                                        info: propertyList["content"] as? [String : Any?])
                            }
                        case "broadcast":
                            // Broadcast on queue - not necessarily connected
                            if self.parent != nil && (self.parent.connectionType == .client || (self.parent.connectionType == .queue  && self.messageDelegate != nil)) {
                                var filterOk = true
                                if self.filterBroadcast != nil {
                                    let messageFilter = propertyList["filter"] as! String?
                                    if messageFilter == nil || messageFilter != self.filterBroadcast {
                                        filterOk = false
                                    }
                                }
                                if filterOk {
                                    if let content = propertyList["content"] as? [String : Any?] {
                                        for (descriptor, data) in content {
                                            self.messageDelegate?.didReceiveBroadcast(descriptor: descriptor, data: data as Any, from: self)
                                        }
                                    }
                                }
                            }
                        default:
                            if self.dataDelegate[fromDeviceName] != nil {
                                if let rabbitMQPeer = self.rabbitMQPeerList[fromDeviceName] {
                                    // Pass anything else up to peer
                                    self.dataDelegate[fromDeviceName]??.didReceiveData(descriptor: type,
                                                                                       data: propertyList,
                                                                                       from: rabbitMQPeer.commsPeer)
                                }
                            }
                        }
                    }
                }
            } catch {
                // Ignore errors
            }
        }
    }
    
    public func forEachPeer(do execute: (RabbitMQPeer)->()) {
        for (_, rabbitMQPeer) in rabbitMQPeerList {
            execute(rabbitMQPeer)
        }
    }
    
    public func findPeer(deviceName: String) -> RabbitMQPeer? {
        return self.rabbitMQPeerList[deviceName]
    }
    
    // MARK: - RMQConnectionDelegate Handlers ========================================================================== -

    public func connection(_ connection: RMQConnection!, failedToConnectWithError error: Error!) {
        self.parent?.debugMessage("Failed to connect with error - \(error.localizedDescription)")
    }
    
    public func connection(_ connection: RMQConnection!, disconnectedWithError error: Error!) {
        self.parent?.debugMessage("Disconnected with error - \(error.localizedDescription)")
    }
    
    public func channel(_ channel: RMQChannel!, error: Error!) {
        if error != nil {
            self.parent?.debugMessage("Channel with error - \(error.localizedDescription)")
        }
    }
    
    
    public func willStartRecovery(with connection: RMQConnection!) {
        self.parent?.debugMessage("Will start recovery")
    }
    
    public func startingRecovery(with connection: RMQConnection!) {
        self.parent?.debugMessage("Starting recovery")
    }
    
    public func recoveredConnection(_ connection: RMQConnection!) {
        self.parent?.debugMessage("Recovered")
        // Disconnect any remotes and let them reconnect to get things back in sync?
    }
    
}

// MARK: RabbitMQPeer Class ==========================================================

public class RabbitMQPeer: NSObject, CommsDataDelegate, CommsConnectionDelegate {
    private weak var parent: RabbitMQService!
    public var playerEmail: String?
    public var playerName: String?
    public var state: CommsConnectionState
    public var reason: String?
    public var reconnect = false
    public var shouldReconnect = false
    public var deviceName: String
    public weak var queue: RabbitMQQueue!
    public var sessionUUID: String!
    private let myDeviceName = Scorecard.deviceName
    
    public weak var connectionDelegate: CommsConnectionDelegate!
    public weak var stateDelegate: CommsStateDelegate!
    public weak var dataDelegate: CommsDataDelegate!

    init(from parent: RabbitMQService, queue: RabbitMQQueue, deviceName: String, playerEmail: String? = "", playerName: String? = "", shouldReconnect: Bool = false) {
        self.parent = parent
        self.deviceName = deviceName
        self.playerEmail = playerEmail
        self.playerName = playerName
        self.shouldReconnect = shouldReconnect
        self.state = .notConnected
        self.reason = nil
        // Set up delegates
        self.connectionDelegate = parent
        self.stateDelegate = parent
        self.dataDelegate = parent
        super.init()
        self.attach(queue)
    }
    
    deinit {
        if self.state == .connected {
            // Pass down disconect
            self.state = .notConnected
            self.stateDelegate.stateChange(for: self.commsPeer, reason: nil)
            // Send disconnect remote
            self.disconnect(reason: "Connection lost")
        }
    }
    
    func attach(_ queue: RabbitMQQueue) {
        self.queue = queue
        self.queue.attach(from: self)
    }
    
    func detach() {
        self.queue.detach(from: self)
        self.queue = nil
    }
    
    public var commsPeer: CommsPeer {
        get {
            return CommsPeer(parent: self.parent as CommsHandlerDelegate, deviceName: self.deviceName, playerEmail: self.playerEmail, playerName: self.playerName, state: self.state, reason: self.reason)
        }
    }
    
    public var queueUUID: String! {
        get {
            return self.queue.queueUUID
        }
    }
    
    public func connect(to peer: CommsPeer, playerEmail: String?, playerName: String?, context: [String : String]? = nil, reconnect: Bool = true) -> Bool{
        var connectSuccess = false
         // Clear any existing connections
        self.disconnect(reason: "Re-connecting")
        // Allocate a session UUID and store details
        self.sessionUUID = self.rabbitMQSessionUUID
        self.playerEmail = playerEmail
        self.playerName = playerName
        self.shouldReconnect = reconnect
        self.reconnect = false
        if let playerName = playerName {
            var dictionary = context
            if dictionary == nil {
                dictionary = [:]
            }
            dictionary!["sessionUUID"] = sessionUUID
            dictionary!["playerEmail"] = playerEmail
            dictionary!["playerName"] = playerName
            if self.publishMessage(descriptor: "connectRequest",
                                   matchSessionUUIDs: [sessionUUID],
                                   dictionary: dictionary) {
                // Update state
                self.state = .connecting
                self.stateDelegate?.stateChange(for: self.commsPeer)
                connectSuccess = true
            }
        }
        return connectSuccess
    }
    
    public func connectionReceived(from peer: CommsPeer, info: [String : Any?]?) -> Bool {
        // Only servers should accept connections
        var oldState = self.state
        var connectSuccess = false
        if self.parent.connectionType == .server {
            if let content = info {
                if let sessionUUID = content["sessionUUID"] as? String {
                    self.parent.debugMessage("Connection from \(peer.deviceName), UUID: \(String(describing: sessionUUID))")
                    
                    // New connection - close any previous session for this device and create a new one
                    if self.state == .connected {
                        self.state = .notConnected
                        self.stateDelegate.stateChange(for: self.commsPeer, reason: "New connection received")
                        oldState = .notConnected
                    }
                    
                    // Update peer details
                    self.deviceName = peer.deviceName
                    self.sessionUUID = sessionUUID
                    self.playerEmail = content["playerEmail"] as? String
                    self.playerName = content["playerName"] as? String
                    self.reconnect = self.shouldReconnect
                    
                    // Call connection delegate if it exists - otherwise OK
                    if let connectionDelegate = self.connectionDelegate {
                        if connectionDelegate.connectionReceived(from: self.commsPeer, info: info) {
                            // Send positive response
                            self.parent.debugMessage("Sending connectResponse to \(self.commsPeer.deviceName)")
                            self.state = .connected
                            if self.send(descriptor:"connectResponse", dictionary: ["success" : true], to: self.commsPeer) {
                                connectSuccess = true
                            } else {
                                self.state = .notConnected
                            }
                        }
                    }
                    if !connectSuccess {
                        // Send negative response
                        _ = self.send(descriptor:"connectResponse", dictionary: ["success" : false], to: self.commsPeer)
                    }
                }
            }
        }
        if self.state != oldState {
            // Pass up any state change
            stateDelegate?.stateChange(for: self.commsPeer, reason: reason)
        }
        return connectSuccess
    }
    
    public func disconnect(reason: String = "", reconnect: Bool = false) {
        if self.state == .connected {
            self.reconnect = reconnect
            self.shouldReconnect = reconnect
            _ = self.send(descriptor:"disconnect", dictionary: ["reason" : reason], to: self.commsPeer)
        }
    }
    
    public func send(descriptor:String, dictionary: Dictionary<String, Any?>! = nil, to commsPeer: CommsPeer! = nil) -> Bool {
        if commsPeer.state == .connected {
            _ = self.publishMessage(descriptor: descriptor, matchSessionUUIDs: [self.sessionUUID], dictionary: dictionary)
        }
        return true
    }
    
    private func publishMessage(descriptor: String, matchSessionUUIDs: [String], dictionary: Dictionary<String, Any?>! = nil) -> Bool {
        do {
            let propertyList: [String : Any?] = ["type" : descriptor,
                                                 "fromDeviceName" : self.myDeviceName,
                                                 "matchSessionUUIDs": matchSessionUUIDs,
                                                 "content" : dictionary]
            let data: Data? = try JSONSerialization.data(withJSONObject: propertyList, options: .prettyPrinted)
            self.publish(data)
            return true
        } catch {
            return false
        }
    }
    
    public func publish(_ data: Data!) {
        self.queue?.publish(data)
    }
    
    public func didReceiveData(descriptor: String, data: [String : Any?]?, from peer: CommsPeer) {
        // Check its for this session
        let oldState = self.state
        var reason: String?
        if let data = data {
            if let matchSessionUUIDs = data["matchSessionUUIDs"] as! [String]? {
                if matchSessionUUIDs.index(where: { $0 == self.sessionUUID}) != nil {
                     // Process message
                    switch descriptor {
                    case "connectResponse":
                        let content = data["content"] as! [String : Any?]
                        var success = false
                        if let successValue = content["success"] as! Bool? {
                            success = successValue
                        }
                        if success {
                            self.state = .connected
                        } else {
                            self.state = .notConnected
                        }
                    case "disconnect":
                        let content = data["content"] as! [String : String]
                        reason = content["reason"]
                        self.reason = reason
                        self.state = .notConnected
                    case "data":
                        let content = data["content"] as! [String : Any?]
                        for (descriptor, values) in content {
                            if values is NSNull {
                                self.dataDelegate?.didReceiveData(descriptor: descriptor, data: nil, from: self.commsPeer)
                            } else {
                                self.dataDelegate?.didReceiveData(descriptor: descriptor, data: values as! [String : Any]?, from: self.commsPeer)
                            }
                        }
                    default:
                        break
                    }
                }
            }
        }
        if self.state != oldState {
            // Pass up any state change
            stateDelegate?.stateChange(for: self.commsPeer, reason: reason)
        }
    }
    
    public var rabbitMQSessionUUID: String {
        get {
            return Scorecard.descriptiveUUID("session")
        }
    }
}

// MARK: - Utility Classes ======================================================================== -

extension Notification.Name {
    static let onlineInviteReceived = Notification.Name("onlineInviteReceived")
}


