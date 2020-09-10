 //
//  Host Controller.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 07/06/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit
 import Combine

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
 
 class HostController: ScorecardAppController, CommsStateDelegate, CommsConnectionDelegate, CommsServiceStateDelegate, ScorecardAppPlayerDelegate, GamePreviewDelegate {
    
    // MARK: - Class Properties ======================================================================== -
        
    private var selectedPlayers: [PlayerMO]!
    private var faceTimeAddress: [String] = []
    private var playingComputer = false
    private var robots: [Int : RobotDelegate]?

    private weak var selectionViewController: SelectionViewController!
    private weak var gamePreviewViewController: GamePreviewViewController!
    
    private var playerData: [PlayerData] = []
    private var completion: ((Bool)->())?
    private var startMode: ConnectionMode?
    private var unique = 0
    private var gameInProgress = false
    private var connectionMode: ConnectionMode!
    private var defaultConnectionMode: ConnectionMode!
    private var nearbyHostService: CommsHostServiceDelegate!
    private var onlineHostService: CommsHostServiceDelegate!
    private var loopbackHostService: CommsHostServiceDelegate!
    private var hostService: CommsHostServiceDelegate!
    private var currentState: CommsServiceState = .notStarted
    private var exiting = false
    private var resetting = false
    private var firstTime = true
    private var canStartGame: Bool = false
    private var lastMessage: String = ""
    private var scoreSubcriber: AnyCancellable?
    private var recoveryMode: Bool = false    // Recovery mode as defined by where weve come from (largely ignored)
    
    private var connectedPlayers: Int {
        get {
            return playerData.filter( {$0.isConnected} ).count
        }
    }
    private var visiblePlayers: Int {
        get {
            return playerData.filter({ $0.disconnectReason == nil} ).count
        }
    }
    
    // MARK: - Constructor ========================================================================== -
    
    init(from parentViewController: ScorecardViewController) {
        super.init(from: parentViewController, type: .host)
    }
    
    public func start(mode: ConnectionMode? = nil, playerUUID: String? = nil, recoveryMode: Bool = false, completion: ((Bool)->())? = nil) {
    
        super.start()
        
        self.startMode = mode
        self.playerData = []
        
        // Stop any existing sharing activity
        Scorecard.shared.stopSharing()
        
        // Save completion handler and mode
        self.recoveryMode = recoveryMode
        self.completion = completion
        
        if self.recoveryMode {
            
            // Set mode
            switch Scorecard.recovery.onlineMode! {
            case .broadcast:
                self.startMode = .nearby
            case .invite:
                self.startMode = .online
            case .loopback:
                self.startMode = .loopback
            default:
                self.startMode = .unknown
            }
            
            // Restore players
            self.resetResumedPlayers()
            for (index, playerMO) in self.selectedPlayers.enumerated() {
                if index == 0 || self.startMode != .loopback {
                    _ = self.addPlayer(name: playerMO.name!, playerUUID: playerMO.playerUUID!, playerMO: playerMO, peer: nil, host: index == 0)
                }
            }
            
            // Start game
            self.initCompletion()
            if Scorecard.recovery.onlineMode == .invite {
                self.sendInvites()
            }
            self.gameInProgress = true
            self.startGame()
            
        } else {
            
            // Use passed in player
            let playerMO = Scorecard.shared.findPlayerByPlayerUUID(playerUUID!)
            _ = self.addPlayer(name: playerMO!.name!, playerUUID: playerMO!.playerUUID!, playerMO: playerMO, peer: nil, host: true)
            
            // Got to selection or game preview
            if self.startMode == .online {
                // Show selection
                self.present(nextView: .selection)
            } else {
                // Show game preview
                self.present(nextView: .gamePreview)
            }
        }
    }
    
    override public func stop() {
        super.stop()
        
        self.setConnectionMode(.unknown)
    }
    
    private func initCompletion() {
        
        // Start communication
        switch self.startMode! {
        case .online:
            self.setConnectionMode(.online)
        case .nearby:
            self.setConnectionMode(.nearby)
        case .loopback:
            self.setConnectionMode(.loopback)
        default:
            return
        }
    }
    
    // MARK: - App Controller Overrides =========================================================== -
     
    override internal func refreshView(view: ScorecardView) {
        
    }
    
    override internal func presentView(view: ScorecardView, context: [String:Any?]?, completion: (([String:Any?]?)->())?) -> ScorecardViewController? {
        var viewController: ScorecardViewController?
        
        switch view {
        case .selection:
            viewController = self.showSelection()
            
        case .gamePreview:
            let selectedPlayers = self.playerData.map { $0.playerMO! }
            viewController = self.showGamePreview(selectedPlayers: selectedPlayers)
            
        case .location:
            viewController = self.showLocation()
            
        case .hand:
            viewController = self.playHand()
            
        case .scorepad:
            viewController = self.showScorepad(scorepadMode: .hosting)
            self.autoDeal()
            
        case .gameSummary:
            viewController = self.showGameSummary(mode: .hosting)
            
        case .confirmPlayed:
            viewController = self.showConfirmPlayed(context: context, completion: completion)
                
        case .highScores:
            viewController = self.showHighScores()
            
        case .review:
            if let round = context?["round"] as? Int {
                viewController = self.showReview(round: round, playerNumber: 1)
            }
            
        case .overrideSettings:
            viewController = self.showOverrideSettings()
            
        case .selectPlayers:
            viewController = self.showSelectPlayers(completion: completion)
        
        case .exit:
            self.exitHost(returnHome: true)
            
        default:
            break
        }
        return viewController
    }
    
    override internal func didDismissView(view: ScorecardView, viewController: ScorecardViewController?) {
        // Tidy up after view dismissed
        
        switch self.activeView {
        case .gamePreview:
            self.gamePreviewViewController.selectedPlayersView.delegate = nil
            self.gamePreviewViewController.controllerDelegate = nil
            self.gamePreviewViewController.delegate = nil
            self.gamePreviewViewController = nil
           
        default:
            break
        }            
    }
     
     // MARK: - View Delegate Handlers  =================================================== -
     
     override internal var canProceed: Bool {
         get {
             var canProceed = true
             switch self.activeView {
             case .gamePreview:
                canProceed = self.canStartGame
                 
             case .scorepad:
                canProceed = true
                
             default:
                 break
             }
             return canProceed
                 
         }
     }
     
     override internal var canCancel: Bool {
         get {
             var canCancel = true
             switch self.activeView {
             case .scorepad:
                canCancel = !Scorecard.game.gameComplete()
                
             default:
                 break
             }
             return canCancel
                 
         }
     }
     
     override internal func didLoad() {
         switch self.activeView {
         case .gamePreview:
            self.initCompletion()
         default:
             break
         }
     }
     
     override internal func didAppear() {
         switch self.activeView {
         default:
             break
         }
     }
     
    override internal func didCancel() {
        switch self.activeView {
        case .selection:
            self.present(nextView: .exit)
            
        case .gamePreview:
            self.gameInProgress = false
            
            self.stopBroadcast() {
                if self.connectionMode == .online {
                    self.present(nextView: .selection)
                } else {
                    self.present(nextView: .exit)
                }
            }
            
        case .location:
            // Link back to game preview
            self.present(nextView: .exit)
            
        case .hand:
            // Link to scorepad
            self.present(nextView: .scorepad)
            
        case .scorepad:
            // Exit - game abandoned
            self.present(nextView: .exit)
            
        case .gameSummary:
            // Go back to scorepad
            self.present(nextView: .scorepad)
            
        default:
            break
        }
     }
     
    override internal func didProceed(context: [String:Any]?) {
        switch self.activeView {
        case .selection:
            // Set up comms connection and then send invitations
            self.initCompletion()
            self.sendInvites()
            self.present(nextView: .gamePreview)
            
        case .gamePreview:
            // Start the new game
            self.newGame()
            self.startGame()
            
        case .location:
        // Got location - show hand
            Scorecard.recovery.saveLocationAndDate()
            self.present(nextView: .hand)
            
        case .hand:
            // Link to scorecard or game summary
            self.handComplete()
            
        case .gameSummary:
            // Game complete
            self.gameComplete(context: context)
            
        case .scorepad:
            // Link to hand unless game is complete
            self.present(nextView: (Scorecard.game.gameComplete() ? .gameSummary : .hand))
            
        default:
            break
        }
    }
    
    override func robotAction(playerNumber: Int! = nil, action: RobotAction) {
        if self.connectionMode == .loopback {
            for (robotNumber, robot) in self.robots! {
                if playerNumber == nil || playerNumber == robotNumber {
                    switch action {
                    case .bid:
                        robot.autoBid()
                    case .play:
                        robot.autoPlay()
                    case .deal:
                        robot.newHand(hand: Scorecard.game.deal.hands[robotNumber - 1])
                    }
                }
            }
        }
    }
     
    private func newGame() {
        Scorecard.game.resetValues()
        Scorecard.game.datePlayed = Date()
        Scorecard.game.gameUUID = UUID().uuidString
        Scorecard.recovery.saveLocationAndDate()
        Scorecard.recovery.saveOverride()
    }
    
    func startGame() {
        self.setupPlayers()
        Scorecard.shared.saveMaxScores()
        Scorecard.recovery.saveInitialValues()
        self.setHandState()
        _ = self.statusMessage()
        
        // Link to hand or location
        if Scorecard.game.gameComplete() {
            self.present(nextView: .gameSummary)
        } else if self.connectionMode == .nearby && Scorecard.activeSettings.saveLocation &&
             (Scorecard.game.location.description == nil || Scorecard.game.location.description == "") {
            self.present(nextView: .location)
        } else {
            self.present(nextView: .hand)
        }
        
        // Do a background partial sync
        Scorecard.shared.syncBeforeGame()
    }
     
    // MARK: - Process received data ==================================================== -

    override internal func processQueue(descriptor: String, data: [String:Any?]?, peer: CommsPeer) -> Bool {
        let stopProcessing = false
        
        if let playerData = playerDataFor(peer: peer) {
            if playerData.isConnected || (playerData.peer.state == .connected && descriptor == "refreshRequest") {
                // Ignore any incoming data (except refresh request) if reconnecting and haven't seen refresh request yet
                
                switch descriptor {
                case "scores":
                    _ = Scorecard.shared.processScores(descriptor: descriptor, data: data!)
                case "played":
                    _ = Scorecard.shared.processCardPlayed(data: data! as Any as! [String : Any], from: self)
                    self.removeCardPlayed(data: data! as Any as! [String : Any])
                case "refreshRequest":
                    // Remote device wants a refresh of the current state
                    if playerData.refreshRequired {
                        // Have been expecting this
                        playerData.refreshRequired = false
                        self.sendPlayers()
                        self.checkCanStartGame()
                        self.lastMessage = "" // Clear last message to force resend
                        self.hideWhisper("Connection to \(peer.playerName!) restored", for: playerData.playerUUID)
                    }
                    Scorecard.shared.refreshState(from: self, to: peer)
                    self.refreshPlayers()
                default:
                    // Try scorecard generic handler
                    Scorecard.shared.didReceiveData(descriptor: descriptor, data: data, from: peer)
                }
            }
        }
        return stopProcessing
    }
    
    // MARK: - Connection Delegate handlers ===================================================================== -
    
    internal func connectionReceived(from peer: CommsPeer, info: [String : Any?]?) -> Bool {
        // Will accept all connections, but some will automatically disconnect with a relevant error message once connection complete
        var playerMO: PlayerMO! = nil
        var name: String!
        if let playerUUID = peer.playerUUID {
            playerMO = Scorecard.shared.findPlayerByPlayerUUID(playerUUID)
        }
        if let playerMO = playerMO {
            // Use local name
            name = playerMO.name!
        }
        if let index = self.playerIndexFor(peer: peer) {
            // A player returning from the same device - probably a reconnect - just update the details
            self.playerData[index].peer = peer
            self.updateFaceTimeAddress(info: info, playerData: self.playerData[index])
        } else {
            // Should already be in list
            let playerIndex = self.playerIndexFor(playerUUID: peer.playerUUID)
            if playerIndex != nil && self.playerData[playerIndex!].peer != nil && self.playerData[playerIndex!].peer.deviceName != peer.deviceName && self.playerData[playerIndex!].peer.state != .notConnected {
                    // Duplicate - add it temporarily - to disconnect in state change
                    addPlayer(name: name, playerUUID: peer.playerUUID!, playerMO: playerMO, peer: peer, inviteStatus: InviteStatus.none, disconnectReason: "\(name ?? "This player") has already joined from another device")
            } else {
                if self.connectionMode == .online {
                    if playerIndex != nil {
                        self.playerData[playerIndex!].peer = peer
                        self.updateFaceTimeAddress(info: info, playerData: self.playerData[playerIndex!])
                    } else {
                        // Not found - shouldn't happen - add it temporarily - to disconnect in state change
                        addPlayer(name: name, playerUUID: peer.playerUUID!, playerMO: playerMO, peer: peer, inviteStatus: InviteStatus.none, disconnectReason: "\(name ?? "This player") has not been invited to a game on this device")
                    }
                } else {
                    addPlayer(name: peer.playerName!, playerUUID: peer.playerUUID!, playerMO: playerMO, peer: peer, robot: self.connectionMode == .loopback)
                }
            }
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
    
    private func addPlayer(name: String, playerUUID: String, playerMO: PlayerMO?, peer: CommsPeer?, inviteStatus: InviteStatus! = nil, disconnectReason: String? = nil, refreshPlayers: Bool = true, host: Bool = false, robot: Bool = false) {
        var disconnectReason = disconnectReason
        
        if disconnectReason == nil {
            if gameInProgress {
                let foundPlayer = Scorecard.game.player(playerUUID:playerUUID)
                if foundPlayer == nil {
                    // Player not in game trying to connect while game in progress - refuse
                    disconnectReason = "A game is already in progress - only existing players can rejoin this game"
                }
            } else if playerData.count >= Scorecard.shared.maxPlayers {
                // Already got a full game
                disconnectReason = "The maximum number of players has already joined this game"
            }
        }
        
        // Check not already there
        var playerData: PlayerData?
        if let peer = peer {
            playerData = self.playerDataFor(peer: peer)
        } else {
            playerData = self.playerDataFor(playerUUID: playerUUID)
        }
        if let playerData = playerData {
            // Update it
            playerData.name = name
            playerData.playerMO = playerMO
            playerData.peer = peer
            playerData.inviteStatus = inviteStatus
            playerData.disconnectReason = disconnectReason
            playerData.host = host
        } else {
            // Add to list
            self.unique += 1
            var playerMO = playerMO
            if playerMO == nil {
                playerMO = self.createLocalPlayer(name: name, playerUUID: playerUUID, peer: peer)
            }
            self.playerData.insert(PlayerData(name: name, playerUUID: playerUUID, playerMO: playerMO, peer: peer, unique: self.unique, disconnectReason: disconnectReason, inviteStatus: inviteStatus, host: host, robot: robot), at: self.visiblePlayers)
            self.refreshPlayers()
        }
    }
    
    // MARK: - State Delegate handlers ===================================================================== -
    
    internal func stateChange(for peer: CommsPeer, reason: String?) {
        Utility.mainThread {
            var playerNumber: Int!
            if let row = self.playerIndexFor(peer: peer) {
                let playerData = self.playerData[row]
                let currentState = playerData.peer?.state ?? .notConnected
                playerNumber = row + 1
                
                // Always require a refresh on change of state if not a robot
                playerData.refreshRequired = (self.connectionMode != .loopback)
                
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
                            if playerData.peer != nil && playerData.peer.deviceName != peer.deviceName {
                                self.disconnectPlayer(playerNumber: playerNumber, reason: "\(peer.playerName ?? "This player") has already connected from another device (\(playerData.peer?.deviceName ?? "Unknown"))")
                                error = true
                            }
                            playerData.peer = peer
                        }
                        if !error {
                            Utility.debugMessage("Host \(self.uuid)", "Connected to \(peer.playerName!)")
                            self.refreshPlayers()
                        }
                    }
                case .notConnected:
                    // Remove from display
                    if peer.mode == .broadcast {
                        if Scorecard.recovery.recovering {
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
                        self.showWhisper("Connection to \(peer.playerName!) lost. Recovering...", for: peer.playerUUID!)
                    }
                }
            }
            
            self.checkCanStartGame()
            self.refreshPlayers()
        }
    }
    
    private func checkCanStartGame() {
        self.canStartGame = false
        if Scorecard.recovery.recovering && self.connectedPlayers == Scorecard.game.currentPlayers {
            // Recovering - go straight to game setup
            self.canStartGame = true
        } else if self.connectionMode == .online && self.playerData.count >= 3 && self.connectedPlayers == self.playerData.count {
            self.canStartGame = true
        } else if self.connectionMode == .nearby && self.connectedPlayers >= 3 {
            self.canStartGame = true
        } else if self.connectionMode == .loopback && self.connectedPlayers >= 3 {
            self.canStartGame = true
        }
    }
    
    private func sendPlayers() {
        // Send updated players to update the preview (prior to the game starting)
        if !self.gameInProgress {
            Scorecard.shared.sendPlayers(from: self)
            Scorecard.shared.sendDealer()
        }
        _ = self.statusMessage()
    }
    
    private func refreshPlayers() {
        self.gamePreviewViewController?.selectedPlayers = self.playerData.map {$0.playerMO}
        self.gamePreviewViewController?.refreshPlayers()
        _ = self.statusMessage()
    }
    
    private func statusMessage() -> String {
        var message: String
        var remoteMessage: String?
        if self.canStartGame {
            message = "Ready to start game"
            remoteMessage = "Waiting for the host\nto start the game"
        } else if self.recoveryMode {
            message = "Waiting for other players\nto reconnect..."
        } else if self.connectionMode == .online {
            message = "Waiting for invited\nplayers to connect..."
        } else if self.connectionMode == .nearby {
            message = "Waiting for other\nplayers to connect..."
        } else {
            message = "Waiting for\ngame to start..."
        }
        remoteMessage = remoteMessage ?? message
        if remoteMessage != lastMessage {
            Scorecard.shared.sendStatus(message:remoteMessage!)
            lastMessage = remoteMessage!
        }
        
        return message
    }
    
    private func reflectState(peer: CommsPeer) {
        if let playerData = playerDataFor(peer: peer) {
            playerData.peer = peer
        }
    }
    
    // MARK: - Handler State Overrides ===================================================================== -
    
    internal func controllerStateChange(to state: CommsServiceState) {
        if state != self.currentState {
            switch state {
            case .notStarted:
                if self.currentState == .invited || self.currentState == .inviting {
                    self.gamePreviewViewController?.alertMessage("Invitation failed")
                }
                if defaultConnectionMode == .unknown {
                    self.setConnectionMode(.unknown)
                }
            case .advertising:
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
                                                        playerUUID: playerData.playerUUID,
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
    
    // MARK: - Handler player overrides =========================================================== -
    
    func currentPlayers() -> [(playerUUID: String, name: String, connected: Bool)]? {
        var players: [(playerUUID: String, name: String, connected: Bool)]?
        
        if !Scorecard.game.inProgress {
            players = playerData.map { ( $0.playerUUID, $0.name, $0.isConnected ) }
        }
        
        return players
    }
 
    // MARK: - Play hand ========================================================================== -
    
    private func setHandState() {
        // Called to explicitly initialise local and remote state when game starts - thereafter just uses .reset() for each new round
        Scorecard.game!.handState = HandState(enteredPlayerNumber: 1, round: Scorecard.game.maxEnteredRound, dealerIs: Scorecard.game.dealerIs, players: Scorecard.game.currentPlayers)
        if Scorecard.game.deal == nil {
            Scorecard.shared.dealNextHand()
        }
        if self.recoveryMode && Scorecard.game?.deal != nil {
            // Hand has been recovered - Check if finished
            var finished = true
            for hand in Scorecard.game!.deal.hands {
                if hand.cards.count != 0 {
                    finished = false
                }
            }
            if finished {
                self.nextHand()
            } else {
                Scorecard.game?.handState.hand = Scorecard.game?.deal.hands[0]
            }
        }
        
        Scorecard.game.setGameInProgress(true)
        
        if self.recoveryMode {
            // Recovering - resend hand state to other players
            Scorecard.recovery.loadCurrentTrick()
            Scorecard.recovery.loadLastTrick()
        }
        
        // Send state to peers
        Scorecard.shared.sendHostState(from: self)
        
    }
    
    private func playHand() -> ScorecardViewController? {
        var handViewController: HandViewController?
           
        Scorecard.game.setGameInProgress(true)

        Scorecard.shared.sendPlayHand()
        
        if let parentViewController = self.parentViewController {
            handViewController = Scorecard.shared.playHand(from: parentViewController, appController: self, animated: true)
        }
        
        return handViewController
    }
    
    private func handComplete() {
        if Scorecard.game!.handState.finished {
            if Scorecard.game.gameComplete() {
                // Game complete
                _ = Scorecard.game.save()
                self.present(nextView: .gameSummary)
            } else {
                // Not complete - move to next round and go to scorepad
                if Scorecard.game.handState.round != Scorecard.game.rounds {
                    // Reset state and prepare for next round
                    self.nextHand()
                    Scorecard.shared.sendHandState()
                }
                self.present(nextView: .scorepad)
            }
        } else {
            // Still in progress just go to scorepad
            self.present(nextView: .scorepad)
        }
    }
    
    private func nextHand() {
        if Scorecard.game.handState.round != Scorecard.game.rounds {
            Scorecard.game!.handState.round += 1
            Scorecard.game.selectedRound = Scorecard.game.handState.round
            Scorecard.game.maxEnteredRound = Scorecard.game.handState.round
            Scorecard.game.handState.reset()
            Scorecard.shared.dealNextHand()
        }
    }
    
    private func gameComplete(context : [String:Any]!) {
        let mode = context["mode"] as? GameSummaryReturnMode ?? .returnHome
        let advanceDealer = context["advanceDealer"] as? Bool ?? true
        let resetOverrides = context["resetOverrides"] as? Bool ?? true
        
        Scorecard.shared.exitScorecard(advanceDealer: advanceDealer, resetOverrides: resetOverrides) {
            if mode == .newGame {
                self.newGame()
                self.startGame()
            } else {
                self.present(nextView: .exit)
            }
        }
    }
    
   // MARK: - Invitations ================================================================ -
    
    func sendInvites() {
        let invitees = (self.selectedPlayers?.count ?? 0) - 1
        if invitees > 0 {
            let playerMO = Array(self.selectedPlayers![1...invitees])
            self.sendInvite(playerMO: playerMO)
        }
    }
    
    func sendInvite(playerMO: [PlayerMO]?) {
        // Save selected players
        self.selectedPlayers = [self.playerData[0].playerMO!] + playerMO!
        
        // Reset player list to just host
        self.playerData = [self.playerData[0]]
        
        // Insert selected players into list
        var invite: [String] = []
        for player in playerMO! {
            invite.append(player.playerUUID!)
            self.addPlayer(name: player.name!,
                           playerUUID: player.playerUUID!,
                           playerMO: player,
                           peer: nil,
                           inviteStatus: .inviting)
        }
        
        // Refresh UI
        self.refreshPlayers()
        
        // Open connection and send invites
        self.startOnlineConnection()
        self.startHostBroadcast(playerUUID: self.playerData[0].playerUUID, name: self.playerData[0].name, invite: invite, queueUUID: (Scorecard.recovery.recovering ? Scorecard.recovery.connectionUUID : nil))
    }

    
    // MARK: - Game Preview Delegate handlers ============================================================================== -
    
    internal let gamePreviewHosting: Bool = true
    
    internal var gamePreviewWaitMessage: NSAttributedString {
        get {
            return NSAttributedString(string: self.statusMessage())
        }
    }
    
    internal func gamePreview(isConnected playerMO: PlayerMO) -> Bool {
        if let playerData = self.playerDataFor(playerUUID: playerMO.playerUUID) {
            return playerData.isConnected
        } else {
            return false
        }
    }
    
    internal func gamePreview(disconnect playerMO: PlayerMO) {
        if let currentSlot = self.playerIndexFor(playerUUID: playerMO.playerUUID) {
            self.disconnectPlayer(playerNumber: currentSlot + 1, reason: "Disconnected by host")
        }
    }
    
    internal func gamePreview(moved playerMO: PlayerMO, to slot: Int) {
        if let currentSlot = self.playerIndexFor(playerUUID: playerMO.playerUUID) {
            let keepPlayerData = self.playerData[slot]
            self.playerData[slot] = self.playerData[currentSlot]
            self.playerData[currentSlot] = keepPlayerData
        }
        self.sendPlayers()
    }
    
     internal func gamePreviewShakeGestureHandler() {
        
        // Play sound
        self.gamePreviewViewController.alertSound()
        
        if self.currentState != .inviting {
            // Don't reset while in middle of inviting
            
            if let mode = self.connectionMode {
                
                // Disconnect
                self.resetting = true
                self.setConnectionMode(.unknown) {
                    self.resetting = false
                    
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
                                self.sendInvite(playerMO: playerMO)
                            }
                        }
                        
                    case .loopback:
                        // Start connection
                        self.setConnectionMode(.loopback)
                        
                    default:
                        break
                    }
                }
            }
        }
    }
    
    // MARK: - Show / refresh / hide other views ==================================================== -
    
    private func showSelection() -> ScorecardViewController {
        if let viewController = self.fromViewController() {
            self.selectionViewController = SelectionViewController.show(from: viewController, appController: self, existing: self.selectionViewController, mode: .invitees, thisPlayer: self.playerData[0].playerUUID, formTitle: "Choose Players", smallFormTitle: "Select", completion:
                { [weak self] (returnHome, selectedPlayers) in
                    // Returned values coming back from select players. Just store them - should get a didProceed immediately after
                    self?.selectedPlayers = selectedPlayers
            })
        }
        return self.selectionViewController
    }
    
    private func showGamePreview(selectedPlayers: [PlayerMO]) -> ScorecardViewController? {
        
        if let viewController = self.fromViewController() {
            self.gamePreviewViewController = GamePreviewViewController.show(from: viewController, appController: self, selectedPlayers: selectedPlayers, formTitle: (self.startMode == .loopback ? "Play Computer" : "Host a Game"), smallFormTitle: (self.startMode == .loopback ? "Play" : "Host"), backText: "", readOnly: false, faceTimeAddress: self.faceTimeAddress, animated: !self.recoveryMode, delegate: self)
        }
        return self.gamePreviewViewController
    }
    
    // MARK: - Utility Routines ======================================================================== -
        
    private func playerDataFor(playerUUID: String?) -> PlayerData? {
        return self.playerData.first(where: {$0.playerUUID == playerUUID})
    }

    private func playerDataFor(peer: CommsPeer, excludeHost: Bool = true) -> PlayerData? {
        return self.playerData.first(where: { (!excludeHost || !$0.host) &&
                                                $0.peer?.deviceName == peer.deviceName &&
                                                $0.playerUUID == peer.playerUUID})
    }
    
    private func playerIndexFor(playerUUID: String?) -> Int? {
         return self.playerData.firstIndex(where: {$0.playerUUID == playerUUID})
    }

    private func playerIndexFor(peer: CommsPeer, excludeHost: Bool = true) -> Int? {
        return self.playerData.firstIndex(where: { (!excludeHost || !$0.host) &&
                                                    $0.peer?.deviceName == peer.deviceName &&
                                                    $0.playerUUID == peer.playerUUID})
    }
    
    private func setConnectionMode(_ connectionMode: ConnectionMode, completion: (()->())? = nil) {
        let oldConnectionMode = self.connectionMode
        if connectionMode != oldConnectionMode {
            self.connectionMode = connectionMode
            
            // Clear hand state
            Scorecard.game?.handState = nil
            
            // Disconnect any existing connected players
            if playerData.count > 1 {
                for playerNumber in (2...playerData.count).reversed() {
                    if !self.recoveryMode || (playerData[playerNumber - 1].peer?.state ?? .notConnected) != .notConnected {
                        self.disconnectPlayer(playerNumber: playerNumber, reason: "Host has disconnected")
                    }
                }
            }
            
            // Switch connection mode
            if self.connectionMode == .unknown {
                self.stopHostBroadcast(completion: completion)
            } else {
                switch self.connectionMode! {
                case .online:
                    break
                case .nearby:
                     self.startNearbyConnection()
                case .loopback:
                    self.startLoopbackConnection()
                default:
                    break
                }
                self.refreshPlayers()
                completion?()
            }
        }
    }
    
    private func startNearbyConnection() {
        // Create comms service and take hosting delegate
        self.nearbyHostService = CommsHandler.server(proximity: .nearby, mode: .broadcast, serviceID: Scorecard.shared.serviceID(), deviceName: Scorecard.deviceName, purpose: .playing)
        Scorecard.shared.setCommsDelegate(nearbyHostService, controller: self, purpose: .playing)
        self.hostService = nearbyHostService
        self.takeDelegates(self)
        if self.playerData.count > 0 {
            var invite: [String]?
            if self.recoveryMode && self.playerData.count > 1 {
                invite = Array(self.playerData.map{$0.playerUUID}[1..<self.playerData.count])
            }
            self.startHostBroadcast(playerUUID: playerData[0].playerUUID, name: playerData[0].name, invite: invite)
        }
    }
    
    private func startOnlineConnection() {
        // Create comms service and take hosting delegate
        self.onlineHostService = CommsHandler.server(proximity: .online, mode: .invite, serviceID: nil, deviceName: Scorecard.deviceName, purpose: .playing)
        Scorecard.shared.setCommsDelegate(onlineHostService, controller: self, purpose: .playing)
        self.hostService = onlineHostService
        self.takeDelegates(self)
    }
    
    private func startLoopbackConnection() {
        // Create loopback service, take delegate and then start loopback service
        self.loopbackHostService = CommsHandler.server(proximity: .loopback, mode: .loopback, serviceID: nil, deviceName: Scorecard.deviceName, purpose: .playing)
        Scorecard.shared.setCommsDelegate(self.loopbackHostService, controller: self, purpose: .playing)
        self.hostService = self.loopbackHostService
        self.takeDelegates(self)
        self.loopbackHostService.start(playerUUID: playerData[0].playerUUID, name: playerData[0].name)
        
        // Set up other players - they should call the host back
        let hostPeer = CommsPeer(parent: self.loopbackHostService, deviceName: Scorecard.deviceName, playerUUID: self.playerData.first?.playerUUID, playerName: playerData.first?.playerMO.name)
        self.robots = [:]
        let names = ["Harry", "Snape", "Ron"]
        for playerNumber in 2...4 {
            self.startLoopbackClient(playerUUID: "_Player\(playerNumber)", name: names[playerNumber - 2], deviceName: "\(names[playerNumber - 2])'s iPhone", hostPeer: hostPeer, playerNumber: playerNumber)
        }
    }
    
    private func startLoopbackClient(playerUUID: String, name: String, deviceName: String, hostPeer: CommsPeer, playerNumber: Int) {
        let robot = RobotPlayer(playerUUID: playerUUID, name: name, deviceName: deviceName, hostPeer: hostPeer, playerNumber: playerNumber)
        robots?[playerNumber] = robot as RobotDelegate
    }
    
    private func takeDelegates(_ delegate: Any?) {
        self.hostService?.stateDelegate = delegate as! CommsStateDelegate?
        self.hostService?.dataDelegate = delegate as! CommsDataDelegate?
        self.hostService?.connectionDelegate = delegate as! CommsConnectionDelegate?
        self.hostService?.handlerStateDelegate = delegate as! CommsServiceStateDelegate?
    }
    
    func removeCardPlayed(data: [String : Any]) {
        let playerNumber = data["player"] as! Int
        let card = Card(fromNumber: data["card"] as! Int)
        if playerNumber != 1 {
            // Only need to remove other players cards since my own will be removed by playing them
            _ = Scorecard.game?.deal.hands[playerNumber - 1].remove(card: card)
        }
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
        self.sendPlayers()
    }
    
    private func setupPlayers() {
        var xref: [Int] = []
        
        for playerNumber in 1...playerData.count {
            if Scorecard.recovery.recovering && !Scorecard.game.isPlayingComputer {
                // Ensure players are in same order as before
                xref.append(self.playerIndexFor(playerUUID: self.selectedPlayers[playerNumber - 1].playerUUID)!)
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
                playerMO = self.createLocalPlayer(name: playerData.name, playerUUID: playerData.playerUUID, peer: playerData.peer)
            }
            playerNumber += 1
            self.selectedPlayers.append(playerMO!)
            self.faceTimeAddress.append(playerData.faceTimeAddress ?? "")
        }
        Scorecard.game.saveSelectedPlayers(self.selectedPlayers)
    }
    
    private func createLocalPlayer(name: String, playerUUID: String, peer: CommsPeer? = nil) -> PlayerMO! {
        let playerDetail = PlayerDetail()
        playerDetail.name = name
        playerDetail.playerUUID = playerUUID
        playerDetail.dedupName()
        if let playerMO = playerDetail.createMO(noSync: true, saveToICloud: false) {
            // Get picture
            if peer?.mode == .loopback {
                let image = UIImage(named: name.lowercased())
                if let pngData = image?.pngData() {
                    playerMO.thumbnail = Data(pngData)
                }
            } else if let peer = peer {
                Scorecard.shared.requestPlayerThumbnail(from: peer, playerUUID: playerDetail.playerUUID)
            }
            return playerMO
        } else {
            return nil
        }
    }
    
    private func resetResumedPlayers() {
        // Run round player list trying to patch in players from last time
        selectedPlayers = []
        for playerNumber in 1...Scorecard.game.currentPlayers {
            let playerUri = Scorecard.game.player(enteredPlayerNumber: playerNumber).playerMO!.uri
            if playerUri != "" {
                if let playerMO = Scorecard.shared.playerList.first(where: { $0.uri == playerUri} ) {
                    selectedPlayers.append(playerMO)
                }
            }
        }
    }
    
    private func startHostBroadcast(playerUUID: String!, name: String!, invite: [String]? = nil, queueUUID: String! = nil) {
        // Start host broadcast
        self.hostService?.start(playerUUID: playerUUID, queueUUID: queueUUID, name: name, invite: invite, recoveryMode: Scorecard.recovery.recovering, matchGameUUID: (Scorecard.recovery.recovering ? Scorecard.game.gameUUID : nil))
    }
    
    public func exitHost(returnHome: Bool) {
        self.exiting = true
        self.stopBroadcast() {
            self.stop()
            let completion = self.completion
            self.completion = nil
            completion?(returnHome)
        }
    }
    
    private func stopBroadcast(completion: (()->())? = nil) {
        self.stopHostBroadcast(completion: {
            self.takeDelegates(nil)
            Scorecard.shared.setCommsDelegate(nil)
            self.hostService = nil
            Scorecard.shared.resetSharing()
            Scorecard.game.reset()
            completion?()
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
    public var playerUUID: String
    public var playerMO: PlayerMO!
    public var peer: CommsPeer!
    public var unique: Int
    public var disconnectReason: String! // Have only accepted connection to be able to pass this message when disconnect
    public var inviteStatus: InviteStatus!
    public var faceTimeAddress: String!
    public var oldState: CommsConnectionState!
    public var lastRefreshSent: Date?
    public var host: Bool = false
    public var refreshRequired = true
    
    public var isConnected: Bool {
        get {
            return (self.host || (self.peer?.state == .connected && !self.refreshRequired && self.disconnectReason == nil))
        }
    }
    
    init(name: String, playerUUID: String, playerMO: PlayerMO!, peer: CommsPeer!, unique: Int,  disconnectReason: String!, inviteStatus: InviteStatus!, host: Bool, robot: Bool = false) {
        self.name = name
        self.playerUUID = playerUUID
        self.playerMO = playerMO
        self.peer = peer
        self.unique = unique
        self.disconnectReason = disconnectReason
        self.inviteStatus = inviteStatus
        self.host = host
        self.refreshRequired = !robot
    }
    
    
    
}
