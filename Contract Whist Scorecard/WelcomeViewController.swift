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

struct ActionButton {
    var tag: Int
    var section: Int
    var title: String
    var highlight: Bool
    var isHidden: (()->Bool)?
    var action: (UITableViewCell)->()
}

class WelcomeViewController: CustomViewController, UITableViewDataSource, UITableViewDelegate, ReconcileDelegate, SyncDelegate, MFMailComposeViewControllerDelegate, UIPopoverPresentationControllerDelegate {

    private enum Shape {
        case arrowTop
        case arrowMiddle
        case arrowBottom
    }
    
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
    
    private var sections: [Int]!
    private var sectionActions: [Int:[ActionButton]]!
    private var actionButtons: [ActionButton]!
    private var mainSection = 1
    private var infoSection = 2
    private var adminSection = 3
    
    private var recoveryAvailable = false
    private var recoverOnline = false
    
    
    // Debug rotations code
    private let code: [CGFloat] = [ -1.0, -1.0, 1.0, -1.0, 1.0]
    private var matching = 0
    
    // UI component pointers
    private var onlineGameCell: UITableViewCell!
    private var reconcileAlertController: UIAlertController!
    private var reconcileContinue: UIAlertAction!
    private var reconcileIndicatorView: UIActivityIndicatorView!
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var welcomeView: UIView!
    @IBOutlet private weak var syncMessage: UILabel!
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
        self.getCloudVersion(async: true)
        self.setupButtons()
    }
    
    @IBAction func hideHost(segue:UIStoryboardSegue) {
        self.getCloudVersion(async: true)
        self.setupButtons()
    }
    
    @IBAction func hideGetStarted(segue:UIStoryboardSegue) {
        self.scorecard.checkNetworkConnection(button: nil, label: syncMessage)
        self.recoveryAvailable = false
        self.getCloudVersion(async: true)
        self.setupButtons()
    }
    
    @IBAction func hidePlayers(segue:UIStoryboardSegue) {
        self.scorecard.checkNetworkConnection(button: nil, label: syncMessage)
        self.getCloudVersion(async: true)
        self.checkButtons()
    }
    
    @IBAction func hideHighScores(segue:UIStoryboardSegue) {
        self.scorecard.checkNetworkConnection(button: nil, label: syncMessage)
        self.getCloudVersion(async: true)
    }
    
    @IBAction func hideSelection(segue:UIStoryboardSegue) {
        // Clear recovery flag
        self.scorecard.checkNetworkConnection(button: nil, label: syncMessage)
        self.recoveryAvailable = false
        self.getCloudVersion(async: true)
        self.checkButtons()
    }
    
    @IBAction func finishGame(segue:UIStoryboardSegue) {
        self.scorecard.checkNetworkConnection(button: nil, label: syncMessage)
        self.recoveryAvailable = false
        self.getCloudVersion(async: true)
        self.checkButtons()
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
            self.scoreGame()
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
        
        (self.recoveryAvailable, self.recoverOnline) = recovery.checkOnlineRecovery()
        
        if !recoveryAvailable {
            scorecard.reset()
        }
        
        scorecard.checkNetworkConnection(button: nil, label: syncMessage)
        
        self.setupButtons()
        
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
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.actionsTableView.layoutIfNeeded()
        self.actionsTableView.reloadData()
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
        return self.sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.sectionActions[sections[section]]!.count
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return 1
        } else {
            return 20
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return " "
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return UIView()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return min(80, max(50, tableView.frame.height / 8.0))
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var welcomeActionCell: WelcomeActionCell
        
        // Action buttons
        welcomeActionCell = tableView.dequeueReusableCell(withIdentifier: "Welcome Action Cell", for: indexPath) as! WelcomeActionCell
        
        let section = self.sections[indexPath.section]
        let actionButtons = self.sectionActions[section]!
        let actionButton = actionButtons[indexPath.row]
        
        var shape: Shape
        var strokeColor: UIColor
        var fillColor: UIColor
        var pointType: PolygonPointType
        
        // Set section colors
        if section == 1 {
            strokeColor = ScorecardUI.shapeHighlightStrokeColor
            fillColor = ScorecardUI.shapeHighlightFillColor
        } else {
            strokeColor = ScorecardUI.shapeStrokeColor
            fillColor = ScorecardUI.shapeFillColor
            if indexPath.row % 2 == 0 {
                shape = .arrowTop
            } else {
                shape = .arrowBottom
            }
        }
        
        // Override fill color if highlighted
        if actionButton.highlight {
            fillColor = strokeColor
        }
        
        // Set shapes
        if actionButtons.count == 1 {
            pointType = .rounded
            shape = .arrowMiddle
        } else if actionButtons.count == 3 {
            if indexPath.item == 0 {
                shape = .arrowTop
                pointType = .insideRounded
            } else if indexPath.item == 1 {
                shape = .arrowMiddle
                pointType = .point
            } else {
                shape = .arrowBottom
                pointType = .insideRounded
            }
        } else {
            pointType = .halfRounded
            if indexPath.item % 2 == 0 {
                shape = .arrowTop
            } else {
                shape = .arrowBottom
            }
        }

        self.backgroundShape(view: welcomeActionCell.shapeView, shape: shape, strokeColor: strokeColor, fillColor: fillColor, abutted: (indexPath.row != 0) && (indexPath.row != actionButtons.count - 1), pointType: pointType)

        welcomeActionCell.title.text = actionButton.title
        welcomeActionCell.title.font = UIFont.systemFont(ofSize: min(40, welcomeActionCell.title.frame.width / 9.0, welcomeActionCell.title.frame.height / 1.25), weight: .thin)
        welcomeActionCell.tag = actionButton.tag
        welcomeActionCell.selectionStyle = .none
        
        return welcomeActionCell as UITableViewCell
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        
        if let cell = tableView.cellForRow(at: indexPath) {
            let actionButton = actionButtons[cell.tag]
            Utility.mainThread {
                actionButton.action(cell)
            }
        }
        return nil
    }
    
     // MARK: - Action Handlers ================================================================ -
    
    private func setupButtons(allowRecovery: Bool = true) {
        
        self.actionButtons = []
        
        self.addAction(section: mainSection, title: "Get Started", isHidden: {self.scorecard.playerList.count != 0}, action: { (_) in
            self.performSegue(withIdentifier: "showGetStarted", sender: self)
        })
        
        self.addAction(section: mainSection, title: "Play Game", isHidden: {!self.scorecard.settingSyncEnabled || !(self.scorecard.settingNearbyPlaying || self.scorecard.onlineEnabled)}, action: newOnlineGame)
        
        self.addAction(section: mainSection, title: "Resume Playing", highlight: true, isHidden: {!self.recoveryAvailable || !self.recoverOnline || !allowRecovery
        }, action: resumeGame)
        
        self.addAction(section: mainSection, title: (self.scorecard.settingSyncEnabled ? "Resume Scoring" : "Resume"), highlight: true, isHidden: {!self.recoveryAvailable || self.recoverOnline || !allowRecovery}, action: resumeGame)

        self.addAction(section: mainSection, title: "Score Game", action: { (_) in
            self.scoreGame()
        })
        
        self.addAction(section: infoSection, title: "Players", action: { (_) in
            self.performSegue(withIdentifier: "showPlayers", sender: self)
        })
        
        self.addAction(section: infoSection, title: "Statistics", action: { (_) in
            let _ = StatisticsViewer(from: self, scorecard: self.scorecard)
        })
        
        self.addAction(section: infoSection, title: "History", isHidden: {!self.scorecard.settingSaveHistory}, action: { (_) in
            let _ = HistoryViewer(from: self, scorecard: self.scorecard)
        })
        
        self.addAction(section: infoSection, title: "High Scores", isHidden: {!self.scorecard.settingSaveHistory}, action: { (_) in
            self.performSegue(withIdentifier: "showHighScores", sender: self)
        })
        
        self.addAction(section: adminSection, title: "Delete iCloud Database", isHidden: {!Scorecard.adminMode}, action: { (_) in
            DataAdmin.deleteCloudDatabase(from: self)
        })

        self.addAction(section: adminSection, title: "Reset Sync Record IDs", isHidden: {!Scorecard.adminMode}, action: { (_) in
            DataAdmin.resetSyncRecordIDs(from: self)
        })

        self.addAction(section: adminSection, title: "Remove Duplicate Games", isHidden: {!Scorecard.adminMode}, action: { (_) in
            DataAdmin.removeDuplicates(from: self)
        })
        
        self.addAction(section: adminSection, title: "Rebuild All Players", isHidden: {!Scorecard.adminMode}, action: { (_) in
            self.reconcilePlayers(allPlayers: true)
        })

        self.addAction(section: adminSection, title: "Backup Device", isHidden: {!Scorecard.adminMode}, action: { (_) in
            self.backupDevice()
        })
        
        self.checkButtons()
        
        self.viewOnlineButton.isHidden = !self.scorecard.settingSyncEnabled || !self.scorecard.settingAllowBroadcast
        
    }
    
    private func checkButtons() {
        self.sections = []
        self.sectionActions = [:]
        for actionButton in self.actionButtons {
            if !(actionButton.isHidden?() ?? false) {
                let section = actionButton.section
                if sectionActions[section] == nil {
                    sectionActions[section] = []
                    sections.append(section)
                }
                sectionActions[section]!.append(actionButton)
            }
        }
        self.actionsTableView.reloadData()
    }
    
    private func addAction(section: Int, title: String, highlight: Bool = false, isHidden: (()->Bool)? = nil, action: @escaping (UITableViewCell)->()) {
        let tag = self.actionButtons.count
        self.actionButtons.append(ActionButton(tag: tag, section: section, title: title, highlight: highlight, isHidden: isHidden, action: action))
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
    
    private func scoreGame() {
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
        self.scorecard.setGameInProgress(false)
        self.scorecard.reset()
        self.performSegue(withIdentifier: "showSelection", sender: self )
    }
    
    private func resumeGame(_ cell: UITableViewCell) {
        // Recover game
        if recovery.checkRecovery() { 
            self.setupButtons(allowRecovery: false)
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
    
    private func newOnlineGame(_ cell: UITableViewCell) {
        if self.recovery.checkRecovery() {
            // Warn that this is irreversible
            self.warnResumeGame(gameType: "online", okHandler: {
                self.scorecard.recoveryMode = false
                self.onlineGame(cell)
            })
        } else {
            self.onlineGame(cell)
        }
    }
    
    private func onlineGame(_ cell: UITableViewCell) {
        if Utility.compareVersions(version1: self.scorecard.settingVersion,
                                 version2: self.scorecard.latestVersion) == .lessThan {
            self.alertMessage("You must upgrade to the latest version of the app to use this option")
        } else if self.scorecard.settingSyncEnabled && (self.scorecard.settingNearbyPlaying || self.scorecard.settingOnlinePlayerEmail != nil) {
            let actionSheet = ActionSheet(view: cell, direction: .up)
            actionSheet.add("Host a Game", handler: hostGame)
            actionSheet.add("Join a Game", style: .destructive, handler: joinGame)
            actionSheet.add("Play Against Computer", handler: computerGame) // TODO Hide
            actionSheet.add("Cancel", style: .cancel)
            actionSheet.present()
        } else {
            self.computerGame() // TODO Hide
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
            
            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.isModalInPopover = true
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = welcomeView
            destination.preferredContentSize = CGSize(width: 400, height: 600)
            
            destination.returnSegue = "hideClient"
            destination.backImage = "home"
            destination.backText = ""
            destination.formTitle = self.clientTitle
            destination.scorecard = self.scorecard
            destination.commsPurpose = self.clientCommsPurpose
            destination.matchDeviceName = self.clientMatchDeviceName
        
        case "showHost":
            let destination = segue.destination as! HostViewController
            
            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.isModalInPopover = true
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = welcomeView
            destination.preferredContentSize = CGSize(width: 400, height: 600)
            
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
            destination.detailMode = .amend
            destination.refresh = true
            destination.returnSegue = "hidePlayers"
            destination.backImage = "home"
            destination.backText = ""
            
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
    
    private func backgroundShape(view: UIView, shape: Shape, strokeColor: UIColor, fillColor: UIColor, abutted: Bool = false, pointType: PolygonPointType = .rounded, lineWidth: CGFloat = 3.0) {
        
        var points: [PolygonPoint] = []
        let size = view.frame.size
        let arrowWidth = size.height
        let shift = lineWidth / 2.0
        
        // Remove any previous view layers
        view.layer.sublayers?.removeAll()
        
        switch shape {
        case .arrowTop:
            points.append(PolygonPoint(x: 0.0, y: (abutted ? 0 : shift), pointType: .point))
            points.append(PolygonPoint(x: size.width - (arrowWidth * 1.5), y: (abutted ? 0 : shift)))
            points.append(PolygonPoint(x: size.width - (arrowWidth * 0.5), y: size.height, pointType: pointType))
            points.append(PolygonPoint(x: 0.0, y: size.height, pointType: .point))
        case .arrowBottom:
            points.append(PolygonPoint(x: 0.0, y: 0.0, pointType: .point))
            points.append(PolygonPoint(x: 0.0, y: size.height - (abutted ? 0 : shift), pointType: .point))
            points.append(PolygonPoint(x: size.width - (arrowWidth * 1.5), y: size.height - (abutted ? 0 : shift)))
            points.append(PolygonPoint(x: size.width - (arrowWidth * 0.5), y: 0.0, pointType: pointType))
        case .arrowMiddle:
            points.append(PolygonPoint(x: 0.0, y: (abutted ? 0 : shift), pointType: .point))
            points.append(PolygonPoint(x: size.width - (arrowWidth * (abutted ? 0.5 : 1.5)), y: (abutted ? 0 : shift), pointType: pointType))
            points.append(PolygonPoint(x: size.width - (arrowWidth * (abutted ? 0.0 : 1.0)) , y: (size.height * 0.5) - (abutted ? 0 : shift)))
            points.append(PolygonPoint(x: size.width - (arrowWidth * (abutted ? 0.5 : 1.5)), y: size.height - (abutted ? 0 : shift), pointType: pointType))
            points.append(PolygonPoint(x: 0.0, y: size.height, pointType: .point))
        }
        
        Polygon.roundedShape(in: view, definedBy: points, strokeColor: strokeColor, fillColor: fillColor, lineWidth: lineWidth, roundingFraction: 0.05)
        
    }
    
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class WelcomeActionCell: UITableViewCell {
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var shapeView: UIView!
}
