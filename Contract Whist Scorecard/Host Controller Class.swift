 //
//  HostViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 07/06/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit

enum ConnectionMode {
    case unknown
    case nearby
    case online
    case loopback
}

enum InviteStatus {
    case none
    case inviting
    case invited
    case reconnecting
}

class HostController: NSObject, CommsStateDelegate, CommsDataDelegate, CommsConnectionDelegate, CommsHandlerStateDelegate, GamePreviewDelegate {
    
    // MARK: - Class Properties ======================================================================== -
    
    // Main state properties
    private let scorecard = Scorecard.shared
    
    // Properties to pass state to game preview
    public var selectedPlayers: [PlayerMO]!
    public var faceTimeAddress: [String] = []
    public var playingComputer = false
    public var computerPlayerDelegate: [ Int : ComputerPlayerDelegate? ]?
    
    // Queue
    private var queue: [QueueEntry] = []
    
    private weak var parentViewController: UIViewController!
    private weak var selectionViewController: SelectionViewController!
    private var playerData: [PlayerData] = []
    private var completion: ((Bool)->())?
    private var startMode: ConnectionMode?
    private var unique = 0
    private var observer: NSObjectProtocol?
    private var gameInProgress = false
    private var alertController: UIAlertController!
    private var connectionMode: ConnectionMode!
    private var defaultConnectionMode: ConnectionMode!
    private var multipeerHost: MultipeerServerService!
    private var rabbitMQHost: RabbitMQServerService!
    private var loopbackHost: LoopbackService!
    private var hostService: CommsServerHandlerDelegate!
    private var currentState: CommsHandlerState = .notStarted
    private var exiting = false
    private var computerPlayers: [Int : ComputerPlayerDelegate]?
    private var firstTime = true
    private var gamePreviewViewController: GamePreviewViewController!
    private var canProceed: Bool = false
    private var lastMessage: String = ""
    private var recoveryMode: Bool = false    // Recovery mode as defined by where weve come from (largely ignored)
    
    private var connectedPlayers: Int {
        get {
            var count = 0
            if self.playerData.count > 0 {
                for playerNumber in 1...self.playerData.count {
                    if playerNumber == 1 || (playerData[playerNumber - 1].disconnectReason == nil &&
                        (playerData[playerNumber - 1].peer != nil && playerData[playerNumber - 1].peer.state == .connected)) ||
                        playerNumber == 1 {
                        count += 1
                    }
                }
            }
            return count
        }
    }
    private var visiblePlayers: Int {
        get {
            var count = 0
            for player in self.playerData {
                if player.disconnectReason == nil {
                    count += 1
                }
            }
            return count
        }
    }
    
    // MARK: - Constructor ========================================================================== -
    
    init(from parentViewController: UIViewController) {
        self.parentViewController = parentViewController
        super.init()
    }
    
    public func start(mode: ConnectionMode? = nil, playerEmail: String? = nil, recoveryMode: Bool = false, completion: ((Bool)->())? = nil) {
        
        self.startMode = mode
        self.playerData = []
        
        // Reload players
        self.scorecard.loadGameDefaults()
        
        // Stop any existing sharing activity
        self.scorecard.stopSharing()
        
        // Save completion handler and mode
        self.recoveryMode = recoveryMode
        self.completion = completion
        
        if self.scorecard.recoveryMode {
            
            // Set mode
            switch self.scorecard.recoveryOnlineMode! {
            case .loopback:
                self.startMode = .loopback
            case .broadcast:
                self.startMode = .nearby
            case .invite:
                self.startMode = .online
            }
            
            // Restore players
            self.resetResumedPlayers()
            let playerMO = self.selectedPlayers[0]
            _ = self.addPlayer(name: playerMO.name!, email: playerMO.email!, playerMO: playerMO, peer: nil)
            
        } else {
            
            // Use passed in player
            let playerMO = scorecard.findPlayerByEmail(playerEmail!)
            _ = self.addPlayer(name: playerMO!.name!, email: playerMO!.email!, playerMO: playerMO, peer: nil)
        }
        
        // Allow broadcast of scores except in loopback mode
        self.scorecard.sendScores = (self.connectionMode != .loopback)
        
        // Set observer to detect UI handler completion
        observer = self.handlerCompleteNotification()
        
        if self.startMode == .online {
            // Show selection
            self.showSelection(completion: { [unowned self] (selectedPlayers) in
                if let selectedPlayers = selectedPlayers {
                    // Finish initialisation
                    self.selectedPlayers = selectedPlayers
                    self.initCompletion()
                    // Send invitations
                    if let selectedPlayers = self.selectedPlayers {
                        let invitees = selectedPlayers.count - 1
                        if invitees > 0 {
                            let playerMO = Array(selectedPlayers[1...invitees])
                            self.sendInvites(playerMO: playerMO)
                        }
                    }
                } else {
                    self.exitHost(returnHome: false)
                }
            })
        } else {
            // Show game preview
            let selectedPlayers = self.playerData.map { $0.playerMO! }
            self.showGamePreview(selectedPlayers: selectedPlayers, showCompletion: self.initCompletion)
        }
    }
    
    private func initCompletion() {
        
        // Start communication
        switch self.startMode! {
        case .loopback:
            self.setConnectionMode(.loopback)
        case .online:
            self.setConnectionMode(.online)
        case .nearby:
            self.setConnectionMode(.nearby)
        default:
            return
        }
    }
    
    // MARK: - Data Delegate Overrides ==================================================== -
    
    internal func didReceiveData(descriptor: String, data: [String : Any?]?, from peer: CommsPeer) {
        
        Utility.mainThread { [unowned self] in
            self.queue.append(QueueEntry(descriptor: descriptor, data: data, peer: peer))
        }
        self.processQueue()
    }
    
    private func processQueue() {
        
        Utility.mainThread { [unowned self] in
            
            while self.queue.count > 0 && self.scorecard.commsHandlerMode == .none {
                
                // Pop top element off the queue
                let descriptor = self.queue[0].descriptor
                let data = self.queue[0].data
                let peer = self.queue[0].peer
                self.queue.remove(at: 0)
                
                switch descriptor {
                case "scores":
                    _ = self.scorecard.processScores(descriptor: descriptor, data: data!, bonus2: self.scorecard.settingBonus2)
                case "played":
                    _ = self.scorecard.processCardPlayed(data: data! as Any as! [String : Any])
                    self.removeCardPlayed(data: data! as Any as! [String : Any])
                case "refreshRequest":
                    // Remote device wants a refresh of the currentstate
                    self.scorecard.refreshState(to: peer)
                default:
                    // Try scorecard generic handler
                    self.scorecard.didReceiveData(descriptor: descriptor, data: data, from: peer!)
                }
            }
        }
    }
    
    // MARK: - Connection Delegate handlers ===================================================================== -
    
    internal func connectionReceived(from peer: CommsPeer, info: [String : Any?]?) -> Bool {
        // Will accept all connections, but some will automatically disconnect with a relevant error message once connection complete
        var playerMO: PlayerMO! = nil
        var name: String!
        if let email = peer.playerEmail {
            playerMO = scorecard.findPlayerByEmail(email)
        }
        if let playerMO = playerMO {
            // Use local name
            name = playerMO.name!
        }
        if let index = self.playerData.firstIndex(where: {($0.peer != nil && $0.peer.deviceName == peer.deviceName) && $0.email == peer.playerEmail}) {
            // A player returning from the same device - probably a reconnect - just update the details
            self.playerData[index].peer = peer
            self.updateFaceTimeAddress(info: info, playerData: self.playerData[index])
        } else if self.connectionMode == .online {
            // Should already be in list
            if let index = self.playerData.firstIndex(where: {$0.email == peer.playerEmail}) {
                if self.playerData[index].peer != nil && self.playerData[index].peer.deviceName != peer.deviceName && self.playerData[index].peer.state != .notConnected {
                    // Duplicate - add it temporarily - to disconnect in state change
                    addPlayer(name: name, email: peer.playerEmail!, playerMO: playerMO, peer: peer, inviteStatus: InviteStatus.none, disconnectReason: "\(name ?? "This player") has already joined from another device")
                } else {
                    self.playerData[index].peer = peer
                    self.updateFaceTimeAddress(info: info, playerData: self.playerData[index])
                }
            } else {
                // Not found - shouldn't happen - add it temporarily - to disconnect in state change
                addPlayer(name: name, email: peer.playerEmail!, playerMO: playerMO, peer: peer, inviteStatus: InviteStatus.none, disconnectReason: "\(name ?? "This player") has not been invited to a game on this device")
            }
        } else {
            addPlayer(name: peer.playerName!, email: peer.playerEmail!, playerMO: playerMO, peer: peer)
        }
        return true
    }
    
    private func updateFaceTimeAddress(info: [String : Any?]?, playerData: PlayerData) {
        if let address = info?["faceTimeAddress"] {
            playerData.faceTimeAddress = address as! String?
        } else {
            playerData.faceTimeAddress = nil
        }
    }
    
    private func addPlayer(name: String, email: String, playerMO: PlayerMO?, peer: CommsPeer?, inviteStatus: InviteStatus! = nil, disconnectReason: String? = nil, refreshPlayers: Bool = true) {
        var disconnectReason = disconnectReason
        
        if disconnectReason == nil {
            if gameInProgress {
                let foundPlayer = self.scorecard.enteredPlayer(email: email)
                if foundPlayer == nil {
                    // Player not in game trying to connect while game in progress - refuse
                    disconnectReason = "A game is already in progress - only existing players can rejoin this game"
                }
            } else if playerData.count >= scorecard.numberPlayers {
                // Already got a full game
                disconnectReason = "The maximum number of players has already joined this game"
            }
        }
        
        // Add to list
        self.unique += 1
        var playerMO = playerMO
        if playerMO == nil {
            playerMO = self.createLocalPlayer(name: name, email: email, peer: peer)
        }
        playerData.insert(PlayerData(name: name, email: email, playerMO: playerMO, peer: peer, unique: self.unique, disconnectReason: disconnectReason, inviteStatus: inviteStatus),
                          at: self.visiblePlayers)
        self.refreshPlayers()
    }
    
    // MARK: - State Delegate handlers ===================================================================== -
    
    internal func stateChange(for peer: CommsPeer, reason: String?) {
        Utility.mainThread { [unowned self] in
            var row: Int!
            var playerNumber: Int!
            row = self.playerData.firstIndex(where: {$0.peer != nil && $0.peer.deviceName == peer.deviceName})
            if row != nil {
                let currentState = self.playerData[row].peer.state
                playerNumber = row! + 1
                switch peer.state {
                case .connected:
                    if let disconnectReason = self.playerData[playerNumber - 1].disconnectReason {
                        // Need to disconnect
                        self.disconnectPlayer(playerNumber: playerNumber, reason: disconnectReason)
                    } else {
                        // Show connection
                        self.reflectState(peer: peer)
                        // Check for duplicates
                        var error = false
                        if self.connectionMode == .nearby {
                            // Nearby connection - Check if duplicate from a different device
                            if let _ = self.playerData.firstIndex(where: {($0.peer == nil || $0.peer.deviceName != peer.deviceName) && $0.email == self.playerData[playerNumber - 1].email}) {
                                print(self.playerData.count)
                                self.playerData.forEach { print("\($0.email) - \($0.peer?.deviceName ?? "No device")") }
                                self.disconnectPlayer(playerNumber: playerNumber, reason: "\(peer.playerName ?? "This player") has already connected from another device")
                                print(self.playerData.count)
                                self.playerData.forEach { print("\($0.email) - \($0.peer?.deviceName ?? "No device")") }
                                error = true
                            }
                        }
                        if !error {
                            Utility.debugMessage("Host", "Connected to \(peer.playerName!)")
                            self.scorecard.refreshState(to: peer)
                            self.lastMessage = "" // Clear last message to force re-transmission
                            self.sendPlayers()
                            self.refreshPlayers()
                        }
                    }
                case .notConnected:
                    // Remove from display
                    if peer.mode == .broadcast {
                        if self.scorecard.recoveryMode {
                            self.playerData[playerNumber - 1].peer = nil
                            self.refreshPlayers()
                        } else {
                            self.reflectState(peer: peer)
                        }
                    } else {
                        self.reflectState(peer: peer)
                    }
                    self.sendPlayers()
                    self.refreshPlayers()
                default:
                    break
                }
                
                // Update game preview if necessary
                self.gamePreviewViewController?.refreshPlayers()
                
                // Update whisper
                if currentState != peer.state {
                    if (peer.state == .notConnected && peer.autoReconnect) || peer.state == .recovering {
                        self.playerData[playerNumber - 1].whisper.show("Connection to \(peer.playerName!) lost. Recovering...")
                    }
                }
                if peer.state == .connected && playerNumber <= self.playerData.count {
                    self.playerData[playerNumber - 1].whisper.hide("Connection to \(peer.playerName!) restored")
                }
            }
            
            self.canProceed = false
            if (self.scorecard.recoveryMode || self.playingComputer) && self.connectedPlayers == self.scorecard.currentPlayers {
                // Recovering or playing computer  - go straight to game setup
                self.canProceed = true
                self.setupPlayers()
            } else if self.connectionMode == .online && self.playerData.count >= 3 && self.connectedPlayers == self.playerData.count {
                self.canProceed = true
            } else if self.connectionMode == .nearby && self.connectedPlayers >= 3 {
                self.canProceed = true
            }
            self.refreshPlayers()
        }
    }
    
    private func sendPlayers() {
        // Send updated players to update the preview (prior to the game starting)
        if !self.gameInProgress {
            var players: [(String, String, Bool)] = []
            for index in 0..<self.playerData.count {
                let playerData = self.playerData[index]
                players.append((playerData.email, playerData.name, index == 0 || playerData.peer?.state == .connected))
            }
            
            self.scorecard.sendPlayers(players: players)
        }
        _ = self.statusMessage()
    }
    
    private func statusMessage() -> String {
        var message: String
        var remoteMessage: String?
        if self.canProceed {
            message = "Ready to start game"
            remoteMessage = "Waiting for the host\nto start the game"
        } else if self.recoveryMode {
            message = "Waiting for other players\nto reconnect..."
        } else if self.connectionMode == .online {
            message = "Waiting for invited\nplayers to connect..."
        } else {
            message = "Waiting for other\nplayers to connect..."
        }
        remoteMessage = remoteMessage ?? message
        if remoteMessage != lastMessage {
            self.scorecard.sendStatus(message:remoteMessage!)
            lastMessage = remoteMessage!
        }
        
        return message
    }
    
    private func reflectState(peer: CommsPeer) {
        let playerNumber = playerData.firstIndex(where: {$0.peer != nil && $0.peer.deviceName == peer.deviceName})
        if playerNumber != nil {
            let playerData = self.playerData[playerNumber!]
            playerData.peer = peer
        }
    }
    
    private func refreshHostView() {
        self.refreshPlayers()
    }
    
    // MARK: - Handler State Overrides ===================================================================== -
    
    internal func handlerStateChange(to state: CommsHandlerState) {
        if state != self.currentState {
            switch state {
            case .notStarted:
                if self.currentState == .invited || self.currentState == .inviting {
                    self.gamePreviewViewController?.alertMessage("Invitation failed")
                }
                if defaultConnectionMode == .unknown {
                    self.setConnectionMode(.unknown)
                } else if !exiting {
                    self.exitHost(returnHome: false)
                }
            case .broadcasting:
                break
                
            default:
                var inviteStatus: InviteStatus = .none
                switch state {
                case .inviting:
                    inviteStatus = .inviting
                case .invited:
                    inviteStatus = .invited
                case .reconnecting:
                    inviteStatus = .reconnecting
                default:
                    break
                }
                if playerData.count >= 2 {
                    for playerNumber in 2...playerData.count {
                        let playerData = self.playerData[playerNumber - 1]
                        if playerData.peer == nil {
                            playerData.peer = CommsPeer(parent: self.hostService!,
                                                        deviceName: "",
                                                        playerEmail: playerData.email,
                                                        playerName: playerData.name)
                        }
                        playerData.inviteStatus = inviteStatus
                        self.refreshPlayers()
                    }
                }
            }
            currentState = state
            _ = self.statusMessage()
        }
    }
    
   // MARK: - Search return handler ================================================================ -
    
    private func returnPlayer(complete: Bool, playerMO: [PlayerMO]?) {
        if complete {
            // Returning player
            self.scorecard.defaultPlayerOnDevice = playerMO![0].email!
            UserDefaults.standard.set(self.scorecard.defaultPlayerOnDevice, forKey: "defaultPlayerOnDevice")
            self.playerData[0].name = playerMO![0].name!
            self.playerData[0].email = playerMO![0].email!
            self.playerData[0].playerMO = playerMO![0]
            self.refreshHostView()
            self.startHostBroadcast(email: playerMO![0].email!, name: playerMO![0].name!)
        }
    }
    
    func sendInvites(playerMO: [PlayerMO]?) {
        // Save selected players
        self.selectedPlayers = [self.playerData[0].playerMO!] + playerMO!
        
        // Reset player list to just host
        self.playerData = [self.playerData[0]]
        
        // Insert selected players into list
        var invite: [String] = []
        for player in playerMO! {
            invite.append(player.email!)
            self.addPlayer(name: player.name!,
                           email: player.email!,
                           playerMO: player,
                           peer: nil,
                           inviteStatus: .inviting)
        }
        
        // Refresh UI
        self.refreshPlayers()
        
        // Open connection and send invites
        self.startOnlineConnection()
        self.startHostBroadcast(email: self.playerData[0].email, name: self.playerData[0].name, invite: invite, queueUUID: (self.scorecard.recoveryMode ? self.scorecard.recoveryConnectionUUID : nil))
    }
    
    private func refreshPlayers() {
        self.gamePreviewViewController?.selectedPlayers = self.playerData.map {$0.playerMO}
        self.gamePreviewViewController?.refreshPlayers()
        _ = self.statusMessage()
    }
    
    // MARK: - Game Preview Delegate handlers ============================================================================== -
    
    internal let gamePreviewHosting: Bool = true
    
    internal var gamePreviewCanStartGame: Bool {
        get {
            return self.canProceed
        }
    }
    
    internal var gamePreviewWaitMessage: NSAttributedString {
        get {
            return NSAttributedString(string: self.statusMessage())
        }
    }
    
    internal func gamePreviewInitialisationComplete(gamePreviewViewController: GamePreviewViewController) {
        if self.startMode == .online {
            
            // Store view controller (passed back from selection)
            self.gamePreviewViewController = gamePreviewViewController
            
        }
    }
    
    internal func gamePreviewCompletion(returnHome: Bool) {
        self.gamePreviewViewController = nil
        self.gameInProgress = false
        self.exitHost(returnHome: returnHome)
    }
    
    internal func gamePreview(isConnected playerMO: PlayerMO) -> Bool {
        if let index = self.playerData.firstIndex(where: {$0.email == playerMO.email}) {
            return (index == 0 || playerData[index].peer?.state == .connected)
        } else {
            return false
        }
    }
    
    internal func gamePreview(disconnect playerMO: PlayerMO) {
        if let currentSlot = self.playerData.firstIndex(where: {$0.email == playerMO.email}) {
            self.disconnectPlayer(playerNumber: currentSlot + 1, reason: "Disconnected by host")
        }
    }
    
    internal func gamePreview(moved playerMO: PlayerMO, to slot: Int) {
        if let currentSlot = self.playerData.firstIndex(where: {$0.email == playerMO.email}) {
            let keepPlayerData = self.playerData[slot]
            self.playerData[slot] = self.playerData[currentSlot]
            self.playerData[currentSlot] = keepPlayerData
        }
        self.sendPlayers()
    }
    
    internal func gamePreviewStartGame() {
        self.setupPlayers()
        self.gameInProgress = true
        self.scorecard.sendPlayers()
        _ = self.statusMessage()
    }
    
    internal func gamePreviewStopGame() {
        self.gameInProgress = false
    }
    
    internal func gamePreviewShakeGestureHandler() {
        
        // Play sound
        self.gamePreviewViewController.alertSound()
        
        if self.currentState != .inviting {
            // Don't reset while in middle of inviting
            
            if let mode = self.connectionMode {
                
                // Disconnect
                self.setConnectionMode(.unknown)
                
                switch mode {
                case .nearby:
                    // Start broadcasting
                    self.setConnectionMode(.nearby)
                    
                case .online:
                    // Start connection
                    self.setConnectionMode(.online)
                    
                    if let selectedPlayers = self.selectedPlayers {
                        // Resend invites
                        let invitees = selectedPlayers.count - 1
                        if invitees > 0 {
                            let playerMO = Array(selectedPlayers[1...invitees])
                            self.sendInvites(playerMO: playerMO)
                        }
                    }
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - Utility Routines ======================================================================== -
    
    private func showGamePreview(selectedPlayers: [PlayerMO], showCompletion: (()->())? = nil) {
        
        if let viewController = parentViewController as? CustomViewController {
            self.gamePreviewViewController = GamePreviewViewController.show(from: viewController, selectedPlayers: selectedPlayers, title: "Host a Game", backText: "", readOnly: false, faceTimeAddress: self.faceTimeAddress, rabbitMQService: self.rabbitMQHost, computerPlayerDelegates: self.computerPlayers, delegate: self, showCompletion: showCompletion)
        }
    }
    
    private func showSelection(showCompletion: (()->())? = nil, completion: (([PlayerMO]?)->())? = nil) {
        if let viewController = parentViewController as? CustomViewController {
            self.selectionViewController = SelectionViewController.show(from: viewController, existing: self.selectionViewController, mode: .invitees, thisPlayer: self.playerData[0].email, formTitle: "Choose Players", smallFormTitle: "Select", backText: "", backImage: "back", completion: completion, showCompletion: showCompletion, gamePreviewDelegate: self)
        }
    }
    
    
    private func setConnectionMode(_ connectionMode: ConnectionMode) {
        let oldConnectionMode = self.connectionMode
        if connectionMode != oldConnectionMode {
            self.connectionMode = connectionMode
            
            // Clear hand state
            self.scorecard.handState = nil
            
            // Disconnect any existing connected players
            if playerData.count > 1 {
                for playerNumber in (2...playerData.count).reversed() {
                    self.disconnectPlayer(playerNumber: playerNumber, reason: "Host has disconnected")
                }
            }
            
            // Switch connection mode
            if self.connectionMode == .unknown {
                self.stopHostBroadcast()
                self.takeDelegates(nil)
            } else {
                switch self.connectionMode! {
                case .online:
                    break
                case .nearby:
                     self.startNearbyConnection()
                case .loopback:
                    self.startLoopbackMode()
                default:
                    break
                }
            }
            
            self.refreshPlayers()
        }
    }
    
    private func startNearbyConnection() {
        // Create comms service and take hosting delegate
        multipeerHost = MultipeerServerService(purpose: .playing, serviceID: self.scorecard.serviceID(.playing))
        self.scorecard.commsDelegate = multipeerHost
        self.hostService = multipeerHost
        self.takeDelegates(self)
        if self.playerData.count > 0 {
            self.startHostBroadcast(email: playerData[0].email, name: playerData[0].name)
        }
    }
    
    private func startOnlineConnection() {
        // Create comms service and take hosting delegate
        rabbitMQHost = RabbitMQServerService(purpose: .playing, serviceID: nil)
        self.scorecard.commsDelegate = rabbitMQHost
        self.hostService = rabbitMQHost
        self.takeDelegates(self)
    }
    
    private func startLoopbackMode() {
        // Create loopback service, take delegate and then start loopback service
        loopbackHost = LoopbackService(purpose: .playing, type: .server, serviceID: nil, deviceName: Scorecard.deviceName)
        self.scorecard.commsDelegate = loopbackHost
        self.hostService = loopbackHost
        self.takeDelegates(self)
        self.loopbackHost.start(email: playerData[0].email, name: playerData[0].name)
        
        // Set up other players - they should call the host back
        let hostPeer = CommsPeer(parent: loopbackHost, deviceName: Scorecard.deviceName, playerEmail: self.playerData.first?.email, playerName: playerData.first?.playerMO.name)
        self.computerPlayers = [:]
        var names = ["Harry", "Snape", "Ron"]
        for playerNumber in 2...4 {
            self.startLoopbackClient(email: "_Player\(playerNumber)", name: names[playerNumber - 2], deviceName: "\(names[playerNumber - 2])'s iPhone", hostPeer: hostPeer, playerNumber: playerNumber)
        }
    }
    
    private func startLoopbackClient(email: String, name: String, deviceName: String, hostPeer: CommsPeer, playerNumber: Int) {
        let computerPlayer = ComputerPlayer(email: email, name: name, deviceName: deviceName, hostPeer: hostPeer, playerNumber: playerNumber)
        computerPlayers?[playerNumber] = computerPlayer as ComputerPlayerDelegate
    }
    
    private func takeDelegates(_ delegate: Any?) {
        self.hostService?.stateDelegate = delegate as! CommsStateDelegate?
        self.hostService?.dataDelegate = delegate as! CommsDataDelegate?
        self.hostService?.connectionDelegate = delegate as! CommsConnectionDelegate?
        self.hostService?.handlerStateDelegate = delegate as! CommsHandlerStateDelegate?
    }
    
    func removeCardPlayed(data: [String : Any]) {
        let playerNumber = data["player"] as! Int
        let card = Card(fromNumber: data["card"] as! Int)
        if playerNumber != 1 {
            // Only need to remove other players cards since my own will be removed by playing them
            _ = self.scorecard.deal.hands[playerNumber - 1].remove(card: card)
        }
    }
    
    func handlerCompleteNotification() -> NSObjectProtocol? {
        // Set a notification for handler complete
        let observer = NotificationCenter.default.addObserver(forName: .clientHandlerCompleted, object: nil, queue: nil) {
            (notification) in
            // Flag not waiting and then process next entry in the queue
            self.scorecard.commsHandlerMode = .none
            self.processQueue()
        }
        return observer
    }
    
    func clearHandlerCompleteNotification(observer: NSObjectProtocol?) {
        NotificationCenter.default.removeObserver(observer!)
    }
    
    private func disconnectPlayer(playerNumber: Int, reason: String) {
        if playerData[playerNumber - 1].peer != nil {
            self.hostService?.disconnect(from: playerData[playerNumber - 1].peer, reason: reason)
        }
        removePlayer(playerNumber: playerNumber)
    }
    
    private func removePlayer(playerNumber: Int) {
        playerData.remove(at: playerNumber - 1)
        self.refreshPlayers()
    }
    
    private func setupPlayers() {
        var xref: [Int] = []
        
        for playerNumber in 1...playerData.count {
            if self.scorecard.recoveryMode && !self.playingComputer {
                // Ensure players are in same order as before
                let index = self.playerData.firstIndex(where: {$0.email == self.selectedPlayers[playerNumber - 1].email})
                xref.append(index!)
            } else {
                xref.append(playerNumber - 1)
            }
        }
        
        var playerNumber = 0
        self.selectedPlayers = []
        self.faceTimeAddress = []
        
        for index in xref {
            let playerData = self.playerData[index]
            var playerMO = playerData.playerMO
            if playerMO == nil {
                // Not found - need to create the player locally
                playerMO = self.createLocalPlayer(name: playerData.name, email: playerData.email, peer: playerData.peer)
            }
            playerNumber += 1
            self.selectedPlayers.append(playerMO!)
            self.faceTimeAddress.append(playerData.faceTimeAddress ?? "")
        }
        self.scorecard.updateSelectedPlayers(self.selectedPlayers)
    }
    
    private func createLocalPlayer(name: String, email: String, peer: CommsPeer? = nil) -> PlayerMO! {
        let playerDetail = PlayerDetail()
        playerDetail.name = name
        playerDetail.email = email
        playerDetail.dedupName()
        if let playerMO = playerDetail.createMO() {
            // Get picture
            if let peer = peer {
                self.scorecard.requestPlayerThumbnail(from: peer, playerEmail: playerDetail.email)
            }
            return playerMO
        } else {
            return nil
        }
    }
    
    private func resetResumedPlayers() {
        // Run round player list trying to patch in players from last time
        var playerListNumber = 0
        selectedPlayers = []
        
        for playerNumber in 1...scorecard.currentPlayers {
            let playerURI = scorecard.playerURI(scorecard.enteredPlayer(playerNumber).playerMO)
            if playerURI != "" {
                
                playerListNumber = 1
                while playerListNumber <= scorecard.playerList.count {
                    let playerMO = scorecard.playerList[playerListNumber-1]
                    if playerURI == scorecard.playerURI(playerMO) {
                        selectedPlayers.append(playerMO)
                        break
                    }
                    playerListNumber += 1
                }
            }
        }
    }
    
    private func startHostBroadcast(email: String!, name: String!, invite: [String]? = nil, queueUUID: String! = nil) {
        // Start host broadcast
        self.hostService?.start(email: email, queueUUID: queueUUID, name: name, invite: invite, recoveryMode: self.scorecard.recoveryMode)
    }
    
    public func exitHost(returnHome: Bool) {
        self.exiting = true
        self.scorecard.sendScores = false
        self.scorecard.commsDelegate?.disconnect(reason: "\(self.playerData[0].name) has stopped hosting", reconnect: false)
        self.stopHostBroadcast(completion: {
            self.takeDelegates(nil)
            self.scorecard.commsDelegate = nil
            self.hostService = nil
            self.scorecard.resetSharing()
            self.clearHandlerCompleteNotification(observer: self.observer)
            self.scorecard.resetOverrideSettings()
            self.completion?(returnHome)
        })
    }

    private func stopHostBroadcast(completion: (()->())? = nil) {
        // Revert to normal sharing (if enabled)
        if let service = self.hostService {
            service.stop(completion: completion)
        } else {
            completion?()
        }
    }
}

// MARK: - Utility classes ========================================================================= -

class PlayerData {
    public var name: String
    public var email: String
    public var playerMO: PlayerMO!
    public var peer: CommsPeer!
    public var unique: Int
    public var disconnectReason: String! // Have only accepted connection to be able to pass this message when disconnect
    public var inviteStatus: InviteStatus!
    public var faceTimeAddress: String!
    public var oldState: CommsConnectionState!
    public var whisper = Whisper()
    public var lastRefreshSent: Date?
    
    init(name: String, email: String, playerMO: PlayerMO!, peer: CommsPeer!, unique: Int,  disconnectReason: String!, inviteStatus: InviteStatus!) {
        self.name = name
        self.email = email
        self.playerMO = playerMO
        self.peer = peer
        self.unique = unique
        self.disconnectReason = disconnectReason
        self.inviteStatus = inviteStatus
    }
}
