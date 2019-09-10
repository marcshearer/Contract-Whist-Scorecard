//
//  RabbitMQ Class.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 19/09/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//
//  Class to implement gaming/sharing between devices using RabbitMQ connectivity

import Foundation
import RMQClient

// RabbitMQ Base Service Class ========================================================================= -

class RabbitMQService: NSObject, CommsHandlerDelegate, CommsDataDelegate, CommsStateDelegate {
    
    // Main class variables
    public let connectionMode: CommsConnectionMode = .invite
    public let connectionFramework: CommsConnectionFramework = .rabbitMQ
    public let connectionProximity: CommsConnectionProximity = .online
    public let connectionType: CommsConnectionType
    public let connectionPurpose: CommsConnectionPurpose = .playing
    private var _connectionEmail: String?
    internal var _connectionDevice: String?
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
    public weak var stateDelegate: CommsStateDelegate!
    public weak var dataDelegate: CommsDataDelegate!
    
    // Other state variables
    internal var rabbitMQQueueList: [String : RabbitMQQueue] = [:]           // [ queueUUID : rabbitMQQueue ]
    private let myDeviceName = Scorecard.deviceName
    internal var recoveryMode = false
    private static let reachabilty = Reachability(uri: (NSURL(string: Config.rabbitMQUri)?.host)!)
    private var observer: NSObjectProtocol?
    
    // MARK: - Comms Handler delegate implementation ======================================================== -

    init(purpose: CommsConnectionPurpose, type: CommsConnectionType, serviceID: String?, deviceName: String) {
        self.connectionType = type
    }
    
    internal func startService(email: String!, recoveryMode: Bool, matchDeviceName: String! = nil) {
        self._connectionEmail = email
        self.recoveryMode = recoveryMode
        self.observer = Reachability.startMonitor { (reachable) in
            self.forEachPeer { (rabbitMQPeer) in
                if rabbitMQPeer.state == .recovering && reachable {
                    rabbitMQPeer.stateChange(state: .connected, reason: "Network restored")
                } else if rabbitMQPeer.state == .connected && !reachable {
                    rabbitMQPeer.stateChange(state: .recovering, reason: "Network lost")
                }
            }
        }
    }
    
    internal func stopService() {
        self._connectionEmail = nil
        if let observer = self.observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    public func disconnect(from commsPeer: CommsPeer? = nil, reason: String = "", reconnect: Bool) {
        self.forEachPeer { (rabbitMQPeer) in
            if commsPeer == nil || commsPeer?.deviceName == rabbitMQPeer.deviceName {
                rabbitMQPeer.disconnect(reason: reason, reconnect: reconnect, reflectStateChange: true)
            }
        }
    }
   
    internal func send(_ descriptor: String, _ dictionary: Dictionary<String, Any?>!, to commsPeer: CommsPeer?, matchEmail: String?) {
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
    
    internal func stateChange(for peer: CommsPeer, reason: String?) {
        self.stateDelegate?.stateChange(for: peer, reason: reason)
    }
    
    internal func didReceiveData(descriptor: String, data: [String : Any?]?, from peer: CommsPeer) {
        // Just pass it on
       let content = data as [String : Any?]?
        if self.findRabbitMQPeer(deviceName: peer.deviceName) != nil {
            dataDelegate?.didReceiveData(descriptor: descriptor, data: content, from: peer)
        }
    }
    
    internal func reset(reason: String? = nil) {
        // Note - overridden in client service - just disconnect and wait for client to reconnect
        self.debugMessage("Resetting")
        self.disconnect(reason: reason ?? "Reset", reconnect: true)
    }
    
    internal func connectionInfo(message: String) {
        var message = message + "\n\nPeers"
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
    
    internal func restartBrowser() {
        // Dummy routine which isn't relevant in invite mode
    }
    
    // MARK: - Queue Start/Stop Routines ================================================================= -
    
    internal func startQueue(delegate: RabbitMQBroadcastDelegate! = nil, queueUUID: String, email: String! = nil) -> RabbitMQQueue {
        // Start a simple queue which will filter incoming messages (optionally) by email
        self.debugMessage("Start Queue")
        let queue = createRabbitMQQueue(queueUUID: queueUUID, filterEmail: email)
        queue.messageDelegate = delegate
        return queue
    }
    
    internal func stopQueue(queueUUID: String) {
        // Disconnecting queue will disconnect all peers
        self.debugMessage("Stop Queue")
        if let queue = self.rabbitMQQueueList[queueUUID] {
            self.debugMessage("Stopping queue \(queue.queueUUID!)")
            queue.disconnect()
        }
        self.rabbitMQQueueList[queueUUID] = nil
    }
    
    // MARK: - Utility Routines ================================================================ -
    
    fileprivate func findRabbitMQPeer(deviceName: String) -> RabbitMQPeer? {
        var rabbitMQPeer: RabbitMQPeer?
        
        for (_, queue) in self.rabbitMQQueueList {
            rabbitMQPeer = queue.findPeer(deviceName: deviceName)
            if rabbitMQPeer != nil {
                break
            }
        }
        return rabbitMQPeer
    }
    
    fileprivate func forEachQueue(do execute: (RabbitMQQueue)->()) {
        for (_, rabbitMQQueue) in rabbitMQQueueList {
            execute(rabbitMQQueue)
        }
    }
    
    fileprivate func forEachPeer(do execute: (RabbitMQPeer)->()) {
        forEachQueue { (rabbitMQQueue) in
            rabbitMQQueue.forEachPeer { (rabbitMQPeer) in
                execute(rabbitMQPeer)
            }
        }
    }
    
    internal func createRabbitMQQueue(queueUUID: String, filterEmail: String? = nil, messageDelegate: RabbitMQBroadcastDelegate! = nil) -> RabbitMQQueue {
        if self.rabbitMQQueueList[queueUUID] == nil {
            self.rabbitMQQueueList[queueUUID] = RabbitMQQueue(from: self, queueUUID: queueUUID, filterBroadcast: filterEmail)
        }
        self.rabbitMQQueueList[queueUUID]?.messageDelegate = messageDelegate
        return self.rabbitMQQueueList[queueUUID]!
    }
    
    internal var rabbitMQConnectionUUID: String {
        get {
            if Config.debugNoICloudOnline {
                return Config.debugNoICloudOnline_QueueUUID
            } else {
                return Scorecard.descriptiveUUID("queue")
            }
        }
    }
}


// RabbitMQ Server Service Class ========================================================================= -

class RabbitMQServerService : RabbitMQService, CommsServerHandlerDelegate, CommsConnectionDelegate, CommsHandlerStateDelegate {

    private var invite: Invite!
    private var inviteEmail: String! = nil
    public var serverInviteUUID: String!
 
    // Delegates
    public weak var connectionDelegate: CommsConnectionDelegate!
    public weak var handlerStateDelegate: CommsHandlerStateDelegate!

    private var _handlerState: CommsHandlerState = .notStarted
    public var handlerState: CommsHandlerState {
        get {
            return _handlerState
        }
    }

    required init(purpose: CommsConnectionPurpose, serviceID: String?, deviceName: String) {
        super.init(purpose: purpose, type: .server, serviceID: serviceID, deviceName: deviceName)
    }
    
    // MARK: - Comms Handler Server handlers ========================================================================= -
    
    internal func start(email: String!, queueUUID: String!, name: String!, invite: [String]!, recoveryMode: Bool) {
        self.debugMessage("Start Server \(self.connectionPurpose) \(serverInviteUUID ?? "")")
        
        super.startService(email: email, recoveryMode: recoveryMode)
        
        self.serverInviteUUID = queueUUID
        if self.serverInviteUUID == nil {
            // New connection
            self.serverInviteUUID = self.rabbitMQConnectionUUID
        }
        
        let queue = createRabbitMQQueue(queueUUID: self.serverInviteUUID!)
        
        for email in invite {
            // Create a dummy peer for each invitee indexed by email (instead of device) - allows us to pass back connection recovery info
            let rabbitMQPeer = RabbitMQPeer(from: self, queue: queue, deviceName: email, playerEmail: email, playerName: name)
            // Simulate a receive
            _ = self.connectionDelegate?.connectionReceived(from: rabbitMQPeer.commsPeer)
        }
        
        // Send (re-send) invitations
        self.sendInvitation(email: email, name: name, invite: invite)
        
        if !self.recoveryMode {
            // New connection
            self.handlerStateChange(to: .inviting)
            self.sendReset(mode: "recover")
        } else {
            // Reconnecting to old connection
            self.handlerStateChange(to: .reconnecting)
            // Send a reset for any other devices already listening
            self.sendReset(mode: "start")
        }
    }
    
    private func sendInvitation(email: String!, name: String!, invite: [String]!) {
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
    }
    
    internal func sendInvitationCompletion(_ success: Bool, _ message: String?, _ invited: [InviteReceived]?) {
        if success {
            self.handlerStateChange(to: .invited)
        } else {
            self.handlerStateChange(to: .notStarted)
        }
    }
    
    internal func stop(completion: (()->())?) {
        self.debugMessage("Stop Server \(self.connectionPurpose)")
        
        func cancelInvitationCompletion(_ success: Bool, _ message: String?, _ invited: [InviteReceived]?) {
            self.debugMessage("Invitation cancelled")
            self.stopServerEnd()
            completion?()
        }
        
        super.stopService()
        
        if let from = self.inviteEmail {
            // Invitation sent - cancel it
            self.invite = Invite()
            self.invite.cancelInvitation(from: from, completion: cancelInvitationCompletion)
        } else {
            self.stopServerEnd()
            completion?()
        }
    }
    
    // MARK: - Comms Connection handlers ===================================================================== -
    
    internal func connectionReceived(from peer: CommsPeer, info: [String : Any?]?) -> Bool {
        if let connectionDelegate = self.connectionDelegate {
            return connectionDelegate.connectionReceived(from: peer, info: info)
        } else {
            return true
        }
    }
    
    // MARK: - Comms Handler State handlers ========================================================================= -
    
    internal func handlerStateChange(to state: CommsHandlerState) {
        // Record state and pass it up
        self._handlerState = state
        self.handlerStateDelegate?.handlerStateChange(to: state)
    }
    
    // MARK: - Queue Reset Class method ================================================================= -
    
    public class func reset(queueUUIDs: [String]) {
        // Start and stop a list of queues (to notify anyone listening on them to stop)
        let service = RabbitMQServerService(purpose: .other, serviceID: nil, deviceName: Scorecard.deviceName)
        for queueUUID in queueUUIDs {
            _ = service.startQueue(queueUUID: queueUUID)
            service.sendReset(mode: "stop")
            service.stopQueue(queueUUID: queueUUID)
        }
    }
    
    // MARK: - Utility Routines ================================================================ -

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
    
    private func sendReset(mode: String) {
        for (_, queue) in self.rabbitMQQueueList {
            self.debugMessage("Resetting queue \(queue.queueUUID!)")
            queue.sendReset(mode: mode)
        }
    }
}


// RabbitMQ Client Service Class ========================================================================= -

class RabbitMQClientService : RabbitMQService, CommsClientHandlerDelegate, RabbitMQBroadcastDelegate {
    
    private var matchDeviceName: String!
    private var invite: Invite!
    private var inviteEmail: String! = nil
    private var onlineInviteObserver: NSObjectProtocol?
    
    // Delegates
    public weak var browserDelegate: CommsBrowserDelegate!

    required init(purpose: CommsConnectionPurpose, serviceID: String?, deviceName: String) {
        super.init(purpose: purpose, type: .client, serviceID: serviceID, deviceName: deviceName)
    }

    internal func start(email: String!, name: String!, recoveryMode: Bool, matchDeviceName: String!) {
        self.debugMessage("Start Client \(self.connectionPurpose) \((recoveryMode ? "recovering" : ""))")

        super.startService(email: email, recoveryMode: recoveryMode)
        
        self.matchDeviceName = matchDeviceName
        
        // Set observer to handle online invitation notification
        self.clientClearOnlineInviteNotifications(observer: self.onlineInviteObserver)
        self.onlineInviteObserver = self.clientOnlineInviteNotification()
        // Check current invites
        self.clientCheckOnlineInvites(email: email, checkExpiry: !self.recoveryMode)
    }
    
    internal func stop() {
        // Disconnecting queues will disconnect all peers
        self.debugMessage("Stop Client \(self.connectionPurpose)")
        
        super.stopService()
        
        // Disable observer
        self.clientClearOnlineInviteNotifications(observer: self.onlineInviteObserver)
        
        // Disconnect peers
        for (deviceName, queue) in self.rabbitMQQueueList {
            queue.disconnect()
            rabbitMQQueueList[deviceName] = nil
        }
        
        // Remove queue from list - hence closing it
        self.rabbitMQQueueList = [:]
    }
    
    override func reset(reason: String? = nil) {
        self.debugMessage("Resetting client")
        // Simulate reset on each queue
        self.forEachQueue { (rabbitMQQueue) in
            self.didReceiveBroadcast(descriptor: "reset", data: "simulated", from: rabbitMQQueue)
        }
    }
    
    internal func connect(to commsPeer: CommsPeer, playerEmail: String?, playerName: String?, context: [String : String]? = nil, reconnect: Bool = true) -> Bool{
        // Used by client to connect to a queue
        var connectSuccess = false
        self.debugMessage("Connect to \(commsPeer.deviceName)")
        let deviceName = commsPeer.deviceName
        if let rabbitMQPeer = self.findRabbitMQPeer(deviceName: deviceName) {
            connectSuccess = rabbitMQPeer.connect(to : commsPeer, playerEmail: playerEmail, playerName: playerName, context: context, reconnect: reconnect)
        }
        if connectSuccess {
            self._connectionDevice = commsPeer.deviceName
        }
        return connectSuccess
    }
    
    // MARK: - Broadcast handler ========================================================================= -
    
    internal func didReceiveBroadcast(descriptor: String, data: Any?, from queue: RabbitMQQueue) {
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
                self.clientCheckOnlineInvites(email: self.inviteEmail, checkExpiry: !self.recoveryMode)
            }
            if let mode = data as? String {
                if mode != "stop" {
                    queue.forEachPeer { (rabbitMQPeer) in
                        if rabbitMQPeer.autoReconnect {
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
    
    
    // MARK: - Online Invites - Client checking for current invites ========================================= -
    
    public func clientCheckOnlineInvites(email: String, checkExpiry: Bool = true) {
        self.inviteEmail = email
        self.invite = Invite()
        self.invite.checkInvitations(to: self.inviteEmail, checkExpiry: checkExpiry, completion: self.clientCheckInvitationsCompletion)
    }
    
    internal func clientCheckInvitationsCompletion(_ success: Bool, _ message: String?, _ invited: [InviteReceived]?) {
        // Response to check for invitations in client
        if !success {
            // Error - need to remove all peers
            self.stop()
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
                                    let queue = self.createRabbitMQQueue(queueUUID: invite.inviteUUID, messageDelegate: self)
                                    rabbitMQPeer.attach(queue)
                                }
                                peerFound = true
                            } else if rabbitMQPeer.state == .notConnected {
                                peerFound = true
                            }
                        } else {
                            // New peer - add to our list and notify delegate
                            let queue = self.createRabbitMQQueue(queueUUID: invite.inviteUUID, messageDelegate: self)
                            rabbitMQPeer = RabbitMQPeer(from: self, queue: queue, deviceName: invite.deviceName, playerEmail: invite.email, playerName: invite.name, shouldReconnect: true)
                            peerFound = true
                            
                        }
                        if peerFound {
                            // Notify delegate
                            self.browserDelegate?.peerFound(peer: rabbitMQPeer.commsPeer)
                            // Auto-reconnect if reconnect flag is set or recovering
                            if rabbitMQPeer.autoReconnect || self.recoveryMode {
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
                    if invited.firstIndex(where: { $0.deviceName == rabbitMQPeer.deviceName }) == nil {
                        // Not in new list - close and delete
                        self.browserDelegate?.peerLost(peer: rabbitMQPeer.commsPeer)
                        rabbitMQPeer.disconnect()
                        rabbitMQPeer.detach()
                    }
                }
            }
        }
    }

    // MARK: - Utility Methods ========================================================================= -
    
    private func clientOnlineInviteNotification() -> NSObjectProtocol? {
        // Add new observer
        let observer = NotificationCenter.default.addObserver(forName: .onlineInviteReceived, object: nil, queue: nil) {
            (notification) in
            // Refresh online games - give iCloud a second to catch up!
            Utility.executeAfter(delay: 2, completion: { [unowned self] in
                self.debugMessage("Notification received")
                self.clientCheckOnlineInvites(email: self.inviteEmail)
            })
        }
        return observer
    }
    
    private func clientClearOnlineInviteNotifications(observer: NSObjectProtocol?) {
        if observer != nil {
            // Remove any previous notification handler
            NotificationCenter.default.removeObserver(observer!)
        }
    }
}


// MARK: RabbitMQQueue Class ========================================================== -

public protocol RabbitMQBroadcastDelegate : class {
    func didReceiveBroadcast(descriptor: String, data: Any?, from queue: RabbitMQQueue)
}

public class RabbitMQQueue: NSObject, RMQConnectionDelegate {
    
    private var connection: RMQConnection!
    private weak var channel: RMQChannel!
    private weak var queue: RMQQueue!
    private weak var exchange: RMQExchange!
    private var rabbitMQUri: String = Config.rabbitMQUri
    private var parent: RabbitMQService!
    private let myDeviceName = Scorecard.deviceName
    private let filterBroadcast: String!
    private var channelRecovery = false

    private var rabbitMQPeerList: [String: RabbitMQPeer] = [:]               // [deviceName: RabbitMQPeer]
    private var connectionDelegate: [String : CommsConnectionDelegate] = [:] // [deviceName : CommsConnectionDelegate]
    private var dataDelegate: [String : CommsDataDelegate?] = [:]            // [deviceName : CommsDataDelegate]
    public var messageDelegate: RabbitMQBroadcastDelegate?
    
    private var _queueUUID: String!
    public var queueUUID: String! {
        get {
            return _queueUUID
        }
    }
    
    init(from parent: RabbitMQService?, queueUUID: String, filterBroadcast: String! = nil) {
        self.parent = parent
        self.filterBroadcast = filterBroadcast
        self._queueUUID = queueUUID
        super.init()
        self.connect()
    }
    
    internal func connect() {
        self.connection = RMQConnection(uri: self.rabbitMQUri, delegate: self)
        self.connection.start()
        self.createChannel()
    }
    
    private func createChannel() {
        if let connection = self.connection {
            self.channel = connection.createChannel()
            self.queue = self.channel.queue("", options: .exclusive)
            self.exchange = self.channel.fanout(self.queueUUID, options: .autoDelete)
            self.queue.bind(self.exchange)
            self.queue.subscribe( { [weak self] (_ message: RMQMessage) -> Void in
                Utility.mainThread {
                    self?.didReceiveData(message.body)
                }
            })
        }
    }
    
    public func disconnect() {
        for (deviceName, rabbitMQPeer) in self.rabbitMQPeerList {
            rabbitMQPeer.disconnect()
            rabbitMQPeer.detach()
            rabbitMQPeerList[deviceName] = nil
        }
        self.queue?.unbind(self.exchange)
        self.connection?.close()
        self.queue?.subscribe(nil)
        self.queue = nil
        self.exchange = nil
        self.channel = nil
        self.connection = nil
        self.messageDelegate = nil
        self.connectionDelegate = [:]
        self.dataDelegate = [:]
        self.rabbitMQPeerList = [:]
    }
    
    fileprivate func attach(to rabbitMQPeer: RabbitMQPeer) {
        // Set up delegates
        self.dataDelegate[rabbitMQPeer.deviceName] = rabbitMQPeer
        self.connectionDelegate[rabbitMQPeer.deviceName] = rabbitMQPeer
        // Add to list of peers
        self.rabbitMQPeerList[rabbitMQPeer.deviceName] = rabbitMQPeer
    }
    
    fileprivate func detach(from rabbitMQPeer: RabbitMQPeer) {
        if self.dataDelegate[rabbitMQPeer.deviceName] != nil {
            self.dataDelegate[rabbitMQPeer.deviceName] = nil
        }
        if self.connectionDelegate[rabbitMQPeer.deviceName] != nil {
            self.connectionDelegate[rabbitMQPeer.deviceName] = nil
        }
        if self.rabbitMQPeerList[rabbitMQPeer.deviceName] != nil {
            self.rabbitMQPeerList[rabbitMQPeer.deviceName] = nil
        }
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
                        var content = ""
                        if !propertyList.isEmpty {
                            content = "(\(Scorecard.serialise(propertyList)))"
                        }
                        self.parent?.debugMessage("Received \(type)\(content) from \(fromDeviceName)")
                        switch type {
                        case "connectRequest":
                            if self.parent.connectionType == .server {
                                // Connections only accepted by servers
                                var rabbitMQPeer: RabbitMQPeer!
                                rabbitMQPeer = self.rabbitMQPeerList[fromDeviceName]
                                if rabbitMQPeer == nil {
                                    // Check if dummy entry exists for this email
                                    rabbitMQPeer = self.findDummyPeerByEmail(propertyList: propertyList, fromDeviceName: fromDeviceName)
                                    if rabbitMQPeer == nil {
                                        // No such peer - need to create it
                                        rabbitMQPeer = RabbitMQPeer(from: self.parent, queue: self, deviceName: fromDeviceName)
                                    }
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
    
    private func findDummyPeerByEmail(propertyList: [String : Any?], fromDeviceName: String) -> RabbitMQPeer? {
        var rabbitMQPeer: RabbitMQPeer?
        
        if let content = propertyList["content"] as? [String : Any?] {
            let fromPlayerEmail = content["playerEmail"] as! String?
            if fromPlayerEmail != nil {
                rabbitMQPeer = self.rabbitMQPeerList[fromPlayerEmail!]
                if rabbitMQPeer != nil {
                    // Remove dummy entry and reset device name
                    self.rabbitMQPeerList[fromPlayerEmail!] = nil
                    self.detach(from: rabbitMQPeer!)
                    rabbitMQPeer!.deviceName = fromDeviceName
                    self.attach(to: rabbitMQPeer!)
                }
            }
        }
        return rabbitMQPeer
    }
    
    fileprivate func forEachPeer(do execute: (RabbitMQPeer)->()) {
        for (_, rabbitMQPeer) in rabbitMQPeerList {
            execute(rabbitMQPeer)
        }
    }
    
    fileprivate func findPeer(deviceName: String) -> RabbitMQPeer? {
        return self.rabbitMQPeerList[deviceName]
    }
    
    fileprivate func sendReset(mode: String) {
        self.sendBroadcast(data: ["reset" : mode])
    }
    
    // MARK: - RMQConnectionDelegate Handlers ========================================================================== -

    public func connection(_ connection: RMQConnection!, failedToConnectWithError error: Error!) {
        // Connection to the Rabbit MQ service failed - retry
        Utility.mainThread {
            self.parent?.debugMessage("Failed to connect to \(self.queueUUID!) with error - \(error.localizedDescription) (\(self.rabbitMQPeerList.count) peers)")
            self.recoverConnectFailed(reason: error?.localizedDescription)
        }
    }
    
    public func connection(_ connection: RMQConnection!, disconnectedWithError error: Error!) {
        self.parent?.debugMessage("Disconnected with error from \(self.queueUUID!) - \(error.localizedDescription) (\(self.rabbitMQPeerList.count) peers)")
        self.recoverConnectFailed(reason: error?.localizedDescription)
    }
    
    public func channel(_ channel: RMQChannel!, error: Error!) {
        Utility.mainThread {
            if error != nil && !self.channelRecovery {
                
                // Block attempting to recover while still recovering
                self.channelRecovery = true
                
                self.parent?.debugMessage("Channel with error for \(self.queueUUID!) - \(error.localizedDescription) (\(self.rabbitMQPeerList.count) peers)")
                
                // Notify state to peers
                self.recoverStateChange(to: .recovering, message: error?.localizedDescription ?? "")
                
                // Channel has probaby gone - restart connection to rabbitMQ
                self.disconnect()
                Utility.executeAfter(delay: 2.0, completion: {
                    self.connect()
                    self.channelRecovery = false
                })
            }
        }
    }
    
    public func willStartRecovery(with connection: RMQConnection!) {
        Utility.mainThread {
            self.parent?.debugMessage("Will start recovery for \(self.queueUUID!) (\(self.rabbitMQPeerList.count) peers)")
            self.recoverStateChange(to: .recovering, message: "Will start recovery")
        }
    }
    
    public func startingRecovery(with connection: RMQConnection!) {
        Utility.mainThread {
            self.parent?.debugMessage("Starting recovery for \(self.queueUUID!) (\(self.rabbitMQPeerList.count) peers)")
            self.recoverStateChange(to: .recovering, message: "Starting recovery")
        }
    }
    
    public func recoveredConnection(_ connection: RMQConnection!) {
        Utility.mainThread {
            self.parent?.debugMessage("Recovered for \(self.queueUUID!) (\(self.rabbitMQPeerList.count) peers)")
            self.recoverStateChange(to: .connected, message: "Recovered")
        }
    }
    
    private func recoverConnectFailed(reason: String?) {
        // Attempt to connect to RabbitMQ server has failed
        
        // Notify peers that something is wrong and we're re-trying
        forEachPeer { (rabbitMQPeer) in
            
            if rabbitMQPeer.state == .connected {
                // Pass a recovering state change back up - rabbitMQ should re-establish the connection
                rabbitMQPeer.stateChange(state: .recovering, reason: reason)
            } else if rabbitMQPeer.state != .recovering {
                // Pass a notConnected state change back up
                rabbitMQPeer.disconnect(reason: reason ?? "Unexpected disconnect", reconnect: false, reflectStateChange: true)
            }
        }
    }

    private func recoverStateChange(to state: CommsConnectionState, message: String) {
        forEachPeer { (rabbitMQPeer) in
            if rabbitMQPeer.state != state {
                // Pass the state change back up if possible (only allow swap between recovering / connected)
                if rabbitMQPeer.state == .recovering && state == .connected ||
                        rabbitMQPeer.state == .connected && state == .recovering {
                    rabbitMQPeer.stateChange(state: state, reason: message)
                }
            }
        }
    }
}

// MARK: RabbitMQPeer Class ==========================================================

fileprivate class RabbitMQPeer: NSObject, CommsDataDelegate, CommsConnectionDelegate {
    private weak var parent: RabbitMQService!
    public var playerEmail: String?
    public var playerName: String?
    public var state: CommsConnectionState
    public var reason: String?
    private var shouldReconnect = false // If set then once a connection is achieved the peer will automatically try to reconnect
    public var deviceName: String
    private weak var queue: RabbitMQQueue!
    public var sessionUUID: String!
    private let myDeviceName = Scorecard.deviceName
    private var reconnectPeer: CommsPeer?
    private var reconnectContext: [String : String]?
    
    public weak var connectionDelegate: CommsConnectionDelegate!
    public weak var stateDelegate: CommsStateDelegate!
    public weak var dataDelegate: CommsDataDelegate!

    fileprivate var _autoReconnect = false   // This gets set once there has been a successful connection on the peer if shouldReconnect is set
    public var autoReconnect: Bool {
        get {
            return self._autoReconnect
        }
    }
    
    init(from parent: RabbitMQService, queue: RabbitMQQueue, deviceName: String, playerEmail: String? = "", playerName: String? = "", shouldReconnect: Bool = false) {
        self.parent = parent
        self.deviceName = deviceName
        self.playerEmail = playerEmail
        self.playerName = playerName
        self.shouldReconnect = shouldReconnect
        self._autoReconnect = false
        self.state = .notConnected
        self.reason = nil
        // Set up delegates
        if parent.connectionType == .server {
            self.connectionDelegate = parent as! RabbitMQServerService
        }
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
        self.queue.attach(to: self)
    }
    
    func detach() {
        self.queue.detach(from: self)
        self.queue = nil
    }
    
    public var commsPeer: CommsPeer {
        get {
            return CommsPeer(parent: self.parent as CommsHandlerDelegate, deviceName: self.deviceName, playerEmail: self.playerEmail, playerName: self.playerName, state: self.state, reason: self.reason, autoReconnect: autoReconnect)
        }
    }
    
    public var queueUUID: String! {
        get {
            return self.queue.queueUUID
        }
    }
    
    public func connect(to peer: CommsPeer, playerEmail: String?, playerName: String?, context: [String : String]? = nil, reconnect: Bool = true) -> Bool{
        var connectSuccess = false
        
        // Connections should only ever come from clients
        if self.parent.connectionType != .client {
            fatalError("Assert violation: Connections should only come from clients")
        } else {
        
             // Clear any existing connections
            self.disconnect(reason: "Re-connecting")
            // Allocate a session UUID and store details
            self.sessionUUID = self.rabbitMQSessionUUID
            self.shouldReconnect = reconnect
            self._autoReconnect = false
            if reconnect {
                // Save details to facilitate re-connection
                self.reconnectPeer = peer
                self.reconnectContext = context
            }
            connectSuccess = self.connectSend(to: peer, playerEmail: playerEmail, playerName: playerName, context: context)
        }
        
        return connectSuccess
    }
    
    fileprivate func reconnect() {
        self.parent.debugMessage("Attempting reconnect")
        if !self.connect(to: self.reconnectPeer!, playerEmail: self.playerEmail, playerName: self.playerName, context: self.reconnectContext, reconnect: self.shouldReconnect) {
            self.parent.debugMessage("Error reconnecting")
            self.stateChange(state: .notConnected, reason: "Connection failed")
        }
    }
    
    private func connectSend(to peer: CommsPeer, playerEmail: String?, playerName: String?, context: [String : String]? = nil) -> Bool {
        var connectSuccess = false
        
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
                // Update state and pass up
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
        
        if self.parent.connectionType != .server {
            fatalError("Assert violation: Connections should only be received by servers")
        } else {
            
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
                    self._autoReconnect = self.shouldReconnect
                    
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
    
    public func disconnect(reason: String = "", reconnect: Bool = false, reflectStateChange: Bool = false) {
        if self.state == .connected {
            self._autoReconnect = reconnect
            self.shouldReconnect = reconnect
            _ = self.send(descriptor: "disconnect", dictionary: ["reason" : reason], to: self.commsPeer)
        }
        if reflectStateChange {
            self.stateChange(state: .notConnected, reason: reason)
            self._autoReconnect = reconnect
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
                if matchSessionUUIDs.firstIndex(where: { $0 == self.sessionUUID}) != nil {
                     // Process message
                    switch descriptor {
                    case "connectResponse":
                        if self.parent.connectionType != .client {
                            fatalError("Assert violation: Connection responses should only be received by clients")
                        } else {
                            
                            let content = data["content"] as! [String : Any?]
                            var success = false
                            if let successValue = content["success"] as! Bool? {
                                success = successValue
                            }
                            if success {
                                self.state = .connected
                                self._autoReconnect = self.shouldReconnect
                            } else {
                                self.state = .notConnected
                            }
                        }
                        
                    case "disconnect":
                        let content = data["content"] as! [String : String]
                        reason = content["reason"]
                        self.reason = reason
                        self.state = .notConnected
                        self._autoReconnect = false
                        
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
            self.stateDelegate?.stateChange(for: self.commsPeer, reason: reason)
        }
    }
    
    public func stateChange(state: CommsConnectionState, reason: String?) {
        if state != self.state {
            // Pass up any state change
            self.state = state
            self.stateDelegate?.stateChange(for: self.commsPeer, reason: reason)
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


