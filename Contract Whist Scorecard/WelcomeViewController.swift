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

class WelcomeViewController: CustomViewController, UITableViewDataSource, UITableViewDelegate, ReconcileDelegate, SyncDelegate, MFMailComposeViewControllerDelegate, UIPopoverPresentationControllerDelegate {

    // MARK: - Class Properties ================================================================ -
    
    // Main state properties
    public var scorecard = Scorecard()
    private let recovery = Recovery()
    private let sync = Sync()
    
    // Properties to pass state to / from segues
    public var clientTitle: String!
    public var clientMatchDeviceName: String!
    public var clientCommsPurpose: CommsConnectionPurpose!
    public var playingComputer = false

    // Local state variables
    private var reconcile: Reconcile!
    private var firstTime = true
    private var getStarted = true
    
    // Action button IDs
    private var newGameButton = -1
    private var onlineGameButton = -1
    private var getStartedButton = -1
    private var resumeGameButton = -1
    private var playersButton = -1
    private var statisticsButton = -1
    private var highScoresButton = -1
    private var historyButton = -1
    private var deleteCloudButton = -1
    private var patchButton = -1
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
    private var playersCell: WelcomeActionCell!
    private var statisticsCell: WelcomeActionCell!
    private var highScoresCell: WelcomeActionCell!
    private var historyCell: WelcomeActionCell!
    private var deleteCloudCell: WelcomeActionCell!
    private var patchCell: WelcomeActionCell!
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
        getCloudVersion(async: true)
        setupButtons()
    }
    
    @IBAction func hideClient(segue:UIStoryboardSegue) {
        getCloudVersion(async: true)
        setupButtons()
        actionsTableView.reloadData()
    }
    
    @IBAction func hideHost(segue:UIStoryboardSegue) {
        getCloudVersion(async: true)
        setupButtons()
        actionsTableView.reloadData()
    }
    
    @IBAction func hideGetStarted(segue:UIStoryboardSegue) {
        scorecard.checkNetworkConnection(button: nil, label: syncMessage)
        scorecard.recoveryMode = false
        getCloudVersion(async: true)
        setupButtons()
    }
    
    @IBAction func hidePlayers(segue:UIStoryboardSegue) {
        scorecard.checkNetworkConnection(button: nil, label: syncMessage)
        getCloudVersion(async: true)
        enableButtons() // In case removed all players
    }
    
    @IBAction func hideStatistics(segue:UIStoryboardSegue) {
        scorecard.checkNetworkConnection(button: nil, label: syncMessage)
        getCloudVersion(async: true)
    }
    
    @IBAction func hideHighScores(segue:UIStoryboardSegue) {
        scorecard.checkNetworkConnection(button: nil, label: syncMessage)
        getCloudVersion(async: true)
    }
    
    @IBAction func hideHistory(segue:UIStoryboardSegue) {
        scorecard.checkNetworkConnection(button: nil, label: syncMessage)
        getCloudVersion(async: true)
    }
    
    @IBAction func hideSelection(segue:UIStoryboardSegue) {
        // Clear recovery flag
        scorecard.checkNetworkConnection(button: nil, label: syncMessage)
        scorecard.recoveryMode = false
        getCloudVersion(async: true)
        enableButtons()
    }
    
    @IBAction func finishGame(segue:UIStoryboardSegue) {
        scorecard.checkNetworkConnection(button: nil, label: syncMessage)
        scorecard.recoveryMode = false
        getCloudVersion(async: true)
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
        
        self.hideNavigationBar()
        
        // Possible clear all data in test mode
        TestMode.resetApp()
        
        scorecard.initialise(from: self, players: 4, maxRounds: 25, recovery: recovery)
        sync.initialise(scorecard: scorecard)
        
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
            scorecard.getVersion(completion: {
                // Don't call this until any upgrade has taken place
                self.getCloudVersion()
            })
            
            // Note flow continues in completion handler of getCloudVersion
        }
        
        setupButtons()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        ScorecardUI.selectBackground(size: size, backgroundImage: backgroundImage)
    }
    
    // MARK: - Sync class delegate methods ===================================================================== -
    
    func getCloudVersion(async: Bool = false) {
        if scorecard.isNetworkAvailable {
            if self.sync.connect() {
                if async {
                    self.sync.delegate = nil
                    self.sync.synchronise(syncMode: .syncGetVersionAsync, timeout: nil, waitFinish: false)
                } else {
                    self.sync.delegate = self
                    self.sync.synchronise(syncMode: .syncGetVersion, timeout: nil)  
                }
            } else {
                self.syncCompletion(0)
            }
        } else {
            self.syncCompletion(0)
        }
    }
    
    func syncCompletion(_ errors: Int) {
        
        // Continue to Get Started if necessary pending version lookup - a risk but probably OK
        if scorecard.playerList.count == 0 && getStarted {
            // No players setup - go to Get Started
            getStarted = false
            self.performSegue(withIdentifier: "showGetStarted", sender: self)
        }
        
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
        case playersButton:
            welcomeActionCell.actionButton.setTitle("Players", for: .normal)
            playersCell = welcomeActionCell
        case statisticsButton:
            welcomeActionCell.actionButton.setTitle("Statistics", for: .normal)
            statisticsCell = welcomeActionCell
        case highScoresButton:
            welcomeActionCell.actionButton.setTitle("High Scores", for: .normal)
            highScoresCell = welcomeActionCell
        case historyButton:
            welcomeActionCell.actionButton.setTitle("History", for: .normal)
            historyCell = welcomeActionCell
        case deleteCloudButton:
            welcomeActionCell.actionButton.setTitle("Delete iCloud Database", for: .normal)
            deleteCloudCell = welcomeActionCell
        case patchButton:
            welcomeActionCell.actionButton.setTitle("Patch Local Database", for: .normal)
            patchCell = welcomeActionCell
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
        welcomeActionCell.separatorInset = UIEdgeInsets.init(top: 0.0, left: welcomeActionCell.bounds.size.width, bottom: 0.0, right: 0.0);
        welcomeActionCell.actionButton.addTarget(self, action: #selector(WelcomeViewController.actionButtonPressed(_:)), for: UIControl.Event.touchUpInside)
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
        case playersButton:
            // Players
            self.performSegue(withIdentifier: "showPlayers", sender: self )
        case statisticsButton:
            // Players
            self.performSegue(withIdentifier: "showStatistics", sender: self )
        case highScoresButton:
            // High Scores
            self.performSegue(withIdentifier: "showHighScores", sender: self )
        case historyButton:
            // History
            self.performSegue(withIdentifier: "showHistory", sender: self )
        case deleteCloudButton:
            // Delete iCloud database
            DataAdmin.deleteCloudDatabase(from: self)
        case patchButton:
            // Delete iCloud database
            DataAdmin.patchLocalDatabase(from: self)
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
        
        // TODO Reinstate (move below online game)
        buttons += 1
        newGameButton = buttons
        
        // TODO Reinstate (move below online game)
        buttons += 1
        resumeGameButton = buttons
        
        if (self.scorecard.settingSyncEnabled && self.scorecard.settingNearbyPlaying || self.scorecard.onlineEnabled) { // TODO Reinstate (remove)
            buttons += 1
            onlineGameButton = buttons
        } // TODO Reinstate (remove
            
        buttons += 1
        playersButton = buttons
        
        buttons += 1
        statisticsButton = buttons
        
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
            patchButton = buttons
            buttons += 1
            removeDuplicatesButton = buttons
            buttons += 1
            rebuildAllButton = buttons
            buttons += 1
            backupButton = buttons
            titleLabel.text = "Admin Mode"
        } else {
            deleteCloudButton = -1
            patchButton = -1
            removeDuplicatesButton = -1
            rebuildAllButton = -1
            backupButton = -1
            deleteCloudCell = nil
            patchCell = nil
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
        if viewController is ClientViewController {
            let clientViewController = viewController as! ClientViewController
            clientViewController.finishClient()
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
                if recoveryEnabled && !online {
                    resumeGameCell.actionButton.setTitle("Resume Scoring")
                } else {
                    resumeGameCell.actionButton.setTitle("Resume Playing")
                }
            }
        }
        
        if button == 0 || button == onlineGameButton {
            if onlineGameCell != nil {
                onlineGameCell.actionButton.isEnabled(scorecard.playerList.count > 0 && (self.scorecard.settingSyncEnabled && self.scorecard.settingNearbyPlaying || self.scorecard.onlineEnabled))
            }
        }
        
        if button == 0 || button == playersButton {
            if playersCell != nil {
                playersCell.actionButton.isEnabled(scorecard.playerList.count > 0)
            }
        }
        
        if button == 0 || button == statisticsButton {
            if statisticsCell != nil {
                statisticsCell.actionButton.isEnabled(scorecard.playerList.count > 0)
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
                    if self.scorecard.recoveryOnlineMode == .loopback {
                        self.computerGame()
                    } else {
                        self.hostGame()
                    }
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
        } else if self.scorecard.settingSyncEnabled && (self.scorecard.settingNearbyPlaying || self.scorecard.settingOnlinePlayerEmail != nil) {
            let actionSheet = ActionSheet( view: onlineGameCell.actionButton, direction: .up)
            actionSheet.add("Host a Game", handler: hostGame)
            actionSheet.add("Join a Game", handler: joinGame)
            // TODO reinstate actionSheet.add("Play against Computer", handler: computerGame)
            actionSheet.add("Cancel", style: .cancel)
            actionSheet.present()
        } else {
            // TODO reinstate self.computerGame()
        }
    }
    
    private func hostGame() -> Void {
        self.playingComputer = false
        self.performSegue(withIdentifier: "showHost", sender: self)
    }
    
    private func joinGame() -> Void {
        self.clientCommsPurpose = .playing
        self.clientTitle = "Join a Game"
        self.performSegue(withIdentifier: "showClient", sender: self)
    }
    
    private func computerGame() -> Void {
        self.playingComputer = true
        self.performSegue(withIdentifier: "showHost", sender: self)
    }
    
    private func viewGame() {
        self.clientCommsPurpose = .sharing
           self.clientTitle = "View a Game"
        self.performSegue(withIdentifier: "showClient", sender: self)
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
            
        case "showClient":
            let destination = segue.destination as! ClientViewController
            destination.returnSegue = "hideClient"
            destination.backImage = "home"
            destination.backText = ""
            destination.formTitle = self.clientTitle
            destination.scorecard = self.scorecard
            destination.commsPurpose = self.clientCommsPurpose
            destination.matchDeviceName = self.clientMatchDeviceName
        
        case "showHost":
            let destination = segue.destination as! HostViewController
            destination.backImage = "home"
            destination.backText = ""
            destination.playingComputer = self.playingComputer
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
            
        case "showPlayers":
            let destination = segue.destination as! PlayersViewController
            destination.scorecard = self.scorecard
            destination.playerList = scorecard.playerDetailList()
            destination.multiSelectMode = false
            destination.detailMode = .amend
            destination.returnSegue = "hidePlayers"
            destination.backImage = "home"
            destination.backText = ""
            
        case "showStatistics":
            let destination = segue.destination as! StatisticsViewController
            destination.scorecard = self.scorecard
            destination.selectedList = scorecard.playerDetailList()
            destination.returnSegue = "hideStatistics"
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
            self.reconcileContinue = UIAlertAction(title: "Continue", style: UIAlertAction.Style.default, handler: nil)
            self.reconcileAlertController.addAction(self.reconcileContinue)
            self.reconcileContinue.isEnabled = false
            
            //add the activity indicator as a subview of the alert controller's view
            self.reconcileIndicatorView = UIActivityIndicatorView(frame: CGRect(x: 0, y: 150,
                                                                                width: self.reconcileAlertController.view.frame.width,
                                                                                height: 100))
            self.reconcileIndicatorView.style = .whiteLarge
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
