//
//  WelcomeViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 31/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData
import MessageUI

class WelcomeViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, ReconcileDelegate, SyncDelegate, MFMailComposeViewControllerDelegate, UIPopoverPresentationControllerDelegate {

    // MARK: - Class Properties ================================================================ -
    
    // Main state properties
    public var scorecard = Scorecard()
    private let recovery = Recovery()
    
    // Properties to pass state to / from segues
    public var broadcastTitle: String!
    public var broadcastMatchDeviceName: String!
    public var broadcastCommsPurpose: CommsConnectionPurpose!

    // Local state variables
    private var reconcile: Reconcile!
    private var firstTime = true
    private var getStarted = true
    
    // Action button IDs
    private var newGameButton = -1
    private var onlineGameButton = -1
    private var getStartedButton = -1
    private var resumeGameButton = -1
    private var playerStatsButton = -1
    private var highScoresButton = -1
    private var historyButton = -1
    private var deleteCloudButton = -1
    private var removeDuplicatesButton = -1
    private var rebuildAllButton = -1
    private var backupButton = -1
    private var buttons = 0
    
    // Debug rotations code
    private let code: [CGFloat] = [ -1.0, -1.0, 1.0, -1.0, 1.0]
    private var matching = 0
    
    // UI component pointers
    private var newGameCell: WelcomeActionCell!
    private var onlineGameCell: WelcomeActionCell!
    private var getStartedCell: WelcomeActionCell!
    private var resumeGameCell: WelcomeActionCell!
    private var statsCell: WelcomeActionCell!
    private var highScoresCell: WelcomeActionCell!
    private var historyCell: WelcomeActionCell!
    private var deleteCloudCell: WelcomeActionCell!
    private var removeDuplicatesCell: WelcomeActionCell!
    private var rebuildAllCell: WelcomeActionCell!
    private var backupCell: WelcomeActionCell!
    private var reconcileAlertController: UIAlertController!
    private var reconcileContinue: UIAlertAction!
    private var reconcileIndicatorView: UIActivityIndicatorView!
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var welcomeView: UIView!
    @IBOutlet private weak var syncMessage: UILabel!
    @IBOutlet private weak var backgroundImage: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var actionsTableView: UITableView!
    @IBOutlet private weak var viewOnlineButton: ClearButton!
    
    // MARK: - IB Unwind Segue Handlers ================================================================ -
    
    @IBAction func hideSettings(segue:UIStoryboardSegue) {
        scorecard.checkNetworkConnection(button: nil, label: syncMessage)
        getCloudVersion()
        setupButtons()
    }
    
    @IBAction func hideBroadcast(segue:UIStoryboardSegue) {
        getCloudVersion()
        setupButtons()
        actionsTableView.reloadData()
    }
    
    @IBAction func hideHost(segue:UIStoryboardSegue) {
        getCloudVersion()
        setupButtons()
        actionsTableView.reloadData()
    }
    
    @IBAction func hideGetStarted(segue:UIStoryboardSegue) {
        scorecard.checkNetworkConnection(button: nil, label: syncMessage)
        scorecard.recoveryMode = false
        getCloudVersion()
        setupButtons()
    }
    
    @IBAction func hidePlayerStats(segue:UIStoryboardSegue) {
        scorecard.checkNetworkConnection(button: nil, label: syncMessage)
        getCloudVersion()
        enableButtons() // In case removed all players
    }
    
    @IBAction func hideHighScores(segue:UIStoryboardSegue) {
        scorecard.checkNetworkConnection(button: nil, label: syncMessage)
        getCloudVersion()
    }
    
    @IBAction func hideHistory(segue:UIStoryboardSegue) {
        scorecard.checkNetworkConnection(button: nil, label: syncMessage)
        getCloudVersion()
    }
    
    @IBAction func returnSelection(segue:UIStoryboardSegue) {
        // Clear recovery flag
        scorecard.checkNetworkConnection(button: nil, label: syncMessage)
        scorecard.recoveryMode = false
        getCloudVersion()
        enableButtons()
    }
    
    @IBAction func finishGame(segue:UIStoryboardSegue) {
        self.navigationController?.isNavigationBarHidden = false
        scorecard.checkNetworkConnection(button: nil, label: syncMessage)
        scorecard.recoveryMode = false
        getCloudVersion()
        enableButtons()
    }
    
    // MARK: - IB Actions ============================================================================== -

    @IBAction func settingsPressed(_ sender: UIButton) {
        self.performSegue(withIdentifier: "showSettings", sender: self)
    }
    
     @IBAction func walkthroughPressed(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "WalkthroughPageViewController", bundle: nil)
        if let pageViewController = storyboard.instantiateViewController(withIdentifier: "WalkthroughPageViewController") as? WalkthroughPageViewController {
            present(pageViewController, animated: true, completion: nil)
        }
    }
    
    @IBAction func leftSwipe(recognizer:UISwipeGestureRecognizer) {
        if recognizer.state == .ended {
            newGame()
        }
    }
    
    @IBAction func viewOnlinePressed(_ sender: UIButton) {
        self.viewGame()
    }
    
    @IBAction func rotationGesture(recognizer:UIRotationGestureRecognizer) {
        if scorecard.iCloudUserIsMe && recognizer.state == .ended {
            let value: CGFloat = (recognizer.rotation < 0.0 ? -1.0 : 1.0)
            if code[matching] == value {
                matching += 1
                if matching == code.count {
                    // Code correct - set admin mode
                    Scorecard.adminMode = !Scorecard.adminMode
                    setupButtons()
                    matching = 0
                }
            } else {
                matching = 0
            }
        }
    }
    
    // MARK: - View Overrides ========================================================================== -

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let reset = ProcessInfo.processInfo.environment["RESET_WHIST_APP"] {
            if reset.lowercased() == "true" {
                // Called in reset mode (from a test script) - reset user defaults and core data
                DataAdmin.resetUserDefaults()
                DataAdmin.resetCoreData()
            }
        }
        
        scorecard.initialise(players: 4, rounds: 25, recovery: recovery)
        
        if !recovery.checkRecovery() {
            scorecard.reset()
        }
        
        scorecard.checkNetworkConnection(button: nil, label: syncMessage)
        
        ScorecardUI.selectBackground(size: welcomeView.frame.size, backgroundImage: backgroundImage)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if firstTime {
            // Get local and cloud version
            scorecard.getVersion()
            getCloudVersion()
            
            // Continue to Get Started if necessary pending version lookup - a risk but probably OK
            if scorecard.playerList.count == 0 && getStarted {
                // No players setup - go to Get Started
                getStarted = false
                self.performSegue(withIdentifier: "showGetStarted", sender: self)
            }
            
            // Note flow continues in completion handler
        }
        
        setupButtons()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        ScorecardUI.selectBackground(size: size, backgroundImage: backgroundImage)
    }
    
    // MARK: - Sync class delegate methods ===================================================================== -
    
    func getCloudVersion() {
        if scorecard.isNetworkAvailable {
            if scorecard.sync.connect() {
                scorecard.sync.delegate = self
                scorecard.sync.synchronise(syncMode: .syncGetVersion, timeout: nil)
            } else {
                self.syncCompletion(0)
            }
        } else {
            self.syncCompletion(0)
        }
    }
    
    func syncCompletion(_ errors: Int) {
        
        if self.firstTime {
            
            if !scorecard.upgradeToVersion(from: self) {
                self.alertMessage("Error upgrading to current version", okHandler: {
                    exit(0)
                })
            }
            
            if scorecard.playerList.count != 0 && !scorecard.settingVersionBlockSync && scorecard.isNetworkAvailable && scorecard.isLoggedIn {
                // Rebuild any players who have a sync in progress flag set
                self.reconcilePlayers()
            }
            
            self.firstTime = false
        }
    }
    
    func syncMessage(_ message: String) {
    }
    
    func syncAlert(_ message: String, completion: @escaping ()->()) {
        self.alertMessage(message, title: "Contract Whist Scorecard", okHandler: {
            if self.scorecard.settingVersionBlockAccess {
                exit(0)
            } else {
                completion()
            }
        })
    }
    
    func syncReturnPlayers(_ playerList: [PlayerDetail]!) {
    }
    
    // MARK: - TableView Overrides ===================================================================== -
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return buttons
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 64
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var welcomeActionCell: WelcomeActionCell
        
        // Action buttons
        welcomeActionCell = tableView.dequeueReusableCell(withIdentifier: "Welcome Action Cell", for: indexPath) as! WelcomeActionCell
        
        switch indexPath.row + 1 {
        case newGameButton:
            welcomeActionCell.actionButton.setTitle("New Game", for: .normal)
            newGameCell = welcomeActionCell
        case onlineGameButton:
            welcomeActionCell.actionButton.setTitle("Online Game", for: .normal)
            onlineGameCell = welcomeActionCell
        case getStartedButton:
            welcomeActionCell.actionButton.setTitle("Get Started", for: .normal)
            getStartedCell = welcomeActionCell
        case resumeGameButton:
            welcomeActionCell.actionButton.setTitle("Resume Game", for: .normal)
            resumeGameCell = welcomeActionCell
        case playerStatsButton:
            welcomeActionCell.actionButton.setTitle("Player Stats", for: .normal)
            statsCell = welcomeActionCell
        case highScoresButton:
            welcomeActionCell.actionButton.setTitle("High Scores", for: .normal)
            highScoresCell = welcomeActionCell
        case historyButton:
            welcomeActionCell.actionButton.setTitle("History", for: .normal)
            historyCell = welcomeActionCell
        case deleteCloudButton:
            welcomeActionCell.actionButton.setTitle("Delete iCloud Database", for: .normal)
            deleteCloudCell = welcomeActionCell
        case removeDuplicatesButton:
            welcomeActionCell.actionButton.setTitle("Remove Duplicate Games", for: .normal)
            removeDuplicatesCell = welcomeActionCell
        case rebuildAllButton:
            welcomeActionCell.actionButton.setTitle("Rebuild All Players", for: .normal)
            rebuildAllCell = welcomeActionCell
        case backupButton:
            welcomeActionCell.actionButton.setTitle("Backup Device", for: .normal)
            backupCell = welcomeActionCell
        default:
            break
        }
        
        welcomeActionCell.actionButton.tag = indexPath.row + 1
        welcomeActionCell.separatorInset = UIEdgeInsetsMake(0.0, welcomeActionCell.bounds.size.width, 0.0, 0.0);
        welcomeActionCell.actionButton.addTarget(self, action: #selector(WelcomeViewController.actionButtonPressed(_:)), for: UIControlEvents.touchUpInside)
        self.enableButtons(button: indexPath.row+1)
        
        return welcomeActionCell as UITableViewCell
    }
    
     // MARK: - Action Handlers ================================================================ -
    
    @objc func actionButtonPressed(_ button: UIButton) {
        switch button.tag {
        case newGameButton:
            // Start new game
           newGame()
        case onlineGameButton:
            // Play an online game
            newOnlineGame()
        case getStartedButton:
            // Get started dialog
            self.performSegue(withIdentifier: "showGetStarted", sender: self)
        case resumeGameButton:
            // Resume game
            resumeGame()
        case playerStatsButton:
            // Player Stats
            self.performSegue(withIdentifier: "showStats", sender: self )
        case highScoresButton:
            // High Scores
            self.performSegue(withIdentifier: "showHighScores", sender: self )
        case historyButton:
            // History
            self.performSegue(withIdentifier: "showHistory", sender: self )
        case deleteCloudButton:
            // Delete iCloud database
            DataAdmin.deleteCloudDatabase(from: self)
        case removeDuplicatesButton:
            // Remove duplicate games locally
            DataAdmin.removeDuplicates(from: self)
        case rebuildAllButton:
            self.reconcilePlayers(allPlayers: true)
        case backupButton:
            self.backupDevice()
        default:
            break
        }
    }
    
    private func setupButtons() {
        
        buttons = 0
        if self.scorecard.playerList.count == 0 {
            buttons += 1
            getStartedButton = buttons
        } else {
            getStartedButton = -1
            getStartedCell = nil
        }
        
        buttons += 1
        newGameButton = buttons
        
        buttons += 1
        resumeGameButton = buttons
        
        if self.scorecard.settingSyncEnabled && (self.scorecard.settingNearbyPlaying || self.scorecard.settingOnlinePlayerEmail != nil) {
            buttons += 1
            onlineGameButton = buttons
        } else {
            onlineGameButton = -1
            onlineGameCell = nil
        }
        
        buttons += 1
        playerStatsButton = buttons
        
        if scorecard.settingSaveHistory {
            buttons += 1
            historyButton = buttons
            buttons += 1
            highScoresButton = buttons
        } else {
            historyButton = -1
            historyCell = nil
            highScoresButton = -1
            highScoresCell = nil
        }

        if Scorecard.adminMode {
            buttons += 1
            deleteCloudButton = buttons
            buttons += 1
            removeDuplicatesButton = buttons
            buttons += 1
            rebuildAllButton = buttons
            buttons += 1
            backupButton = buttons
            titleLabel.text = "Admin Mode"
        } else {
            deleteCloudButton = -1
            removeDuplicatesButton = -1
            rebuildAllButton = -1
            backupButton = -1
            deleteCloudCell = nil
            removeDuplicatesCell = nil
            rebuildAllCell = nil
            backupCell = nil
            titleLabel.text = "Welcome"
        }
        
        actionsTableView.reloadData()
        
        self.viewOnlineButton.isHidden = !self.scorecard.settingSyncEnabled || !self.scorecard.settingAllowBroadcast
        
    }
    
    // MARK: - Popover Overrides ================================================================ -
    
    func popoverPresentationControllerShouldDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) -> Bool {
        let viewController = popoverPresentationController.presentedViewController
        if viewController is BroadcastViewController {
            let broadcastViewController = viewController as! BroadcastViewController
            broadcastViewController.finishBroadcast()
        } else if viewController is HostViewController {
            let hostViewController = viewController as! HostViewController
            hostViewController.finishHost()
        }
        return true
    }

    // MARK: - Utility Routines ======================================================================== -
    
    private func enableButtons(button: Int = 0) {
        if button == 0 || button == getStartedButton {
            if getStartedCell != nil {
                getStartedCell.actionButton.isEnabled(scorecard.playerList.count == 0)
            }
        }
        
        if button == 0 || button == resumeGameButton {
            if resumeGameCell != nil {
                let (recoveryEnabled, online) = self.recovery.checkOnlineRecovery()
                resumeGameCell.actionButton.isEnabled(recoveryEnabled)
                if recoveryEnabled && online {
                    resumeGameCell.actionButton.setTitle("Resume Online Game")
                } else {
                    resumeGameCell.actionButton.setTitle("Resume Game")
                }
            }
        }
        
        if button == 0 || button == onlineGameButton {
            if onlineGameCell != nil {
                onlineGameCell.actionButton.isEnabled(scorecard.playerList.count > 0 && (self.scorecard.settingSyncEnabled && self.scorecard.settingNearbyPlaying || self.scorecard.onlineEnabled))
            }
        }
        
        if button == 0 || button == playerStatsButton {
            if statsCell != nil {
                statsCell.actionButton.isEnabled(scorecard.playerList.count > 0)
            }
        }
        
        if button == 0 || button == highScoresButton {
            if highScoresCell != nil {
                highScoresCell.actionButton.isEnabled(scorecard.playerList.count > 0)
            }
        }
        
        if button == 0 || button == historyButton {
            if historyCell != nil {
                historyCell.actionButton.isEnabled(scorecard.playerList.count > 0)
            }
        }
        
        if button == 0 || button == backupButton {
            if backupCell != nil {
                backupCell.actionButton.isEnabled(scorecard.playerList.count > 0)
            }
        }
    }
    
    private func newGame() {
        if recovery.checkRecovery() {
            // Warn that this is irreversible
            warnResumeGame(okHandler: {
                self.startNewGame()
            })
        } else {
            startNewGame()
        }
    }
    
    private func warnResumeGame(gameType: String = "", okHandler: @escaping ()->()) {
        let gameText = (gameType == "" ? "game" : "\(gameType) game")
        self.alertDecision("You appear to have an existing game in progress.\nStarting a new \(gameText) will mean that you cannot resume this game.\n\nAre you sure you want to continue", okButtonText: "Continue", okHandler: okHandler)
    }
    
    private func startNewGame() {
        resumeGameCell.actionButton.isEnabled(false)
        self.scorecard.setGameInProgress(false)
        self.scorecard.reset()
        self.performSegue(withIdentifier: "showSelection", sender: self )
    }
    
    private func resumeGame() {
        // Recover game
        if recovery.checkRecovery() { 
            resumeGameCell.actionButton.isEnabled(false)
            self.scorecard.loadGameDefaults()
            recovery.loadSavedValues()
            scorecard.recoveryMode = true
            if scorecard.recoveryOnlinePurpose != nil && scorecard.recoveryOnlinePurpose == .playing {
                if scorecard.recoveryOnlineType == .server {
                    self.hostGame()
                } else {
                    self.joinGame()
                }
            } else {
                self.performSegue(withIdentifier: "showSelection", sender: self )
            }
        }
    }
    
    private func newOnlineGame() {
        if recovery.checkRecovery() {
            // Warn that this is irreversible
            warnResumeGame(gameType: "online", okHandler: {
                self.scorecard.recoveryMode = false
                self.onlineGame()
            })
        } else {
            self.onlineGame()
        }
    }
    
    private func onlineGame() {
      if Utility.compareVersions(version1: self.scorecard.settingVersion,
                                 version2: self.scorecard.latestVersion) == .lessThan {
            self.alertMessage("You must upgrade to the latest version of the app to use this option")
      } else {
        let actionSheet = ActionSheet( view: onlineGameCell.actionButton, direction: .up)
            actionSheet.add("Host a Game", handler: hostGame)
            actionSheet.add("Join a Game", handler: joinGame)
            actionSheet.add("Cancel", style: .cancel)
            actionSheet.present()
        }
    }
    
    private func hostGame() -> Void {
        self.performSegue(withIdentifier: "showHost", sender: self)
    }
    
    private func joinGame() -> Void {
        self.broadcastCommsPurpose = .playing
        self.broadcastTitle = "Join a Game"
        self.performSegue(withIdentifier: "showBroadcast", sender: self)
    }
    
    private func viewGame() {
        self.broadcastCommsPurpose = .sharing
           self.broadcastTitle = "View a Game"
        self.performSegue(withIdentifier: "showBroadcast", sender: self)
    }

    // MARK: - Segue Prepare Handler ================================================================ -
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier! {
        case "showSettings":
            let destination = segue.destination as! SettingsViewController
            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.isModalInPopover = true
            destination.popoverPresentationController?.sourceView = welcomeView
            destination.preferredContentSize = CGSize(width: 400, height: 600)
            destination.scorecard = self.scorecard
            destination.returnSegue = "hideSettings"
            destination.backImage = "home"
            destination.backText = ""
            
        case "showBroadcast":
            let destination = segue.destination as! BroadcastViewController
            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = welcomeView
            destination.preferredContentSize = CGSize(width: 400, height: 600)
            destination.popoverPresentationController?.delegate = self
            destination.returnSegue = "hideBroadcast"
            destination.backImage = "home"
            destination.backText = ""
            destination.formTitle = self.broadcastTitle
            destination.scorecard = self.scorecard
            destination.commsPurpose = self.broadcastCommsPurpose
            destination.matchDeviceName = self.broadcastMatchDeviceName
        
        case "showHost":
            let destination = segue.destination as! HostViewController
            destination.backImage = "home"
            destination.backText = ""
            destination.scorecard = self.scorecard
            
        case "showHighScores":
            let destination = segue.destination as! HighScoresViewController
            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = welcomeView
            destination.preferredContentSize = CGSize(width: 400, height: 523)
            destination.returnSegue = "hideHighScores"
            destination.backImage = "home"
            destination.backText = ""
            destination.scorecard = self.scorecard
            
        case "showStats":
            let destination = segue.destination as! StatsViewController
            destination.scorecard = self.scorecard
            destination.playerList = scorecard.playerDetailList()
            destination.returnSegue = "hidePlayerStats"
            destination.backImage = "home"
            destination.backText = ""
            
        case "showHistory":
            let destination = segue.destination as! HistoryViewController
            destination.scorecard = self.scorecard
            
        case "showSelection":
            let destination = segue.destination as! SelectionViewController
            destination.scorecard = self.scorecard

        case "showGetStarted":
            let destination = segue.destination as! GetStartedViewController
            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = welcomeView
            destination.preferredContentSize = CGSize(width: 400, height: 600)
            destination.scorecard = self.scorecard
            
        default:
            break
        }
    }
    
    // MARK: - Send email and delegate methods =========================================================== -
    
    func backupDevice() {
        Backup.sendEmail(from: self, scorecard: self.scorecard)
    }
        
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
    
    // MARK: - Call reconcile and reconcile delegate methods =========================================================== -
    
    private func reconcilePlayers(allPlayers: Bool = false) {
        
        var playerMOList: [PlayerMO] = []
        for playerMO in scorecard.playerList {
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
            self.reconcileContinue = UIAlertAction(title: "Continue", style: UIAlertActionStyle.default, handler: nil)
            self.reconcileAlertController.addAction(self.reconcileContinue)
            self.reconcileContinue.isEnabled = false
            
            //add the activity indicator as a subview of the alert controller's view
            self.reconcileIndicatorView = UIActivityIndicatorView(frame: CGRect(x: 0, y: 150,
                                                                                width: self.reconcileAlertController.view.frame.width,
                                                                                height: 100))
            self.reconcileIndicatorView.activityIndicatorViewStyle = .whiteLarge
            self.reconcileIndicatorView.color = UIColor.black
            self.reconcileIndicatorView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.reconcileAlertController.view.addSubview(self.reconcileIndicatorView)
            self.reconcileIndicatorView.isUserInteractionEnabled = true
            self.reconcileIndicatorView.startAnimating()
            
            self.present(self.reconcileAlertController, animated: true, completion: nil)
            
            // Set reconcile running
            reconcile = Reconcile()
            reconcile.delegate = self
            reconcile.initialise(scorecard: self.scorecard)
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
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class WelcomeActionCell: UITableViewCell {
    @IBOutlet weak var actionButton: RoundedButton!
    @IBOutlet weak var resumeButtonView: UIView!
}
