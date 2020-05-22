//
//  ClientViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 27/05/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit
import Combine
import MessageUI

struct MenuAction {
    var tag: Int
    var section: Int
    var title: String
    var highlight: Bool
    var sequence: Int
    var isHidden: (()->Bool)?
    var action: ()->()
}

public enum ClientAppState: String {
    case notConnected = "Not connected"
    case connecting = "Connecting"
    case reconnecting = "Re-connecting"
    case connected = "Connected"
    case waiting = "Waiting to start"
    case finished = "Finished"
}

class ClientViewController: ScorecardViewController, UITableViewDelegate, UITableViewDataSource, MFMailComposeViewControllerDelegate, PlayerSelectionViewDelegate, SyncDelegate, ReconcileDelegate, ClientControllerDelegate {

    // MARK: - Class Properties ======================================================================== -
    
    // Main state properties
    internal let sync = Sync()
    private var hostController: HostController!
    private var clientController: ClientController!

    // Properties to pass state
    public let commsPurpose: CommsPurpose = .playing
    private var matchDeviceName: String!
    private var matchProximity: CommsConnectionProximity!
 
    // Local class variables
    private var availablePeers: [AvailablePeer] = []
    public var thisPlayer: String!
    public var thisPlayerName: String!
    internal var choosingPlayer = false
    internal var tableViewHeight: CGFloat = 0.0

    // Timers
    internal var networkTimer: Timer!
    
    // Startup and reconcile
    internal var getStarted = true
    internal var reconcile: Reconcile!
    internal var reconcileAlertController: UIAlertController!
    internal var reconcileContinue: UIAlertAction!
    internal var reconcileIndicatorView: UIActivityIndicatorView!
    
    // Actions
    private var sections: [Int:Int]!
    private var sectionActions: [Int : [(frame: CGRect, position: Position, action: MenuAction)]]!
    private var menuActions: [MenuAction]!
    private let mainSection = 1
    private let infoSection = 2
    private let adminSection = 3

    // Debug rotations code
    private let code: [CGFloat] = [ -1.0, -1.0, 1.0, -1.0, 1.0]
    private var matching = 0
    
    private var appState: ClientAppState!
    private var peerSection: Int! = 0
    private var hostSection: Int! = 1
    internal var invite: Invite!
    internal var recoveryMode = false
    internal var firstTime = true
    private var rotated = false
    private var isNetworkAvailable: Bool?
    private var isLoggedIn: Bool?
    
    private var hostingOptions: Int = 0
    private var onlineRow: Int = -1
    private var nearbyRow: Int = -1
    
    // MARK: - IB Outlets ============================================================================== -
    
    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var titleBar: UINavigationItem!
    @IBOutlet private weak var clientTableView: UITableView!
    @IBOutlet private weak var clientTableViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var thisPlayerTitle: UILabel!
    @IBOutlet private weak var thisPlayerThumbnail: ThumbnailView!
    @IBOutlet private weak var thisPlayerNameLabel: UILabel!
    @IBOutlet private weak var thisPlayerThumbnailWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var changePlayerButton: RoundedButton!
    @IBOutlet private weak var playerSelectionView: PlayerSelectionView!
    @IBOutlet private weak var playerSelectionViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var menuButton: ClearButton!
    
    // MARK: - IB Actions ============================================================================== -
        
    @IBAction func changePlayerPressed(_ sender: UIButton) {
        if self.choosingPlayer {
            self.hidePlayerSelection()
        } else {
            self.showPlayerSelection()
        }
    }
    
    @IBAction func actionButtonPressed(_ sender: UIButton) {
        self.showActionMenu()
    }
    
    @IBAction func rotationGesture(recognizer:UIRotationGestureRecognizer) {
        if self.appState != .notConnected || Scorecard.adminMode {
            // Go to standard menu
             RotationGesture.adminMenu(recognizer: recognizer, message: "App state: \(self.appState?.rawValue ?? "Unknown")")
        } else {
            // Enter admin mode
            if Scorecard.shared.iCloudUserIsMe && recognizer.state == .ended {
                let value: CGFloat = (recognizer.rotation < 0.0 ? -1.0 : 1.0)
                if code[matching] == value {
                    matching += 1
                    if matching == code.count {
                        // Code correct - set admin mode
                        Scorecard.adminMode = !Scorecard.adminMode
                        self.restart()
                        matching = 0
                    }
                } else {
                    matching = 0
                }
            }
        }
    }
    
    // MARK: - View Overrides ========================================================================== -

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup game
        Scorecard.game = Game()
                
        self.hideNavigationBar()
        
        // Possible clear all data in test mode
        TestMode.resetApp()
        
        // Restart client
        self.restart(createController: false)

        // Set not connected
        self.appStateChange(to: .notConnected)
        
        // Stop any existing sharing activity
        Scorecard.shared.stopSharing()
                
        // Update instructions / title
        self.titleBar.title = "Play a Game"
        
        // Check if recovering
        self.recoveryMode = Scorecard.recovery.recoveryAvailable
        if self.recoveryMode && Scorecard.recovery.onlineType == .server {
            Scorecard.recovery.recovering = true
            Scorecard.recovery.loadSavedValues()
        }

        // Setup playing as
        self.setupThisPlayer()
                
        Scorecard.shared.viewPresenting = .none
        
        // Clear hand state
        Scorecard.game?.handState = nil
        
        // Setup action menu
        self.setupMenuActions()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.showThisPlayer()
        self.changePlayerAvailable()
        if firstTime {
            // Get local and cloud version
            Scorecard.shared.getVersion(completion: {
                // Don't call this until any upgrade has taken place
                self.getCloudVersion()
            })
            
            // Note flow continues in completion handler of getCloudVersion
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.rotated = true
        Scorecard.shared.reCenterPopup(self)
        self.view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Update sizes to layout constraints immediately to aid calculations
        self.view.layoutIfNeeded()
        
        if self.rotated && self.choosingPlayer {
            // Resize player selection
            self.showPlayerSelection()
        }
        if self.firstTime || self.rotated {
            self.rotated = false
            self.clientTableView.reloadData()
        }
    }
    
    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        
        // Play sound
        self.alertSound()
        
        self.restart()
    }

    // MARK: - Show other views ======================================================================= -
    
    private func showGetStarted() {
        GetStartedViewController.show(from: self, completion: {self.restart()})
    }
        
    private func showHighScores() {
        HighScoresViewController.show(from: self, backText: "", backImage: "home")
    }
    
    private func showSettings() {
        SettingsViewController.show(from: self, backText: "", backImage: "home", completion: self.showSettingsCompletion)
    }
    
    private func showSettingsCompletion() {
        Scorecard.game.reset()
        self.restart()
    }
    
    private func showPlayers() {
        PlayersViewController.show(from: self, completion: {self.restart()})
    }
    
    private func scoreGame() {
        // TODO: Need to write a scoring appController like client or host
    }
            
    // MARK: - Player Selection View Delegate Handlers ======================================================= -
    
    private func showPlayerSelection() {
        let alreadyChoosingPlayer = self.choosingPlayer
        if !alreadyChoosingPlayer {
            self.choosingPlayer = true
            self.playerSelectionView.set(parent: self)
            self.playerSelectionView.delegate = self
        }
        let selectionHeight = self.view.frame.height - self.playerSelectionView.frame.minY - self.scrollView.frame.minY
        self.playerSelectionView.set(size: CGSize(width: UIScreen.main.bounds.width, height: selectionHeight))
        let requiredHeight = self.playerSelectionView.getHeightFor(items: Scorecard.shared.playerList.count + 1)
        if requiredHeight > selectionHeight {
            self.playerSelectionView.set(size: CGSize(width: UIScreen.main.bounds.width, height: requiredHeight))
        }
        UIView.performWithoutAnimation {
            // Update labels without animation to avoid distraction
            self.thisPlayerNameLabel.text = "Choose Player"
            self.thisPlayerNameLabel.layoutIfNeeded()
            self.changePlayerButton.setTitle("Cancel", for: .normal)
            self.changePlayerButton.layoutIfNeeded()
        }
        if !alreadyChoosingPlayer {
            self.scrollView.scrollRectToVisible(CGRect(), animated: false)
            self.tableViewHeight = self.clientTableViewHeightConstraint.constant
        }
        
        Utility.animate(view: self.view, duration: 0.5, completion: {
            self.clientTableViewHeightConstraint.constant = 0.0

        }) {
            self.playerSelectionViewHeightConstraint.constant = max(requiredHeight, selectionHeight)
        }
        let playerList = Scorecard.shared.playerList.filter { $0.email != self.thisPlayer }
        self.playerSelectionView.set(players: playerList, addButton: true, updateBeforeSelect: false)
        
    }
    
    private func hidePlayerSelection() {
        self.choosingPlayer = false
        self.showThisPlayer()
        self.scrollView.isScrollEnabled = true

        Utility.animate(view: self.view, duration: 0.5) {
            self.playerSelectionViewHeightConstraint.constant = 0.0
        }
        self.clientTableViewHeightConstraint.constant = self.tableViewHeight
        self.clientTableView.reloadData()
    }
    
    internal func didSelect(playerMO: PlayerMO) {
        // Save player as default for device
        if let onlineEmail = Scorecard.activeSettings.onlinePlayerEmail {
            if playerMO.email == onlineEmail {
                // Back to normal user - can remove temporary override
                Notifications.removeTemporaryOnlineGameSubscription()
            } else {
                Notifications.addTemporaryOnlineGameSubscription(email: playerMO.email!)
            }
        }
        self.thisPlayer = playerMO.email!
        Scorecard.shared.defaultPlayerOnDevice = self.thisPlayer
        UserDefaults.standard.set(self.thisPlayer, forKey: "defaultPlayerOnDevice")
        self.destroyClientController()
        self.createClientController()
        self.hidePlayerSelection()
    }
    
    internal func resizeView() {
        // Additional players added - resize the view
        self.showPlayerSelection()
    }
    
     // MARK: - Action Handlers ================================================================ -
    
    private func setupMenuActions() {
        
        self.menuActions = []
        
        self.addAction(section: mainSection, title: "Get Started", isHidden: {Scorecard.shared.playerList.count != 0}, action: { () in
            self.showGetStarted()
        })
        
        self.addAction(section: mainSection, title: "Settings", action: { () in
            self.showSettings()
        })
        
        self.addAction(section: mainSection, title: "Score Game", action: { () in
            self.scoreGame()
        })
        
        self.addAction(section: infoSection, title: "Players", isHidden: {Scorecard.shared.playerList.count == 0}, action: { () in
            self.showPlayers()
        })
        
        self.addAction(section: infoSection, title: "Statistics", isHidden: {Scorecard.shared.playerList.count == 0}, action: { () in
            let _ = StatisticsViewer(from: self)
        })
        
        self.addAction(section: infoSection, title: "History", isHidden: {!Scorecard.activeSettings.saveHistory || Scorecard.shared.playerList.count == 0}, action: { () in
            let _ = HistoryViewer(from: self)
        })
        
        self.addAction(section: infoSection, title: "High Scores", isHidden: {!Scorecard.activeSettings.saveHistory || Scorecard.shared.playerList.count == 0}, action: { () in
            self.showHighScores()
        })
        
        self.addAction(section: infoSection, title: "Cancel recovery", isHidden: {!Scorecard.recovery.recoveryAvailable}, action: { () in
            self.cancelRecovery()
            self.restart()
        })
        
        self.addAction(section: adminSection, title: "Delete iCloud Database", isHidden: {!Scorecard.adminMode}, action: { () in
            DataAdmin.deleteCloudDatabase(from: self)
        })

        self.addAction(section: adminSection, title: "Reset Sync Record IDs", isHidden: {!Scorecard.adminMode}, action: { () in
            DataAdmin.resetSyncRecordIDs(from: self)
        })

        self.addAction(section: adminSection, title: "Remove Duplicate Games", isHidden: {!Scorecard.adminMode}, action: { () in
            DataAdmin.removeDuplicates(from: self)
        })
        
        self.addAction(section: adminSection, title: "Rebuild All Players", isHidden: {!Scorecard.adminMode}, action: { () in
            self.reconcilePlayers(allPlayers: true)
        })

        self.addAction(section: adminSection, title: "Backup Device", isHidden: {!Scorecard.adminMode}, action: { () in
            self.backupDevice()
        })
        
    }
    
    private func addAction(section: Int, title: String, highlight: Bool = false, isHidden: (()->Bool)? = nil, action: @escaping ()->()) {
        let tag = self.menuActions.count
        self.menuActions.append(MenuAction(tag: tag, section: section, title: title, highlight: highlight, sequence: self.menuActions.count, isHidden: isHidden, action: action))
    }
    
    private func showActionMenu() {
        let actionSheet = ActionSheet("Other Options")
        
        for action in self.menuActions {
            if !(action.isHidden?() ?? false) {
                actionSheet.add(action.title, handler: {
                    action.action()
                })
            }
        }
        
        // Present the action sheet
        actionSheet.add("Cancel", style: .cancel)
        actionSheet.present()
    }
    
    // MARK: - Send email and delegate methods =========================================================== -
    
    func backupDevice() {
        Backup.sendEmail(from: self)
    }
        
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }

    
    // MARK: - Helper routines ===================================================================== -
    
    internal func restart(createController: Bool = true) {
        self.destroyClientController()
        self.hostController = nil
        self.setupHostingOptions()
        self.appStateChange(to: .notConnected)
        self.changePlayerAvailable()
        Scorecard.game?.resetValues()
        Scorecard.shared.setGameInProgress(false)
        self.availablePeers = []
        self.clientTableView.reloadData()

        // Check network / iCloud
        Scorecard.shared.checkNetworkConnection() {
            if (self.isNetworkAvailable != Scorecard.shared.isNetworkAvailable || self.isLoggedIn != Scorecard.shared.isLoggedIn) {
                self.clientTableView.reloadData()
            }
            self.isNetworkAvailable = Scorecard.shared.isNetworkAvailable
            self.isLoggedIn = Scorecard.shared.isLoggedIn
        }

        if createController {
            // Create controller after short delay
            Utility.executeAfter(delay: 0.1) {
                self.createClientController()
            }
        }
    }
    
    @objc private func checkNetwork(_ sender: Any? = nil) {
        // Check network
        self.restart()
    }
    
    // MARK: - iCloud fetch and sync delegates ======================================================== -
    
    private func getCloudVersion(async: Bool = false) {
        if Scorecard.shared.isNetworkAvailable {
            self.sync.delegate = self
            if self.sync.synchronise(syncMode: .syncGetVersion, timeout: nil, waitFinish: async) {
                // Running or queued (if async)
            } else {
                self.syncCompletion(0)
            }
        } else {
            self.syncCompletion(0)
        }
    }
    
    internal func syncCompletion(_ errors: Int) {
        
        Utility.debugMessage("client", "Version returned")
        
        // Continue to Get Started if necessary pending version lookup - a risk but probably OK
        if Scorecard.shared.playerList.count == 0 && getStarted {
            // No players setup - go to Get Started
            getStarted = false
            self.showGetStarted()
        }
        
        if self.firstTime {
            
            if !Scorecard.shared.upgradeToVersion(from: self) {
                self.alertMessage("Error upgrading to current version", okHandler: {
                    exit(0)
                })
            }
            
            if Scorecard.shared.playerList.count != 0 && !Scorecard.version.blockSync && Scorecard.shared.isNetworkAvailable && Scorecard.shared.isLoggedIn {
                // Rebuild any players who have a sync in progress flag set
                self.reconcilePlayers()
            }

            self.firstTime = false
            
            // Create a client controller to manage connections
            self.createClientController()
            
            self.clientTableView.reloadData()
            
            // Link to host if recovering a server
            if self.recoveryMode && Scorecard.recovery.onlineType == .server {
                self.hostGame(recoveryMode: true)
            }
            
        }
    }
    
    internal func syncAlert(_ message: String, completion: @escaping ()->()) {
        self.alertMessage(message, title: "Contract Whist Scorecard", okHandler: {
            if Scorecard.version.blockAccess {
                exit(0)
            } else {
                completion()
            }
        })
    }
    
    // MARK: - Call reconcile and reconcile delegate methods =========================================================== -
    
    private func reconcilePlayers(allPlayers: Bool = false) {
        
        var playerMOList: [PlayerMO] = []
        for playerMO in Scorecard.shared.playerList {
            if allPlayers || playerMO.syncInProgress {
                playerMOList.append(playerMO)
            }
        }

        if playerMOList.count != 0 {
            // Create an alert controller
            var title = ""
            if allPlayers {
                title = "\n\n\nRebuilding all players\n\n\n\n"
            } else {
                title = "Some players may have been corrupted during synchronisation and are being rebuilt\n\n\n"
            }
            
            self.reconcileAlertController = UIAlertController(title: title, message: "", preferredStyle: .alert)
            self.reconcileContinue = UIAlertAction(title: "Continue", style: UIAlertAction.Style.default, handler: nil)
            self.reconcileAlertController.addAction(self.reconcileContinue)
            self.reconcileContinue.isEnabled = false
            
            //add the activity indicator as a subview of the alert controller's view
            self.reconcileIndicatorView = UIActivityIndicatorView(frame: CGRect(x: 0, y: 150,
                                                                                width: self.reconcileAlertController.view.frame.width,
                                                                                height: 100))
            self.reconcileIndicatorView.style = UIActivityIndicatorView.Style.large
            self.reconcileIndicatorView.color = UIColor.black
            self.reconcileIndicatorView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.reconcileAlertController.view.addSubview(self.reconcileIndicatorView)
            self.reconcileIndicatorView.isUserInteractionEnabled = true
            self.reconcileIndicatorView.startAnimating()
            
            self.present(self.reconcileAlertController, animated: true, completion: nil)
            
            // Set reconcile running
            reconcile = Reconcile()
            reconcile.delegate = self
            reconcile.reconcilePlayers(playerMOList: playerMOList)
        }
    }
    
    public func reconcileAlertMessage(_ message: String) {
        Utility.mainThread {
            self.reconcileAlertController.title = message
            self.reconcileAlertController.message = ""
        }
    }
    
    public func reconcileMessage(_ message: String) {
        Utility.mainThread {
            self.reconcileAlertController.message = message
        }
    }
    
    public func reconcileCompletion(_ errors: Bool) {
        Utility.mainThread {
            self.reconcileIndicatorView.stopAnimating()
            self.reconcileIndicatorView.isHidden = true
            self.reconcileContinue.isEnabled = true
        }
    }
    
    // MARK: - TableView Overrides ===================================================================== -
    
    internal func numberOfSections(in tableView: UITableView) -> Int {
        if commsPurpose == .playing && !recoveryMode {
            return 2
        } else {
            return 1
        }
    }
    
    internal func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Defer showing entries until view is fully loaded (i.e. firstTime is false)
        switch section {
        case peerSection:
            return (self.firstTime ? 0 : max(1, self.availablePeers.count))
        case hostSection:
            return ((!Scorecard.shared.isNetworkAvailable || !Scorecard.shared.isLoggedIn) ? 1 : (self.firstTime ? 0 : self.hostingOptions))
        default:
            return 0
        }
    }
    
    internal func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case hostSection:
            return (ScorecardUI.landscapePhone() ? 40 : 76)
        default:
            return 0
        }
    }
    
    internal func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == hostSection {
            let headerView = UITableViewHeaderFooterView(frame: CGRect(origin: CGPoint(), size: CGSize(width: tableView.frame.width, height: 76.0)))
            let width: CGFloat = 150.0
            let button = AngledButton(frame: CGRect(x: (headerView.frame.width - width) / 2.0, y: (ScorecardUI.landscapePhone() ? 4 : 40), width: width, height: 30))
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
            return (ScorecardUI.landscapePhone() ? 80 : 100)
            
        case self.hostSection:
            // Hosting options
            return (ScorecardUI.landscapePhone() ? 60 : 80)
            
        default:
            return 0
        }
    }
    
    internal func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: ClientTableCell!
        let labelWidth: CGFloat = min(self.view.frame.width - 128, self.view.frame.height)
        let arrowWidth: CGFloat = 80.0 / 3.0
        let hexagonInset: CGFloat = ((self.view.frame.width - labelWidth) / 2.0) - arrowWidth
        let hexagonWidth: CGFloat = labelWidth + (2 * arrowWidth)
        
        switch indexPath.section {
        case self.peerSection:
            // List of remote peers
            
            cell = tableView.dequeueReusableCell(withIdentifier: "Service Cell", for: indexPath) as? ClientTableCell
            cell.hexagonLayer?.removeFromSuperlayer()
            cell.serviceLabelWidthConstraint.constant = labelWidth
            cell.serviceButton.setTitle((self.commsPurpose == .playing ? "Join a Game" : "View Scorecard"), for: .normal)
            
            if self.availablePeers.count == 0 && !self.recoveryMode {
                
                cell.serviceLabel.textColor = Palette.text
                if self.commsPurpose == .sharing {
                    cell.serviceLabel.text = "There are no other devices currently offering to share with you"
                } else {
                    cell.serviceLabel.text = "There are no other players currently offering to host a game for you to join"
                }
                cell.serviceLabel.font = UIFont.systemFont(ofSize: 18.0, weight: .regular)
                
            } else {
                
                let lineWidth: CGFloat = 3.5
                let frame = CGRect(x: hexagonInset, y: cell.serviceButton.frame.midY - (lineWidth / 2.0), width: hexagonWidth, height: cell.frame.height - cell.serviceButton.frame.midY - 2.0)
                cell.hexagonLayer = Polygon.hexagonFrame(in: cell, frame: frame, strokeColor: Palette.tableTop, lineWidth: lineWidth, radius: 10.0)
                var name: String
                var state: CommsConnectionState = .notConnected
                var oldState: CommsConnectionState = .notConnected
                var deviceName = ""
                var proximity = ""
                var connecting = false
                if self.availablePeers.count == 0 && recoveryMode {
                    name = Scorecard.shared.findPlayerByEmail(Scorecard.recovery.connectionRemoteEmail ?? "")?.name ?? "Unknown"
                } else {
                    let availableFound = self.availablePeers[indexPath.row]
                    name = availableFound.name
                    state = availableFound.state
                    oldState = availableFound.oldState
                    deviceName = availableFound.deviceName!
                    connecting = availableFound.connecting
                    proximity = availableFound.proximity?.rawValue ?? ""
                }
                var serviceText: String
                
                switch state {
                case .notConnected:
                    if oldState != .notConnected {
                        serviceText = "\(name) has disconnected"
                    } else if self.recoveryMode {
                        serviceText = (Scorecard.recovery.onlineType == .server ? "Trying to resume game..." : "Trying to reconnect to \(name)...")
                    } else if self.commsPurpose == .sharing {
                        serviceText = "View scorecard on \(deviceName)"
                    } else if connecting {
                        serviceText = "Connecting to \(name)..."
                    } else {
                        serviceText = "Join \(name)'s \(proximity) game"
                    }
                case .connected:
                    if self.commsPurpose == .sharing {
                        serviceText = "Viewing Scorecard on\n\(deviceName).\nWaiting to start..."
                    } else {
                        serviceText = "Connected to \(name). Waiting to start..."
                    }
                case .recovering:
                    serviceText = "Trying to recover connection to \(name)..."
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
            cell.serviceLabelWidthConstraint.constant = labelWidth
            
            let frame = CGRect(x: hexagonInset, y: 4.0, width: hexagonWidth, height: cell.frame.height - 8.0)
            cell.hexagonLayer = Polygon.hexagonFrame(in: cell, frame: frame, strokeColor: Palette.roomInterior.withAlphaComponent((self.availablePeers.count == 0 ? 1.0 : 1.0)), lineWidth: (self.availablePeers.count == 0 ? 2.0 : 1.0), radius: 10.0)
            
            cell.serviceLabel.textColor = Palette.roomInterior
            let hostText = NSMutableAttributedString()
            let normalText = [NSAttributedString.Key.foregroundColor: Palette.roomInterior.withAlphaComponent((self.availablePeers.count == 0 ? 1.0 : 1.0))]
            var boldText: [NSAttributedString.Key : Any] = normalText
            boldText[NSAttributedString.Key.font] = UIFont.systemFont(ofSize: 18.0, weight: .black)
            let errorText = [NSAttributedString.Key.foregroundColor: Palette.error]
            
            
            if !Scorecard.shared.isNetworkAvailable || !Scorecard.shared.isLoggedIn {
                let action = (Scorecard.shared.isNetworkAvailable ? "Login to iCloud" : "Join a network")
                hostText.append(NSMutableAttributedString(string: action, attributes: errorText))
                hostText.append(NSMutableAttributedString(string: " to enable online games and sync", attributes: normalText))
            } else {
                switch indexPath.row {
                case self.nearbyRow:
                    hostText.append(NSMutableAttributedString(string: "Host a", attributes: normalText))
                    hostText.append(NSMutableAttributedString(string: " local ", attributes: boldText))
                    hostText.append(NSMutableAttributedString(string: "bluetooth game for nearby players", attributes: normalText))
                case self.onlineRow:
                    hostText.append(NSMutableAttributedString(string: "Host an", attributes: normalText))
                    hostText.append(NSMutableAttributedString(string: " online ", attributes: boldText))
                    hostText.append(NSMutableAttributedString(string: "game to play over the internet", attributes: normalText))
                default:
                    break
                }
            }
            cell.serviceLabel.attributedText = hostText
        default:
            break
        }
        
        // Make sure all off table view is shown without scrolling - scrolling handled by underlying scroll view
        let newHeight = self.clientTableView.contentSize.height
        if newHeight > self.clientTableView.frame.height && !self.choosingPlayer {
            self.clientTableViewHeightConstraint.constant = newHeight
        }
        
       return cell!
    }
    
    internal func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        switch indexPath.section {
        case peerSection:
            if self.availablePeers.count == 0 {
                return nil
            } else if !Scorecard.shared.isNetworkAvailable || !Scorecard.shared.isLoggedIn {
                return indexPath
            } else {
                let availableFound = self.availablePeers[indexPath.row]
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
            if !Scorecard.shared.isNetworkAvailable || !Scorecard.shared.isLoggedIn {
                self.restart()
            } else {
                var mode: ConnectionMode
                switch indexPath.row {
                case nearbyRow:
                    mode = .nearby
                default:
                    mode = .online
                }
                
                self.destroyClientController()
                
                self.hostGame(mode: mode, playerEmail: self.thisPlayer)
            }
            
        default:
            break
        }
    }
    
    private func hostGame(mode: ConnectionMode? = nil, playerEmail: String? = nil, recoveryMode: Bool = false) -> Void {
        // Stop any Client controller
        if self.clientController != nil {
            self.clientController.stop()
            self.clientController = nil
        }
        
        // Create Host controller
        if self.hostController == nil {
            self.hostController = HostController(from: self)
        }
        
        // Start Host controller
        hostController.start(mode: mode, playerEmail: playerEmail, recoveryMode: recoveryMode, completion: { (returnHome) in
            if returnHome {
                self.cancelRecovery()
            }
            self.hostController?.stop()
            self.hostController = nil
            self.restart()
        })
    }
    
    @objc private func selectPeerSelector(_ sender: UIButton) {
        self.selectPeer(sender.tag)
    }
    
    private func selectPeer(_ row: Int) {
        let availableFound = availablePeers[row]
        self.checkFaceTime(peer: availableFound, completion: { (faceTimeAddress) in
            self.clientController.connect(row: row, faceTimeAddress: faceTimeAddress ?? "")
        })
    }
    
    private func checkFaceTime(peer: AvailablePeer, completion: @escaping (String?)->()) {
        if peer.proximity == .online && (Scorecard.activeSettings.faceTimeAddress ?? "") != "" && Utility.faceTimeAvailable() {
            self.alertDecision("\nWould you like the host to call you back on FaceTime at '\(Scorecard.activeSettings.faceTimeAddress!)'?\n\nNote that this will make this address visible to the host",
                title: "FaceTime",
                okButtonText: "Yes",
                okHandler: {
                    completion(Scorecard.activeSettings.faceTimeAddress)
            },
                cancelButtonText: "No",
                cancelHandler: {
                    completion(nil)
            })
        } else {
            completion(nil)
        }
    }
    
    // MARK: - Utility Routines ======================================================================== -

    private func createClientController() {
        self.availablePeers = []
        self.clientTableView.reloadData()
        self.clientTableView.layoutIfNeeded()
        if self.thisPlayer != nil {
            self.clientController = ClientController(from: self, purpose: self.commsPurpose, playerEmail: self.thisPlayer, playerName: self.thisPlayerName, matchDeviceName: self.matchDeviceName, matchProximity: self.matchProximity)
            self.clientController.delegate = self
        }
    }
    
    private func destroyClientController() {
        self.clientController?.stop()
        self.clientController = nil
    }
    
    private func setupHostingOptions() {
        // Set up sections
        if self.commsPurpose == .playing {
            peerSection = 0
            hostSection = 1
        } else {
            peerSection = 0
            hostSection = -1
        }
        
        // Setup hosting options
        self.hostingOptions = 0
        
        if self.commsPurpose == .playing {
            
            if Scorecard.activeSettings.onlinePlayerEmail != nil {
                self.nearbyRow = self.hostingOptions
                self.hostingOptions += 1
                self.onlineRow = self.hostingOptions
                self.hostingOptions += 1
            }
        }
    }
    
    private func setupThisPlayer() {
        if self.commsPurpose == .playing {
            if self.recoveryMode && Scorecard.recovery.onlineMode != nil {
                // Recovering - use same player
                self.thisPlayer = Scorecard.recovery.connectionEmail
                self.thisPlayerName = Scorecard.shared.findPlayerByEmail(self.thisPlayer)?.name
                self.matchDeviceName = Scorecard.recovery.connectionRemoteDeviceName
                self.matchProximity = Scorecard.recovery.onlineProximity
                if self.recoveryMode && Scorecard.recovery.onlineMode == .invite {
                    if self.thisPlayer == nil {
                        self.alertMessage("Error recovering game", okHandler: {
                            self.cancelRecovery()
                            self.restart()
                        })
                        return
                    }
                }
            }
            if !self.recoveryMode || Scorecard.recovery.onlineType == .client {
                if self.thisPlayer == nil || self.matchDeviceName == nil {
                    // Not got player and device name from recovery - use default
                    var defaultPlayer: String!
                    if Scorecard.shared.onlineEnabled {
                        defaultPlayer = Scorecard.activeSettings.onlinePlayerEmail
                    } else {
                        defaultPlayer = Scorecard.shared.defaultPlayerOnDevice
                    }
                    if defaultPlayer != nil {
                        let playerMO = Scorecard.shared.findPlayerByEmail(defaultPlayer)
                        if playerMO != nil {
                            self.thisPlayer = defaultPlayer
                            self.thisPlayerName = playerMO!.name
                        } else {
                            defaultPlayer = nil
                        }
                    }
                    if defaultPlayer == nil {
                        if let playerMO = Scorecard.shared.playerList.min(by: {($0.localDateCreated! as Date) < ($1.localDateCreated! as Date)}) {
                            self.thisPlayer = playerMO.email
                            self.thisPlayerName = playerMO.name
                        }
                    }
                }
            }
        }
    }
    
    private func showThisPlayer() {
        if self.commsPurpose == .playing {
            if let player = self.thisPlayer, let playerMO = Scorecard.shared.findPlayerByEmail(player) {
                let size = SelectionViewController.thumbnailSize(labelHeight: 0.0)
                self.thisPlayerThumbnailWidthConstraint.constant = size.width
                self.thisPlayerThumbnail.set(data: playerMO.thumbnail, name: playerMO.name!, nameHeight: 0.0, diameter: size.width)
                self.thisPlayerNameLabel.text = "Play as \(playerMO.name!)"
                self.changePlayerButton.setTitle("Change", for: .normal)
            }
        } else {
            self.thisPlayerNameLabel.text = "Choose Device to View"
            self.changePlayerButton.isHidden = true
        }
    }
    
    internal func appStateChange(to newState: ClientAppState) {
        if newState != self.appState {
            Utility.debugMessage("client", "Application state \(newState)")

            self.appState = newState
            self.changePlayerAvailable()
        }
    }
    
    private func startNetworkTimer(interval: TimeInterval = 10) {
        self.stopNetworkTimer(report: false)
        Utility.debugMessage("client", "Starting network timer")
        if !firstTime && (!Scorecard.shared.isNetworkAvailable || !Scorecard.shared.isLoggedIn) {
            self.networkTimer = Timer.scheduledTimer(
                timeInterval: TimeInterval(5),
                target: self,
                selector: #selector(ClientViewController.checkNetwork(_:)),
                userInfo: nil,
                repeats: true)
        }
    }
    
    private func stopNetworkTimer(report: Bool = true) {
        if let timer = self.networkTimer {
            if report {
                Utility.debugMessage("client", "Stopping network timer")
            }
            timer.invalidate()
            self.networkTimer = nil
        }
    }
    
    internal func changePlayerAvailable() {
        let available = (self.appState == .notConnected && !self.recoveryMode && self.commsPurpose == .playing)
        self.changePlayerButton?.isHidden = !available
    }
    
    public func refreshStatus() {
        // Just refresh all
        self.clientTableView.reloadData()
    }
    
    // MARK: - Client controller delegates ======================================================================== -
    
    internal func addPeer(deviceName: String, name: String, oldState: CommsConnectionState, state: CommsConnectionState, connecting: Bool, proximity: CommsConnectionProximity, at row: Int) {
        self.clientTableView.beginUpdates()
        if self.availablePeers.count == 0 {
            // Need to remove previous placeholder and refresh hosting options
            self.clientTableView.deleteRows(at: [IndexPath(row: 0, section: self.peerSection)], with: .right)
            if !self.recoveryMode && self.hostingOptions > 0 {
                let hostingRows = self.clientTableView.numberOfRows(inSection: self.hostSection)
                if hostingRows > 0 {
                    for row in 0..<hostingRows {
                        self.clientTableView.reloadRows(at: [IndexPath(row: row, section: self.hostSection)], with: .automatic)
                    }
                }
            }
        }
        
        let host = AvailablePeer(deviceName: deviceName, name: name, oldState: oldState, state: state, connecting: connecting, proximity: proximity)
        self.availablePeers.insert(host, at: row)
        self.clientTableView.insertRows(at: [IndexPath(row: row, section: peerSection)], with: .left)
        self.clientTableView.endUpdates()
    }
    
    internal func removePeer(at row: Int) {
        Utility.mainThread {
            self.clientTableView.beginUpdates()
            self.availablePeers.remove(at: row)
            self.clientTableView.deleteRows(at: [IndexPath(row: row, section: self.peerSection)], with: .left)
            if self.availablePeers.count == 0 {
                // Just lost last one - need to insert placeholder and update hosting options
                self.clientTableView.insertRows(at: [IndexPath(row: 0, section: self.peerSection)], with: .right)
            }
            self.clientTableView.endUpdates()
        }
    }
    
    internal func reflectPeer(deviceName: String, name: String, oldState: CommsConnectionState, state: CommsConnectionState, connecting: Bool, proximity: CommsConnectionProximity) {
        if let row = self.availablePeers.firstIndex(where: {$0.deviceName == deviceName && $0.proximity == proximity}) {
            self.availablePeers[row].set(deviceName: deviceName, name: name, oldState: oldState, state: state, connecting: connecting, proximity: proximity)
            self.clientTableView.reloadRows(at: [IndexPath(row: row, section: peerSection)], with: .automatic)
        }
    }
        
    internal func stateChange(to state: ClientAppState) {
        let oldState = self.appState
        if self.appState != state {
            self.appStateChange(to: state)
            switch self.appState {
            case .finished:
                if oldState != .notConnected {
                    self.cancelRecovery()
                    self.restart()
                }
                self.appState = .notConnected
            default:
                break
            }
        }
    }
    
    private func cancelRecovery() {
        Scorecard.recovery = Recovery(load: false)
        Scorecard.shared.setGameInProgress(false)
        self.hostController?.stop()
        self.hostController = nil
        self.clientController?.stop()
        self.clientController = nil
        self.recoveryMode = false
        self.matchDeviceName = nil
        self.matchProximity = nil
    }
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -
    
class ClientTableCell: UITableViewCell {
    @IBOutlet weak var serviceButton: UIButton!
    @IBOutlet weak var serviceLabel: UILabel!
    @IBOutlet weak var serviceLabelWidthConstraint: NSLayoutConstraint!
    public var hexagonLayer: CAShapeLayer!
}

// MARK: - Other Classes =========================================================== -

fileprivate class AvailablePeer {
    fileprivate var deviceName: String!
    fileprivate var name: String!
    fileprivate var oldState: CommsConnectionState!
    fileprivate var state: CommsConnectionState!
    fileprivate var connecting: Bool = false
    fileprivate var proximity: CommsConnectionProximity!
    
    init(deviceName: String, name: String, oldState: CommsConnectionState, state: CommsConnectionState, connecting: Bool, proximity: CommsConnectionProximity) {
        self.set(deviceName: deviceName, name: name, oldState: oldState, state: state, connecting: connecting, proximity: proximity)
    }
        
    public func set(deviceName: String, name: String, oldState: CommsConnectionState, state: CommsConnectionState, connecting: Bool, proximity: CommsConnectionProximity) {
        self.deviceName = deviceName
        self.name = name
        self.oldState = oldState
        self.state = state
        self.connecting = connecting
        self.proximity = proximity
    }
}
