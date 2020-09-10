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
import CoreData

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

class ClientViewController: ScorecardViewController, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource, MFMailComposeViewControllerDelegate, PlayerSelectionViewDelegate, ReconcileDelegate, ClientControllerDelegate, ButtonDelegate, CustomCollectionViewLayoutDelegate {

    // MARK: - Class Properties ======================================================================== -
    
    // Main state properties
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
    private var thisPlayerBeforeSettings: String!
    private var displayingPeer = 0
    public var dismissImageView: UIImageView!
    internal var viewControllerStack: [(uniqueID: String, viewController: ScorecardViewController)] = []

    // Observers
    private var observer: NSObjectProtocol?
    
    // Startup and reconcile
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
    private var launchScreen = true
    private var rotated = false
    private var isNetworkAvailable: Bool?
    private var isLoggedIn: Bool?
    private var imageObserver: NSObjectProtocol?
    private var whisper: Whisper!
    
    private var hostingOptions: Int = 0
    private var onlineItem: Int?
    private var nearbyItem: Int?
    private var scoringItem: Int?
    private var robotItem: Int?
    private var playersItem: Int = -1
    private var resultsItem: Int = -2
    private var settingsItem: Int = -3
    internal var hostsAcross = 3
    internal var hostsDown = 1
    internal var hostVerticalSpacing: CGFloat = 0
    internal var hostHorizontalSpacing: CGFloat = 0
    internal var hostRoundedContainer: Bool = true
    internal var containerTitle = "Play Game"
    internal var centeredFlowLayout = CenteredCollectionViewLayout()
    private var lastWidth: CGFloat?
    
    internal var containers = false
    
    // MARK: - IB Outlets ============================================================================== -
    
    @IBOutlet internal weak var leftContainer: UIView!
    @IBOutlet internal weak var mainContainer: UIView!
    @IBOutlet internal weak var rightPanel: UIView!
    @IBOutlet internal weak var rightContainer: UIView!
    @IBOutlet internal weak var mainRightContainer: UIView!
    @IBOutlet internal weak var leftPanelWidthConstraint: NSLayoutConstraint!
    @IBOutlet internal weak var rightPanelWidthConstraint: NSLayoutConstraint!

    @IBOutlet internal weak var rightPanelTitleLabel: UILabel!
    @IBOutlet internal weak var rightPanelCaptionLabel: UILabel!

    @IBOutlet internal weak var topSection: UIView!
    @IBOutlet internal weak var upperMiddleSection: UIView!
    @IBOutlet internal weak var lowerMiddleSection: UIView!
    @IBOutlet internal weak var bottomSection: UIView!
    @IBOutlet internal weak var topSectionTopConstraint: NSLayoutConstraint!
    @IBOutlet internal weak var banner: Banner!
    @IBOutlet private weak var leftPaddingView: InsetPaddingView!
    @IBOutlet private weak var bannerHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var thisPlayerContainerView: UIView!
    @IBOutlet private weak var thisPlayerOverlap: UIView!
    @IBOutlet private weak var thisPlayerThumbnail: ThumbnailView!
    @IBOutlet internal weak var infoButton: ShadowButton!
    @IBOutlet internal weak var hostTitleBar: TitleBar!
    @IBOutlet internal weak var hostCollectionContainerView: UIView!
    @IBOutlet internal var hostCollectionContainerInsets: [NSLayoutConstraint]!
    @IBOutlet internal weak var hostCollectionContentView: UIView!
    @IBOutlet internal weak var hostCollectionView: UICollectionView!
    @IBOutlet internal var hostCollectionViewLayout: UICollectionViewLayout!
    @IBOutlet internal weak var peerTitleBar: TitleBar!
    @IBOutlet internal weak var peerTitleBarTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var peerCollectionContainerView: UIView!
    @IBOutlet private weak var peerCollectionContentView: UIView!
    @IBOutlet private weak var peerCollectionView: UICollectionView!
    @IBOutlet private weak var peerScrollCollectionView: UICollectionView!
    @IBOutlet private weak var peerScrollCollectionViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var bottomSectionBottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var bottomSectionTrailingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var playerSelectionView: PlayerSelectionView!
    @IBOutlet private weak var playerSelectionViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var playerSelectionViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var tapGestureRecognizer: UITapGestureRecognizer!
    @IBOutlet private weak var flowLayout: CustomCollectionViewLayout!
    @IBOutlet private var actionButtons: [ImageButton]!
    @IBOutlet internal var menuHeightConstraints: [NSLayoutConstraint]!
    @IBOutlet internal var noMenuHeightConstraints: [NSLayoutConstraint]!
    @IBOutlet private weak var settingsBadgeButton: ShadowButton!

    // MARK: - IB Actions ============================================================================== -
        
    @IBAction private func tapGesture(recognizer: UITapGestureRecognizer) {
        if self.playerSelectionViewHeightConstraint.constant != 0 || self.playerSelectionViewWidthConstraint.constant != 0 {
            self.hidePlayerSelection()
        } else {
            self.showPlayerSelection()
        }
    }
    
    internal func adminButtonPressed() {
        self.showActionMenu()
    }
    
    @IBAction func infoButtonPressed(_ sender: UIButton) {
        self.showWalkthrough()
    }
    
    @IBAction func settingsBadgePressed(_ sender: UIButton) {
        self.showSettings()
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
                        self.banner.setButton("admin", isHidden: false)
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
        
        // Patch in right panel label
        self.rightTitleLabel = self.rightPanelTitleLabel
        self.rightCaptionLabel = self.rightPanelCaptionLabel
        self.showLastGame()
        
        // Show menu container if necessary
        self.allocateContainerSizes()
        if self.containers {
            let menuPanelViewController = MenuPanelViewController.create()
            self.menuController = menuPanelViewController
            self.presentInContainers([PanelContainerItem(viewController: menuPanelViewController, container: Container.left)], animated: false, completion: nil)
        }
        
        self.hideNavigationBar()

        // Setup colours (previously in storyboard) and setup whisper
        self.DefaultScreenColors()
        self.whisper = Whisper()

        // Check network
        self.checkNetwork()
        
        // Setup game
        Scorecard.game = Game()
                
        // Possible clear all data in test mode
        TestMode.resetApp()
        
        // Restart client
        self.restart(createController: false)
        
        // Set not connected
        self.appStateChange(to: .notConnected)
        
        // Stop any existing sharing activity
        Scorecard.shared.stopSharing()
                
        // Check if recovering
        self.recoveryMode = Scorecard.recovery.recoveryAvailable && Scorecard.recovery.onlineMode != .loopback
        if self.recoveryMode && (!Scorecard.recovery.onlineRecovery || Scorecard.recovery.onlineType == .server) {
            Scorecard.recovery.recovering = true
            Scorecard.recovery.loadSavedValues()
        }

        // Setup playing as
        self.setupThisPlayer()
        
        // Clear presenting views
        Scorecard.shared.viewPresenting = .none
        
        // Look out for images arriving
        self.imageObserver = setPlayerDownloadNotification(name: .playerImageDownloaded)
        
        // Clear hand state
        Scorecard.game?.handState = nil
        
        // Setup action menu, banner etc
        self.setupBanner()
        self.setupMenuActions()
                
        // Set flow layout delegate
        if let flowLayout = self.flowLayout {
            flowLayout.delegate = self
        }
        self.peerCollectionView.decelerationRate = UIScrollView.DecelerationRate.fast
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        Palette.ignoringGameBanners {
            
            if self.launchScreen {
                // Cover with launch screen
                self.launchScreen = false
                self.showLaunchScreen()
            }
        }
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        Palette.ignoringGameBanners {
            
            self.changePlayerAvailable()
            
            if self.firstTime {
                
                // Create a client controller to manage connections
                self.createClientController()
                
                self.peerReloadData()
            }
        }
        if self.firstTime {
            firstTime = false
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
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        self.rotated = true
        Scorecard.shared.reCenterPopup(self)
        self.view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.mainContainer?.layoutIfNeeded()
        self.allocateContainerSizes()
        
        Palette.ignoringGameBanners {
            
            self.panelLayoutSubviews()
            self.setupBanner()
            
            // Update sizes to layout constraints immediately to aid calculations
            self.view.layoutIfNeeded()
            
            self.showThisPlayer()
            
            if self.rotated && (self.playerSelectionViewHeightConstraint.constant != 0 ||
                self.playerSelectionViewWidthConstraint.constant != 0) {
                // Resize player selection
                self.showPlayerSelection()
            }

            if rotated || self.lastWidth != self.view.frame.width {
                self.launchScreenView?.layoutSubviews()
                self.hostCollectionView.reloadData()
                self.lastWidth = self.view.frame.width
            }
            
            if self.firstTime || self.rotated {
                self.rotated = false
                self.peerReloadData()
            }
            
            self.layoutControls()
        }
    }
    
    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        
        // Play sound
        self.alertSound()
        
        self.restart()
    }

    // MARK: - Show other views ======================================================================= -
    
    private func showLaunchScreen() {
        self.showLaunchScreenView() {
            self.clientController?.set(noHideDismissImageView: true) // Suppress hiding of screenview since will do it later ourselves
            if !self.recoveryMode {
                self.showSettingsCompletion()
            }
            self.clientController?.set(noHideDismissImageView: false)
            if !Scorecard.settings.syncEnabled {
                self.showGetStarted()
            }
        }
    }
    
    private func showGetStarted() {
        GetStartedViewController.show(from: self, completion: {self.restart()})
    }
        
    @discardableResult internal func showSettings(presentCompletion: (()->())? = nil) -> ScorecardViewController {
        self.thisPlayerBeforeSettings = Scorecard.settings.thisPlayerUUID
        let settingsViewController = SettingsViewController.create(backText: "", backImage: "home", completion: self.showSettingsCompletion)
        self.present(settingsViewController, animated: true, container: .main, completion: presentCompletion)
        return settingsViewController
    }
    
    private func showSettingsCompletion() {
        Scorecard.game.reset()
        if self.thisPlayerBeforeSettings != Scorecard.settings.thisPlayerUUID {
            self.setupThisPlayer()
            self.showThisPlayer()
        }
        self.DefaultScreenColors()
        hostCollectionView.reloadData()
        peerCollectionView.reloadData()
        self.menuController?.refresh()
        self.restart()
    }
    
    private func showPlayers() {
        PlayersViewController.show(from: self, completion: {self.restart()})
    }
    
    private func showDashboard() {
        DashboardViewController.show(from: self,
            dashboardNames: [(title: "Awards",  fileName: "AwardsDashboard",  imageName: "award"),
                             (title: "Personal", fileName: "PersonalDashboard", imageName: "personal"),
                             (title: "Everyone", fileName: "EveryoneDashboard", imageName: "everyone")],
            container: .mainRight)
    }
    
    private func showWalkthrough() {
        WalkthroughPageViewController.show(from: self)
    }
    
    // MARK: - Player Selection View Delegate Handlers ======================================================= -
    
    internal func showPlayerSelection(completion: (()->())? = nil) {
        
        Utility.animate(view: self.view, duration: 0.5, completion: {
            self.hostTitleBar.isHidden = true
            completion?()
        }, animations: {
            if ScorecardUI.landscapePhone() {
                let selectionWidth = self.view.frame.width - self.playerSelectionView.frame.minX + self.view.safeAreaInsets.right
                self.playerSelectionView.set(size: CGSize(width: selectionWidth, height: UIScreen.main.bounds.width))
                self.playerSelectionViewWidthConstraint.constant = selectionWidth
                self.bottomSectionTrailingConstraint.constant = self.bottomSectionTrailingConstraint.constant - selectionWidth
            } else {
                let selectionHeight = self.view.frame.height - self.playerSelectionView.frame.minY + self.view.safeAreaInsets.bottom
                self.playerSelectionView.set(size: CGSize(width: UIScreen.main.bounds.width, height: selectionHeight))
                self.playerSelectionViewHeightConstraint.constant = selectionHeight
                self.bottomSectionBottomConstraint.constant = self.bottomSectionBottomConstraint.constant - selectionHeight
            }
            self.thisPlayerThumbnail.name.text = "Cancel"
        })
        
        let playerList = Scorecard.shared.playerList.filter { $0.playerUUID != self.thisPlayer }
        self.playerSelectionView.set(players: playerList, addButton: true, updateBeforeSelect: false, scrollEnabled: true, collectionViewInsets: UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10))
        if self.containers {
            self.banner.set(title: "Select Player")
        }
    }
    
    internal func hidePlayerSelection(completion: (()->())? = nil) {
        self.showThisPlayer(alwaysShow: true)
        self.hostTitleBar.isHidden = false
        
        Utility.animate(view: self.view, duration: 0.5, completion: completion) {
            if ScorecardUI.landscapePhone() {
                self.playerSelectionViewWidthConstraint.constant = 0.0
            } else {
                self.playerSelectionViewHeightConstraint.constant = 0.0
            }
            self.bottomSectionBottomConstraint?.constant = (self.view.safeAreaInsets.bottom == 0.0 ? 10.0 : 0.0)
            self.bottomSectionTrailingConstraint?.constant = (self.view.safeAreaInsets.right == 0.0 ? 10.0 : 0.0)
        }
        self.peerReloadData()
        if self.containers {
            self.banner.set(title: self.containerTitle)
        }
        self.showLastGame()
    }
    
    internal func didSelect(playerMO: PlayerMO) {
        // Save player as default for device
        Scorecard.settings.thisPlayerUUID = playerMO.playerUUID!
        Scorecard.settings.save()
        Scorecard.settings.saveToICloud()
        Notifications.addOnlineGameSubscription(Scorecard.settings.thisPlayerUUID, completion: nil)
        self.thisPlayer = playerMO.playerUUID!
        self.destroyClientController()
        self.createClientController()
        self.hidePlayerSelection()
        self.menuController?.refresh()
    }
    
    internal func resizeView() {
        // Additional players added - resize the view
        self.showPlayerSelection()
    }
    
     // MARK: - Action Handlers ================================================================ -
    
    private func setupMenuActions() {
        
        self.menuActions = []
        
        self.addAction(title: "Leave admin mode", isHidden: {!Scorecard.adminMode}, action: { () in
            Scorecard.adminMode = false
            self.banner.setButton("admin", isHidden: true)
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
    
    // MARK: - Send playerUUID and delegate methods =========================================================== -
    
    func backupDevice() {
        Backup.sendPlayerUUID(from: self)
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
        self.displayingPeer = 0
        self.peerCollectionView.contentOffset = CGPoint()
        self.peerReloadData()
        self.updateSettingsBadge()
        self.menuController.set(playingGame: false)

        if createController {
            // Create controller after short delay
            Utility.executeAfter(delay: 0.1) {
                self.createClientController()
            }
        }
    }
    
    @objc private func checkNetwork(_ sender: Any? = nil) {
        // Check network
        self.observer = Scorecard.reachability.startMonitor { (available) in
            self.networkChanged(available)
        }
        
        Scorecard.shared.checkNetworkConnection() {
            self.networkChanged(Scorecard.shared.isNetworkAvailable)
        }
    }
    
    private func networkChanged(_ available: Bool) {
        Utility.mainThread {
            Scorecard.shared.isNetworkAvailable = available
            if (self.isNetworkAvailable != Scorecard.shared.isNetworkAvailable || self.isLoggedIn != Scorecard.shared.isLoggedIn) {
                self.isNetworkAvailable = available
                self.isLoggedIn = Scorecard.shared.isLoggedIn
                self.setupHostingOptions()
                self.hostCollectionView.reloadData()
                self.peerReloadData()
            }
        }
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
            self.hostCollectionView.layoutIfNeeded()
            size = CGSize(width: ((self.hostCollectionView.frame.width + self.hostHorizontalSpacing) / CGFloat(self.hostsAcross)) - self.hostHorizontalSpacing, height: ((self.hostCollectionView.frame.height + self.hostVerticalSpacing) / CGFloat(self.hostsDown)) - self.hostVerticalSpacing - 1)
        case peerScrollCollection:
            size = CGSize(width: 10, height: 10)
        case peerCollection:
            size = self.peerCollectionView.bounds.size
        default:
            break
        }
        return size
    }
    
    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, minimumLineSpacingForSectionAt: Int) -> CGFloat {
        if collectionView.tag == hostCollection {
            return self.hostHorizontalSpacing
        } else {
            return 0
        }
    }
    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt: Int) -> CGFloat {
        if collectionView.tag == hostCollection {
            return self.hostVerticalSpacing
        } else {
            return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var cell = UICollectionViewCell()
        
        switch collectionView.tag {
        case hostCollection:
            let hostCell = collectionView.dequeueReusableCell(withReuseIdentifier: "Host Cell", for: indexPath) as! HostCollectionViewCell
            
            hostCell.button.setProportions(top: 10, image: 40, imageBottom: 2, title: 10, titleBottom: 1, message: 18, bottom: 10)
            hostCell.button.delegate = self
            hostCell.button.tag = indexPath.row
            self.defaultCellColors(cell: hostCell)
            
            switch indexPath.row {
            case nearbyItem:
                hostCell.button.set(image: UIImage(named: "local"))
                hostCell.button.set(title: "Nearby")
                hostCell.button.set(message: "Host a game\nfor nearby players")
            case onlineItem:
                hostCell.button.set(image: UIImage(named: "online"))
                hostCell.button.set(title: "Online")
                hostCell.button.set(message: "Host a game to\nplay over the internet")
            case scoringItem:
                hostCell.button.set(image: UIImage(named: "score"))
                hostCell.button.set(title: "Score")
                hostCell.button.set(message: "Score a game played\n with physical cards")
            case robotItem:
                hostCell.button.set(image: UIImage(systemName: "desktopcomputer"))
                hostCell.button.set(title: "Robot")
                hostCell.button.set(message: "Play a game\nagainst robot players")
            default:
                break
            }
            cell = hostCell
            
        case peerCollection:
             let peerCell = collectionView.dequeueReusableCell(withReuseIdentifier: "Peer Cell", for: indexPath) as! PeerCollectionViewCell
             self.defaultCellColors(cell: peerCell)
             
             if self.availablePeers.count == 0 && !self.recoveryMode {
                
                peerCell.backgroundColor = Palette.mid.background
                peerCell.label.textColor = Palette.mid.text
                peerCell.label.text = "No devices are currently\noffering to host a game"
                peerCell.label.font = UIFont.systemFont(ofSize: 18.0, weight: .light)
                peerCell.leftScrollButton.isHidden = true
                peerCell.rightScrollButton.isHidden = true
                peerCell.cancelButton.isHidden = true
                
            } else {
                var name: String
                var state: CommsConnectionState = .notConnected
                var oldState: CommsConnectionState = .notConnected
                var deviceName = ""
                var proximity = ""
                var connecting = false
                var purpose = CommsPurpose.playing
                var reason: String?
                if self.availablePeers.count == 0 && recoveryMode {
                    name = Scorecard.shared.findPlayerByPlayerUUID(Scorecard.recovery.connectionRemotePlayerUUID ?? "")?.name ?? "Unknown"
                } else {
                    let availableFound = self.availablePeers[indexPath.row]
                    name = availableFound.name
                    state = availableFound.state
                    oldState = availableFound.oldState
                    deviceName = availableFound.deviceName!
                    connecting = availableFound.connecting
                    proximity = availableFound.proximity?.rawValue ?? ""
                    purpose = availableFound.purpose
                    reason = availableFound.reason
                }
                var serviceText: String
                
                switch state {
                case .notConnected:
                    if let reason = reason {
                        self.whisper.show(reason, from: self.view, hideAfter: 3)
                    }
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

                peerCell.label.font = UIFont.systemFont(ofSize: 18.0, weight: .bold)
                Palette.ignoringGameBanners {
                    peerCell.backgroundColor = Palette.alwaysTheme.background
                    peerCell.label.textColor = Palette.alwaysTheme.text
                }
                peerCell.label.text = serviceText
                
                peerCell.leftScrollButton.isHidden = (indexPath.row <= 0 || self.availablePeers.count <= 1)
                peerCell.rightScrollButton.isHidden = (indexPath.row >= self.availablePeers.count - 1 || self.availablePeers.count <= 1)
                peerCell.cancelButton.isHidden = !(state == .connecting || state == .reconnecting || state == .recovering) && !recoveryMode
             }
             
             peerCell.leftScrollButton.addTarget(self, action: #selector(ClientViewController.scrollPeers(_:)), for: .touchUpInside)
             peerCell.leftScrollButton.tag = indexPath.row - 1
             
             peerCell.rightScrollButton.addTarget(self, action: #selector(ClientViewController.scrollPeers(_:)), for: .touchUpInside)
             peerCell.rightScrollButton.tag = indexPath.row + 1
             
             peerCell.cancelButton.addTarget(self, action: #selector(ClientViewController.cancelPeer(_:)), for: .touchUpInside)
             
            cell = peerCell

        case peerScrollCollection:
            let peerScrollCell = collectionView.dequeueReusableCell(withReuseIdentifier: "Peer Scroll Cell", for: indexPath) as! PeerScrollCollectionViewCell
            
            peerScrollCell.indicator.image = UIImage(systemName: (indexPath.row == self.displayingPeer ? "circle.fill" : "circle"))
            Palette.ignoringGameBanners {
                peerScrollCell.indicator.tintColor = Palette.banner.text
            }
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
    
    internal func changed(_ collectionView: UICollectionView, itemAtCenter: Int, forceScroll: Bool) {
        Utility.mainThread {
            self.displayingPeer = itemAtCenter
            self.peerScrollCollectionView.reloadData()
        }
    }

    // MARK: - Image button delegate handlers =============================================== -
    
    internal func buttonPressed(_ button: UIView) {
        switch button.tag {
        case scoringItem:
            self.scoreGame()
        case playersItem:
            self.showPlayers()
        case resultsItem:
            self.showDashboard()
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
            
            self.hostGame(mode: mode, playerUUID: self.thisPlayer)
        }
    }
    
    // MARK: - Button actions =============================================================== -
    
    @objc private func scrollPeers(_ button: UIButton) {
        self.peerCollectionView.scrollToItem(at: IndexPath(item: button.tag, section: 0), at: .centeredHorizontally, animated: true)
        self.displayingPeer = button.tag
        self.peerScrollCollectionView.reloadData()
    }
    
    @objc private func cancelPeer(_ button: UIButton) {
        self.cancelRecovery()
        self.restart()
    }
    
    // MARK: - Action buttons =============================================================== -
    
    private func hostGame(mode: ConnectionMode? = nil, playerUUID: String? = nil, recoveryMode: Bool = false) -> Void {
        // Stop any Client controller
        if self.clientController != nil {
            self.clientController.stop()
            self.clientController = nil
        }
        
        // Move menu to in-game mode
        self.menuController.set(playingGame: true)

        // Create Host controller
        if self.hostController == nil {
            self.hostController = HostController(from: self)
        }
        
        // Start Host controller
        hostController.start(mode: mode, playerUUID: playerUUID, recoveryMode: recoveryMode, completion: { (returnHome) in
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
        
        // Move menu to in-game mode
        self.menuController.set(playingGame: true)
        
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
        
        // Move menu to in-game mode
        self.menuController.set(playingGame: true)
    }
    
    private func checkFaceTime(peer: AvailablePeer, completion: @escaping (String?)->()) {
        if peer.proximity == .online && Scorecard.activeSettings.faceTimeAddress != "" && Utility.faceTimeAvailable() {
            self.alertDecision("\nWould you like the host to call you back on FaceTime at '\(Scorecard.activeSettings.faceTimeAddress)'?\n\nNote that this will make this address visible to the host",
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
            self.clientController = ClientController(from: self, playerUUID: self.thisPlayer, playerName: self.thisPlayerName, matchDeviceName: self.matchDeviceName, matchProximity: self.matchProximity, matchGameUUID: matchGameUUID)
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
        self.nearbyItem = -1
        self.onlineItem = -1
        self.scoringItem = -1
        self.robotItem = -1
        
        if Scorecard.activeSettings.onlineGamesEnabled {
            self.nearbyItem = self.hostingOptions
            self.hostingOptions += 1
            if Scorecard.shared.isNetworkAvailable && Scorecard.shared.isLoggedIn {
                self.onlineItem = self.hostingOptions
                self.hostingOptions += 1
            }
        }
        self.scoringItem = self.hostingOptions
        self.hostingOptions += 1
        if Scorecard.shared.iCloudUserIsMe {
            self.robotItem = self.hostingOptions
            self.hostingOptions += 1
        }
    }
    
    private func setupThisPlayer() {
        
        if self.recoveryMode && Scorecard.recovery.onlineMode != nil {
            // Recovering - use same player
            self.thisPlayer = Scorecard.recovery.connectionPlayerUUID

            self.thisPlayerName = Scorecard.shared.findPlayerByPlayerUUID(self.thisPlayer)?.name
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
                defaultPlayer = Scorecard.settings.thisPlayerUUID
                if defaultPlayer != nil {
                    let playerMO = Scorecard.shared.findPlayerByPlayerUUID(defaultPlayer)
                    if playerMO != nil {
                        self.thisPlayer = defaultPlayer
                        self.thisPlayerName = playerMO!.name
                    } else {
                        defaultPlayer = nil
                    }
                }
                if defaultPlayer == nil {
                    if let playerMO = Scorecard.shared.playerList.min(by: {($0.localDateCreated! as Date) < ($1.localDateCreated! as Date)}) {
                        self.thisPlayer = playerMO.playerUUID
                        self.thisPlayerName = playerMO.name
                    }
                }
            }
        }
        if self.thisPlayer == nil && Scorecard.game.currentPlayers >= 1 {
            let player = Scorecard.game.player(enteredPlayerNumber: 1)
            if let playerMO = player.playerMO {
                self.thisPlayer = playerMO.playerUUID
                self.thisPlayerName = playerMO.name
            }
        }
    }
    
    private func showThisPlayer(alwaysShow: Bool = false) {
        if let player = self.thisPlayer, let playerMO = Scorecard.shared.findPlayerByPlayerUUID(player) {
            if alwaysShow || playerSelectionViewHeightConstraint.constant == 0 {
                self.thisPlayerThumbnail.set(data: playerMO.thumbnail, name: playerMO.name!, nameHeight: 20.0, diameter: self.thisPlayerThumbnail.frame.width)
            }
        }
    }
    
    internal func appStateChange(to newState: ClientAppState) {
        if newState != self.appState {
            Utility.debugMessage("client", "Application state \(newState)")

            self.appState = newState
            self.changePlayerAvailable()
        }
    }
    
    internal func changePlayerAvailable() {
        let available = (self.appState == .notConnected && !self.recoveryMode)
        self.tapGestureRecognizer.isEnabled = available
    }
    
    internal func updateSettingsBadge() {
        let count = Scorecard.settings.notifyCount()
        if count == 0 {
            self.settingsBadgeButton.isHidden = true
        } else {
            self.settingsBadgeButton.isHidden = false
            self.settingsBadgeButton.setTitle("\(count)", for: .normal)
        }
    }
    
    public func refreshStatus() {
        // Just refresh all
        self.peerReloadData()
    }
    
    private func peerReloadData() {
        self.peerCollectionView.reloadData()
        self.peerScrollCollectionView.reloadData()
    }
    
    func setPlayerDownloadNotification(name: Notification.Name) -> NSObjectProtocol? {
        // Set a notification for images downloaded
        let observer = NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) {
            (notification) in
            self.updatePlayer(objectID: notification.userInfo?["playerObjectID"] as! NSManagedObjectID)
        }
        return observer
    }
    
    func updatePlayer(objectID: NSManagedObjectID) {
        // Find any cells containing an image/player which has just been downloaded asynchronously
        Utility.mainThread {
            if let thisPlayer = self.thisPlayer {
                if let playerMO = Scorecard.shared.findPlayerByPlayerUUID(thisPlayer) {
                    if playerMO.objectID == objectID {
                        // This is this player - update player
                        self.showThisPlayer()
                    }
                }
            }
        }
    }
    
    private func setupBanner() {
        self.banner.set(rightButtons: [
            BannerButton(image: UIImage(systemName: "line.horizontal.3"), width: 30, action: self.adminButtonPressed, containerHide: false, id: "admin")])
        self.banner.setButton("admin", isHidden: true)
        if self.menuController.isVisible() && self.container == .main {
            self.banner.set(title: self.containerTitle, titleFont: Banner.panelFont, titleColor: self.defaultBannerTextColor)
        } else {
            self.banner.set(title: "W H I S T", titleFont: Banner.heavyFont, titleColor: Palette.banner.themeText)
        }
        self.bannerHeightConstraint.constant = (self.containers ? self.defaultBannerHeight : 75)
    }
    
    // MARK: - Client controller delegates ======================================================================== -
    
    internal func addPeer(deviceName: String, name: String, oldState: CommsConnectionState, state: CommsConnectionState, connecting: Bool, proximity: CommsConnectionProximity, purpose: CommsPurpose, at item: Int) {
        self.peerCollectionView.performBatchUpdates( {
            self.peerScrollCollectionView.performBatchUpdates( {
                let host = AvailablePeer(deviceName: deviceName, name: name, oldState: oldState, state: state, connecting: connecting, proximity: proximity, purpose: purpose, reason: nil)
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
                self.updateMenuNotifications()
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
                    self.updateMenuNotifications()
                    self.setScrollWidth()
                })
            })
        }
    }
    
    private func setScrollWidth() {
        let items = self.availablePeers.count
        self.peerScrollCollectionViewWidthConstraint.constant = (CGFloat(items) * 15.0) - 5.0
        self.peerScrollCollectionView.isHidden = (items <= 1)
        self.peerScrollCollectionView.reloadData()
    }
    
    internal func reflectPeer(deviceName: String, name: String, oldState: CommsConnectionState, state: CommsConnectionState, connecting: Bool, proximity: CommsConnectionProximity, purpose: CommsPurpose, reason: String?) {
        if let row = self.availablePeers.firstIndex(where: {$0.deviceName == deviceName && $0.proximity == proximity}) {
            self.availablePeers[row].set(deviceName: deviceName, name: name, oldState: oldState, state: state, connecting: connecting, proximity: proximity, purpose: purpose, reason: reason)
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

    private func updateMenuNotifications() {
        if let menuController = self.menuController {
            var count = 0
            var message: String?
            var deviceName: String?
            if !self.recoveryMode {
                for available in self.availablePeers {
                    if available.state == .notConnected {
                        count += 1
                        if available.purpose == .sharing {
                            message = "View scorecard on \(available.deviceName!)"
                        } else {
                            message = "Join \(available.name!)'s \(available.proximity!.rawValue) game"
                        }
                        deviceName = available.deviceName
                    } else {
                        // Connection in progress
                        message = nil
                        deviceName = nil
                        count = 0
                        break
                    }
                }
                if count > 1 {
                    message = "Games available to join / share"
                    deviceName = nil
                }
            }
            menuController.setNotification(message: message, deviceName: deviceName)
        }
    }
    
    internal func selectAvailable(deviceName: String) {
        // Connect to a particular device based on click-through of notification
        if let item = self.availablePeers.firstIndex(where: {$0.deviceName == deviceName}) {
            let availableFound = availablePeers[item]
            if availableFound.state == .notConnected {
                let indexPath = IndexPath(item: item, section: 0)
                if self.collectionView(peerCollectionView, shouldSelectItemAt: indexPath) {
                    self.collectionView(peerCollectionView, didSelectItemAt: indexPath)
                }
            }
        }
    }
    
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class HostCollectionViewCell: UICollectionViewCell {
    @IBOutlet fileprivate weak var button: ImageButton!
}

class PeerCollectionViewCell: UICollectionViewCell {
    @IBOutlet fileprivate weak var label: UILabel!
    @IBOutlet fileprivate weak var leftScrollButton: ClearButton!
    @IBOutlet fileprivate weak var rightScrollButton: ClearButton!
    @IBOutlet fileprivate weak var cancelButton: ClearButton!
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
    fileprivate var reason: String?
    
    init(deviceName: String, name: String, oldState: CommsConnectionState, state: CommsConnectionState, connecting: Bool, proximity: CommsConnectionProximity, purpose: CommsPurpose, reason: String?) {
        self.set(deviceName: deviceName, name: name, oldState: oldState, state: state, connecting: connecting, proximity: proximity, purpose: purpose, reason: reason)
    }
        
    public func set(deviceName: String, name: String, oldState: CommsConnectionState, state: CommsConnectionState, connecting: Bool, proximity: CommsConnectionProximity, purpose: CommsPurpose, reason: String?) {
        self.deviceName = deviceName
        self.name = name
        self.oldState = oldState
        self.state = state
        self.connecting = connecting
        self.proximity = proximity
        self.purpose = purpose
        self.reason = reason
    }
}

extension ClientViewController {

    /** _Note that this code was generated as part of the move to themed colors_ */

    private func DefaultScreenColors() {
        Palette.ignoringGameBanners {
            self.view.backgroundColor = Palette.dark.background
            self.topSection.backgroundColor = Palette.banner.background
            self.leftPaddingView.bannerColor = Palette.banner.background
            self.hostTitleBar.set(faceColor: Palette.buttonFace.background)
            self.hostTitleBar.set(textColor: Palette.buttonFace.text)
            self.thisPlayerThumbnail.set(textColor: Palette.banner.text)
            self.thisPlayerThumbnail.set(font: UIFont.systemFont(ofSize: 15, weight: .bold))
            self.infoButton.setBackgroundColor(Palette.bannerShadow.background)
            self.infoButton.setTitleColor(Palette.bannerShadow.text, for: .normal)
            self.hostCollectionView.backgroundColor = Palette.buttonFace.background
            self.peerTitleBar.set(faceColor: Palette.buttonFace.background)
            self.peerTitleBar.set(textColor: Palette.buttonFace.text)
            self.actionButtons.forEach{(button) in button.set(faceColor: Palette.buttonFace.background)}
            self.actionButtons.forEach{(button) in button.set(titleColor: Palette.buttonFace.themeText)}
            self.actionButtons.forEach{(button) in button.set(titleFont: UIFont.systemFont(ofSize: 18, weight: .bold))}
            self.settingsBadgeButton.setBackgroundColor(Palette.alwaysTheme.background)
            self.settingsBadgeButton.setTitleColor(Palette.alwaysTheme.text, for: .normal)
            self.playerSelectionView.backgroundColor = self.view.backgroundColor
            self.rightPanelDefaultScreenColors()
        }
    }
    
    private func layoutControls() {
        self.infoButton.toCircle()
        if self.hostRoundedContainer {
            self.hostCollectionContentView.roundCorners(cornerRadius: 8.0, topRounded: false, bottomRounded: true)
        } else {
            self.hostCollectionContentView.removeRoundCorners()
        }
        self.hostCollectionContentView.layoutIfNeeded()
        self.peerCollectionContentView.roundCorners(cornerRadius: 8.0, topRounded: self.menuController?.isVisible() ?? false, bottomRounded: true)
        self.peerCollectionContainerView.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0), shadowOpacity: 0.1, shadowRadius: 2.0)
        self.peerScrollCollectionView.isHidden = (self.availablePeers.count <= 1)
        if self.firstTime {
            self.bottomSectionBottomConstraint?.constant = (self.view.safeAreaInsets.bottom == 0.0 ? 10.0 : 0.0)
            self.bottomSectionTrailingConstraint?.constant = (self.view.safeAreaInsets.right == 0.0 ? 10.0 : 0.0)
        }
        self.actionButtons.forEach{(button) in button.setProportions(top: 30, image: 0, imageBottom: 0, title: 35, titleBottom: 0, message: 0, bottom: 30)}
    }

    private func defaultCellColors(cell: HostCollectionViewCell) {
        Palette.ignoringGameBanners {
            cell.button.set(faceColor: Palette.buttonFace.background)
            cell.button.set(titleColor: Palette.buttonFace.text)
            cell.button.set(messageColor: Palette.buttonFace.text)
            cell.button.set(imageTintColor: Palette.buttonFace.themeText)
        }
    }
    
    private func defaultCellColors(cell: PeerCollectionViewCell) {
        Palette.ignoringGameBanners {
            cell.leftScrollButton.imageView?.tintColor = Palette.banner.text
            cell.rightScrollButton.imageView?.tintColor = Palette.banner.text
            cell.cancelButton.imageView?.tintColor = Palette.banner.text
        }
    }
}
