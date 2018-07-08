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
}
        
enum InviteStatus {
    case none
    case inviting
    case invited
    case reconnecting
}

class HostViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIPopoverPresentationControllerDelegate,
CommsStateDelegate, CommsDataDelegate, CommsConnectionDelegate, CommsHandlerStateDelegate, SearchDelegate {

    // MARK: - Class Properties ======================================================================== -
    
    // Main state properties
    var scorecard: Scorecard!
    
    // Properties to pass state to / from segues
    public var returnSegue = ""
    public var selectedPlayers: [PlayerMO]!
    public var formTitle = "Host a Game"
    public var backText = "Back"
    public var backImage = "back"
    
    // Queue
    private var queue: [QueueEntry] = []

    private var playerData: [PlayerData] = []
    private var unique = 0
    private var observer: NSObjectProtocol?
    private var gameInProgress = false
    private var alertController: UIAlertController!
    private var connectionMode: ConnectionMode!
    private var defaultConnectionMode: ConnectionMode!
    private var multipeerHost: MultipeerService!
    private var rabbitMQHost: RabbitMQService!
    private var currentState: CommsHandlerState = .notStarted

    private var connectedPlayers: Int {
        get {
            var count = 0
            if self.playerData.count > 0 {
                for playerNumber in 1...self.playerData.count {
                    if (playerData[playerNumber - 1].disconnectReason == nil &&
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
    
    // MARK: - IB Outlets ============================================================================== -
    
    @IBOutlet weak var titleBar: UINavigationItem!
    @IBOutlet weak var finishButton: RoundedButton!
    @IBOutlet weak var hostPlayerTableView: UITableView!
    @IBOutlet weak var guestPlayerTableView: UITableView!
    @IBOutlet weak var hostPlayerTableViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var instructionLabel: UILabel!
    @IBOutlet weak var scorecardButton: RoundedButton!
    @IBOutlet weak var continueButton: RoundedButton!
    @IBOutlet weak var imageView: UIImageView!

    // MARK: - IB Unwind Segue Handlers ================================================================ -
    
    @IBAction func hideHostGameSetup(segue:UIStoryboardSegue) {
        gameInProgress = false
    }
    
    @IBAction private func linkFinishGame(segue:UIStoryboardSegue) {
        if let segue = segue as? UIStoryboardSegueWithCompletion {
            segue.completion = {
                self.exitHost()
            }
        }
    }
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func finishPressed(_ sender: RoundedButton) {
        exitHost()
    }
    
    @IBAction func continuePressed(_ sender: RoundedButton) {
        self.setupPlayers()
        gameInProgress = true
        self.performSegue(withIdentifier: "showHostGameSetup", sender: self)
    }
    
    // MARK: - View Overrides ========================================================================== -
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Stop existing server service (sharing)
        self.scorecard.commsDelegate?.stop()
        
        // Stop any existing sharing activity
        self.scorecard.stopSharing()
        
        // Start broadcasting unless need to give option to use Online
        let nearby = self.scorecard.settingNearbyPlaying
        let online = self.scorecard.settingOnlinePlayerEmail != nil
        if nearby && online {
            defaultConnectionMode = .unknown
        } else if nearby {
            defaultConnectionMode = .nearby
        } else {
            defaultConnectionMode = .online
        }
        if online && self.scorecard.recoveryMode && scorecard.recoveryOnlineMode == .invite {
            self.setConnectionMode(.online, chooseInvitees: false)
        } else if nearby && scorecard.recoveryMode && scorecard.recoveryOnlineMode == .broadcast {
            self.setConnectionMode(.nearby)
        } else {
            self.setConnectionMode(defaultConnectionMode)
        }
        
        // Set finish button
        finishButton.setImage(UIImage(named: self.backImage), for: .normal)
        finishButton.setTitle(self.backText)

        // Allow broadcast of scores
        self.scorecard.sendScores = true
        
        // Update instructions / title
        if Utility.isSimulator {
            self.titleBar.title = Scorecard.deviceName
        } else {
            self.titleBar.title = self.formTitle
        }
        self.setInstructions()
    
        // Set observer to detect UI handler completion
        observer = self.handlerCompleteNotification()
        
        // Setup player and start broadcasting
        if scorecard.recoveryMode {
            // Recovering - use same player
            self.scorecard.loadGameDefaults()
            self.resetResumedPlayers()
            let playerMO = self.selectedPlayers[0]
            _ = self.addPlayer(name: playerMO.name!, email: playerMO.email!, playerMO: playerMO, peer: nil)
            self.startHostBroadcast(email: playerMO.email, name: playerMO.name!)
        } else {
            // Work out default player
            var defaultPlayer: String!
            if self.scorecard.settingOnlinePlayerEmail != nil {
                defaultPlayer = self.scorecard.settingOnlinePlayerEmail
            } else {
                defaultPlayer = self.scorecard.defaultPlayerOnDevice
            }
            if defaultPlayer != nil {
                let playerMO = scorecard.findPlayerByEmail(defaultPlayer)
                if playerMO != nil {
                    _ = self.addPlayer(name: playerMO!.name!, email: playerMO!.email!, playerMO: playerMO, peer: nil)
                } else {
                    defaultPlayer = nil
                }
            }
            if defaultPlayer == nil {
                let playerMO = self.scorecard.playerList.min(by: {($0.localDateCreated! as Date) < ($1.localDateCreated! as Date)})
                _ = self.addPlayer(name: playerMO!.name!, email: playerMO!.email!, playerMO: playerMO, peer: nil)
            }
        }
        
        // Check if in recovery mode - if so go straight to game setup
        if self.scorecard.recoveryMode {
            self.waitOtherPlayers(completion: {
                self.gameInProgress = true
                if self.scorecard.recoveryOnlineMode == .invite {
                    // Simulate return from invitee search
                    if let selectedPlayers = self.selectedPlayers {
                        let invitees = selectedPlayers.count - 1
                        if invitees > 0 {
                            let playerMO = Array(selectedPlayers[1...invitees])
                            self.returnPlayers(complete: true, playerMO: playerMO, info: ["invitees" : true])
                        }
                    }
                }
            })
        }
        
        /* Add in dummy players for testing - TODO make this more elegant - move to test extension
        var playerMO = self.scorecard.findPlayerByEmail("jackshearer@tesco.net")
        _ = self.addPlayer(name: playerMO!.name!, email: playerMO!.email!, playerMO: playerMO, peer: CommsPeer(deviceName: "Jack's iPhone", playerEmail: playerMO!.email!, playerName: playerMO!.name!))
        playerMO = self.scorecard.findPlayerByEmail("emmasarahshearer@gmail.com")
         _ = self.addPlayer(name: playerMO!.name!, email: playerMO!.email!, playerMO: playerMO, peer: CommsPeer(deviceName: "Emma's iPhone", playerEmail: playerMO!.email!, playerName: playerMO!.name!))
        playerMO = self.scorecard.findPlayerByEmail("rachel.shearer@tesco.net")
          _ = self.addPlayer(name: playerMO!.name!, email: playerMO!.email!, playerMO: playerMO, peer: CommsPeer(deviceName: "Rachel's iPad", playerEmail: playerMO!.email!, playerName: playerMO!.name!))
        */

        // Allow resequencing of participants
        guestPlayerTableView.isEditing = true
        
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        scorecard.reCenterPopup(self)
    }
    
    // MARK: - Broadcast Service Delegate Overrides ==================================================== -
    
    func didReceiveData(descriptor: String, data: [String : Any?]?, from peer: CommsPeer) {
        
        Utility.mainThread { [unowned self] in
            self.queue.append(QueueEntry(descriptor: descriptor, data: data, peer: peer))
        }
        self.processQueue()
    }
    
    func processQueue() {
        
        Utility.mainThread { [unowned self] in
            
            while self.queue.count > 0 && self.scorecard.commsHandlerMode == .none {
                
                // Pop top element off the queue
                let descriptor = self.queue[0].descriptor
                let data = self.queue[0].data
                self.queue.remove(at: 0)
                
                switch descriptor {
                case "scores":
                    _ = self.scorecard.processScores(descriptor: descriptor, data: data!, bonus2: self.scorecard.settingBonus2)
                case "played":
                    _ = self.scorecard.processCardPlayed(data: data! as Any as! [String : Any])
                    self.removeCardPlayed(data: data! as Any as! [String : Any])
                default:
                    break
                }
            }
        }
    }
    
    func connectionReceived(from peer: CommsPeer, info: [String : Any?]?) -> Bool {
        // Will accept all connections, but some will automatically disconnect with a relevant error message once connection complete
        var playerMO: PlayerMO! = nil
        var name = peer.playerName!
        if let email = peer.playerEmail {
            playerMO = scorecard.findPlayerByEmail(email)
        }
        if let playerMO = playerMO {
            // Use local name
            name = playerMO.name!
        }
        if let index = self.playerData.index(where: {($0.peer != nil && $0.peer.deviceName == peer.deviceName) && $0.email == peer.playerEmail}) {
            // A player returning from the same device - probably a reconnect - just update the details
            self.playerData[index].peer = peer
        } else if self.connectionMode == .online {
            // Should already be in list
            if let index = self.playerData.index(where: {$0.email == peer.playerEmail}) {
                if self.playerData[index].peer != nil && self.playerData[index].peer.deviceName != peer.deviceName && self.playerData[index].peer.state != .notConnected {
                    // Duplicate - add it temporarily - to disconnect in state change
                    addPlayer(name: name, email: peer.playerEmail!, playerMO: playerMO, peer: peer, inviteStatus: .none, disconnectReason: "This player has already joined from another device")
                } else {
                    self.playerData[index].peer = peer
                }
            } else {
                // Not found - shouldn't happen - add it temporarily - to disconnect in state change
                addPlayer(name: name, email: peer.playerEmail!, playerMO: playerMO, peer: peer, inviteStatus: .none, disconnectReason: "This player has not been invited to a game on this device")
            }
        } else {
            addPlayer(name: name, email: peer.playerEmail!, playerMO: playerMO, peer: peer)
        }
        return true
    }
    
    func addPlayer(name: String, email: String, playerMO: PlayerMO?, peer: CommsPeer?, inviteStatus: InviteStatus! = nil, disconnectReason: String? = nil) {
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
        
        // Add to list and view - don't add players to view if going to disconnect them
        guestPlayerTableView.beginUpdates()
        unique += 1
        playerData.insert(PlayerData(name: name, email: email, playerMO: playerMO, peer: peer, unique: unique, disconnectReason: disconnectReason, inviteStatus: inviteStatus),
                          at: self.visiblePlayers)
        if disconnectReason == nil {
            guestPlayerTableView.insertRows(at: [IndexPath(row: playerData.count-2, section: 0)], with: .automatic)
        }
        guestPlayerTableView.endUpdates()
        
    }
    
    func stateChange(for peer: CommsPeer, reason: String?) {
        Utility.mainThread { [unowned self] in
            var row: Int!
            var playerNumber: Int!
            row = self.playerData.index(where: {$0.peer != nil && $0.peer.deviceName == peer.deviceName})
            if row != nil {
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
                            if self.playerData.index(where: {($0.peer == nil || $0.peer.deviceName != peer.deviceName) && $0.email == self.playerData[playerNumber - 1].email}) != nil {
                                error = true
                            }
                            if error {
                                self.disconnectPlayer(playerNumber: playerNumber, reason: "This player has already connected from another device")
                                error = true
                            }
                        }
                        if !error {
                            if !self.gameInProgress || self.scorecard.handState == nil {
                                // Game not started yet - wait
                                self.scorecard.sendInstruction("wait", to: peer)
                            } else {
                                // Game in progress - need to resend state - luckily have what we need in handState
                                self.scorecard.sendPlayers(rounds: self.scorecard.handState.rounds, cards: self.scorecard.handState.cards, bounce: self.scorecard.handState.bounce, bonus2: self.scorecard.handState.bonus2, suits: self.scorecard.handState.suits, to: peer)
                                self.scorecard.sendScores(to: peer)
                                self.scorecard.sendHandState(to: peer)
                            }
                        }
                    }
                case .notConnected:
                    // Remove from display
                    if peer.mode == .broadcast {
                        self.removePlayer(playerNumber: playerNumber)
                    } else {
                        self.reflectState(peer: peer)
                    }
                default:
                    break
                }
            }
            let ready = (self.connectedPlayers >= 3)
            self.scorecardButton.isHidden = !ready
            self.continueButton.isHidden = !ready
            self.setInstructions()
            if self.scorecard.recoveryMode && self.connectedPlayers == self.scorecard.currentPlayers {
                // Recovering  - go straight to game setup
                if self.alertController != nil {
                    self.alertController.dismiss(animated: true, completion: {
                        self.performSegue(withIdentifier: "showHostGameSetup", sender: self)
                    })
                } else {
                    self.performSegue(withIdentifier: "showHostGameSetup", sender: self)
                }
            } else if self.connectionMode == .online && self.playerData.count >= 3 && self.connectedPlayers == self.playerData.count {
                // Have connections from all invited players - press continue button
                self.continuePressed(self.scorecardButton)
            }
        }
    }
    
    func setInstructions() {
        if self.connectionMode == .unknown {
            self.instructionLabel.text = "Choose whether you want to conect with nearby players (same room) or over the internet"
        } else if self.connectedPlayers == scorecard.numberPlayers {
            self.instructionLabel.text = "All players are now connected. Press the continue button to start the game"
        } else if self.connectedPlayers >= 3 {
            self.instructionLabel.text = "Sufficient players are now connected. Press the continue button to start the game, or wait for another player to join"
        } else {
            self.instructionLabel.text = "Wait for all other players to connect and then you will be able to start the game"
        }
    }
    
    func reflectState(peer: CommsPeer) {
        let playerNumber = playerData.index(where: {$0.peer != nil && $0.peer.deviceName == peer.deviceName})
        if playerNumber != nil {
            let playerData = self.playerData[playerNumber!]
            playerData.peer = peer
            self.updateCell(playerData: playerData, hostMode: false)
        }
    }
    
    func refreshHostView() {
        self.hostPlayerTableView.reloadData()
    }
    
    func handlerStateChange(to state: CommsHandlerState) {
        if state != self.currentState {
            if state == .notStarted {
                if self.currentState == .invited || self.currentState == .inviting {
                    self.alertMessage("Invitation failed")
                }
                if defaultConnectionMode == .unknown {
                    self.setConnectionMode(.unknown)
                } else {
                    self.exitHost()
                }
            } else if state != .broadcasting {
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
                for playerNumber in 2...playerData.count {
                    let playerData = self.playerData[playerNumber - 1]
                    if playerData.peer == nil {
                        playerData.peer = CommsPeer(parent: self.scorecard.commsDelegate!,
                                                    deviceName: "",
                                                    playerEmail: playerData.email,
                                                    playerName: playerData.name)
                    }
                    playerData.inviteStatus = inviteStatus
                    self.updateCell(playerData: playerData, hostMode: false)
                }
            }
            currentState = state
        }
    }
    
    // MARK: - TableView Overrides ===================================================================== -

    func numberOfSections(in tableView: UITableView) -> Int {
        switch tableView.tag {
        case 1:
            // Host
            return (self.scorecard.settingOnlinePlayerEmail != nil ? 2 : 1)
        case 2:
            // Guests
            return 1
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView,
                   titleForHeaderInSection section: Int) -> String? {
        switch tableView.tag {
        case 1:
            switch section {
            case 0:
                // Host
                return "Host game as player"
            case 1:
                // Mode
                return "Connection mode"
            default:
                return ""
            }
        case 2:
            // Guests
            return "Other participants"
        default:
            return ""
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        switch tableView.tag {
        case 1:
            switch section {
            case 0:
                // Host
                return 1
            case 1:
                // Mode
                return (self.connectionMode == .unknown ? 2 : 1)
            default:
                return 0
            }
        case 2:
            // Guests
            return self.visiblePlayers - 1
        default:
            return 0
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
        var cell: HostPlayerTableCell
        var cellIdentifier = ""
        var dataRow = -1
        
        if tableView.tag == 1 && indexPath.section == 1 {
            // Mode
            cell = tableView.dequeueReusableCell(withIdentifier: "Host Mode Table Cell", for: indexPath) as! HostPlayerTableCell
            switch indexPath.row {
            case 0:
                // Nearby
                cell.modeLabel.text = "Broadcast for nearby players"
                cell.modeImageView.image = UIImage(named: "bluetooth")
                cell.modeLabel.alpha = 1.0
                cell.modeImageView.alpha = 1.0
            case 1:
                // Online
                
                cell.modeImageView.image = UIImage(named: "online")
                if !self.scorecard.onlineEnabled {
                    cell.modeLabel.text = "Invite players online (offline)"
                    cell.modeLabel.alpha = 0.2
                    cell.modeImageView.alpha = 0.2
                } else {
                    cell.modeLabel.text = "Invite players online"
                    cell.modeLabel.alpha = 1.0
                    cell.modeImageView.alpha = 1.0
                }
            default:
                break
            }
           
        } else {
            // Player
            switch tableView.tag {
            case 1:
                // Host
                cellIdentifier = "Host Player Table Cell"
                dataRow = 0
            case 2:
                // Guests
                cellIdentifier = "Guest Player Table Cell"
                dataRow = indexPath.row + 1
            default:
                break
            }

            cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! HostPlayerTableCell
            
            self.playerData[dataRow].cell = cell
            self.updateCell(playerData: self.playerData[dataRow], hostMode: tableView.tag==1)
            
        }
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor.clear
        cell.selectedBackgroundView = backgroundView
        
        return cell

    }
    
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return (tableView.tag == 2)
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return .none
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let sourcePlayerData = playerData[sourceIndexPath.row + 1]
        playerData.remove(at: sourceIndexPath.row + 1)
        playerData.insert(sourcePlayerData, at: destinationIndexPath.row + 1)
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if self.connectionMode == .unknown && tableView.tag == 1 && indexPath.section == 1 {
            // Mode - allow selection unless disabled
            if indexPath.row == 1 && !self.scorecard.onlineEnabled {
                return nil
            } else {
                return indexPath
            }
        } else {
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.tag == 1 && indexPath.section == 1 {
            switch indexPath.row {
            case 0:
                self.setConnectionMode(.nearby)
            case 1:
                self.setConnectionMode(.online)
            default:
                break
            }
            tableView.reloadData()
        }
    }
    
    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    // MARK: - Action Handlers ================================================================ -
    
    @objc func changeHostButtonPressed(_ button: UIButton) {
        self.scorecard.identifyPlayers(from: self, info: ["player" : true], filter: { (playerMO) in
            // Exclude inviting player
            return (self.playerData[0].email != playerMO.email )
        })
    }
    
    @objc func changeModeButtonPressed(_ button: UIButton) {
        self.setConnectionMode(.unknown)
    }
    
    @objc func disconnectButtonPressed(_ button: UIButton) {
        let row = playerData.index(where: {$0.unique == button.tag})
        if row != nil {
            let playerNumber = row! + 1
            self.disconnectPlayer(playerNumber: playerNumber, reason: "Closed by remote device")
        }
    }
    
    // MARK: - Search delegate handlers ================================================================ -
    
    func returnPlayers(complete: Bool, playerMO: [PlayerMO]?, info: [String : Any?]?) {
        if info?["player"] != nil {
            if complete {
                // Returning player
                self.scorecard.defaultPlayerOnDevice = playerMO![0].email!
                UserDefaults.standard.set(self.scorecard.defaultPlayerOnDevice, forKey: "defaultPlayerOnDevice")
                self.playerData[0].name = playerMO![0].name!
                self.playerData[0].email = playerMO![0].email!
                self.playerData[0].playerMO = playerMO![0]
                self.refreshHostView()
                
                // Check that this player hadn't connected from another devivce
                if playerData.count > 1 {
                    var disconnectPlayer: Int! = nil
                    for playerNumber in 2...playerData.count {
                        if self.playerData[playerNumber - 1].email == playerMO![0].email! {
                            disconnectPlayer = playerNumber
                        }
                    }
                    if disconnectPlayer != nil {
                        self.disconnectPlayer(playerNumber: disconnectPlayer, reason: "This player has already connected from another device")
                    }
                }
            }
        } else if info?["invitees"] != nil {
            if complete {
                // Returning invitees - Insert selected players into list
                var invite: [String] = []
                for player in playerMO! {
                    invite.append(player.email!)
                    self.addPlayer(name: player.name!,
                                   email: player.email!,
                                   playerMO: player,
                                   peer: nil,
                                   inviteStatus: .inviting)
                }
                self.guestPlayerTableView.reloadData()
                self.startOnlineConnection()
                self.startHostBroadcast(email: self.playerData[0].email, name: self.playerData[0].name, invite: invite, queueUUID: (self.scorecard.recoveryMode ? self.scorecard.recoveryConnectionUUID : nil))
             } else {
                if self.defaultConnectionMode == .unknown {
                    self.setConnectionMode(.unknown)
                } else {
                    self.exitHost()
                    
                }
            }
        }
    }
    
    // MARK: - Popover Overrides ================================================================ -
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        let viewController = popoverPresentationController.presentedViewController
        if viewController is SearchViewController {
            if self.playerData.count == 0 {
                self.exitHost()
            }
        }
    }
    
    // MARK: - User Interface Methods ================================================================ -

    func updateCell(playerData: PlayerData, hostMode: Bool) {
        if let cell = playerData.cell {
            cell.playerNameLabel.text = playerData.name
            var thumbnail: Data? = nil
            if playerData.playerMO != nil {
                thumbnail = playerData.playerMO.thumbnail
            }
            Utility.setThumbnail(data: thumbnail,
                                 imageView: cell.playerImage,
                                 initials: playerData.name,
                                 label: cell.playerDisc,
                                 size: 50)
            
            if hostMode {
                // Host
                cell.changeButton.addTarget(self, action: #selector(HostViewController.changeHostButtonPressed(_:)), for: UIControlEvents.touchUpInside)
                cell.changeButton.isHidden = (self.connectionMode == .online)
            } else {
                // Guest
                if playerData.peer == nil || playerData.peer.state == .notConnected {
                    if let inviteStatus = playerData.inviteStatus {
                        switch inviteStatus {
                        case .inviting:
                            cell.deviceNameLabel.text = "Inviting..."
                        case .invited:
                            cell.deviceNameLabel.text = "Invitation sent"
                        case .reconnecting:
                            cell.deviceNameLabel.text = "Reconnecting..."
                        default:
                            cell.deviceNameLabel.text = "Invitation failed"
                        }
                    } else {
                        cell.deviceNameLabel.text = "Not connected"
                    }
                } else {
                    cell.deviceNameLabel.text = "Connected on \(String(describing: playerData.peer!.deviceName))"
                }
                cell.disconnectButton.addTarget(self, action: #selector(HostViewController.disconnectButtonPressed(_:)), for: UIControlEvents.touchUpInside)
                cell.disconnectButton.tag = playerData.unique
                cell.disconnectButton.isHidden = (self.connectionMode == .online)
            }
        }
    }
    
    // MARK: - Utility Routines ======================================================================== -
    
    private func setConnectionMode(_ connectionMode: ConnectionMode, chooseInvitees: Bool = true) {
        let oldConnectionMode = self.connectionMode
        if connectionMode != oldConnectionMode {
            self.connectionMode = connectionMode
            // Format table views
            switch connectionMode {
            case .unknown:
                self.hostPlayerTableViewHeightConstraint.constant = 260
                self.guestPlayerTableView.isHidden = true
            default:
                self.hostPlayerTableViewHeightConstraint.constant = 100
                self.guestPlayerTableView.isHidden = false
            }
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
                if self.connectionMode == .online {
                    if chooseInvitees {
                        self.chooseOnlineInvitees()
                    }
                } else {
                    self.startNearbyConnection()
                }
            }
            
            hostPlayerTableView.reloadData()
            self.setInstructions()
        }
    }
    
    private func startNearbyConnection() {
        // Create comms service and take hosting delegate
        multipeerHost = MultipeerService(purpose: .playing, type: .server, serviceID: self.scorecard.serviceID(.playing))
        self.scorecard.commsDelegate = multipeerHost
        self.takeDelegates(self)
        if self.playerData.count > 0 {
            self.startHostBroadcast(email: playerData[0].email, name: playerData[0].name)
        }
    }

    private func startOnlineConnection() {
        // Create comms service and take hosting delegate
        rabbitMQHost = RabbitMQService(purpose: .playing, type: .server, serviceID: nil)
        self.scorecard.commsDelegate = rabbitMQHost
        self.takeDelegates(self)
    }

    private func takeDelegates(_ delegate: Any?) {
        self.scorecard.commsDelegate?.stateDelegate = delegate as! CommsStateDelegate?
        self.scorecard.commsDelegate?.dataDelegate = delegate as! CommsDataDelegate?
        self.scorecard.commsDelegate?.connectionDelegate = delegate as! CommsConnectionDelegate?
        self.scorecard.commsDelegate?.handlerStateDelegate = delegate as! CommsHandlerStateDelegate?
    }
    
    private func chooseOnlineInvitees() {
        self.scorecard.identifyPlayers(from: self,
                                       title: "Choose players",
                                       instructions: "Choose 2 or 3 players to invite to the game",
                                       minPlayers: 2,
                                       maxPlayers: self.scorecard.numberPlayers - 1,
                                       info: ["invitees" : true],
                                       filter: self.filterPlayers)
    }
    
    internal func filterPlayers(_ playerMO: PlayerMO) -> Bool {
        if playerMO.email == self.playerData[0].email || playerMO.email == nil {
            return false
        } else {
            return true
        }
    }
    
    func removeCardPlayed(data: [String : Any]) {
        let playerNumber = data["player"] as! Int
        let card = Card(fromNumber: data["card"] as! Int)
        if playerNumber != 1 {
            // Only need to remove other players cards since my own will be removed by playing them
            if let cardNumber = Pack.findCard(hand: self.scorecard.deal.hands[playerNumber - 1], card: card) {
                self.scorecard.deal.hands[playerNumber - 1].cards.remove(at: cardNumber)
            }
        }
    }
    
    func handlerCompleteNotification() -> NSObjectProtocol? {
        // Set a notification for handler complete
        let observer = NotificationCenter.default.addObserver(forName: .broadcastHandlerCompleted, object: nil, queue: nil) {
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
            self.scorecard.commsDelegate?.disconnect(from: playerData[playerNumber - 1].peer, reason: reason)
        }
        removePlayer(playerNumber: playerNumber)
    }
    
    private func removePlayer(playerNumber: Int) {
        guestPlayerTableView.beginUpdates()
        let disconnectReason = playerData[playerNumber - 1].disconnectReason
        playerData.remove(at: playerNumber - 1)
        if disconnectReason == nil {
            guestPlayerTableView.deleteRows(at: [IndexPath(row: playerNumber - 2, section: 0)], with: .automatic)
        }
        guestPlayerTableView.endUpdates()
    }
        
    private func setupPlayers() {
        var playerNumber = 0
        selectedPlayers = []
        for playerData in self.playerData {
            var playerMO = playerData.playerMO
            if playerMO == nil {
                // Not found - need to create the player locally
                let playerDetail = PlayerDetail(self.scorecard)
                playerDetail.name = playerData.name
                playerDetail.email = playerData.email
                playerDetail.dedupName(self.scorecard)
                playerMO = playerDetail.createMO()
                // Get picture
                if let peer = playerData.peer {
                    self.scorecard.requestPlayerThumbnail(from: peer, playerEmail: playerDetail.email)
                }
            }
            playerNumber += 1
            selectedPlayers.append(playerMO!)
        }
        self.scorecard.updateSelectedPlayers(selectedPlayers)
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
    
    private func waitOtherPlayers(completion: (()->())? = nil) {
        self.alertController = UIAlertController(title: "Ready", message: "Waiting for other players to rejoin...", preferredStyle: .alert)
        self.alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { UIAlertAction -> () in
            self.exitHost()
            self.alertController = nil
        }))
        self.present(self.alertController, animated: true, completion: completion)
    }
    
    private func startHostBroadcast(email: String!, name: String!, invite: [String]? = nil, queueUUID: String! = nil) {
        // Start host broadcast
        self.scorecard.commsDelegate?.start(email: email, queueUUID: queueUUID, name: name, invite: invite, recoveryMode: self.scorecard.recoveryMode, matchDeviceName: nil)
    }
    
    public func finishHost() {
        self.scorecard.sendScores = false
        self.stopHostBroadcast()
        self.takeDelegates(nil)
        self.scorecard.commsDelegate = nil
        self.scorecard.resetSharing()
        self.clearHandlerCompleteNotification(observer: self.observer)
        self.scorecard.resetOverrideSettings()
    }
    
    private func exitHost() {
        self.finishHost()
        self.performSegue(withIdentifier: "hideHost", sender: self)
    }
    
    private func stopHostBroadcast() {
        // Revert to normal sharing (if enabled)
        self.scorecard.commsDelegate?.stop()
    }
    // MARK: - Segue Prepare Handler ================================================================ -
    
    override internal func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier! {
        case "showHostGameSetup":
            let destination = segue.destination as! GameSetupViewController
            destination.selectedPlayers = selectedPlayers
            destination.scorecard = self.scorecard
            destination.returnSegue = "hideHostGameSetup"
            destination.rabbitMQService = self.rabbitMQHost
            
        default:
            break
        }
    }
}
        
// MARK: - Utility classes ========================================================================= -

class PlayerData {
    var cell: HostPlayerTableCell!
    var name: String
    var email: String
    var playerMO: PlayerMO!
    var peer: CommsPeer!
    var unique: Int
    var disconnectReason: String! // Have only accepted connection to be able to pass this message when disconnect
    var inviteStatus: InviteStatus!
    
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

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class HostPlayerTableCell: UITableViewCell {
    @IBOutlet weak var playerNameLabel: UILabel!
    @IBOutlet weak var playerImage: UIImageView!
    @IBOutlet weak var playerDisc: UILabel!
    @IBOutlet weak var modeLabel: UILabel!
    @IBOutlet weak var modeImageView: UIImageView!
    @IBOutlet weak var deviceNameLabel: UILabel!
    @IBOutlet weak var changeButton: UIButton!
    @IBOutlet weak var disconnectButton: UIButton!
}

