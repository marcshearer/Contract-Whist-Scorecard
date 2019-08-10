//
//  ClientViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 27/05/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit

struct QueueEntry {
    let descriptor: String
    let data: [String : Any?]?
    let peer: CommsPeer?
}

enum AppState {
    case notConnected
    case connecting
    case connected
    case waiting
}

class ClientViewController: CustomViewController, UITableViewDelegate, UITableViewDataSource, CommsBrowserDelegate, CommsStateDelegate, CommsDataDelegate, GamePreviewDelegate, UIPopoverPresentationControllerDelegate {

    // MARK: - Class Properties ======================================================================== -
    
    // Main state properties
    private let scorecard = Scorecard.shared
    private var recovery: Recovery!
    private weak var selectionViewController: SelectionViewController!
    private weak var scorepadViewController: ScorepadViewController!
    private weak var gamePreviewViewController: GamePreviewViewController!
    private var hostController: HostController!
    public let transition = FadeAnimator()

    // Properties to pass state to / from segues
    public var returnSegue = ""
    public var backText = ""
    public var backImage = "back"
    public var formTitle: String!
    public var commsPurpose: CommsConnectionPurpose!
    public var matchDeviceName: String!

    // Queue
    private var queue: [QueueEntry] = []

    // Local class variables
    
    private var available: [Available] = []
    private var rounds = 0
    private var cards: [Int] = []
    private var bounce = false
    private var bonus2 = false
    private var suits: [Suit] = []
    private var alertController: UIAlertController!
    public var thisPlayer: String!
    public var thisPlayerName: String!
    private var thisPlayerNumber: Int!

    private var idleTimer: Timer!
    private var connectingTimer: Timer!
    private var finishing = false

    private var newGame: Bool!
    private var gameOver = false
    private var gameUUID: String!
    private var peerSection: Int! = 0
    private var hostSection: Int! = 1
    private var clientHandlerObserver: NSObjectProtocol?
    private var multipeerClient: MultipeerClientService?
    private var rabbitMQClient: RabbitMQClientService?
    private var clientService: CommsClientHandlerDelegate?
    private var appState: AppState!
    private var invite: Invite!
    private var recoveryMode = false
    private let whisper = Whisper()
    private var playerConnected: [String : Bool] = [:]
    
    // MARK: - IB Outlets ============================================================================== -
    
    @IBOutlet weak var titleBar: UINavigationItem!
    @IBOutlet weak var finishButton: RoundedButton!
    @IBOutlet weak var clientTableView: UITableView!
    @IBOutlet private weak var thisPlayerThumbnail: ThumbnailView!
    @IBOutlet private weak var thisPlayerNameLabel: UILabel!
    @IBOutlet private weak var thisPlayerThumbnailWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var changePlayerButton: UIButton!
    
    // MARK: - IB Unwind Segue Handlers ================================================================ -

    @IBAction func hideClientScorepad(segue:UIStoryboardSegue) {
        // Manual return - disconnect and refresh
        self.restart()
    }
    
    @IBAction private func linkFinishGame(segue:UIStoryboardSegue) {
        if let segue = segue as? UIStoryboardSegueWithCompletion {
            segue.completion = {
                self.exitClient()
            }
        }
    }
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func finishPressed(_ sender: RoundedButton) {
        exitClient(resetRecovery: !self.scorecard.gameInProgress)
    }
    
    @IBAction func rightSwipe(recognizer:UISwipeGestureRecognizer) {
        if recognizer.state == .ended {
            finishPressed(finishButton)
        }
    }
    
    @IBAction func changePlayerPressed(_ sender: UIButton) {
        self.selectionViewController = SelectionViewController.show(from: self, existing: self.selectionViewController, mode: .single, thisPlayer: self.thisPlayer, thisPlayerFrame: self.thisPlayerThumbnail.frame, formTitle: "Choose Player", backText: "", backImage: "cross white", preCompletion: { (playerMO) in
            self.returnPlayers(playerMO: playerMO)
        })
    }
    
    // MARK: - View Overrides ========================================================================== -

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Avoid resuming game
        recovery = scorecard.recovery
        
        // Set not connected
        self.appStateChange(to: .notConnected)
        
        // Set finish button
        finishButton.setImage(UIImage(named: self.backImage), for: .normal)
        finishButton.setTitle(self.backText)
        
        // Stop any existing sharing activity
        self.scorecard.stopSharing()
        
        // Set recovery mode
        self.recoveryMode = self.scorecard.recoveryMode
        
        // Update instructions / title
        if Utility.isSimulator {
            self.titleBar.title = Scorecard.deviceName
        } else {
            self.titleBar.title = self.formTitle
        }

        // Set up sections
        if self.commsPurpose == .playing {
            peerSection = 0
            hostSection = 1
        } else {
            peerSection = 0
            hostSection = -1
        }
        
        // Get this player
        if self.commsPurpose == .playing {
            if self.recoveryMode {
                // Recovering - use same player
                self.thisPlayer = self.scorecard.recoveryConnectionEmail
                self.thisPlayerName = self.scorecard.findPlayerByEmail(self.thisPlayer)?.name
                self.matchDeviceName = self.scorecard.recoveryConnectionDevice
                if self.scorecard.recoveryOnlineMode == .invite {
                    if self.thisPlayer == nil {
                        self.alertMessage("Error recovering game", okHandler: {
                            self.exitClient()
                        })
                        return
                    }
                }
            }
            if self.thisPlayer == nil || self.matchDeviceName == nil {
                // Not got player and device name from recovery - use default
                var defaultPlayer: String!
                if self.scorecard.onlineEnabled {
                    defaultPlayer = self.scorecard.settingOnlinePlayerEmail
                } else {
                    defaultPlayer = self.scorecard.defaultPlayerOnDevice
                }
                if defaultPlayer != nil {
                    let playerMO = scorecard.findPlayerByEmail(defaultPlayer)
                    if playerMO != nil {
                        self.thisPlayer = defaultPlayer
                        self.thisPlayerName = playerMO!.name
                    } else {
                        defaultPlayer = nil
                    }
                }
                if defaultPlayer == nil {
                    let playerMO = self.scorecard.playerList.min(by: {($0.localDateCreated! as Date) < ($1.localDateCreated! as Date)})
                    self.thisPlayer = playerMO!.email
                    self.thisPlayerName = playerMO!.name
                }
            }
        }
        
        self.createConnections()
        
        self.available = []
        self.scorecard.sendScores = true
        self.scorecard.commsHandlerMode = .none
        
        // Clear hand state
        self.scorecard.handState = nil
        
        // Set observer to detect UI handler completion
        clientHandlerObserver = self.handlerCompleteNotification()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.showThisPlayer()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        scorecard.reCenterPopup(self)
        self.view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.clientTableView.reloadData()
    }
    
    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        
        // Play sound
        self.alertSound()
        
        // Reset connections
        self.closeConnections()
        self.available = []
        self.appStateChange(to: .notConnected)
        self.refreshStatus()
        self.createConnections()
    }

    // MARK: - Data Delegate Handlers ==================================================== -
    
    internal func didReceiveData(descriptor: String, data: [String : Any?]?, from peer: CommsPeer) {
        Utility.mainThread { [unowned self] in
            self.clientService?.debugMessage("\(descriptor) received from \(peer.deviceName)")
            self.queue.append(QueueEntry(descriptor: descriptor, data: data, peer: peer))
        }
        self.processQueue()
    }
    
    private func processQueue() {
        
        Utility.mainThread { [unowned self] in
            var queueText = ""
            for element in self.queue {
                queueText = queueText + " " + element.descriptor
            }
            
            while self.queue.count > 0 && self.scorecard.commsHandlerMode == .none {
                
                // Pop top element off the queue
                let descriptor = self.queue.first!.descriptor
                let data = self.queue.first!.data
                let peer = self.queue.first!.peer!
                self.queue.removeFirst()

                // Set state to connected unless receive wait
                if descriptor != "wait" {
                    self.appStateChange(to: .connected)
                }
                self.changePlayerAvailable()

                switch descriptor {
                case "wait":
                    // No game running - need to wait for it to start
                    if self.appState != .waiting {
                        self.dismissAll(completion: {
                            self.appStateChange(to: .waiting)
                            self.reflectState(peer: peer)
                        })
                    }
                   
                case "settings":
                    self.rounds = data!["rounds"] as! Int
                    self.cards = data!["cards"] as! [Int]
                    self.bounce = data!["bounce"] as! Bool
                    self.bonus2 = data!["bonus2"] as! Bool
                    let suitStrings = data!["suits"] as! [String]
                    self.suits = []
                    for suitString in suitStrings {
                        self.suits.append(Suit(fromString: suitString))
                    }
                    let gameUUID = data!["gameUUID"] as! String
                    if self.gameUUID == nil || self.gameUUID != gameUUID {
                        self.newGame = true
                    } else {
                        self.newGame = false
                    }
                    self.gameUUID = gameUUID
                    self.thisPlayerNumber = nil
                    self.scorecard.maxEnteredRound = data!["round"] as! Int
                    self.scorecard.selectedRound = self.scorecard.maxEnteredRound
                    
                case "dealer":
                    self.scorecard.dealerIs = data!["dealer"] as! Int
                    if self.gamePreviewViewController != nil {
                        for playerNumber in 1...self.scorecard.currentPlayers {
                            self.gamePreviewViewController.showDealer(playerNumber: playerNumber, forceHide: true)
                        }
                        self.gamePreviewViewController.showCurrentDealer()
                    }
                    
                case "play", "players":
                    self.scorecard.setCurrentPlayers(players: data!.count)
                    for playerNumber in 1...self.scorecard.currentPlayers {
                        self.scorecard.enteredPlayer(playerNumber).reset()
                    }
                    self.playerConnected = [:]
                    for (playerNumberData, playerData) in data as! [String : [String : Any]] {
                        let playerNumber = Int(playerNumberData)!
                        let playerName = playerData["name"] as! String
                        let playerEmail = playerData["email"] as! String
                        let playerConnected = (playerData["connected"] as? String) ?? "true"
                        var playerMO = self.scorecard.findPlayerByEmail(playerEmail)
                        if playerMO == nil {
                            // Not found - need to create the player locally
                            let playerDetail = PlayerDetail()
                            playerDetail.name = playerName
                            playerDetail.email = playerEmail
                            playerDetail.dedupName()
                            playerMO = playerDetail.createMO()
                            self.scorecard.requestPlayerThumbnail(from: peer, playerEmail: playerEmail)
                        }
                        self.playerConnected[playerEmail] = (playerConnected == "true")
                        self.scorecard.enteredPlayer(playerNumber).playerMO = playerMO
                        self.scorecard.enteredPlayer(playerNumber).reset()
                        self.scorecard.enteredPlayer(playerNumber).saveMaxScore()
                        if self.commsPurpose == .playing {
                            if playerEmail == self.thisPlayer {
                                self.thisPlayerNumber = playerNumber
                            }
                        }
                    }
                    if descriptor == "players" {
                        self.showGamePreview()
                    }
                    if descriptor == "play" {
                        if self.scorecard.isViewing && self.scorepadViewController != nil {
                            // Need to clear grid just in case less data now than there was
                            self.scorepadViewController.reloadScorepad()
                        
                        }
                        self.queue.insert(QueueEntry(descriptor: "playHand", data: nil, peer: peer), at: 0)
                    }
                    
                case "cut":
                    if self.gamePreviewViewController != nil {
                        var preCutCards: [Card] = []
                        let cardNumbers = data!["cards"] as! [Int]
                        for cardNumber in cardNumbers {
                            preCutCards.append(Card(fromNumber: cardNumber))
                        }
                        _ = self.gamePreviewViewController.executeCut(preCutCards: preCutCards)
                    }
                
                case "scores", "allscores":
                    
                    self.gameOver = false
                    let gameWasOver = self.scorecard.gameComplete(rounds: self.rounds)
                    
                    // Avoid echo
                    self.scorecard.sendScores = false
                    var maxRound = self.scorecard.processScores(descriptor: descriptor, data: data!, bonus2: self.bonus2)
                    self.scorecard.sendScores = true
                    if self.scorecard.entryPlayer(self.scorecard.currentPlayers).score(maxRound) != nil {
                        // Current round all finished
                        if maxRound == self.rounds {
                            // This is the last round - end of the game - show game summary
                            self.gameOver = true
                        } else {
                            // Move to the next round
                            maxRound += 1
                        }
                    }
                    
                    if !self.gameOver {
                        // Update dealer and advance round
                        if self.scorepadViewController != nil && self.scorecard.maxEnteredRound > 0 {
                            self.scorepadViewController.highlightCurrentDealer(false)
                        }
                        self.scorecard.selectedRound = min(maxRound, self.rounds)
                        self.scorecard.maxEnteredRound = max(1, self.scorecard.selectedRound)
                        if self.scorepadViewController != nil {
                            self.scorepadViewController.highlightCurrentDealer(true)
                        }
                    }
                    
                    if self.commsPurpose == .sharing {
                        // Queue game / round summary
                        var summaryDescriptor: String
                        if self.gameOver {
                            summaryDescriptor = "gameSummary"
                        } else {
                            summaryDescriptor = "roundSummary"
                        }
                        self.queue.insert(QueueEntry(descriptor: summaryDescriptor, data: nil, peer: peer), at: 0)
                    } else if self.commsPurpose == .playing {
                        if self.scorecard.gameComplete(rounds: self.rounds) && !gameWasOver {
                            // Game just completed - show summary
                            self.queue.insert(QueueEntry(descriptor: "gameSummary", data: nil, peer: peer), at: 0)
                        }
                    }
                    
                case "thumbnail":
                    let email = data!["email"] as! String
                    let thumbnail = data!["image"] as! String
                    let thumbnailDate = data!["date"] as! String
                    if let playerMO = self.scorecard.findPlayerByEmail(email) {
                        _ = CoreData.update( updateLogic: {
                            playerMO.thumbnail = NSData(base64Encoded: thumbnail, options: []) as Data?
                            playerMO.thumbnailDate = Utility.dateFromString(thumbnailDate) as Date?
                        })
                        // And notify any views waiting for images
                        NotificationCenter.default.post(name: .playerImageDownloaded, object: self, userInfo: ["playerObjectID": playerMO.objectID])
                    }
                    
                case "deal":
                    if let round = data!["round"] as? Int {
                        if let dealCards = data!["deal"] as? [[Int]] {
                            let deal = Deal(fromNumbers: dealCards)
                            let hand = deal.hands[self.thisPlayerNumber - 1].copy() as! Hand
                            self.clientService?.debugMessage("Hand: \(hand.toString())")
                            self.playHand(peer: peer, dismiss: self.newGame, hand: hand)
                            self.newGame = false
                            
                            // Save in history
                            self.scorecard.dealHistory[round] = deal
                            
                            // Save for recovery
                            self.recovery.saveDeal(round: round, deal: deal)
                        }
                    }
                                       
                case "played":
                    _ = self.scorecard.processCardPlayed(data: data! as Any as! [String : Any])
                    
                case "handState":
                    // Updated state to re-sync after a disconnect - should already have a scorepad view controller so just fill in state
                    if self.commsPurpose == .playing {
                        var lastCards: [Card]!
                        var lastToLead: Int!
                        let cardNumbers = data!["cards"] as! [Int]
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
                        
                        self.playHand(peer: peer, dismiss: true, hand: hand, round: round, trick: trick, made: made, twos: twos, trickCards: trickCards, toLead: toLead, lastCards: lastCards, lastToLead: lastToLead)
                    }
                    
                // Special cases which are not transmitted but added to queue locally
                    
                case "playHand":
                    // Clear any previous games and then play the hand
                    if self.commsPurpose == .playing {
                        self.scorecard.setGameInProgress(true)
                    }
                    self.playHand(peer: peer, dismiss: self.newGame)
                    
                case "roundSummary":
                    self.refreshRoundSummary()
                    
                case "gameSummary":
                    self.showGameSummary()
                    
                default:
                    self.checkTestMessages(descriptor: descriptor, data: data, peer: peer)
                }
            }
        }
    }
    
    private func showGamePreview() {
        if self.scorepadViewController == nil {
            var selectedPlayers: [PlayerMO] = []
            for playerNumber in 1...self.scorecard.currentPlayers {
                if let playerMO = self.scorecard.enteredPlayer(playerNumber).playerMO {
                    selectedPlayers.append(playerMO)
                }
            }
            if self.gamePreviewViewController == nil {
                self.dismissAll {
                    self.gamePreviewViewController = GamePreviewViewController.show(from: self, selectedPlayers: selectedPlayers, title: "Join a Game", backText: "", delegate: self)
                }
            } else {
                self.gamePreviewViewController.selectedPlayers = selectedPlayers
                self.gamePreviewViewController.refreshPlayers()
            }
        }
    }
    
    private func hideGamePreview(completion: (()->())? = nil) {
        self.gamePreviewViewController.dismiss(animated: true, completion: completion)
        self.gamePreviewViewController = nil
    }
    
    private func playHand(peer: CommsPeer, dismiss: Bool = false, hand: Hand! = nil, round: Int! = nil, trick: Int! = nil, made: [Int]! = nil, twos: [Int]! = nil, trickCards: [Card]! = nil, toLead: Int! = nil, lastCards: [Card]! = nil, lastToLead: Int! = nil) {
        
        if self.commsPurpose == .sharing || (self.thisPlayerNumber != nil && hand != nil) {
            if self.available.firstIndex(where: { $0.deviceName == peer.deviceName && $0.framework == peer.framework}) != nil {
                if !dismiss && self.commsPurpose == .playing && self.scorepadViewController != nil {
                    self.scorecard.commsHandlerMode = .playHand
                    self.scorecard.handState.hand = hand
                    self.scorecard.playHand(from: self.scorepadViewController, sourceView: self.scorepadViewController.scorepadView)
                } else {
                    // Need to start a new scorecard?
                    if dismiss {
                        self.dismissAll(completion: {
                            self.playHandScorecard(peer: peer, hand: hand, round: round, trick: trick, made: made, twos: twos, trickCards: trickCards, toLead: toLead, lastCards: lastCards, lastToLead: lastToLead)
                        })
                    } else if self.scorepadViewController == nil {
                        self.playHandScorecard(peer: peer, hand: hand, round: round, trick: trick, made: made, twos: twos, trickCards: trickCards, toLead: toLead, lastCards: lastCards, lastToLead: lastToLead)
                    }
                }
            }
        }
        processQueue()
    }
    
    private func playHandScorecard(peer: CommsPeer, hand: Hand!, round: Int!, trick: Int!, made: [Int]!, twos: [Int]!, trickCards: [Card]!, toLead: Int!, lastCards: [Card]!, lastToLead: Int! = nil) {
        var mode: CommsHandlerMode = .scorepad
        if self.commsPurpose == .playing {
            if round != nil {
                self.scorecard.selectedRound = round
                self.scorecard.maxEnteredRound = round
            }
            self.scorecard.handState = HandState(enteredPlayerNumber: self.thisPlayerNumber, round: self.scorecard.selectedRound, dealerIs: self.scorecard.dealerIs, players: self.scorecard.currentPlayers, rounds: self.rounds, cards: self.cards, bounce: self.bounce, bonus2: self.bonus2, suits: self.suits, trick: trick, made: made, twos: twos, trickCards: trickCards, toLead: toLead, lastCards: lastCards, lastToLead: lastToLead)
            self.scorecard.handState.hand = hand
            mode = .playHand
        }
        self.scorecard.commsHandlerMode = mode
        self.scorecard.recoveryMode = false
        self.recoveryMode = true
        self.performSegue(withIdentifier: "showClientScorepad", sender: self)
    }
    
    // MARK: - Game Preview Delegate handlers ================================================================ -
    
    internal func gamePreviewCompletion() {
        self.disconnectPressed()
        self.gamePreviewViewController = nil
    }
    
    internal func gamePreview(isConnected playerMO: PlayerMO) -> Bool {
        return self.playerConnected[playerMO.email!] ?? true
    }
    
    // MARK: - Browser Delegate handlers ===================================================================== -
    
    internal func peerFound(peer: CommsPeer) {
        Utility.mainThread { [unowned self] in
            Utility.debugMessage("client", "Peer found for \(peer.deviceName)")
            // Check if already got this device - if so disconnect it and replace it

            if let index = self.available.firstIndex(where: { $0.deviceName == peer.deviceName && $0.peer.framework == peer.framework }) {
                // Already have an entry for this device - re-use it (unless showing as 'Disconnected')
                
                if peer.state != .notConnected || self.available[index].oldState != .notConnected {
                    self.available[index].peer = peer
                    
                    // Just mark as disconnected and wait for user to reconnect
                    self.reflectState(peer: peer)
                }
                
            } else {
                // New peer - add to list
                self.clientTableView.beginUpdates()
                self.available.append(Available(peer: peer))
                if self.available.count == 1 {
                    // Need to remove previous placeholder and refresh hosting options
                    self.clientTableView.deleteRows(at: [IndexPath(row: 0, section: self.peerSection)], with: .automatic)
                    for row in 0...1 {
                        self.clientTableView.reloadRows(at: [IndexPath(row: row, section: self.hostSection)], with: .automatic)
                    }
                }
                self.clientTableView.insertRows(at: [IndexPath(row: self.available.count - 1, section: self.peerSection)], with: .automatic)
                self.clientTableView.endUpdates()
            }
            if self.matchDeviceName != nil && peer.deviceName == self.matchDeviceName {
                // Recovering/reacting to notification and this is the device I'm waiting for!
                self.checkFaceTime(peer: peer, completion: { (faceTimeAddress) in
                    _ = self.connect(peer: peer, faceTimeAddress: faceTimeAddress)
                    self.reflectState(peer: peer)
                })
            }
        }
    }
    
    internal func peerLost(peer: CommsPeer) {
        Utility.mainThread { [unowned self] in
            self.removeEntry(peer: peer)
        }
    }
    
    internal func error(_ message: String) {
       self.whisper.show(message, hideAfter: 10.0)
    }
    
    // MARK: - State Delegate handlers ===================================================================== -
    
    internal func stateChange(for peer: CommsPeer, reason: String?) {
        Utility.mainThread { [unowned self] in
            let currentState = self.currentState(peer: peer)
            Utility.debugMessage("client", "Changing from \(currentState) to \(peer.state)")
            if peer.state == .notConnected {
                self.appStateChange(to: .notConnected)
                self.changePlayerAvailable()
                self.dismissAll(reason != nil && reason != "" , reason: reason ?? "", completion: {
                    self.clientService?.start(email: self.thisPlayer, name: self.thisPlayerName)
                    self.removeEntry(peer: peer)
                    UIApplication.shared.isIdleTimerDisabled = false
                })
            } else {
                self.changePlayerAvailable()
                if peer.state == .connected {
                    // Can dismiss any whisper
                    self.whisper.hide()
                } else if peer.state == .reconnecting {
                    self.whisper.show("Connection lost. Trying to reconnect...")
                }
                
                if peer.state != .recovering {
                    self.appStateChange(to: .waiting)
                }
                // Set framework based on this connection (for reconnect at lower level)
                self.selectFramework(framework: peer.framework)
                self.reflectState(peer: peer)
                UIApplication.shared.isIdleTimerDisabled = true
                if peer.state == .connected && currentState != .connected && self.scorecard.gameInProgress {
                    // Get up-to-date
                    self.scorecard.sendRefreshRequest(to: peer)
                }
            }
            // Update whisper
            if currentState != peer.state {
                if (peer.state == .notConnected && peer.autoReconnect) || peer.state == .recovering {
                    self.whisper.show("Connection lost. Recovering...")
                }
            }
            if peer.state == .connected {
                self.whisper.hide("Connection restored")
            }
        }
    }
   
    // MARK: - Helper routines ===================================================================== -
    
    private func restart() {
        self.scorepadViewController = nil
        self.clientService?.stop()
        self.clientService?.start(email: self.thisPlayer, name: self.thisPlayerName)
        self.available = []
        self.clientTableView.reloadData()
        self.appStateChange(to: .notConnected)
        self.changePlayerAvailable()
        scorecard.reset()
        scorecard.setGameInProgress(false)
    }
    
    @objc private func refreshInvites(_ sender: Any? = nil) {
        // Refresh online game invites
        if sender != nil {
            Utility.debugMessage("client", "Timer")
        }
        if self.scorecard.onlineEnabled && self.appState == .notConnected {
            self.rabbitMQClient?.stop()
            self.rabbitMQClient?.start(email: self.thisPlayer, name: self.thisPlayerName, recoveryMode: self.recoveryMode)
            self.clientTableView.reloadData()
        }
    }
    
    private func closeConnections() {
        self.multipeerClient?.stop()
        self.rabbitMQClient?.stop()
    }
    
    private func createConnections() {
        // Create nearby comms service, take delegates and start listening
        if !self.recoveryMode || self.scorecard.recoveryOnlineMode == .broadcast {
            self.multipeerClient = MultipeerClientService(purpose: self.commsPurpose, serviceID: self.scorecard.serviceID(self.commsPurpose), deviceName: Scorecard.deviceName)
            self.multipeerClient?.stateDelegate = self
            self.multipeerClient?.dataDelegate = self
            self.multipeerClient?.browserDelegate = self
            self.multipeerClient?.start(email: self.thisPlayer, name: self.thisPlayerName, recoveryMode: self.recoveryMode, matchDeviceName: self.matchDeviceName)
        }
        
        // Create online comms service, take delegates and start listening
        if self.commsPurpose == .playing && self.scorecard.onlineEnabled && (!self.recoveryMode || self.scorecard.recoveryOnlineMode == .invite) {
            self.rabbitMQClient = RabbitMQClientService(purpose: self.commsPurpose, serviceID: nil, deviceName: Scorecard.deviceName)
            self.rabbitMQClient?.stateDelegate = self
            self.rabbitMQClient?.dataDelegate = self
            self.rabbitMQClient?.browserDelegate = self
            self.rabbitMQClient?.start(email: self.thisPlayer, name: self.thisPlayerName, recoveryMode: self.recoveryMode, matchDeviceName: self.matchDeviceName)
        }
    }
    
    private func connect(peer: CommsPeer, faceTimeAddress: String?) -> Bool {
        var playerName: String!
        var context: [String : String]? = [:]
        
        // Change to connecting (disables timer)
        self.appStateChange(to: .connecting)
        
        if self.thisPlayer != nil {
            let playerMO = scorecard.findPlayerByEmail(self.thisPlayer)
            playerName = playerMO?.name
        }
        
        self.selectFramework(framework: peer.framework)
        
        if faceTimeAddress != nil {
            // Send face time address to remote
            context?["faceTimeAddress"] = faceTimeAddress!
        }
        
        if self.clientService!.connect(to: peer, playerEmail: self.thisPlayer, playerName: playerName, context: context, reconnect: true) {
            if let index = self.available.firstIndex(where: { $0.deviceName == peer.deviceName && $0.peer.framework == peer.framework }) {
                available[index].lastConnect = Date()
            }
        } else {
            self.whisper.show("Error connecting to device", hideAfter: 3.0)
            return false
        }
        
        return true
    }
    
    private func selectFramework(framework: CommsConnectionFramework) {
        // Wire up the selected connection
        switch framework {
        case .multipeer:
            self.clientService = self.multipeerClient
        case .rabbitMQ:
            self.clientService = self.rabbitMQClient
        default:
            break
        }
        self.scorecard.commsDelegate = self.clientService
    }
    
    private func reflectState(peer: CommsPeer) {
        if let combinedIndex = available.firstIndex(where: {$0.deviceName == peer.deviceName && $0.framework == peer.framework}) {
            let availableFound = self.available[combinedIndex]
            if peer.state != .connecting {
                availableFound.connecting = false
            }
            availableFound.oldState = availableFound.peer.state
            availableFound.peer = peer
            self.refreshStatus()
        }
    }

    private func currentState(peer: CommsPeer) -> CommsConnectionState {
        // Get current state of a player associated with a device
        if let combinedIndex = available.firstIndex(where: {$0.deviceName == peer.deviceName && $0.framework == peer.framework}) {
            return self.available[combinedIndex].peer.state
        } else {
            return .notConnected
        }
    }
    
    @objc private func checkConnecting(_ sender: Any? = nil) {
        // Periodically check that a peer that thinks it is connecting has not gone quiescent for more than 10 secs
        
        for available in self.available {
            if available.connecting {
                if available.lastConnect?.timeIntervalSinceNow ?? TimeInterval(-11.0) < TimeInterval(-10.0) {
                    Utility.mainThread {
                        self.clientService?.reset()
                    }
                }
            }
        }
    }
    
    // MARK: - TableView Overrides ===================================================================== -
    
    internal func numberOfSections(in tableView: UITableView) -> Int {
        if commsPurpose == .playing {
            return 2
        } else {
            return 1
        }
    }
    
    internal func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case peerSection:
            return max(1, available.count)
        case hostSection:
            return 2
        default:
            return 0
        }
    }
    
    internal func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case hostSection:
            return 76
        default:
            return 0
        }
    }
    
    internal func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == hostSection {
            let headerView = UITableViewHeaderFooterView(frame: CGRect(origin: CGPoint(), size: CGSize(width: tableView.frame.width, height: 76.0)))
            let width: CGFloat = 150.0
            let button = AngledButton(frame: CGRect(x: (headerView.frame.width - width) / 2.0, y: 40.0, width: width, height: 30))
            button.setTitle("Host a Game")
            button.fillColor = Palette.roomInterior
            button.strokeColor = Palette.roomInterior
            button.normalTextColor = Palette.roomInteriorText
            headerView.backgroundView = UIView()
            headerView.addSubview(button)
            return headerView
        } else {
            return nil
        }
    }
    
    internal func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case self.peerSection:
            // List of remote peers
            return 100
            
        case self.hostSection:
            // Hosting options
            return 80
            
        default:
            return 0
        }
    }
    
    internal func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: ClientTableCell!
        
        switch indexPath.section {
        case self.peerSection:
            // List of remote peers
            
            cell = tableView.dequeueReusableCell(withIdentifier: "Service Cell", for: indexPath) as? ClientTableCell
            cell.hexagonLayer?.removeFromSuperlayer()
            
            if available.count == 0 {
                
                cell.serviceLabel.textColor = Palette.text
                cell.serviceLabel.text = "There are no other devices currently offering to host a game for you to join"
                cell.serviceLabel.font = UIFont.systemFont(ofSize: 18.0, weight: .regular)
                
            } else {
                
                let frame = CGRect(x: 40.0, y: cell.serviceButton.frame.midY, width: cell.frame.width - (2.0 * 40), height: cell.frame.height - cell.serviceButton.frame.midY - 2.0)
                cell.hexagonLayer = Polygon.hexagonFrame(in: cell, frame: frame, strokeColor: Palette.tableTop, lineWidth: 3.5, radius: 10.0)
                
                let availableFound = self.available[indexPath.row]
                let name = availableFound.peer.playerName!
                let state = availableFound.state
                let oldState = availableFound.oldState
                var serviceText: String
                
                switch state {
                case .notConnected:
                    if oldState != .notConnected {
                        serviceText = "\(name) has disconnected"
                    } else if self.commsPurpose == .sharing {
                        serviceText = "View \(name)'s scorecard"
                    } else if availableFound.connecting {
                        serviceText = "Connecting to \(name)..."
                    } else {
                        serviceText = "Join \(name)'s game"
                    }
                case .connected, .recovering:
                    serviceText = "Connected to \(name). Waiting to start..."
                case .connecting:
                    if self.recoveryMode {
                        serviceText = "Trying to reconnect to \(name)..."
                    } else {
                        serviceText = "Connecting to \(name)..."
                    }
                case .reconnecting:
                    serviceText = "Trying to reconnect to \(name)"
                }
                cell.serviceLabel.font = UIFont.systemFont(ofSize: 18.0, weight: .bold)
                
                cell.serviceButton.addTarget(self, action: #selector(ClientViewController.selectPeerSelector(_:)), for: UIControl.Event.touchUpInside)
                cell.serviceButton.tag = indexPath.row

                cell.serviceLabel.textColor = Palette.tableTop
                cell.serviceLabel.text = serviceText
            }
            
        case hostSection:
            // Hosting options
            
            cell = tableView.dequeueReusableCell(withIdentifier: "Host Cell", for: indexPath) as? ClientTableCell
            cell.hexagonLayer?.removeFromSuperlayer()
           
            let frame = CGRect(x: 40.0, y: 4.0, width: cell.frame.width - (2.0 * 40), height: cell.frame.height - 8.0)
            cell.hexagonLayer = Polygon.hexagonFrame(in: cell, frame: frame, strokeColor: Palette.roomInterior.withAlphaComponent((self.available.count == 0 ? 1.0 : 1.0)), lineWidth: (self.available.count == 0 ? 2.0 : 1.0), radius: 10.0)
            
            cell.serviceLabel.textColor = Palette.roomInterior
            let hostText = NSMutableAttributedString()
            let normalText = [NSAttributedString.Key.foregroundColor: Palette.roomInterior.withAlphaComponent((self.available.count == 0 ? 1.0 : 1.0))]
            var boldText: [NSAttributedString.Key : Any] = normalText
            boldText[NSAttributedString.Key.font] = UIFont.systemFont(ofSize: 18.0, weight: .black)
            switch indexPath.row {
            case 0: 
                hostText.append(NSMutableAttributedString(string: "Host a", attributes: normalText))
                hostText.append(NSMutableAttributedString(string: " local ", attributes: boldText))
                hostText.append(NSMutableAttributedString(string: "bluetooth game for nearby players", attributes: normalText))
            case 1:
                hostText.append(NSMutableAttributedString(string: "Host an", attributes: normalText))
                hostText.append(NSMutableAttributedString(string: " online ", attributes: boldText))
                hostText.append(NSMutableAttributedString(string: "game to play over the internet", attributes: normalText))
            default:
                break
            }
            cell.serviceLabel.attributedText = hostText
            
        default:
            break
        }
        
       return cell!
    }
    
    internal func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        switch indexPath.section {
        case peerSection:
            if self.available.count == 0 {
                return nil
            } else {
                let availableFound = self.available[indexPath.row]
                if (appState == .notConnected && availableFound.state == .notConnected) && indexPath.section == self.peerSection {
                    return indexPath
                } else {
                    return nil
                }
            }
        case hostSection:
            return indexPath
        default:
            return nil
        }
    }
    
    internal func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        switch indexPath.section {
        case self.peerSection:
            self.selectPeer(indexPath.row)
        case self.hostSection:
            var mode: ConnectionMode
            // TODO Need to limit what is shown to settings
            switch indexPath.row {
            case 0:
                mode = .nearby
            default:
                mode = .online
            }
            
            self.clientService?.stop()
            self.stopIdleTimer()
            if self.hostController == nil {
                self.hostController = HostController(from: self)
            }
            self.hostController.start(mode: mode, playerEmail: self.thisPlayer, completion: {
                self.restart()
            })
            
        default:
            break
        }
    }
    
    @objc private func selectPeerSelector(_ sender: UIButton) {
        self.selectPeer(sender.tag)
    }
    
    private func selectPeer(_ row: Int) {
        let availableFound = available[row]
        availableFound.connecting = true
        self.refreshStatus()
        
        self.checkFaceTime(peer: availableFound.peer, completion: { (faceTimeAddress) in
            if !self.connect(peer: availableFound.peer, faceTimeAddress: faceTimeAddress) {
                availableFound.connecting = false
            }
            self.refreshStatus()
        })
    }
    
    private func checkFaceTime(peer: CommsPeer, completion: @escaping (String?)->()) {
        if peer.proximity == .online && (self.scorecard.settingFaceTimeAddress ?? "") != "" && Utility.faceTimeAvailable() {
            self.alertDecision("\nWould you like the host to call you back on FaceTime at '\(self.scorecard.settingFaceTimeAddress!)'?\n\nNote that this will make this address visible to the host",
                title: "FaceTime",
                okButtonText: "Yes",
                okHandler: {
                    completion(self.scorecard.settingFaceTimeAddress)
            },
                cancelButtonText: "No",
                cancelHandler: {
                    completion(nil)
            })
        } else {
            completion(nil)
        }
    }
    
    // MARK: - Search return handler ================================================================ -
    
    private func returnPlayers(playerMO: [PlayerMO]?) {
        // Save player as default for device
        if playerMO == nil {
            // Cancel taken - exit if no player
            if thisPlayer == nil {
                exitClient()
            }
        } else {
            if let onlineEmail = self.scorecard.settingOnlinePlayerEmail {
                if playerMO![0].email! == onlineEmail {
                    // Back to normal user - can remove temporary override
                    Notifications.removeTemporaryOnlineGameSubscription()
                } else {
                    Notifications.addTemporaryOnlineGameSubscription(email: playerMO![0].email!)
                }
            }
            self.thisPlayer = playerMO![0].email!
            self.scorecard.defaultPlayerOnDevice = self.thisPlayer
            UserDefaults.standard.set(self.thisPlayer, forKey: "defaultPlayerOnDevice")
            self.refreshInvites()
            self.showThisPlayer()
        }
    }
    
    // MARK: - Popover Overrides ================================================================ -
    
    internal func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        let viewController = popoverPresentationController.presentedViewController
        if viewController is SearchViewController {
            self.returnPlayers(playerMO: nil)
        }
    }
    
    // MARK: - Utility Routines ======================================================================== -

    private func showThisPlayer() {
        if let playerMO = self.scorecard.findPlayerByEmail(self.thisPlayer) {
            let size = SelectionViewController.thumbnailSize(view: self.view, labelHeight: 0.0)
            self.thisPlayerThumbnailWidthConstraint.constant = size.width
            self.thisPlayerThumbnail.set(data: playerMO.thumbnail, name: playerMO.name!, nameHeight: 0.0, diameter: size.width)
            self.thisPlayerNameLabel.text = "Play as \(playerMO.name!)"
        }
    }
    
    private func appStateChange(to newState: AppState) {
        if newState != self.appState {
            Utility.debugMessage("client", "Application state \(newState)")
            
            self.appState = newState
            if newState == .notConnected && !finishing {
                self.startIdleTimer()
            } else {
                self.stopIdleTimer()
            }
            if newState == .connecting {
                self.startConnectingTimer()
            } else {
                self.stopConnectingTimer()
            }
        }
    }
    
    private func startIdleTimer() {
        self.stopIdleTimer()
        self.idleTimer = Timer.scheduledTimer(
            timeInterval: TimeInterval(10),
            target: self,
            selector: #selector(ClientViewController.refreshInvites(_:)),
            userInfo: nil,
            repeats: true)
    }
    
    private func stopIdleTimer() {
        if let timer = self.idleTimer {
            Utility.debugMessage("client", "Stopping idle timer")
            timer.invalidate()
            self.idleTimer = nil
        }
    }
    
    private func startConnectingTimer() {
        self.stopConnectingTimer()
        self.connectingTimer = Timer.scheduledTimer(
            timeInterval: TimeInterval(2),
            target: self,
            selector: #selector(ClientViewController.checkConnecting(_:)),
            userInfo: nil,
            repeats: true)
    }
    
    private func stopConnectingTimer() {
        self.connectingTimer?.invalidate()
        self.connectingTimer = nil
    }

    
    private func handlerCompleteNotification() -> NSObjectProtocol? {
        // Set a notification for handler complete
        let observer = NotificationCenter.default.addObserver(forName: .clientHandlerCompleted, object: nil, queue: nil) {
            (notification) in
            // Flag not waiting and then process next entry in the queue
            self.scorecard.commsHandlerMode = .none
            self.processQueue()
        }
        return observer
    }
    
    private func clearHandlerCompleteNotification(observer: NSObjectProtocol?) {
        NotificationCenter.default.removeObserver(observer!)
    }
    
    private func disconnectPressed() {
        if self.recoveryMode {
            self.exitClient(resetRecovery: false)
        } else {
            self.clientService?.disconnect(reason: "", reconnect: false)
            self.clientService?.stop()
            self.matchDeviceName = nil
            self.clientService?.start(email: self.thisPlayer, name: self.thisPlayerName)
            self.appStateChange(to: .notConnected)
            self.changePlayerAvailable()
            self.refreshStatus()
        }
    }
    
    private func changePlayerAvailable() {
        let available = (self.appState == .notConnected && !self.recoveryMode)
        self.changePlayerButton?.isHidden = !available
    }
    
    private func refreshRoundSummary() {
        if self.scorecard.roundStarted(self.scorecard.maxEnteredRound)  &&
            !self.scorecard.roundMadeStarted(self.scorecard.maxEnteredRound) {
            // Have a bid but no made so show round summary
            if self.scorepadViewController != nil {
                if self.scorepadViewController.roundSummaryViewController == nil {
                    // Need to create one
                    if self.scorepadViewController.gameSummaryViewController != nil {
                        self.scorepadViewController.gameSummaryViewController.dismiss(animated: true, completion: {
                            self.segueToRoundSummary()
                        })
                    } else {
                        self.segueToRoundSummary()
                    }
                } else {
                    // Just need to refresh it
                    self.scorepadViewController.roundSummaryViewController.refresh()
                }
            }
        } else {
            dismissRoundSummary()
        }
    }
    
    private func segueToRoundSummary() {
        self.scorecard.commsHandlerMode = .roundSummary
        scorepadViewController.performSegue(withIdentifier: "showClientRoundSummary", sender: scorepadViewController)
    }
    
    private func showGameSummary() {
        if self.scorepadViewController != nil {
            if self.scorepadViewController.gameSummaryViewController == nil {
                // Need to create one
                if self.scorepadViewController.roundSummaryViewController != nil {
                    self.scorepadViewController.roundSummaryViewController.dismiss(animated: true, completion: {
                        self.segueToGameSummary()
                    })
                } else {
                    self.segueToGameSummary()
                }
            } else {
                // Just need to refresh it
                self.scorepadViewController.gameSummaryViewController.refresh()
            }
        }
    }
    
    private func segueToGameSummary() {
        self.scorecard.commsHandlerMode = .gameSummary
        // Need to reset game in progress to avoid resume online game
        self.scorecard.setGameInProgress(false)
        self.scorecard.recoveryMode = false
        scorepadViewController.performSegue(withIdentifier: "showGameSummary", sender: scorepadViewController)
    }
    
    public func finishClient(resetRecovery: Bool = true) {
        self.finishing = true
        self.stopIdleTimer()
        self.stopConnectingTimer()
        UIApplication.shared.isIdleTimerDisabled = false
        self.finishConnection(self.multipeerClient)
        self.multipeerClient = nil
        self.finishConnection(self.rabbitMQClient)
        self.rabbitMQClient = nil
        self.scorecard.commsDelegate = nil
        self.clientService = nil
        self.scorecard.sendScores = false
        self.scorecard.reset()
        if resetRecovery {
            self.scorecard.setGameInProgress(false)
            self.scorecard.recoveryMode = false
        }
        self.scorecard.resetSharing()
        Notifications.removeTemporaryOnlineGameSubscription()
        self.clearHandlerCompleteNotification(observer: self.clientHandlerObserver)
    }
    
    private func finishConnection(_ commsDelegate: CommsHandlerDelegate?) {
        self.clientService?.stop()
        self.scorecard.resetSharing()
    }
    
    private func exitClient(resetRecovery: Bool = true) {
        self.finishClient(resetRecovery: resetRecovery)
        self.performSegue(withIdentifier: self.returnSegue, sender: self)
    }
    
    private func removeEntry(peer: CommsPeer) {
        let index = available.firstIndex(where: {$0.deviceName == peer.deviceName && $0.framework == peer.framework})
        if index != nil {
            self.clientTableView.beginUpdates()
            self.available.remove(at: index!)
            self.clientTableView.deleteRows(at: [IndexPath(row: index!, section: peerSection)], with: .left)
            if available.count == 0 {
                // Just lost last one - need to insert placeholder and update hosting options
                self.clientTableView.insertRows(at: [IndexPath(row: 0, section: peerSection)], with: .right)
                for row in 0...1 {
                    self.clientTableView.reloadRows(at: [IndexPath(row: row, section: hostSection)], with: .automatic)
                }
            }
            self.clientTableView.endUpdates()
        }
    }
    
    private func refreshStatus() {
        // Just refresh all
        self.clientTableView.reloadData()
    }
    
    private func dismissAll(_ alert: Bool = false, reason: String = "", completion: (()->())? = nil) {
        var reason = reason
        if reason == "" {
            reason = "Connection with remote device lost"
        }
        
        if self.scorepadViewController == nil && self.gamePreviewViewController == nil {
            // Check alert controller
            if self.alertController != nil {
                self.alertController.dismiss(animated: true, completion: {
                    self.alertController = nil
                    self.alertCompletion(alert: alert, message: reason, completion: completion)
                })
            } else {
                self.alertCompletion(alert: alert, message: reason, completion: completion)
            }
        } else {
            self.dismissAllInternal(reason: reason, completion: completion)
        }
    }
    
    private func alertCompletion(alert: Bool, message: String, completion: (()->())?) {
        Utility.mainThread {
            if alert {
                self.whisper.show(message, hideAfter: 5.0)
            }
            completion!()
        }
    }
    
    private func dismissAllInternal(reason: String, completion: (()->())? = nil) {
        
        func doCompletion() {
            Utility.mainThread {
                if self.scorecard.commsHandlerMode == .dismiss {
                    self.scorecard.commsHandlerMode = .none
                }
                if completion != nil {
                    completion!()
                }
                self.processQueue()
            }
        }
        
        func dismissScorepad() {
            self.scorepadViewController.roundSummaryViewController = nil
            self.scorepadViewController.gameSummaryViewController = nil
            self.scorecard.handViewController = nil
            self.scorepadViewController.dismiss(animated: true, completion: {
                self.scorepadViewController = nil
                doCompletion()
            })
        }
        
        func dismissGamePreview() {
            if self.gamePreviewViewController != nil {
                Utility.debugMessage("dismiss", "Preview dismissed (\(reason))")
                self.gamePreviewViewController.dismiss(animated: true, completion: {
                    self.gamePreviewViewController = nil
                    if reason != "" {
                        self.whisper.show(reason, hideAfter: 5.0)
                        doCompletion()
                    } else {
                        doCompletion()
                    }
                    
                })
            } else {
                doCompletion()
            }
        }
        
        if self.scorecard.commsHandlerMode == .none {
            self.scorecard.commsHandlerMode = .dismiss
        }
        
        if self.scorepadViewController == nil && self.gamePreviewViewController == nil{
            doCompletion()
        } else {
            if self.gamePreviewViewController != nil {
                dismissGamePreview()
            } else if self.scorepadViewController.roundSummaryViewController != nil {
                self.scorepadViewController.roundSummaryViewController.dismiss(animated: true, completion: dismissScorepad)
            } else if self.scorepadViewController != nil && self.scorepadViewController.gameSummaryViewController != nil {
                self.scorepadViewController.gameSummaryViewController.dismiss(animated: true, completion: dismissScorepad)
            } else if self.scorecard.handViewController != nil {
                self.scorecard.handViewController.dismiss(animated: true, completion: dismissScorepad)
            } else {
                dismissScorepad()
            }
        }
    }
    
    private func dismissRoundSummary() {
        if self.scorepadViewController != nil && self.scorepadViewController.roundSummaryViewController != nil {
            self.scorecard.commsHandlerMode = .dismiss
            self.scorepadViewController.roundSummaryViewController.dismiss(animated: true, completion: {
                self.scorecard.commsHandlerMode = .none
                self.processQueue()
            })
            self.scorepadViewController.roundSummaryViewController = nil
        }
    }
    
    private func dismissGameSummary() {
        if self.scorepadViewController != nil && self.scorepadViewController.gameSummaryViewController != nil {
            self.scorecard.commsHandlerMode = .dismiss
            self.scorepadViewController.gameSummaryViewController.dismiss(animated: true, completion: {
                self.scorecard.commsHandlerMode = .none
                self.processQueue()
            })
            self.scorepadViewController.gameSummaryViewController = nil
        }
    }
    
    // MARK: - Segue Prepare Handler ================================================================ -
    
    override internal func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier! {
            
        case "showClientScorepad":
            scorepadViewController = segue.destination as? ScorepadViewController
            scorepadViewController.scorepadMode = .display
            scorepadViewController.rounds = self.rounds
            scorepadViewController.cards = self.cards
            scorepadViewController.bounce = self.bounce
            scorepadViewController.bonus2 = self.bonus2
            scorepadViewController.suits = self.suits
            scorepadViewController.returnSegue = "hideClientScorepad"
            scorepadViewController.parentView = view
            scorepadViewController.rabbitMQService = self.rabbitMQClient
            
        default:
            break
        }
    }
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

fileprivate class Available {
    fileprivate var peer: CommsPeer
    fileprivate var oldState: CommsConnectionState = .notConnected
    fileprivate var connecting = false
    fileprivate var expires: Date?
    fileprivate var inviteUUID: String?
    fileprivate var lastConnect: Date?
    
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
    fileprivate var framework: CommsConnectionFramework {
        get {
            return self.peer.framework
        }
    }
    
    init(peer: CommsPeer, expires: Date? = nil, inviteUUID: String? = nil) {
        self.peer = peer
        self.expires = expires
        self.inviteUUID = inviteUUID
    }
}
    
class ClientTableCell: UITableViewCell {
    @IBOutlet weak var serviceButton: UIButton!
    @IBOutlet weak var serviceLabel: UILabel!
    public var hexagonLayer: CAShapeLayer!
}

// MARK: - Utility Classes ======================================================================== -

extension Notification.Name {
    static let clientHandlerCompleted = Notification.Name("clientHandlerCompleted")
}
