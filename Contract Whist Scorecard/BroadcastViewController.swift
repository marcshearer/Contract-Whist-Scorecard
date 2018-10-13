//
//  BroadcastViewController.swift
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
    case waiting
    case connected
}

class BroadcastViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, CommsBrowserDelegate, CommsStateDelegate, CommsDataDelegate, SearchDelegate, CutDelegate, GameSetupDelegate, UIPopoverPresentationControllerDelegate {

    // MARK: - Class Properties ======================================================================== -
    
    // Main state properties
    public var scorecard: Scorecard!
    private var recovery: Recovery!
    private var scorepadViewController: ScorepadViewController!
    private var cutViewController: CutViewController!
    private var gameSetupViewController: GameSetupViewController!

    // Properties to pass state to / from segues
    public var returnSegue = ""
    public var backText = "Back"
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
    private var thisPlayerNumber: Int!

    private var timer: Timer!

    private var newGame: Bool!
    private var gameOver = false
    private var gameUUID: String!
    private var playerSection: Int!
    private var peerSection: Int!
    private var broadcastHandlerObserver: NSObjectProtocol?
    private var multipeerClient: MultipeerService?
    private var rabbitMQClient: RabbitMQService?
    private var appState: AppState!
    private var invite: Invite!
    private var recoveryMode = false
    private var changePlayerButton: UIButton!
    
    // MARK: - IB Outlets ============================================================================== -
    
    @IBOutlet weak var titleBar: UINavigationItem!
    @IBOutlet weak var finishButton: RoundedButton!
    @IBOutlet weak var broadcastTableView: UITableView!
    @IBOutlet weak var instructionLabel: UILabel!
    
    // MARK: - IB Unwind Segue Handlers ================================================================ -

    @IBAction func hideBroadcastScorepad(segue:UIStoryboardSegue) {
        // Manual return - disconnect and refresh
        self.restart()
    }
    
    @IBAction private func linkFinishGame(segue:UIStoryboardSegue) {
        if let segue = segue as? UIStoryboardSegueWithCompletion {
            segue.completion = {
                self.exitBroadcast()
            }
        }
    }
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func finishPressed(_ sender: RoundedButton) {
        exitBroadcast()
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
        setInstructions()
        
        // Set up sections
        if self.commsPurpose == .playing {
            playerSection = 0
            peerSection = 1
        } else {
            playerSection = -1
            peerSection = 0
        }
        
        // Get this player
        if self.commsPurpose == .playing {
            if self.recoveryMode {
                // Recovering - use same player
                self.thisPlayer = self.scorecard.recoveryConnectionEmail
                self.matchDeviceName = self.scorecard.recoveryConnectionDevice
                if self.scorecard.recoveryOnlineMode == .invite {
                    if self.thisPlayer == nil {
                        self.alertMessage("Error recovering game", okHandler: {
                            self.exitBroadcast()
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
                    } else {
                        defaultPlayer = nil
                    }
                }
                if defaultPlayer == nil {
                    let playerMO = self.scorecard.playerList.min(by: {($0.localDateCreated! as Date) < ($1.localDateCreated! as Date)})
                    self.thisPlayer = playerMO!.email
                }
            }
            self.broadcastTableView.reloadRows(at: [IndexPath(row: 0, section: playerSection)], with: .automatic)
        }
        
        self.createConnections()
        
        self.available = []
        self.scorecard.sendScores = true
        self.scorecard.commsHandlerMode = .none
        
        // Clear hand state
        self.scorecard.handState = nil
        
        // Set observer to detect UI handler completion
        broadcastHandlerObserver = self.handlerCompleteNotification()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
         scorecard.reCenterPopup(self)
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

    // MARK: - Comms Delegate Overrides ==================================================== -
    
    func didReceiveData(descriptor: String, data: [String : Any?]?, from peer: CommsPeer) {
        Utility.mainThread { [unowned self] in
            self.scorecard.commsDelegate?.debugMessage("\(descriptor) received from \(peer.deviceName)")
            self.queue.append(QueueEntry(descriptor: descriptor, data: data, peer: peer))
        }
        self.processQueue()
    }
    
    func processQueue() {
        
        Utility.mainThread { [unowned self] in
            var queueText = ""
            for element in self.queue {
                queueText = queueText + " " + element.descriptor
            }
            
            while self.queue.count > 0 && self.scorecard.commsHandlerMode == .none {
                
                // Set state to connected unless receive wait
                self.appStateChange(to: .connected)
                self.changePlayerAvailable()
                
                // Pop top element off the queue
                let descriptor = self.queue.first!.descriptor
                let data = self.queue.first!.data
                let peer = self.queue.first!.peer!
                self.queue.removeFirst()
                
                switch descriptor {
                case "wait":
                    // No game running - need to wait for it to start
                    self.dismissAll(completion: {
                        self.appStateChange(to: .waiting)
                        self.reflectState(peer: peer)
                    })
                   
                    
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
                    if self.gameSetupViewController != nil {
                        self.gameSetupViewController.cutComplete()
                    }
                    
                case "play", "players":
                    self.scorecard.setCurrentPlayers(players: data!.count)
                    for (playerNumberData, playerData) in data as! [String : [String : Any]] {
                        let playerNumber = Int(playerNumberData)!
                        let playerName = playerData["name"] as! String
                        let playerEmail = playerData["email"] as! String
                        var playerMO = self.scorecard.findPlayerByEmail(playerEmail)
                        if playerMO == nil {
                            // Not found - need to create the player locally
                            let playerDetail = PlayerDetail(self.scorecard)
                            playerDetail.name = playerName
                            playerDetail.email = playerEmail
                            playerDetail.dedupName(self.scorecard)
                            playerMO = playerDetail.createMO()
                            self.scorecard.requestPlayerThumbnail(from: peer, playerEmail: playerEmail)
                        }
                        self.scorecard.enteredPlayer(playerNumber).playerMO = playerMO
                        self.scorecard.enteredPlayer(playerNumber).reset()
                        self.scorecard.enteredPlayer(playerNumber).saveMaxScore()
                        if self.commsPurpose == .playing {
                            if playerEmail == self.thisPlayer {
                                self.thisPlayerNumber = playerNumber
                            }
                        }
                    }
                    if descriptor == "players" && self.gameSetupViewController == nil {
                        var selectedPlayers: [PlayerMO] = []
                        for playerNumber in 1...self.scorecard.currentPlayers {
                            selectedPlayers.append(self.scorecard.enteredPlayer(playerNumber).playerMO!)
                        }
                        self.dismissAll {
                            self.gameSetupViewController = GameSetupViewController.showGameSetup(viewController: self, scorecard: self.scorecard, selectedPlayers: selectedPlayers)
                            self.gameSetupViewController.delegate = self
                        }
                    }
                    if descriptor == "play" {
                        if self.scorecard.isViewing && self.scorepadViewController != nil {
                            // Need to clear grid just in case less data now than there was
                            self.scorepadViewController.reloadScorepad()
                        
                        }
                        self.queue.insert(QueueEntry(descriptor: "playHand", data: nil, peer: peer), at: 0)
                    }
                    
                case "cut":
                    var preCutCards: [Card] = []
                    let cardNumbers = data!["cards"] as! [Int]
                    for cardNumber in cardNumbers {
                        preCutCards.append(Card(fromNumber: cardNumber))
                    }
                    let playerName = data!["names"] as! [String]
                    self.cutViewController?.delegate = nil
                    
                    var viewController: UIViewController
                    if self.gameSetupViewController != nil {
                        self.gameSetupViewController.cutDelegate = self
                        viewController = self.gameSetupViewController
                    } else {
                        viewController = self
                    }
                    let cutDelegate = viewController as! CutDelegate
                    self.cutViewController = CutViewController.cutForDealer(viewController: viewController, view: viewController.view, scorecard: self.scorecard, cutDelegate: cutDelegate, preCutCards: preCutCards, playerName: playerName)
                
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
                            self.scorecard.commsDelegate?.debugMessage("Hand: \(hand.toString())")
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
                    let cardNumbers = data!["cards"] as! [Int]
                    let hand = Hand(fromNumbers: cardNumbers)
                    let trick = data!["trick"] as! Int
                    let made = data!["made"] as! [Int]
                    let twos = data!["twos"] as! [Int]
                    let trickCards = Hand(fromNumbers: data!["trickCards"] as! [Int]).cards
                    let toLead = data!["toLead"] as! Int
                    let round = data!["round"] as! Int
                    
                    self.playHand(peer: peer, dismiss: true, hand: hand, round: round, trick: trick, made: made, twos: twos, trickCards: trickCards, toLead: toLead)
                    
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
    
    private func playHand(peer: CommsPeer, dismiss: Bool = false, hand: Hand! = nil, round: Int! = nil, trick: Int! = nil, made: [Int]! = nil, twos: [Int]! = nil, trickCards: [Card]! = nil, toLead: Int! = nil) {
        
        if self.commsPurpose == .sharing || (self.thisPlayerNumber != nil && hand != nil) {
            if self.available.index(where: { $0.deviceName == peer.deviceName && $0.framework == peer.framework}) != nil {
                if !dismiss && self.commsPurpose == .playing && self.scorepadViewController != nil {
                    self.scorecard.commsHandlerMode = .playHand
                    self.scorecard.handState.hand = hand
                    self.scorecard.playHand(from: self.scorepadViewController, sourceView: self.scorepadViewController.scorepadView)
                } else {
                    // Need to start a new scorecard?
                    if dismiss {
                        self.dismissAll(completion: {
                            self.playHandScorecard(peer: peer, hand: hand, round: round, trick: trick, made: made, twos: twos, trickCards: trickCards, toLead: toLead)
                        })
                    } else if self.scorepadViewController == nil {
                        self.playHandScorecard(peer: peer, hand: hand, round: round, trick: trick, made: made, twos: twos, trickCards: trickCards, toLead: toLead)
                    }
                }
            } else {
                self.error("Unknown: \(peer.deviceName)")
            }
        }
        processQueue()
    }
    
    private func playHandScorecard(peer: CommsPeer, hand: Hand!, round: Int!, trick: Int!, made: [Int]!, twos: [Int]!, trickCards: [Card]!, toLead: Int!) {
        var mode: CommsHandlerMode = .scorepad
        if self.commsPurpose == .playing {
            if round != nil {
                self.scorecard.selectedRound = round
                self.scorecard.maxEnteredRound = round
            }
            self.scorecard.handState = HandState(enteredPlayerNumber: self.thisPlayerNumber, round: self.scorecard.selectedRound, dealerIs: self.scorecard.dealerIs, players: self.scorecard.currentPlayers, rounds: self.rounds, cards: self.cards, bounce: self.bounce, bonus2: self.bonus2, suits: self.suits, trick: trick, made: made, twos: twos, trickCards: trickCards, toLead: toLead)
            self.scorecard.handState.hand = hand
            mode = .playHand
        }
        self.scorecard.commsHandlerMode = mode
        self.scorecard.recoveryMode = false
        self.recoveryMode = true
        self.performSegue(withIdentifier: "showBroadcastScorepad", sender: self)
    }
    
    func peerFound(peer: CommsPeer) {
        Utility.mainThread { [unowned self] in
            // Check if already got this device - if so disconnect it and replace it

            if let index = self.available.index(where: { $0.deviceName == peer.deviceName && $0.peer.framework == peer.framework }) {
                // Already have an entry for this device - re-use it
                self.available[index].peer = peer
                
                // Just mark as disconnected and wait for user to reconnect
                self.reflectState(peer: peer)
                
            } else {
                // New peer - add to list
                self.broadcastTableView.beginUpdates()
                self.available.append(Available(peer: peer))
                self.broadcastTableView.insertRows(at: [IndexPath(row: self.available.count - 1, section: self.peerSection)], with: .automatic)
                self.broadcastTableView.endUpdates()
            }
            if self.matchDeviceName != nil && peer.deviceName == self.matchDeviceName {
                // Recovering/reacting to notification and this is the device I'm waiting for!
                self.checkFaceTime(peer: peer, completion: { (faceTimeAddress) in
                    _ = self.connect(peer: peer, faceTimeAddress: faceTimeAddress)
                    self.reflectState(peer: peer)
                })
            }
            self.setInstructions()
        }
    }
    
    func peerLost(peer: CommsPeer) {
        Utility.mainThread { [unowned self] in
            self.removeEntry(peer: peer)
            self.setInstructions()
        }
    }
    
    func appStateChange(to newState: AppState) {
        if newState != self.appState {
            self.appState = newState
            if newState == .notConnected {
                self.scheduleRefresh()
            } else {
                self.clearSchedule()
            }
        }
    }
    
    func stateChange(for peer: CommsPeer, reason: String?) {
        Utility.mainThread { [unowned self] in
            if peer.state == .notConnected {
                self.appStateChange(to: .notConnected)
                self.changePlayerAvailable()
                self.dismissAll(reason != nil, reason: reason ?? "", completion: {
                    self.scorecard.commsDelegate?.start(email: self.thisPlayer)
                    self.reflectState(peer: peer)
                    UIApplication.shared.isIdleTimerDisabled = false
                })
            } else {
                self.changePlayerAvailable()
                if peer.state == .connected && self.alertController != nil {
                    // Can dismiss re-connecting dialog
                    self.alertController.dismiss(animated: true, completion: nil)
                    self.alertController = nil
                }
                self.appStateChange(to: .waiting)
                // Set framework based on this connection (for reconnect at lower level)
                self.selectFramework(framework: peer.framework)
                self.reflectState(peer: peer)
                UIApplication.shared.isIdleTimerDisabled = true
            }
        }
    }
    
    private func restart() {
        self.scorepadViewController = nil
        self.scorecard.commsDelegate?.stop()
        self.scorecard.commsDelegate?.start(email: self.thisPlayer)
        self.available = []
        self.broadcastTableView.reloadData()
        self.appStateChange(to: .notConnected)
        self.changePlayerAvailable()
        scorecard.reset()
        scorecard.setGameInProgress(false)
    }
    
    @objc private func refreshInvites(_ sender: Any? = nil) {
        // Refresh online game invites
        if sender != nil {
            Utility.debugMessage("broadcast", "Timer")
        }
        if self.scorecard.onlineEnabled && self.appState == .notConnected {
            self.rabbitMQClient?.stop()
            self.rabbitMQClient?.start(email: self.thisPlayer)
            self.broadcastTableView.reloadRows(at: [IndexPath(row: 0, section: playerSection)], with: .automatic)
        }
    }
    
    private func closeConnections() {
        self.multipeerClient?.stop()
        self.rabbitMQClient?.stop()
    }
    
    private func createConnections() {
        // Create nearby comms service, take delegates and start listening
        if !self.recoveryMode || self.scorecard.recoveryOnlineMode == .broadcast {
            self.multipeerClient = MultipeerService(purpose: self.commsPurpose, type: .client, serviceID: self.scorecard.serviceID(self.commsPurpose))
            self.multipeerClient?.stateDelegate = self
            self.multipeerClient?.dataDelegate = self
            self.multipeerClient?.browserDelegate = self
            self.multipeerClient?.start(email: self.thisPlayer, recoveryMode: self.recoveryMode, matchDeviceName: self.matchDeviceName)
        }
        
        // Create online comms service, take delegates and start listening
        if self.commsPurpose == .playing && self.scorecard.onlineEnabled && (!self.recoveryMode || self.scorecard.recoveryOnlineMode == .invite) {
            self.rabbitMQClient = RabbitMQService(purpose: self.commsPurpose, type: .client, serviceID: nil)
            self.rabbitMQClient?.stateDelegate = self
            self.rabbitMQClient?.dataDelegate = self
            self.rabbitMQClient?.browserDelegate = self
            self.rabbitMQClient?.start(email: self.thisPlayer, recoveryMode: self.recoveryMode, matchDeviceName: self.matchDeviceName)
        }
    }
    
    func connect(peer: CommsPeer, faceTimeAddress: String?) -> Bool {
        var playerName: String!
        var context: [String : String]? = [:]
        
        if self.thisPlayer != nil {
            let playerMO = scorecard.findPlayerByEmail(self.thisPlayer)
            playerName = playerMO?.name
        }
        
        self.selectFramework(framework: peer.framework)
        
        if faceTimeAddress != nil {
            // Send face time address to remote
            context?["faceTimeAddress"] = faceTimeAddress!
        }
        
        if !self.scorecard.commsDelegate!.connect(to: peer, playerEmail: self.thisPlayer, playerName: playerName, context: context, reconnect: true) {
            self.alertMessage("Error connecting to device", title: "Error")
            return false
        }
        
        return true
    }
    
    func selectFramework(framework: CommsConnectionFramework) {
        // Wire up the selected connection
        switch framework {
        case .multipeer:
            self.scorecard.commsDelegate = self.multipeerClient
        case .rabbitMQ:
            self.scorecard.commsDelegate = self.rabbitMQClient
        default:
            break
        }
    }
    
    func reflectState(peer: CommsPeer) {
        if let combinedIndex = available.index(where: {$0.deviceName == peer.deviceName && $0.framework == peer.framework}) {
            let availableFound = self.available[combinedIndex]
            availableFound.connecting = false
            availableFound.oldState = availableFound.peer.state
            availableFound.peer = peer
            self.refreshStatus()
            self.setInstructions()
        }
    }

    func error(_ message: String) {
        Utility.getActiveViewController()?.alertMessage(message, title: "Connected Devices", okHandler: {
            self.exitBroadcast()
        })
    }

    // MARK: - Cut for dealer delegate routines ===================================================================== -
    
    func cutComplete() {
        if self.gameSetupViewController != nil {
            self.gameSetupViewController.cutDelegate = nil
        }
        self.cutViewController.delegate = nil
        self.cutViewController = nil
    }
    
    // MARK: - Game Setup delegate routines ============================================================ -
    
    func gameSetupComplete() {
        self.gameSetupViewController?.delegate = nil
        self.gameSetupViewController = nil
    }
    
    // MARK: - TableView Overrides ===================================================================== -
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if commsPurpose == .playing {
            return 2
        } else {
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView,
                   titleForHeaderInSection section: Int) -> String? {
        if section == peerSection {
            return "Select a device from the list below"
        } else {
            return "Join game as player"
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == peerSection {
            return available.count
        } else {
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        ScorecardUI.sectionHeaderStyleView(header)
        header.textLabel!.font = UIFont.boldSystemFont(ofSize: 18.0)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: BroadcastTableCell!
        if self.commsPurpose != .playing || indexPath.section == self.peerSection {
            // List of remote peers
            cell = tableView.dequeueReusableCell(withIdentifier: "Service Cell", for: indexPath) as? BroadcastTableCell
            
            let availableFound = self.available[indexPath.row]
            let deviceName = availableFound.deviceName
            let mode = self.available[indexPath.row].peer.mode
            let state = availableFound.state
            let oldState = availableFound.oldState
            
            if mode == .invite {
                cell.serviceLabel.text = availableFound.peer.playerName
            } else {
                cell.serviceLabel.text = deviceName
            }
            switch state {
            case .notConnected:
                if oldState != .notConnected {
                    cell.stateLabel.text = "Disconnected"
                } else if self.commsPurpose == .sharing {
                    cell.stateLabel.text = "Offering to share scorecard"
                } else if availableFound.connecting {
                    cell.stateLabel.text = "Connecting..."
                } else {
                    if mode == .invite {
                        let hostName = availableFound.peer.playerName!
                        cell.stateLabel.text = hostName + " has invited you to join an online game"
                    } else {
                        cell.stateLabel.text = "Offering to host a nearby game"
                    }
                }
            case .connected:
                var message: String
                message = "Connected"
                if self.appState == .waiting {
                    message = message + ". Waiting to start..."
                }
                cell.stateLabel.text = message
            case .connecting:
                if self.recoveryMode {
                    cell.stateLabel.text = "Trying to reconnect..."
                } else {
                    cell.stateLabel.text = "Connecting..."
                }
            case .reconnecting:
                cell.stateLabel.text = "Trying to reconnect"
            }
            
            if self.appState == .notConnected || state != .notConnected {
                cell.isUserInteractionEnabled = true
                cell.isEditing = false
                cell.serviceLabel.textColor = UIColor.black
                cell.stateLabel.textColor = UIColor.blue
                cell.disconnectButton.isHidden = (self.appState == .notConnected)
            } else {
                cell.serviceLabel.textColor = ScorecardUI.darkHighlightColor
                cell.stateLabel.textColor = ScorecardUI.highlightColor
                cell.disconnectButton.isHidden = true
            }
            
            cell.disconnectButton.addTarget(self, action: #selector(BroadcastViewController.disconnectPressed(_:)), for: UIControl.Event.touchUpInside)
            
        } else {
            // My details when joining a game
            cell = tableView.dequeueReusableCell(withIdentifier: "Player Cell", for: indexPath) as? BroadcastTableCell
            if self.thisPlayer != nil {
                if let playerMO = self.scorecard.findPlayerByEmail(self.thisPlayer) {
                    cell.playerNameLabel.text = playerMO.name!
                    Utility.setThumbnail(data: playerMO.thumbnail,
                                         imageView: cell.playerImage,
                                         initials: playerMO.name!,
                                         label: cell.playerDisc,
                                         size: 50)
                }
            }
            
            self.changePlayerButton = cell.changePlayerButton
            if !self.recoveryMode {
                cell.changePlayerButton.addTarget(self, action: #selector(BroadcastViewController.changePlayerPressed(_:)), for: UIControl.Event.touchUpInside)
            }
            self.changePlayerAvailable()
        }
        
        // let backgroundView = UIView()
        // backgroundView.backgroundColor = UIColor.clear
        //  cell.selectedBackgroundView = backgroundView
        
        return cell!
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        let availableFound = self.available[indexPath.row]
        if (appState == .notConnected && availableFound.state == .notConnected) && indexPath.section == self.peerSection {
            return indexPath
        } else {
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.section == self.peerSection {
            let availableFound = available[indexPath.row]
            availableFound.connecting = true
            self.refreshStatus()
        
            self.checkFaceTime(peer: availableFound.peer, completion: { (faceTimeAddress) in
                if !self.connect(peer: availableFound.peer, faceTimeAddress: faceTimeAddress) {
                    availableFound.connecting = false
                }
                self.refreshStatus()
            })
                
        }
    }
    
    func checkFaceTime(peer: CommsPeer, completion: @escaping (String?)->()) {
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
    
    // MARK: - Search delegate handlers ================================================================ -
    
    func returnPlayers(complete: Bool, playerMO: [PlayerMO]?, info: [String : Any?]?) {
        // Save player as default for device
        if !complete {
            // Cancel taken - exit if no player
            if thisPlayer == nil {
                exitBroadcast()
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
        }
    }
    
    // MARK: - Popover Overrides ================================================================ -
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        let viewController = popoverPresentationController.presentedViewController
        if viewController is SearchViewController {
            self.returnPlayers(complete: false, playerMO: nil, info: nil)
        }
    }
    
    // MARK: - Utility Routines ======================================================================== -

    private func scheduleRefresh() {
        self.timer = Timer.scheduledTimer(
            timeInterval: TimeInterval(10),
            target: self,
            selector: #selector(BroadcastViewController.refreshInvites(_:)),
            userInfo: nil,
            repeats: true)
    }
    
    private func clearSchedule() {
        self.timer.invalidate()
    }
    
    private func handlerCompleteNotification() -> NSObjectProtocol? {
        // Set a notification for handler complete
        let observer = NotificationCenter.default.addObserver(forName: .broadcastHandlerCompleted, object: nil, queue: nil) {
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
    
    @objc private func disconnectPressed(_ button: UIButton) {
        if self.recoveryMode {
            self.exitBroadcast(resetRecovery: false)
        } else {
            self.scorecard.commsDelegate?.stop()
            self.matchDeviceName = nil
            self.scorecard.commsDelegate?.start(email: self.thisPlayer)
            self.appStateChange(to: .notConnected)
            self.changePlayerAvailable()
            self.refreshStatus()
        }
    }
    
    @objc private func changePlayerPressed(_ button: UIButton) {
        self.scorecard.identifyPlayers(from: self, filter: { (playerMO) in
            // Exclude current player
            return (self.thisPlayer == nil || self.thisPlayer != playerMO.email )
        })
    }
    
    private func changePlayerAvailable() {
        let available = (self.appState == .notConnected && !self.recoveryMode)
        self.changePlayerButton?.isEnabled = available
        self.changePlayerButton?.setTitleColor((available ? UIColor.blue : UIColor.lightGray), for: .normal)
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
        scorepadViewController.performSegue(withIdentifier: "showBroadcastRoundSummary", sender: scorepadViewController)
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
    
    public func finishBroadcast(resetRecovery: Bool = true) {
        self.clearSchedule()
        UIApplication.shared.isIdleTimerDisabled = false
        self.scorecard.commsDelegate?.stop()
        self.scorecard.commsDelegate?.browserDelegate = nil
        self.scorecard.commsDelegate?.dataDelegate = self.scorecard
        self.scorecard.commsDelegate?.stateDelegate = self.scorecard
        self.scorecard.commsDelegate = nil
        self.scorecard.sendScores = false
        self.scorecard.reset()
        if resetRecovery {
            self.scorecard.setGameInProgress(false)
            self.scorecard.recoveryMode = false
        }
        self.scorecard.resetSharing()
        Notifications.removeTemporaryOnlineGameSubscription()
        self.clearHandlerCompleteNotification(observer: self.broadcastHandlerObserver)
    }
    
    private func exitBroadcast(resetRecovery: Bool = true) {
        self.finishBroadcast(resetRecovery: resetRecovery)
        self.performSegue(withIdentifier: self.returnSegue, sender: self)
    }
    
    private func removeEntry(peer: CommsPeer) {
        let index = available.index(where: {$0.deviceName == peer.deviceName && $0.framework == peer.framework})
        if index != nil {
            self.broadcastTableView.beginUpdates()
            self.available.remove(at: index!)
            self.broadcastTableView.deleteRows(at: [IndexPath(row: index!, section: peerSection)], with: .automatic)
            self.broadcastTableView.endUpdates()
        }
    }
    
    private func refreshStatus() {
        // Just refresh all
        self.broadcastTableView.reloadData()
    }
    
    private func dismissAll(_ alert: Bool = false, reason: String = "", completion: (()->())? = nil) {
        var reason = reason
        if reason == "" {
            reason = "Connection with remote device lost"
        }
        
        if self.scorepadViewController == nil && self.cutViewController == nil && self.gameSetupViewController == nil {
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
            if alert {
                Utility.getActiveViewController()?.alertMessage(reason, title: "Connected Devices",
                                            okHandler: {
                                                self.dismissAllInternal(completion: completion)
                                            })
            } else {
                self.dismissAllInternal(completion: completion)
            }
        }
    }
    
    private func alertCompletion(alert: Bool, message: String, completion: (()->())?) {
        Utility.mainThread {
            self.alertMessage(if: alert, message, title: "Connected Devices", okHandler: {
                if completion != nil {
                    completion!()
                }
            })
        }
    }
    
    private func dismissAllInternal(completion: (()->())? = nil) {
        
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
        
        func dismissGameSetup() {
            if self.gameSetupViewController != nil {
                Utility.debugMessage("dismiss", "Dismissing setup")
                self.gameSetupViewController.delegate = nil
                self.gameSetupViewController.dismiss(animated: true, completion: {
                    Utility.debugMessage("dismiss", "Setup dismissed")
                    self.gameSetupViewController = nil
                    doCompletion()
                })
            } else {
                doCompletion()
            }
        }
        
        if self.scorecard.commsHandlerMode == .none {
            self.scorecard.commsHandlerMode = .dismiss
        }
        
        if self.scorepadViewController == nil && self.cutViewController == nil && self.gameSetupViewController == nil{
            doCompletion()
        } else {
            if self.cutViewController != nil  || self.gameSetupViewController != nil {
                if self.cutViewController != nil {
                    Utility.debugMessage("dismiss", "Dismissing cut")
                    self.cutViewController.dismiss(animated: true, completion: {
                        Utility.debugMessage("dismiss", "Cut dismissed")
                        self.cutViewController?.delegate = nil
                        self.cutViewController = nil
                        dismissGameSetup()
                    })
                } else {
                    dismissGameSetup()
                }
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
    
    private func setInstructions() {
        if self.commsPurpose == .sharing {
            if self.available.count == 0 {
                instructionLabel.text =  "No other devices are currently offering to share a scorecard. Make sure sharing is enabled in the settings of the remote device"
            } else {
                instructionLabel.text =  "Select one of the devices below to join. If the device you want to join is not in the list, make sure sharing is enabled in the settings of the remote device"
            }
        } else {
            if self.available.count == 0 {
                instructionLabel.text =  "No other devices are currently offering to host a game. You can only join a game that another device is hosting"
            } else {
                instructionLabel.text =  "Select one of the devices below to join. You can only join a game that another device is hosting"
            }
        }
    }
    
    // MARK: - Segue Prepare Handler ================================================================ -
    
    override internal func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier! {
        case "showBroadcastScorepad":
            scorepadViewController = segue.destination as? ScorepadViewController
            scorepadViewController.scorecard = self.scorecard
            scorepadViewController.scorepadMode = .display
            scorepadViewController.rounds = self.rounds
            scorepadViewController.cards = self.cards
            scorepadViewController.bounce = self.bounce
            scorepadViewController.bonus2 = self.bonus2
            scorepadViewController.suits = self.suits
            scorepadViewController.returnSegue = "hideBroadcastScorepad"
            scorepadViewController.parentView = view
            scorepadViewController.rabbitMQService = self.rabbitMQClient
            
        default:
            break
        }
    }
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class Available {
    var peer: CommsPeer
    var oldState: CommsConnectionState = .notConnected
    var connecting = false
    var expires: Date?
    var inviteUUID: String?
    
    var state: CommsConnectionState {
        get {
            return self.peer.state
        }
    }
    var deviceName: String {
        get {
            return self.peer.deviceName
        }
    }
    var framework: CommsConnectionFramework {
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
    
class BroadcastTableCell: UITableViewCell {
    @IBOutlet weak var serviceLabel: UILabel!
    @IBOutlet weak var stateLabel: UILabel!
    @IBOutlet weak var playerNameLabel: UILabel!
    @IBOutlet weak var playerImage: UIImageView!
    @IBOutlet weak var playerDisc: UILabel!
    @IBOutlet weak var changePlayerButton: UIButton!
    @IBOutlet weak var disconnectButton: UIButton!
}

// MARK: - Utility Classes ======================================================================== -

extension Notification.Name {
    static let broadcastHandlerCompleted = Notification.Name("broadcastHandlerCompleted")
}
