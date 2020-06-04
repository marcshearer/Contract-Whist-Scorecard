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
    var title: String
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

class ClientViewController: ScorecardViewController, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource, MFMailComposeViewControllerDelegate, PlayerSelectionViewDelegate, SyncDelegate, ReconcileDelegate, ClientControllerDelegate, ImageButtonDelegate {

    // MARK: - Class Properties ======================================================================== -
    
    // Main state properties
    internal let sync = Sync()
    private var hostController: HostController!
    private var scoringController: ScoringController!
    private var clientController: ClientController!
    
    private var historyViewer: HistoryViewer!
    private var statisticsViewer: StatisticsViewer!

    // Properties to pass state
    private var matchDeviceName: String!
    private var matchProximity: CommsConnectionProximity!
    private var matchGameUUID: String!
 
    // Local class variables
    private var availablePeers: [AvailablePeer] = []
    public var thisPlayer: String!
    public var thisPlayerName: String!
    internal var choosingPlayer = false
    private var displayingPeer = 0

    // Timers
    internal var networkTimer: Timer!
    
    // Startup and reconcile
    internal var getStarted = true
    internal var reconcile: Reconcile!
    internal var reconcileAlertController: UIAlertController!
    internal var reconcileContinue: UIAlertAction!
    internal var reconcileIndicatorView: UIActivityIndicatorView!

    // Actions
    private var menuActions: [MenuAction]!
    
    // Debug rotations code
    private let code: [CGFloat] = [ -1.0, -1.0, 1.0, -1.0, 1.0]
    private var matching = 0
    
    private var appState: ClientAppState!
    private var hostCollection: Int! = 1
    private var peerCollection: Int! = 2
    private var peerScrollCollection: Int! = 3
    internal var invite: Invite!
    internal var recoveryMode = false
    internal var firstTime = true
    private var rotated = false
    private var isNetworkAvailable: Bool?
    private var isLoggedIn: Bool?
    
    private var hostingOptions: Int = 0
    private var onlineItem: Int?
    private var nearbyItem: Int?
    private var scoringItem: Int?
    private var robotItem: Int?
    private var playersItem: Int = -1
    private var resultsItem: Int = -2
    private var settingsItem: Int = -3
    
    // MARK: - IB Outlets ============================================================================== -
    
    @IBOutlet private weak var topSection: UIView!
    @IBOutlet private weak var topHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var upperMiddleSection: UIView!
    @IBOutlet private weak var upperMiddleHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var lowerMiddleSection: UIView!
    @IBOutlet private weak var lowerMiddleHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var bottomSection: UIView!
    @IBOutlet private weak var bannerPaddingView: InsetPaddingView!
    @IBOutlet private weak var bannerView: UIView!
    @IBOutlet private weak var bannerContinuation: BannerContinuation!
    @IBOutlet private weak var bannerOverlap: UIView!
    @IBOutlet private weak var adminMenuButton: ClearButton!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var thisPlayerThumbnail: ThumbnailView!
    @IBOutlet private weak var infoButtonContainer: UIView!
    @IBOutlet private weak var infoButton: RoundedButton!
    @IBOutlet private weak var hostTitleBar: TitleBar!
    @IBOutlet private weak var hostCollectionContainerView: UIView!
    @IBOutlet private weak var hostCollectionContentView: UIView!
    @IBOutlet private weak var hostCollectionView: UICollectionView!
    @IBOutlet private weak var peerTitleBar: TitleBar!
    @IBOutlet private weak var peerCollectionContainerView: UIView!
    @IBOutlet private weak var peerCollectionContentView: UIView!
    @IBOutlet private weak var peerCollectionView: UICollectionView!
    @IBOutlet private weak var peerScrollCollectionView: UICollectionView!
    @IBOutlet private weak var peerScrollCollectionViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var playersButton: ImageButton!
    @IBOutlet private weak var resultsButton: ImageButton!
    @IBOutlet private weak var settingsButton: ImageButton!
    @IBOutlet private weak var bottomSectionBottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var playerSelectionView: PlayerSelectionView!
    @IBOutlet private weak var playerSelectionViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var tapGestureRecognizer: UITapGestureRecognizer!

    // MARK: - IB Actions ============================================================================== -
        
    @IBAction private func tapGesture(recognizer: UITapGestureRecognizer) {
        if self.choosingPlayer {
            self.hidePlayerSelection()
        } else {
            self.showPlayerSelection()
        }
    }
    
    @IBAction func actionButtonPressed(_ sender: UIButton) {
        self.showActionMenu()
    }
    
    @IBAction func infoButtonPressed(_ sender: UIButton) {
        self.showWalkthrough()
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
        
        // Setup colours (previously in storyboard)
        self.DefaultScreenColors()
        
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
                
        // Check if recovering
        self.recoveryMode = Scorecard.recovery.recoveryAvailable
        if self.recoveryMode && (!Scorecard.recovery.onlineRecovery || Scorecard.recovery.onlineType == .server) {
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
            self.peerReloadData()
        }
        
        self.layoutControls()
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
        _ = HighScoresViewController.show(from: self, backText: "", backImage: "home")
    }
    
    private func showSettings() {
        SettingsViewController.show(from: self, backText: "", backImage: "home", completion: self.showSettingsCompletion)
    }
    
    private func showSettingsCompletion() {
        Scorecard.game.reset()
        self.setupThisPlayer()
        self.showThisPlayer()
        hostCollectionView.reloadData()
        self.restart()
    }
    
    private func showPlayers() {
        PlayersViewController.show(from: self, completion: {self.restart()})
    }
    
    private func showWalkthrough() {
        WalkthroughPageViewController.show(from: self)
    }
    
    // MARK: - Player Selection View Delegate Handlers ======================================================= -
    
    private func showPlayerSelection() {
        let alreadyChoosingPlayer = self.choosingPlayer
        if !alreadyChoosingPlayer {
            self.choosingPlayer = true
            self.playerSelectionView.set(parent: self)
            self.playerSelectionView.delegate = self
        }
        
        Utility.animate(view: self.view, duration: 0.5) {
            let selectionHeight = self.view.frame.height - self.playerSelectionView.frame.minY + self.view.safeAreaInsets.bottom
            self.playerSelectionView.set(size: CGSize(width: UIScreen.main.bounds.width, height: selectionHeight))
            self.playerSelectionViewHeightConstraint.constant = selectionHeight
            self.bottomSectionBottomConstraint.constant = self.bottomSectionBottomConstraint.constant - selectionHeight
            self.thisPlayerThumbnail.name.text = "Cancel"
        }
        
        let playerList = Scorecard.shared.playerList.filter { $0.email != self.thisPlayer }
        self.playerSelectionView.set(players: playerList, addButton: true, updateBeforeSelect: false)
        
    }
    
    private func hidePlayerSelection() {
        self.choosingPlayer = false
        self.showThisPlayer()

        Utility.animate(view: self.view, duration: 0.5) {
            self.playerSelectionViewHeightConstraint.constant = 0.0
            self.bottomSectionBottomConstraint.constant = 0.0
        }
        self.peerReloadData()
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
        
        self.addAction(title: "Get Started", isHidden: {Scorecard.shared.playerList.count != 0}, action: { () in
            self.showGetStarted()
        })
        
        self.addAction(title: "Statistics", isHidden: {Scorecard.shared.playerList.count == 0}, action: { () in
            self.statisticsViewer = StatisticsViewer(from: self) {
                self.statisticsViewer = nil
            }
        })
        
        self.addAction(title: "High Scores", isHidden: {!Scorecard.activeSettings.saveHistory || Scorecard.shared.playerList.count == 0}, action: { () in
            self.showHighScores()
        })
        
        self.addAction(title: "Cancel recovery", isHidden: {!Scorecard.recovery.recoveryAvailable}, action: { () in
            self.cancelRecovery()
            self.restart()
        })
        
        self.addAction(title: "Delete iCloud Database", isHidden: {!Scorecard.adminMode}, action: { () in
            DataAdmin.deleteCloudDatabase(from: self)
        })
                
        self.addAction(title: "Reset Sync Record IDs", isHidden: {!Scorecard.adminMode}, action: { () in
            DataAdmin.resetSyncRecordIDs(from: self)
        })

        self.addAction(title: "Remove Duplicate Games", isHidden: {!Scorecard.adminMode}, action: { () in
            DataAdmin.removeDuplicates(from: self)
        })
        
        self.addAction(title: "Rebuild All Players", isHidden: {!Scorecard.adminMode}, action: { () in
            self.reconcilePlayers(allPlayers: true)
        })

        self.addAction(title: "Backup Device", isHidden: {!Scorecard.adminMode}, action: { () in
            self.backupDevice()
        })
        
    }
    
    private func addAction(title: String, isHidden: (()->Bool)? = nil, action: @escaping ()->()) {
        let tag = self.menuActions.count
        self.menuActions.append(MenuAction(tag: tag, title: title, sequence: self.menuActions.count, isHidden: isHidden, action: action))
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
        self.scoringController = nil
        self.setupHostingOptions()
        self.appStateChange(to: .notConnected)
        self.changePlayerAvailable()
        Scorecard.game?.resetValues()
        Scorecard.game.setGameInProgress(false)
        self.availablePeers = []
        self.peerReloadData()

        // Check network / iCloud
        Scorecard.shared.checkNetworkConnection() {
            if (self.isNetworkAvailable != Scorecard.shared.isNetworkAvailable || self.isLoggedIn != Scorecard.shared.isLoggedIn) {
                self.peerReloadData()
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
            
            self.peerReloadData()
            
            // Link to host if recovering a server or scoring if recovering a game
            if self.recoveryMode {
                if !Scorecard.recovery.onlineRecovery {
                    self.scoreGame(recoveryMode: true)
                } else if Scorecard.recovery.onlineType == .server {
                    self.hostGame(recoveryMode: true)
                }
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
    
    // MARK: - Host Collection View Overrides ===================================================================== -

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        var items = 0
        switch collectionView.tag {
        case hostCollection:
            items = hostingOptions
        case peerCollection, peerScrollCollection:
            items = (self.firstTime ? 0 : max(1, self.availablePeers.count))
         default:
            break
        }
        return items
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        var size = CGSize()
        switch collectionView.tag {
        case hostCollection:
            size = CGSize(width: (self.hostCollectionView.frame.width / 3.0) - 0.01, height: self.hostCollectionView.frame.height)
        case peerScrollCollection:
            size = CGSize(width: 10, height: 10)
        case peerCollection:
            size = self.peerCollectionView.bounds.size
        default:
            break
        }
        return size
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var cell = UICollectionViewCell()
        
        switch collectionView.tag {
        case hostCollection:
            let hostCell = collectionView.dequeueReusableCell(withReuseIdentifier: "Host Cell", for: indexPath) as! HostCollectionViewCell
            
            hostCell.button.setProportions(top: 12, image: 20, imageBottom: 3, title: 10, titleBottom: 1, message: 25, bottom: 5)
            hostCell.button.delegate = self
            hostCell.button.tag = indexPath.row
            self.defaultCellColors(cell: hostCell)
            
            switch indexPath.row {
            case nearbyItem:
                hostCell.button.set(image: UIImage(systemName: "dot.radiowaves.left.and.right"))
                hostCell.button.set(title: "Nearby")
                hostCell.button.set(message: "Host a local,\nbluetooth game\nfor nearby players")
            case onlineItem:
                hostCell.button.set(image: UIImage(systemName: "globe"))
                hostCell.button.set(title: "Online")
                hostCell.button.set(message: "Host an online\ngame to play\nover the internet")
            case scoringItem:
                hostCell.button.set(image: UIImage(systemName: "square.and.pencil"))
                hostCell.button.set(title: "Score")
                hostCell.button.set(message: "Score a game\n while playing with\n physical cards")
            case robotItem:
                hostCell.button.set(image: UIImage(systemName: "desktopcomputer"))
                hostCell.button.set(title: "Computer")
                hostCell.button.set(message: "Play a game\nagainst the computer")
            default:
                break
            }
            cell = hostCell
            
        case peerCollection:
             let peerCell = collectionView.dequeueReusableCell(withReuseIdentifier: "Peer Cell", for: indexPath) as! PeerCollectionViewCell
             self.defaultCellColors(cell: peerCell)
             
             if self.availablePeers.count == 0 && !self.recoveryMode {
                
                peerCell.label.backgroundColor = Palette.background
                peerCell.label.textColor = Palette.text
                peerCell.label.text = "No devices are currently offering\nto host a game for you to join"
                peerCell.label.font = UIFont.systemFont(ofSize: 20.0, weight: .light)
                peerCell.leftScrollButton.isHidden = true
                peerCell.rightScrollButton.isHidden = true
                
            } else {
                var name: String
                var state: CommsConnectionState = .notConnected
                var oldState: CommsConnectionState = .notConnected
                var deviceName = ""
                var proximity = ""
                var connecting = false
                var purpose = CommsPurpose.playing
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
                    purpose = availableFound.purpose
                }
                var serviceText: String
                
                switch state {
                case .notConnected:
                    if oldState != .notConnected {
                        serviceText = "\(name) has disconnected"
                    } else if self.recoveryMode {
                        serviceText = (Scorecard.recovery.onlineType == .server ? "Trying to resume game..." : "Trying to reconnect to \(name)...")
                    } else if purpose == .sharing {
                        serviceText = "View scorecard on \(deviceName)"
                    } else if connecting {
                        serviceText = "Connecting to \(name)..."
                    } else {
                        serviceText = "Join \(name)'s \(proximity) game"
                    }
                case .connected:
                    if purpose == .sharing {
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

                peerCell.label.font = UIFont.systemFont(ofSize: 20.0, weight: .bold)
                peerCell.label.backgroundColor = Palette.gameBanner
                peerCell.label.textColor = Palette.gameBannerText
                peerCell.label.text = serviceText
             }
             
             peerCell.leftScrollButton.isHidden = (indexPath.row <= 0 || self.availablePeers.count <= 1)
             peerCell.leftScrollButton.addTarget(self, action: #selector(ClientViewController.scrollPeers(_:)), for: .touchUpInside)
             peerCell.leftScrollButton.tag = indexPath.row - 1
             
             peerCell.rightScrollButton.isHidden = (indexPath.row >= self.availablePeers.count - 1 || self.availablePeers.count <= 1)
             peerCell.rightScrollButton.addTarget(self, action: #selector(ClientViewController.scrollPeers(_:)), for: .touchUpInside)
             peerCell.rightScrollButton.tag = indexPath.row + 1
             
            cell = peerCell

        case peerScrollCollection:
            let peerScrollCell = collectionView.dequeueReusableCell(withReuseIdentifier: "Peer Scroll Cell", for: indexPath) as! PeerScrollCollectionViewCell
            
            peerScrollCell.indicator.image = UIImage(systemName: (indexPath.row == self.displayingPeer ? "circle.fill" : "circle"))
            peerScrollCell.indicator.tintColor = Palette.gameBannerText
            cell = peerScrollCell
            
        default:
            break
        }
        
        return cell
    }
    
    internal func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        switch collectionView.tag {
        case peerCollection:
            if self.availablePeers.count == 0 {
                return false
            } else if !Scorecard.shared.isNetworkAvailable || !Scorecard.shared.isLoggedIn {
                return true
            } else {
                let availableFound = self.availablePeers[indexPath.row]
                if (appState == .notConnected && availableFound.state == .notConnected) {
                    return true
                } else {
                    return false
                }
            }
        default:
            return false
        }
    }
    
    internal func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch collectionView.tag {            
        case self.peerCollection:
            self.selectPeer(indexPath.row)
            
        default:
            break
        }
    }
    
    internal func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        Utility.mainThread {
            self.displayingPeer = self.displayedPeer()
            self.peerScrollCollectionView.reloadData()
        }
    }
    
    
    internal func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        Utility.mainThread {
            self.displayingPeer = self.displayedPeer()
            self.peerScrollCollectionView.reloadData()
        }
    }
    
    private func displayedPeer() -> Int {
        let offset = peerCollectionView.contentOffset.x
        return Utility.round(Double(offset / self.peerCollectionView.frame.width))
    }
        
    // MARK: - Image button delegate handlers =============================================== -
    
    internal func imageButtonPressed(_ button: ImageButton) {
        if !Scorecard.shared.isNetworkAvailable || !Scorecard.shared.isLoggedIn {
            self.restart()
        } else {
            switch button.tag {
            case scoringItem:
                self.scoreGame()
            case playersItem:
                self.showPlayers()
            case resultsItem:
                self.historyViewer = HistoryViewer(from: self) {
                    self.historyViewer = nil
                }
            case settingsItem:
                self.showSettings()
            default:
                var mode: ConnectionMode
                switch button.tag {
                case nearbyItem:
                    mode = .nearby
                case onlineItem:
                    mode = .online
                case robotItem:
                    mode = .loopback
                default:
                    mode = .online
                }
                
                self.destroyClientController()
                
                self.hostGame(mode: mode, playerEmail: self.thisPlayer)
            }
        }
    }
    
    // MARK: - Button actions =============================================================== -
    
    @objc private func scrollPeers(_ button: UIButton) {
        self.peerCollectionView.scrollToItem(at: IndexPath(item: button.tag, section: 0), at: .centeredHorizontally, animated: true)
        self.displayingPeer = button.tag
        self.peerScrollCollectionView.reloadData()
    }
    
    // MARK: - Action buttons =============================================================== -
    
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
    
    private func scoreGame(recoveryMode: Bool = false) -> Void {
        // Stop any Client controller
        if self.clientController != nil {
            self.clientController.stop()
            self.clientController = nil
        }
                
        // Create Scoring controller
        if self.scoringController == nil {
            self.scoringController = ScoringController(from: self)
        }
        
        // Start Host controller
        scoringController.start(recoveryMode: recoveryMode, completion: { (returnHome) in
            if returnHome {
                self.cancelRecovery()
            }
            self.scoringController?.stop()
            self.scoringController = nil
            self.restart()
        })
    }
    
    @objc private func selectPeerSelector(_ sender: UIButton) {
        self.selectPeer(sender.tag)
    }
    
    private func selectPeer(_ item: Int) {
        let availableFound = availablePeers[item]
        self.checkFaceTime(peer: availableFound, completion: { (faceTimeAddress) in
            self.clientController.connect(row: item, faceTimeAddress: faceTimeAddress ?? "")
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
        self.peerReloadData()
        self.peerCollectionView.layoutIfNeeded()
        if self.thisPlayer != nil {
            self.clientController = ClientController(from: self, playerEmail: self.thisPlayer, playerName: self.thisPlayerName, matchDeviceName: self.matchDeviceName, matchProximity: self.matchProximity, matchGameUUID: matchGameUUID)
            self.clientController.delegate = self
        }
    }
    
    private func destroyClientController() {
        self.clientController?.stop()
        self.clientController = nil
    }
    
    private func setupHostingOptions() {
        // Set up sections
        
        // Setup hosting options
        self.hostingOptions = 0
        
            if Scorecard.activeSettings.onlinePlayerEmail != nil {
                self.nearbyItem = self.hostingOptions
                self.hostingOptions += 1
                self.onlineItem = self.hostingOptions
                self.hostingOptions += 1
                self.scoringItem = self.hostingOptions
                self.hostingOptions += 1
                self.robotItem = self.hostingOptions
                self.hostingOptions += 1
            }
    }
    
    private func setupThisPlayer() {
        
        if self.recoveryMode && Scorecard.recovery.onlineMode != nil {
            // Recovering - use same player
            self.thisPlayer = Scorecard.recovery.connectionEmail
            self.thisPlayerName = Scorecard.shared.findPlayerByEmail(self.thisPlayer)?.name
            self.matchDeviceName = Scorecard.recovery.connectionRemoteDeviceName
            self.matchProximity = Scorecard.recovery.onlineProximity
            self.matchGameUUID = Scorecard.recovery.gameUUID
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
        if self.thisPlayer == nil && Scorecard.game.currentPlayers >= 1 {
            let player = Scorecard.game.player(enteredPlayerNumber: 1)
            if let playerMO = player.playerMO {
                self.thisPlayer = playerMO.email
                self.thisPlayerName = playerMO.name
            }
        }
    }
    
    private func showThisPlayer() {
        if let player = self.thisPlayer, let playerMO = Scorecard.shared.findPlayerByEmail(player) {
            self.thisPlayerThumbnail.set(data: playerMO.thumbnail, name: playerMO.name!, nameHeight: 20.0, diameter: self.thisPlayerThumbnail.frame.width)
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
        let available = (self.appState == .notConnected && !self.recoveryMode)
        self.tapGestureRecognizer.isEnabled = available
    }
    
    public func refreshStatus() {
        // Just refresh all
        self.peerReloadData()
    }
    
    private func peerReloadData() {
        self.peerCollectionView.reloadData()
        self.peerScrollCollectionView.reloadData()
    }
    
    // MARK: - Client controller delegates ======================================================================== -
    
    internal func addPeer(deviceName: String, name: String, oldState: CommsConnectionState, state: CommsConnectionState, connecting: Bool, proximity: CommsConnectionProximity, purpose: CommsPurpose, at item: Int) {
        self.peerCollectionView.performBatchUpdates( {
            self.peerScrollCollectionView.performBatchUpdates( {
                let host = AvailablePeer(deviceName: deviceName, name: name, oldState: oldState, state: state, connecting: connecting, proximity: proximity, purpose: purpose)
                self.availablePeers.insert(host, at: item)
                if self.availablePeers.count > 1 {
                    // Add to collection view
                    self.peerCollectionView.insertItems(at: [IndexPath(item: item, section: 0)])
                    if item != self.displayingPeer {
                        self.peerCollectionView.reloadItems(at: [IndexPath(item: self.displayingPeer, section: 0)])
                    }
                } else {
                    // Replace placeholder
                    self.peerCollectionView.reloadItems(at: [IndexPath(row: item, section: 0)])
                }
                self.peerScrollCollectionView.reloadData()
                self.setScrollWidth()
            })
        })
    }
    
    internal func removePeer(at item: Int) {
        Utility.mainThread {
            self.peerCollectionView.performBatchUpdates( {
                self.peerScrollCollectionView.performBatchUpdates( {
                    self.availablePeers.remove(at: item)
                    if self.availablePeers.count == 0 {
                        // Replace with placeholder
                        self.peerCollectionView.reloadItems(at: [IndexPath(row: item, section: 0)])
                    } else {
                        // Remove from collection view
                        self.peerCollectionView.deleteItems(at: [IndexPath(row: item, section: 0)])
                        if item != self.displayingPeer {
                            self.peerCollectionView.reloadItems(at: [IndexPath(item: self.displayingPeer, section: 0)])
                        }
                        self.peerScrollCollectionView.deleteItems(at: [IndexPath(row: item, section: 0)])
                    }
                    self.setScrollWidth()
                })
            })
        }
    }
    
    private func setScrollWidth() {
        let items = self.availablePeers.count
        self.peerScrollCollectionViewWidthConstraint.constant = (CGFloat(items) * 15.0) - 5.0
        self.peerScrollCollectionView.isHidden = (items <= 1)
        self.displayingPeer = self.displayedPeer()
        self.peerScrollCollectionView.reloadData()
    }
    
    internal func reflectPeer(deviceName: String, name: String, oldState: CommsConnectionState, state: CommsConnectionState, connecting: Bool, proximity: CommsConnectionProximity, purpose: CommsPurpose) {
        if let row = self.availablePeers.firstIndex(where: {$0.deviceName == deviceName && $0.proximity == proximity}) {
            self.availablePeers[row].set(deviceName: deviceName, name: name, oldState: oldState, state: state, connecting: connecting, proximity: proximity, purpose: purpose)
            self.peerCollectionView.reloadItems(at: [IndexPath(row: row, section: 0)])
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
        Scorecard.game.setGameInProgress(false)
        self.hostController?.stop()
        self.hostController = nil
        self.clientController?.stop()
        self.clientController = nil
        self.recoveryMode = false
        self.matchDeviceName = nil
        self.matchProximity = nil
        self.matchGameUUID = nil
    }
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class HostCollectionViewCell: UICollectionViewCell {
    @IBOutlet fileprivate weak var button: ImageButton!
}

class PeerCollectionViewCell: UICollectionViewCell {
    @IBOutlet fileprivate weak var label: UILabel!
    @IBOutlet fileprivate weak var leftScrollButton: UIButton!
    @IBOutlet fileprivate weak var rightScrollButton: UIButton!
}

class PeerScrollCollectionViewCell: UICollectionViewCell {
    @IBOutlet fileprivate weak var indicator: UIImageView!
}

// MARK: - Other Classes =========================================================== -

fileprivate class AvailablePeer {
    fileprivate var deviceName: String!
    fileprivate var name: String!
    fileprivate var oldState: CommsConnectionState!
    fileprivate var state: CommsConnectionState!
    fileprivate var connecting: Bool = false
    fileprivate var proximity: CommsConnectionProximity!
    fileprivate var purpose: CommsPurpose!
    
    init(deviceName: String, name: String, oldState: CommsConnectionState, state: CommsConnectionState, connecting: Bool, proximity: CommsConnectionProximity, purpose: CommsPurpose) {
        self.set(deviceName: deviceName, name: name, oldState: oldState, state: state, connecting: connecting, proximity: proximity, purpose: purpose)
    }
        
    public func set(deviceName: String, name: String, oldState: CommsConnectionState, state: CommsConnectionState, connecting: Bool, proximity: CommsConnectionProximity, purpose: CommsPurpose) {
        self.deviceName = deviceName
        self.name = name
        self.oldState = oldState
        self.state = state
        self.connecting = connecting
        self.proximity = proximity
        self.purpose = purpose
    }
}

extension ClientViewController {

    /** _Note that this code was generated as part of the move to themed colors_ */

    private func DefaultScreenColors() {
        self.topSection.backgroundColor = Palette.gameBanner
        self.bannerPaddingView.bannerColor = Palette.gameBanner
        self.bannerOverlap.backgroundColor = Palette.gameBanner
        self.hostTitleBar.backgroundColor = Palette.buttonFace
        self.hostTitleBar.set(faceColor: Palette.buttonFace)
        self.hostTitleBar.set(textColor: Palette.buttonFaceText)
        self.adminMenuButton.tintColor = Palette.gameBannerText
        self.titleLabel.textColor = Palette.gameBannerText
        self.thisPlayerThumbnail.set(textColor: Palette.gameBannerText)
        self.thisPlayerThumbnail.set(font: UIFont.systemFont(ofSize: 15, weight: .bold))
        self.infoButton.backgroundColor = Palette.gameBannerShadow
        self.infoButton.setTitleColor(Palette.gameBannerText, for: .normal)
        self.hostCollectionView.backgroundColor = Palette.buttonFace
        self.peerTitleBar.set(faceColor: Palette.buttonFace)
        self.peerTitleBar.set(textColor: Palette.buttonFaceText)
        self.playersButton.set(faceColor: Palette.buttonFace)
        self.playersButton.set(textColor: Palette.gameBanner)
        self.playersButton.set(titleFont: UIFont.systemFont(ofSize: 18, weight: .bold))
        self.resultsButton.set(faceColor: Palette.buttonFace)
        self.resultsButton.set(textColor: Palette.gameBanner)
        self.resultsButton.set(titleFont: UIFont.systemFont(ofSize: 18, weight: .bold))
        self.settingsButton.set(faceColor: Palette.buttonFace)
        self.settingsButton.set(textColor: Palette.gameBanner)
        self.settingsButton.set(titleFont: UIFont.systemFont(ofSize: 18, weight: .bold))

        self.playerSelectionView.backgroundColor = Palette.background
        self.view.backgroundColor = Palette.background
    }
    
    private func layoutControls() {
        self.infoButton.toCircle()
        self.infoButtonContainer.addShadow(shadowSize: CGSize(width: 2.0, height: 2.0), shadowOpacity: 0.2, shadowRadius: 1.0)
        self.hostCollectionContentView.roundCorners(cornerRadius: 8.0, topRounded: false, bottomRounded: true)
        self.hostCollectionContainerView.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0), shadowOpacity: 0.1, shadowRadius: 2.0)
        self.peerCollectionContentView.roundCorners(cornerRadius: 8.0, topRounded: false, bottomRounded: true)
        self.peerCollectionContainerView.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0), shadowOpacity: 0.1, shadowRadius: 2.0)
        self.peerScrollCollectionView.isHidden = (self.availablePeers.count <= 1)
        if self.firstTime {
            self.bottomSectionBottomConstraint.constant = (self.view.safeAreaInsets.bottom == 0.0 ? 10.0 : 0.0)
        }
        self.playersButton.setProportions(top: 30, image: 0, imageBottom: 0, title: 15, titleBottom: 0, message: 0, bottom: 30)
        self.resultsButton.setProportions(top: 30, image: 0, imageBottom: 0, title: 15, titleBottom: 0, message: 0, bottom: 30)
        self.settingsButton.setProportions(top: 30, image: 0, imageBottom: 0, title: 15, titleBottom: 0, message: 0, bottom: 30)
    }

    private func defaultCellColors(cell: HostCollectionViewCell) {
        cell.button.set(faceColor: Palette.buttonFace)
        cell.button.set(titleColor: Palette.buttonFaceText)
        cell.button.set(messageColor: Palette.buttonFaceText)
        cell.button.set(imageTintColor: Palette.gameBanner)
    }
    
    private func defaultCellColors(cell: PeerCollectionViewCell) {
        cell.leftScrollButton.imageView?.tintColor = Palette.gameBannerText
        cell.rightScrollButton.imageView?.tintColor = Palette.gameBannerText
    }
}
