//
//  Client Controller Class.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 09/05/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

protocol ClientControllerDelegate : ScorecardViewController {
    
    func addPeer(deviceName: String, name: String, oldState: CommsConnectionState, state: CommsConnectionState, connecting: Bool, proximity: CommsConnectionProximity, purpose: CommsPurpose, at row: Int)
    
    func removePeer(at row: Int)
    
    func reflectPeer(deviceName: String, name: String, oldState: CommsConnectionState, state: CommsConnectionState, connecting: Bool, proximity: CommsConnectionProximity, purpose: CommsPurpose)
    
    func stateChange(to state: ClientAppState)
}

class ClientController: ScorecardAppController, CommsBrowserDelegate, CommsStateDelegate, GamePreviewDelegate {
        
    // Controller delegate
    public weak var delegate: ClientControllerDelegate?

    private var available: [Available] = []
    private let whisper = Whisper()
    private let sync = Sync()
    private var controllerState: ClientAppState! = .notConnected
   
    private var nearbyClientService: CommsClientServiceDelegate?
    private var onlineClientService: CommsClientServiceDelegate?
    private var clientService: CommsClientServiceDelegate?
    
    private weak var gamePreviewViewController: GamePreviewViewController!
    private weak var alertController: UIAlertController!
    
    private var gameOver = false
    
    private var thisPlayer: String!
    private var thisPlayerName: String!
    private var thisPlayerNumber: Int!
    
    private var matchDeviceName: String?
    private var matchProximity: CommsConnectionProximity?
    private var matchGameUUID: String?
    private var purpose: CommsPurpose!
    
    private var playerConnected: [String : Bool] = [:]
    private var lastStatus = ""
    
    private var setCommsDelegate = false
    
    // Timers
    private var checkInviteTimer: Timer!
    private var connectingTimer: Timer!
    
    init(from parentViewController: ScorecardViewController, playerUUID: String, playerName: String, matchDeviceName: String?, matchProximity: CommsConnectionProximity?, matchGameUUID: String?) {
                
        self.thisPlayer = playerUUID
        self.thisPlayerName = playerName
        self.matchDeviceName = matchDeviceName
        self.matchProximity = matchProximity
        self.matchGameUUID = matchGameUUID

        super.init(from: parentViewController, type: .client)

        self.createConnections()
        
        super.start()
    }
    
    override public func stop() {
        super.stop()
        self.closeConnections()
        self.stopCheckInviteTimer()
        self.stopConnectingTimer()
        if self.setCommsDelegate {
            Scorecard.shared.setCommsDelegate(nil)
        }
     }
    
    public func refresh() {
        self.refreshInvites()
    }
    
    // MARK: - View Controller =========================================================== -
    
    override func refreshView(view: ScorecardView) {
        
        switch view {
        case .gamePreview:
            self.refreshGamePreview()
            
        case .roundSummary:
            self.refreshRoundSummary()
            
        case .hand:
            if let handViewController = self.activeViewController as? HandViewController {
                handViewController.refreshAll()
            }
            
        default:
            break
        }
    }
    
    override internal func presentView(view: ScorecardView, context: [String:Any?]? = nil, completion: (([String:Any?]?)->())?) -> ScorecardViewController? {
        var viewController: ScorecardViewController?
        
        switch view {
        case .gamePreview:
            let getPlayers = context?["getPlayers"] as? Bool
            viewController =  self.showGamePreview(getPlayers: getPlayers ?? true)
            
        case .hand:
            viewController = self.playHand()
            
        case .scorepad:
            viewController = self.showScorepad(scorepadMode: (self.purpose == .playing ? .joining : .viewing))
            
        case .roundSummary:
            viewController = self.showRoundSummary()
            
        case .gameSummary:
            viewController = self.showGameSummary(mode: .joining)
            
        case .confirmPlayed:
            viewController = self.showConfirmPlayed(context: context, completion: completion)
            
        case .highScores:
            viewController = self.showHighScores()
            
        case .review:
            if let round = context?["round"] as? Int {
                viewController = self.showReview(round: round, playerNumber: self.thisPlayerNumber)
            }
            
        case .exit:
            self.delegate?.stateChange(to: .finished)
            
        default:
            break
        }
        return viewController
    }
    
    override internal func didDismissView(view: ScorecardView, viewController: ScorecardViewController?) {
        // Tidy up after view dismissed
        
        switch self.activeView {
        case .gamePreview:
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
                canProceed = false
                
            case .scorepad:
                canProceed = (self.purpose != .sharing ||
                    !Scorecard.game.roundComplete(Scorecard.game.maxEnteredRound) ||
                    Scorecard.game.maxEnteredRound == Scorecard.game.rounds)
                
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
                canCancel = (self.purpose != .sharing || !Scorecard.game.gameComplete())
                
            default:
                break
            }
            
            return canCancel
        }
    }
    
    override internal func didLoad() {
        switch self.activeView {
            
        default:
            break
        }
    }
    
    override internal func didAppear() {
        switch self.activeView {
        case .gamePreview:
            self.gamePreviewViewController?.showStatus(status: self.lastStatus)
        default:
            break
        }
    }
    
    override internal func didCancel() {
        switch self.activeView {
        case .gamePreview:
            // Exit
            Scorecard.game.resetValues()
            self.gamePreviewViewController = nil
            self.present(nextView: .exit)
            
        case .hand:
            // Link to scorepad
            self.present(nextView: .scorepad)
            
        case .roundSummary:
            // Go back to scorepad
            self.present(nextView: .scorepad)
            
        case .scorepad:
            // Exit - game left
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
        case .hand:
            // Link to scorecard or game summary
            self.handComplete()
            
        case .scorepad:
            // Link to hand unless game is complete
            if self.purpose == .sharing {
                _ = self.checkSharedScores(maxRound: Scorecard.game.maxEnteredRound)
            } else {
                self.present(nextView: (Scorecard.game.gameComplete() ? .gameSummary : .hand))
            }
            
        case .gameSummary:
            // Finished
            self.present(nextView: .exit)

        default:
            break
        }
    }
    
    // MARK: - Process received data ==================================================== -
    
    override internal func processQueue(descriptor: String, data: [String:Any?]?, peer: CommsPeer) -> Bool {
        var stopProcessing = false
        
        if let availableFound = availableFor(peer: peer) {
            if availableFound.isConnected || (availableFound.state == .connected && (descriptor == "state" || descriptor == "previewPlayers" || descriptor == "dealer" || descriptor == "status")) {
                // Ignore any incoming data (except state) if reconnecting and haven't seen state yet
                
                switch descriptor {
                case "state":
                    // No longer waiting for state
                    availableFound.stateRequired = false
                    
                    // Wrappered state - split out components
                    if let data = data?["settings"] as? [String:Any?]? {
                        stopProcessing = self.processQueue(descriptor: "settings", data: data, peer: peer) || stopProcessing
                    }
                    if let data = data?["gamePlayers"] as? [String:Any?]? {
                        stopProcessing = self.processQueue(descriptor: "gamePlayers", data: data, peer: peer) || stopProcessing
                    }
                    if let data = data?["dealer"] as? [String:Any?]? {
                        stopProcessing = self.processQueue(descriptor: "dealer", data: data, peer: peer) || stopProcessing
                    }
                    if let data = data?["allscores"] as? [String:Any?]? {
                        stopProcessing =  self.processQueue(descriptor: "allscores", data: data, peer: peer) || stopProcessing
                    }
                    if let data = data?["autoPlay"] as? [String:Any?]? {
                        stopProcessing =  self.processQueue(descriptor: "autoPlay", data: data, peer: peer) || stopProcessing
                    }
                    
                    // Need to process the game UID before the hand state as game UUID will clear the deal history
                    
                    if let data = data?["gameUUID"] as? [String:Any?]? {
                        stopProcessing = self.processQueue(descriptor: "gameUUID", data: data, peer: peer) || stopProcessing
                    }
                    if let data = data?["handState"] as? [String:Any?]? {
                        stopProcessing =  self.processQueue(descriptor: "handState", data: data, peer: peer) || stopProcessing
                        
                    }

                    // Can now consider ourselves connected
                    self.controllerStateChange(to: .connected)
                    
                    if let _ = data?["playHand"] as? [String:Any?]? {
                        stopProcessing =  self.processQueue(descriptor: "playHand", data: nil, peer: peer) || stopProcessing
                    }
                    
                case "gameUUID":
                    
                    if let gameUUID = data!["gameUUID"] as? String {
                        Scorecard.game.gameUUID = gameUUID
                        if Scorecard.recovery.recoveryAvailable {
                            if gameUUID == Scorecard.recovery.gameUUID {
                                // Matches last game we had - recover deal history
                                Scorecard.recovery.loadDealHistory()
                            } else {
                                // Looks like a different game - game history is not useful
                                Scorecard.game.dealHistory = [:]
                            }
                        } else {
                            // Not recovering - remove history
                            Scorecard.game.dealHistory = [:]
                        }
                    }
                    
                case "settings":
                    // Only ever received as part of a complete state
                    Scorecard.activeSettings.cards = data!["numberCards"] as! [Int]
                    Scorecard.activeSettings.bounceNumberCards = data!["bounceNumberCards"] as! Bool
                    Scorecard.activeSettings.trumpSequence = data!["trumpSequence"] as! [String]
                    Scorecard.activeSettings.bonus2 = data!["bonus2"] as! Bool
                    Scorecard.activeSettings.saveHistory = data!["saveHistory"] as! Bool
                    Scorecard.activeSettings.saveStats = data!["saveStats"] as! Bool
                    self.thisPlayerNumber = nil
                    
                case "dealer":
                    Scorecard.game.dealerIs = data!["dealer"] as! Int
                    if self.activeView == .gamePreview {
                        self.gamePreviewViewController?.showCurrentDealer(clear: true)
                    }
                    
                case "previewPlayers", "gamePlayers":
                    Scorecard.game.setCurrentPlayers(players: data!.count)
                    Scorecard.game.resetPlayers()
                    self.playerConnected = [:]
                    for (playerNumberData, playerData) in data as! [String : [String : Any]] {
                        let playerNumber = Int(playerNumberData)!
                        let playerName = playerData["name"] as! String
                        let playerUUID = playerData["playerUUID"] as! String
                        let playerConnected = (playerData["connected"] as? String) ?? "true"
                        var playerMO = Scorecard.shared.findPlayerByPlayerUUID(playerUUID)
                        if playerMO == nil {
                            // Not found - need to create the player locally
                            let playerDetail = PlayerDetail()
                            playerDetail.name = playerName
                            playerDetail.playerUUID = playerUUID
                            playerDetail.dedupName()
                            playerMO = playerDetail.createMO()
                            Scorecard.shared.requestPlayerThumbnail(from: peer, playerUUID: playerUUID)
                        }
                        self.playerConnected[playerUUID] = (playerConnected == "true")
                        Scorecard.game.player(enteredPlayerNumber: playerNumber).playerMO = playerMO
                        Scorecard.game.player(enteredPlayerNumber: playerNumber).saveMaxScore()
                        if self.purpose == .playing {
                            if playerUUID == self.thisPlayer {
                                self.thisPlayerNumber = playerNumber
                            }
                        }
                    }
                    
                    // Show or refresh game preview
                    if descriptor == "previewPlayers" && (self.activeView == .gamePreview || (self.activeView == .none && self.matchProximity == nil)) {
                        self.present(nextView: .gamePreview, willDismiss: true)
                        stopProcessing = true
                    }
                    
                case "status":
                    if let status = data!["status"] as! String? {
                        if status != self.lastStatus {
                            self.gamePreviewViewController?.showStatus(status: status)
                            self.lastStatus = status
                        }
                    }
                    
                case "cut":
                    if self.activeView == .gamePreview {
                        var preCutCards: [Card] = []
                        let cardNumbers = data!["cards"] as! [Int]
                        for cardNumber in cardNumbers {
                            preCutCards.append(Card(fromNumber: cardNumber))
                        }
                        _ = self.gamePreviewViewController?.executeCut(preCutCards: preCutCards)
                    }
                    
                case "scores", "allscores":
                    
                    let maxRound = Scorecard.shared.processScores(descriptor: descriptor, data: data!)
                    if self.purpose == .sharing {
                        stopProcessing = checkSharedScores(maxRound: maxRound)
                    }
                    
                case "thumbnail":
                    let playerUUID = data!["playerUUID"] as! String
                    let thumbnail = data!["image"] as! String
                    let thumbnailDate = data!["date"] as! String
                    if let playerMO = Scorecard.shared.findPlayerByPlayerUUID(playerUUID) {
                        _ = CoreData.update( updateLogic: {
                            playerMO.thumbnail = NSData(base64Encoded: thumbnail, options: []) as Data?
                            playerMO.thumbnailDate = Utility.dateFromString(thumbnailDate) as Date?
                        })
                        // And notify any views waiting for images
                        NotificationCenter.default.post(name: .playerImageDownloaded, object: self, userInfo: ["playerObjectID": playerMO.objectID])
                    }
                    
                case "deal":
                    // Only ever sent with a hand state
                    if let round = data!["round"] as? Int {
                        if Scorecard.game?.dealHistory[round] == nil {
                            if let dealCards = data!["deal"] as? [[Int]] {
                                let deal = Deal(fromNumbers: dealCards)
                                
                                // Save in history
                                Scorecard.game?.dealHistory[round] = deal
                                
                                // Save for recovery
                                Scorecard.recovery.saveDeal(round: round, deal: deal)
                            }
                        }
                    }
                    
                case "played":
                    _ = Scorecard.shared.processCardPlayed(data: data! as Any as! [String : Any], from: self)
                    
                case "handState":
                    // Updated state to re-sync after a disconnect - should already have a scorepad view controller so just fill in state
                    if self.purpose == .playing {
                        var lastCards: [Card]!
                        var lastToLead: Int!
                        
                        let hands = data!["hands"] as! [String:[String:[Int]]]
                        let thisHand = hands["\(self.thisPlayerNumber!)"]!
                        let cardNumbers = thisHand["cards"]!
                        let hand = Hand(fromNumbers: cardNumbers, sorted: true)
                        let trick = data!["trick"] as! Int
                        let made = data!["made"] as! [Int]
                        let twos = data!["twos"] as! [Int]
                        let trickCards = Hand(fromNumbers: data!["trickCards"] as! [Int]).cards
                        if data!["lastCards"] != nil {
                            lastCards = Hand(fromNumbers: data!["lastCards"] as! [Int]).cards
                        }
                        let toLead = data!["toLead"] as! Int
                        if data!["lastToLead"] != nil && data!["lastToLead"] as! Int >= 0 {
                            lastToLead = data!["lastToLead"] as? Int
                        }
                        let round = data!["round"] as! Int
                        Scorecard.game.maxEnteredRound = round
                        Scorecard.game.selectedRound = Scorecard.game.maxEnteredRound
                        if let data = data!["deal"] as? [String:Any?]? {
                            stopProcessing = self.processQueue(descriptor: "deal", data: data, peer: peer) || stopProcessing
                        }
                        
                        self.setupHandState(hand: hand, round: round, trick: trick, made: made, twos: twos, trickCards: trickCards, toLead: toLead, lastCards: lastCards, lastToLead: lastToLead)
                    }
                    
                case "playHand":
                    // Play the hand
                    if self.purpose == .playing {
                        Scorecard.game.setGameInProgress(true)
                    }
                    self.present(nextView: .hand, willDismiss: true)
                    stopProcessing = true
                    
                default:
                    // Try test messages
                    if !self.checkTestMessages(descriptor: descriptor, data: data, peer: peer) {
                        // Try generic scorecard handler
                        Utility.debugMessage("controller \(self.uuid)", "Trying generic for \(descriptor) from \(peer.playerName!)")
                        Scorecard.shared.didReceiveData(descriptor: descriptor, data: data, from: peer)
                    }
                }
            }
        }
        return stopProcessing
    }
    
    // MARK: - State Delegate handlers ===================================================================== -
    
    internal func stateChange(for peer: CommsPeer, reason: String?) {
        
        Utility.mainThread {
            let currentState = self.currentState(peer: peer)
            var refreshRequired = false
            
            if peer.state != currentState {
                // State changing
                Utility.debugMessage("controller \(self.uuid)", "Connection changing from \(currentState) to \(peer.state)")
                
                switch peer.state {
                case .notConnected:
                    // Disconnected
                    
                    if peer.autoReconnect {
                        self.controllerStateChange(to: .reconnecting)
                        Utility.debugMessage("controller \(self.uuid)", "Trying to reconnect")
                        self.whisper.show("Connection lost. Recovering...")
                    } else {
                        // Remote has disconnected intentionally - go back to home screen and reset recovery
                        self.controllerStateChange(to: .notConnected, startTimers: false)
                        Utility.debugMessage("controller \(self.uuid)", "Intentional disconnect - exit")
                        self.present(nextView: .exit, willDismiss: true)
                    }
                    
                    // Flush the queue
                    self.queue = []
                    
                case .connected:
                    // Connected - send a state refresh request and flag as waiting for it
                    Scorecard.shared.sendRefreshRequest()
                    refreshRequired = true
                    self.whisper.hide("Connection restored")
                    
                case .connecting:
                    // Connecting
                    self.controllerStateChange(to: .connecting)
                    
                default:
                    // Recovering or re-connecting
                    self.controllerStateChange(to: .reconnecting)
                    
                    self.whisper.show("Connection lost. Trying to reconnect...")
                }
                
                if peer.state != .notConnected {
                    // Set framework based on this connection (for reconnect at lower level)
                    self.selectService(proximity: peer.proximity, purpose: peer.purpose)
                    
                    // Don't allow device to timeout
                    UIApplication.shared.isIdleTimerDisabled = true
                }
                
                // Reflect state in data structure
                self.reflectState(peer: peer, refreshRequired: refreshRequired)
            }
        }
    }
    
    private func currentState(peer: CommsPeer) -> CommsConnectionState {
        // Get current state of a player associated with a device
        if let localPeer = self.peerFor(deviceName: peer.deviceName, mode: peer.mode, proximity: peer.proximity) {
            return localPeer.state
        } else {
            return .notConnected
        }
    }
    
    private func connect(peer: CommsPeer, faceTimeAddress: String?) -> Bool {
        var playerName: String!
        var context: [String : String]? = [:]
        
        // Change to connecting (disables timer)
        self.controllerStateChange(to: .connecting)
        
        if self.thisPlayer != nil {
            let playerMO = Scorecard.shared.findPlayerByPlayerUUID(self.thisPlayer)
            playerName = playerMO?.name
        }
        
        self.selectService(proximity: peer.proximity, purpose: peer.purpose)
        
        if faceTimeAddress != nil {
            // Send face time address to remote
            context?["faceTimeAddress"] = faceTimeAddress!
        }
        
        let success = self.clientService!.connect(to: peer, playerUUID: self.thisPlayer, playerName: playerName, context: context, reconnect: true)
        if let availableFound = self.availableFor(peer: peer) {
            if success {
                availableFound.lastConnect = Date()
            }
            availableFound.connecting = success
        }
        if !success {
            self.whisper.show("Error connecting to device", hideAfter: 3.0)
        }
        
        // Do a background sync
        Scorecard.shared.syncBeforeGame()
        
        return success
    }
    
    private func selectService(proximity: CommsConnectionProximity, purpose: CommsPurpose) {
        // Wire up the selected connection
        switch proximity {
        case .nearby:
            self.clientService = self.nearbyClientService
        case .online:
            self.clientService = self.onlineClientService
        default:
            break
        }
        self.purpose = (self.clientService == nil ? nil : purpose)
        Scorecard.shared.setCommsDelegate(self.clientService, purpose: purpose)
        self.setCommsDelegate = true
    }
    
    private func reflectState(peer: CommsPeer, overrideOldState: CommsConnectionState? = nil, refreshRequired: Bool = false) {
        if let availableFound = availableFor(peer: peer) {
            if peer.state != .connecting {
                availableFound.connecting = false
            }
            availableFound.oldState = overrideOldState ?? availableFound.peer.state
            availableFound.peer = peer
            if refreshRequired {
                availableFound.stateRequired = true
            }
            self.delegate?.reflectPeer(deviceName: peer.deviceName, name: peer.playerName!, oldState: availableFound.oldState, state: peer.state, connecting: availableFound.connecting, proximity: peer.proximity, purpose: peer.purpose)
            self.updateStatus(peer: peer)
        }
    }
    
    @objc private func checkConnecting(_ sender: Any? = nil) {
        // Periodically check that a peer that thinks it is connecting has not gone quiescent for more than 3 secs
        Utility.mainThread { [unowned self] in
            for available in self.available {
                if available.connecting {
                    if available.lastConnect?.timeIntervalSinceNow ?? TimeInterval(-4.0) < TimeInterval(-3.0) {
                        Utility.mainThread {
                            Utility.debugMessage("controller \(self.uuid)", "Firing connection timer")
                            self.clientService?.reset()
                        }
                    }
                }
            }
        }
    }
    
    private func updateStatus(peer: CommsPeer) {
        if self.activeView == .gamePreview {
            let personDevice = peer.playerName ?? peer.deviceName
            switch peer.state {
            case .notConnected:
                self.lastStatus = "Disconnected from \(personDevice)"
            case .connecting:
                self.lastStatus = "Connecting to \(personDevice)..."
            case .reconnecting:
                self.lastStatus = "Reconnecting to \(personDevice)..."
            case .connected:
                self.lastStatus = "Waiting for other\n players to connect..."
            default:
                break
            }
        }
        self.gamePreviewViewController?.showStatus(status: self.lastStatus)
    }
    
    // MARK: - Play the hand ======================================================================== -
    
    private func setupHandState(hand: Hand! = nil, round: Int! = nil, trick: Int! = nil, made: [Int]! = nil, twos: [Int]! = nil, trickCards: [Card]! = nil, toLead: Int! = nil, lastCards: [Card]! = nil, lastToLead: Int! = nil) {
        if round != nil {
            Scorecard.game.selectedRound = round
            Scorecard.game.maxEnteredRound = round
        }
        Scorecard.game?.handState = HandState(enteredPlayerNumber: self.thisPlayerNumber, round: Scorecard.game.selectedRound, dealerIs: Scorecard.game.dealerIs, players: Scorecard.game.currentPlayers, trick: trick, made: made, twos: twos, trickCards: trickCards, toLead: toLead, lastCards: lastCards, lastToLead: lastToLead)
        Scorecard.game?.handState.hand = hand
    }
    
    private func playHand() -> HandViewController? {
        var handViewController: HandViewController?
        
        if let parentViewController = self.parentViewController {
            handViewController = Scorecard.shared.playHand(from: parentViewController, appController: self, sourceView: parentViewController.view, animated: true)
        }
        
        return handViewController
    }
    
    private func handComplete() {
        if Scorecard.game!.handState.finished && Scorecard.game.gameComplete() {
            _ = Scorecard.game.save()
            self.present(nextView: .gameSummary)
        } else {
            self.present(nextView: .scorepad)
        }
    }
    
    
    // MARK: - Browser Delegate handlers ===================================================================== -
     
    internal func peerFound(peer: CommsPeer, reconnect: Bool = true) {
        Utility.mainThread {
            Utility.debugMessage("controller \(self.uuid)", "Peer found for \(peer.deviceName)")
            // Check if already got this device - if so disconnect it and replace it
            
            if let index = self.availableIndexFor(peer: peer, checkMode: false) {
                // Already have an entry for this device - re-use it (unless it is online and have one nearby) - but keep old state
                if ( peer.proximity == .nearby || self.available[index].proximity == .online) && peer.state == .notConnected {
                    let oldState = self.available[index].oldState
                    self.available[index] = Available(peer: peer)
                    self.available[index].oldState = oldState
                    self.reflectState(peer: peer, overrideOldState: oldState)
                }
                
            } else if self.controllerState != .reconnecting && (self.matchDeviceName == nil || peer.deviceName == self.matchDeviceName) {
                // New peer - add to list
                let item = self.available.count
                self.available.insert(Available(peer: peer), at: item)
                self.delegate?.addPeer(deviceName: peer.deviceName, name: peer.playerName!, oldState: .notConnected, state: peer.state, connecting: false, proximity: peer.proximity, purpose: peer.purpose, at: item)
            }
        }
        if Config.autoConnectClient || (self.matchDeviceName != nil && peer.deviceName == self.matchDeviceName) {
            // Recovering/reacting to notification and this is the device I'm waiting for
            if !peer.autoReconnect {
                // Not trying to reconnect at a lower level so reconnect here
                if reconnect {
                    // Reconnect unless calling code has not asked us not to
                    
                    // Assume that FaceTime connection had already been sent
                    _ = self.connect(peer: peer, faceTimeAddress: nil)
                    self.reflectState(peer: peer)
                }
            }
        }
    }
    
    internal func peerLost(peer: CommsPeer) {
        Utility.mainThread {
            Utility.debugMessage("controller \(self.uuid)", "Peer lost for \(peer.deviceName)")
            self.removeEntry(peer: peer)
        }
    }
    
    private func removeEntry(peer: CommsPeer) {
        if let item = availableIndexFor(peer: peer, checkMode: false) {
            // Remove entry
            self.available.remove(at: item)
            self.delegate?.removePeer(at: item)
        }
    }
     
    internal func error(_ message: String) {
        self.whisper.show(message, hideAfter: 10.0)
     }
    
    public func connect(row: Int, faceTimeAddress: String) {
        if row < available.count {
            if let peer = available[row].peer {
                if self.connect(peer: peer, faceTimeAddress: faceTimeAddress) {
                    self.lastStatus = ("Connecting to \((peer.playerName ?? peer.deviceName))...")
                    self.present(nextView: .gamePreview, context: ["getPlayers" : false])
                }
            }
            self.reflectState(peer: available[0].peer)
        }
    }

    // MARK: - Sharing state checker ========================================================================= -
    
    private func checkSharedScores(maxRound: Int) -> Bool {
        var stopProcessing = false
        var nextView: ScorecardView
        
        if maxRound > Scorecard.game.maxEnteredRound {
            Scorecard.game.maxEnteredRound = maxRound
            if !Scorecard.game.roundStarted(maxRound) {
                Scorecard.game.selectedRound = max(1, maxRound-1)
            } else {
                Scorecard.game.selectedRound = maxRound
            }
        }
        
        if !Scorecard.game.roundComplete(Scorecard.game.selectedRound) {
            nextView = .roundSummary
        } else if Scorecard.game.selectedRound == Scorecard.game.rounds {
            nextView = .gameSummary
        } else {
            nextView = .scorepad
        }
        
        if nextView != self.activeView {
            self.present(nextView: nextView)
            stopProcessing = true
        } else if nextView == .roundSummary {
            self.refreshRoundSummary()
        }
        
        return stopProcessing
    }
    
    // MARK: - Game Preview Delegate handlers ================================================================ -
    
    internal func gamePreview(isConnected playerMO: PlayerMO) -> Bool {
        return self.playerConnected[playerMO.playerUUID!] ?? true
    }
    
    // MARK: - Show/ refresh other views ======================================================================== -

    private func showGamePreview(getPlayers: Bool = true) -> ScorecardViewController? {
        // Create new view controller
        self.gamePreviewViewController = nil
        var selectedPlayers: [PlayerMO] = []
        if getPlayers {
            selectedPlayers = getSelectedPlayers()
        }
        if let parentViewController = self.parentViewController {
            self.gamePreviewViewController = GamePreviewViewController.show(from: parentViewController, appController: self, selectedPlayers: selectedPlayers, formTitle: "Join a Game", smallFormTitle: "Join", backText: "", delegate: self)
        }
        return self.gamePreviewViewController
    }

    private func refreshGamePreview() {
        let selectedPlayers = self.getSelectedPlayers()
        // Refresh existing view controller
        self.gamePreviewViewController?.selectedPlayers = selectedPlayers
        self.gamePreviewViewController?.refreshPlayers()
    }
    
    private func refreshRoundSummary() {
        self.roundSummaryViewController?.refresh()
    }
    
    private func getSelectedPlayers() -> [PlayerMO] {
        var selectedPlayers: [PlayerMO] = []
        // Reload previous players in recovery mode
        for playerNumber in 1...Scorecard.game.currentPlayers {
            if let playerMO = Scorecard.game.player(enteredPlayerNumber: playerNumber).playerMO {
                selectedPlayers.append(playerMO)
            }
        }
        return selectedPlayers
    }
       
    // MARK: - Create / remove connections ======================================================== -
    
    @objc private func refreshInvites(_ sender: Any? = nil) {
        // Refresh online game invites
        Utility.mainThread { [unowned self] in
            if Scorecard.shared.onlineEnabled && (self.controllerState == .notConnected || self.controllerState == .reconnecting) {
                self.onlineClientService?.checkOnlineInvites(playerUUID: self.thisPlayer)
            }
        }
    }
    
    private func closeConnections() {
        self.nearbyClientService?.stop()
        self.onlineClientService?.stop()
        self.nearbyClientService = nil
        self.onlineClientService = nil
    }
    
    private func createConnections() {
        // Create nearby comms service, take delegates and start listening
        if self.matchProximity == nil || self.matchProximity == .nearby {
            self.nearbyClientService = CommsHandler.client(proximity: .nearby, mode: .broadcast, serviceID: Scorecard.shared.serviceID(), deviceName: Scorecard.deviceName)
            self.nearbyClientService?.stateDelegate = self
            self.nearbyClientService?.dataDelegate = self
            self.nearbyClientService?.browserDelegate = self
            self.nearbyClientService?.start(playerUUID: self.thisPlayer, name: self.thisPlayerName, recoveryMode: self.matchProximity != nil, matchDeviceName: self.matchDeviceName, matchGameUUID: self.matchGameUUID)
        }
        
        // Create online comms service, take delegates and start listening
        if (self.matchProximity == nil || self.matchProximity == .online) {
            self.onlineClientService = CommsHandler.client(proximity: .online, mode: .invite, serviceID: nil, deviceName: Scorecard.deviceName)
            self.onlineClientService?.stateDelegate = self
            self.onlineClientService?.dataDelegate = self
            self.onlineClientService?.browserDelegate = self
            self.onlineClientService?.start(playerUUID: self.thisPlayer, name: self.thisPlayerName, recoveryMode: self.matchProximity != nil, matchDeviceName: self.matchDeviceName, matchGameUUID: self.matchGameUUID)
            self.startCheckInviteTimer()
        }
    }

    // MARK: - Utility Methods ========================================================================= -
   
    private func availableFor(peer: CommsPeer, checkMode: Bool = true) -> Available? {
        return self.available.first(where: { $0.deviceName == peer.deviceName && (!checkMode || ($0.mode == peer.mode && $0.proximity == peer.proximity)) })
    }
    
    private func availableIndexFor(peer: CommsPeer, checkMode: Bool = true) -> Int? {
        return self.available.firstIndex(where: { $0.deviceName == peer.deviceName && (!checkMode || ($0.mode == peer.mode && $0.proximity == peer.proximity)) })
    }
    
    private func peerFor(deviceName: String, mode: CommsConnectionMode, proximity: CommsConnectionProximity) -> CommsPeer? {
        if let available = available.first(where: {$0.deviceName == deviceName && $0.mode == mode && $0.proximity == proximity}) {
            return available.peer
        } else {
            return nil
        }
    }
    
    private func controllerStateChange(to state: ClientAppState, startTimers: Bool = true) {
        if state != self.controllerState {
            Utility.debugMessage("controller \(self.uuid)", "Controller state changing to \(state)")

            self.controllerState = state
            
            if state == .notConnected || state == .reconnecting {
                if startTimers {
                    self.startCheckInviteTimer(interval: (state == .reconnecting ? 1 : 5))
                }
            } else {
                self.stopCheckInviteTimer()
            }
            
            if state == .connecting {
                if startTimers {
                    self.startConnectingTimer()
                }
            } else {
                self.stopConnectingTimer()
            }
            
            self.delegate?.stateChange(to: state)
            
            if state == .finished {
                self.present(nextView: .exit, willDismiss: true)
            } else if state == .notConnected {
                self.present(nextView: .none, willDismiss: true)
            }
        }
    }

    private func startCheckInviteTimer(interval: TimeInterval = 5) {
        self.stopCheckInviteTimer(report: false)
        if self.matchProximity == nil || self.matchProximity == .online {
            Utility.debugMessage("controller \(self.uuid)", "Starting check invite timer")
            self.checkInviteTimer = Timer.scheduledTimer(
                timeInterval: TimeInterval(interval),
                target: self,
                selector: #selector(ClientController.refreshInvites(_:)),
                userInfo: nil,
                repeats: true)
        }
    }
    
    private func stopCheckInviteTimer(report: Bool = true) {
        if let timer = self.checkInviteTimer {
            if report {
                Utility.debugMessage("controller \(self.uuid)", "Stopping check invite timer")
            }
            timer.invalidate()
            self.checkInviteTimer = nil
        }
    }
    
    private func startConnectingTimer() {
        self.stopConnectingTimer(report: false)
        Utility.debugMessage("controller \(self.uuid)", "Starting connecting timer")
        self.connectingTimer = Timer.scheduledTimer(
            timeInterval: TimeInterval(6),
            target: self,
            selector: #selector(ClientController.checkConnecting(_:)),
            userInfo: nil,
            repeats: true)
    }
    
    private func stopConnectingTimer(report: Bool = true) {
        if let timer = self.connectingTimer {
            if report {
                Utility.debugMessage("controller \(self.uuid)", "Stopping connecting timer")
            }
            timer.invalidate()
            self.connectingTimer = nil
        }
    }
    
}

// MARK: - Other Classes =========================================================== -

fileprivate class Available {
    fileprivate var peer: CommsPeer!
    fileprivate var oldState: CommsConnectionState = .notConnected
    fileprivate var connecting = false
    fileprivate var expires: Date?
    fileprivate var inviteUUID: String?
    fileprivate var lastConnect: Date?
    fileprivate var stateRequired = true
    
    fileprivate var isConnected: Bool {
        get {
            return self.state == .connected && !self.stateRequired
        }
    }
    
    fileprivate var state: CommsConnectionState {
        get {
            return self.peer.state
        }
    }
    fileprivate var deviceName: String {
        get {
            return self.peer.deviceName
        }
    }
    fileprivate var mode: CommsConnectionMode {
        get {
            return self.peer.mode
        }
    }
    fileprivate var proximity: CommsConnectionProximity {
        get {
            return self.peer.proximity
        }
    }
    
    init(peer: CommsPeer, expires: Date? = nil, inviteUUID: String? = nil) {
        self.peer = peer
        self.expires = expires
        self.inviteUUID = inviteUUID
    }
}
