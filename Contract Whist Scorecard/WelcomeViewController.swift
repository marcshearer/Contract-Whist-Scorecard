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
    var sequence: Int
    var isHidden: (()->Bool)?
    var action: (WelcomeActionCell)->()
}

public enum Position: String {
    case left = "left"
    case right = "right"
}

class WelcomeViewController: CustomViewController, ScrollViewDataSource, ScrollViewDelegate, ReconcileDelegate, SyncDelegate, MFMailComposeViewControllerDelegate, UIPopoverPresentationControllerDelegate {
    
    private enum Shape {
        case arrowTop
        case arrowMiddle
        case shortArrowMiddle
        case arrowBottom
    }
    
    // MARK: - Class Properties ================================================================ -
    
    // Main state properties
    private let scorecard = Scorecard.shared
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
    private weak var selectionViewController: SelectionViewController!
    
    private var sections: [Int:Int]!
    private var sectionActions: [Int : [(frame: CGRect, position: Position, action: ActionButton)]]!
    private var actionButtons: [ActionButton]!
    private var mainSection = 1
    private var infoSection = 2
    private var adminSection = 3
    
    private var recoveryAvailable = false
    private var recoverOnline = false
    
    private var scrollView: ScrollView!
    
    private let actionStart: CGFloat = 144.0
    private var actionHeight: CGFloat = 80.0
    private var lineWidth: CGFloat = 3.0
    private var sectionSpace: CGFloat = 20.0
    private var syncLabelHeight: CGFloat = 20.0
    
    // Debug rotations code
    private let code: [CGFloat] = [ -1.0, -1.0, 1.0, -1.0, 1.0]
    private var matching = 0
    
    // UI component pointers
    private var reconcileAlertController: UIAlertController!
    private var reconcileContinue: UIAlertAction!
    private var reconcileIndicatorView: UIActivityIndicatorView!
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var welcomeView: UIView!
    @IBOutlet private weak var viewOnlineButton: ClearButton!
    @IBOutlet private weak var actionScrollView: UIScrollView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var syncLabel: UILabel!
    @IBOutlet private weak var syncLabelHeightConstraint: NSLayoutConstraint!
    
    // MARK: - IB Unwind Segue Handlers ================================================================ -
    
    @IBAction func hideSettings(segue:UIStoryboardSegue) {
        scorecard.checkNetworkConnection(button: nil, label: syncLabel, labelHeightConstraint: syncLabelHeightConstraint, labelHeight: syncLabelHeight)
        getCloudVersion(async: true)
        setupButtons()
    }
    
    @IBAction func hideClient(segue:UIStoryboardSegue) {
        self.getCloudVersion(async: true)
        self.setupButtons()
    }
    
   @IBAction func hideGetStarted(segue:UIStoryboardSegue) {
        self.scorecard.checkNetworkConnection(button: nil, label: syncLabel)
        self.recoveryAvailable = false
        self.getCloudVersion(async: true)
        self.setupButtons()
    }
    
    @IBAction func hidePlayers(segue:UIStoryboardSegue) {
        self.scorecard.checkNetworkConnection(button: nil, label: syncLabel)
        self.getCloudVersion(async: true)
        self.checkButtons()
    }
    
    @IBAction func hideHighScores(segue:UIStoryboardSegue) {
        self.scorecard.checkNetworkConnection(button: nil, label: syncLabel)
        self.getCloudVersion(async: true)
    }
    
    @IBAction func finishGame(segue:UIStoryboardSegue) {
        self.scorecard.checkNetworkConnection(button: nil, label: syncLabel)
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
                    self.setTitle()
                    self.checkButtons()
                    self.scrollView.reloadData()
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
        
        scorecard.initialise(from: self, players: 4, maxRounds: 25)
        
        (self.recoveryAvailable, self.recoverOnline) = scorecard.recovery.checkOnlineRecovery()
        
        if !recoveryAvailable {
            scorecard.reset()
        }
        
        // Setup scroll view
        self.scrollView = ScrollView(self.actionScrollView)
        self.scrollView.dataSource = self
        self.scrollView.delegate = self
        
        scorecard.checkNetworkConnection(button: nil, label: syncLabel)
        
        // Setup screen
        self.setupButtons()
        self.setTitle()
        
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

        if ScorecardUI.portraitPhone() {
            self.actionHeight = min(80.0, max(50.0, (view.frame.height - 44.0 - self.actionStart) / 6.8))
            self.sectionSpace = 20.0
        } else {
            self.actionHeight = (ScorecardUI.phoneSize() ?  80.0 : 120.0)
            self.sectionSpace = 100.0
        }
        
        // Redraw
        self.checkButtons()
        self.scrollView.reloadData()
    }
    
    // MARK: - Sync class delegate methods ============================================== -
    
    func getCloudVersion(async: Bool = false) {
        if scorecard.isNetworkAvailable {
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
    
    func syncCompletion(_ errors: Int) {
        
        Utility.debugMessage("Welcome", "Version returned")
        
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
    
    func syncAlert(_ message: String, completion: @escaping ()->()) {
        self.alertMessage(message, title: "Contract Whist Scorecard", okHandler: {
            if self.scorecard.settingVersionBlockAccess {
                exit(0)
            } else {
                completion()
            }
        })
    }
        
    // MARK: - ScrollView Overrides ===================================================================== -
    
    internal func numberOfSections(in: ScrollView) -> Int {
        return self.sections.count
    }
    
    internal func scrollView(_ scrollView: ScrollView, numberOfItemsIn section: Int) -> Int {
        return self.sectionActions[sections[section]!]?.count ?? 0
    }
    
    internal func scrollView(_ scrollView: ScrollView, frameForItemAt indexPath: IndexPath) -> CGRect {
        let section = self.sections[indexPath.section]!
        let actionButtons = self.sectionActions[section]!
        let (frame, _, _) = actionButtons[indexPath.row]
        return frame
    }
    
    internal func scrollView(_ scrollView: ScrollView, cellForItemAt indexPath: IndexPath) -> ScrollViewCell {
        
        let section = self.sections[indexPath.section]!
        let actionButtons = self.sectionActions[section]!
        let (frame, position, actionButton) = actionButtons[indexPath.row]
        
        var shape: Shape
        var strokeColor: UIColor
        var fillColor: UIColor
        var textColor: UIColor
        var strokeTextColor: UIColor
        var pointType: PolygonPointType
        
        // Get cell
        let welcomeActionCell = WelcomeActionCell(frame: CGRect(origin: CGPoint(), size: frame.size), position: position, textInset: 20.0 + (position == .left ? self.view.safeAreaInsets.left : self.view.safeAreaInsets.right))
        
        // Set section colors
        if section == mainSection {
            strokeColor = Palette.shapeHighlightStroke
            strokeTextColor = Palette.shapeHighlightStrokeText
            fillColor = Palette.shapeHighlightFill
            textColor = Palette.shapeHighlightFillText
        } else if section == adminSection {
            strokeColor = Palette.shapeAdminStroke
            strokeTextColor = Palette.shapeAdminText
            fillColor = Palette.shapeAdminFill
            textColor = Palette.shapeAdminText
        } else {
            strokeColor = Palette.shapeStroke
            strokeTextColor = Palette.shapeStrokeText
            fillColor = Palette.shapeFill
            textColor = Palette.shapeFillText
        }
        
        // Override fill color if highlighted
        if actionButton.highlight {
            fillColor = strokeColor
            textColor = strokeTextColor
        }
        
        // Set shapes
        if section == adminSection {
            pointType = .rounded
            shape = .arrowMiddle
        } else if actionButtons.count == 1 {
            pointType = .rounded
            shape = .shortArrowMiddle
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
        
        welcomeActionCell.path = self.backgroundShape(view: welcomeActionCell.actionShapeView, shape: shape, strokeColor: strokeColor, fillColor: fillColor, pointType: pointType, lineWidth: self.lineWidth, reflected: (position == .right))
        
        welcomeActionCell.actionTitle.text = actionButton.title
        welcomeActionCell.actionTitle.textColor = textColor
        welcomeActionCell.actionTitle.font = UIFont.systemFont(ofSize: min((section == adminSection ? 22 : 40), welcomeActionCell.actionTitle.frame.width / 7.5, welcomeActionCell.actionTitle.frame.height / 1.25), weight: .thin)
        welcomeActionCell.tag = actionButton.tag
        
        return welcomeActionCell
    }
    
    internal func scrollView(_ scrollView: ScrollView, didSelectCell cell: ScrollViewCell, tapPosition: CGPoint) {

        if let cell = cell as? WelcomeActionCell {
            let relativeTapPosition = CGPoint(x: tapPosition.x - cell.frame.minX, y: tapPosition.y - cell.frame.minY)
            if let path = cell.path {
                if path.contains(relativeTapPosition) {
                    Utility.mainThread {
                        let actionButton = self.actionButtons[cell.tag]
                        actionButton.action(cell)
                    }
                }
            }
        }
    }
    
     // MARK: - Action Handlers ================================================================ -
    
    private func setupButtons(allowRecovery: Bool = true) {
        
        self.actionButtons = []
        
        self.addAction(section: mainSection, title: "Get Started", isHidden: {self.scorecard.playerList.count != 0}, action: { (_) in
            self.performSegue(withIdentifier: "showGetStarted", sender: self)
        })
        
        self.addAction(section: mainSection, title: "Play Game", isHidden: {!self.scorecard.settingSyncEnabled || !(self.scorecard.settingNearbyPlaying || self.scorecard.onlineEnabled) || self.scorecard.playerList.count == 0}, action: newOnlineGame)
        
        self.addAction(section: mainSection, title: "Resume Playing", highlight: true, isHidden: {!self.recoveryAvailable || !self.recoverOnline || !allowRecovery
        }, action: resumeGame)
        
        self.addAction(section: mainSection, title: (self.scorecard.settingSyncEnabled ? "Resume Scoring" : "Resume"), highlight: true, isHidden: {!self.recoveryAvailable || self.recoverOnline || !allowRecovery}, action: resumeGame)

        self.addAction(section: mainSection, title: "Score Game", action: { (_) in
            self.scoreGame()
        })
        
        self.addAction(section: infoSection, title: "Players", isHidden: {self.scorecard.playerList.count == 0}, action: { (_) in
            self.performSegue(withIdentifier: "showPlayers", sender: self)
        })
        
        self.addAction(section: infoSection, title: "Statistics", isHidden: {self.scorecard.playerList.count == 0}, action: { (_) in
            let _ = StatisticsViewer(from: self)
        })
        
        self.addAction(section: infoSection, title: "History", isHidden: {!self.scorecard.settingSaveHistory || self.scorecard.playerList.count == 0}, action: { (_) in
            let _ = HistoryViewer(from: self)
        })
        
        self.addAction(section: infoSection, title: "High Scores", isHidden: {!self.scorecard.settingSaveHistory || self.scorecard.playerList.count == 0}, action: { (_) in
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
        var position: Position
        var columnData: [Position : (y: CGFloat, sections: Int)] = [:]
        var scrollViewSection = -1

        columnData[.left] = (self.actionStart , 0)
        columnData[.right] = (self.actionStart, 0)
        
        // Initialise structures
        self.sections = [:]
        self.sectionActions = [:]
        
        // Scan actions building lists by section of included options and position (left/right)
        for actionButton in self.actionButtons {
            if !(actionButton.isHidden?() ?? false) {
                let section = actionButton.section
                
                if self.sectionActions[section] == nil {
                    scrollViewSection += 1
                }
                
                if ScorecardUI.portraitPhone() {
                    position = .left
                } else {
                    position = ((scrollViewSection % 2) == 0 ? .left : .right)
                }
                
                if self.sectionActions[section] == nil {
                    self.sectionActions[section] = []
                    self.sections[scrollViewSection] = section
                }
                
                self.sectionActions[section]!.append((CGRect(), position, actionButton))
            }
        }
        
        // Update frames
        let sorted = self.sectionActions!.sorted(by: {$0.key < $1.key})
        for (section, actions) in sorted {
            var newSection = true
            
            for (index, action) in actions.enumerated() {
            
                if newSection {
                    columnData[action.position]!.sections += 1
                    newSection = false
                }
                
                var x: CGFloat
                var width: CGFloat
                let column = columnData[action.position]!
                var offset: CGFloat = 0.0
                
                // Adjust position for two column mode / format
                if ScorecardUI.portraitPhone() {
                    x = 0.0
                    width = self.actionScrollView.frame.width
                    
                } else {
                    if action.position == .left {
                        x = 0.0
                        width = (self.actionScrollView.frame.width / 2.0)
                        if section == mainSection && actions.count == 3 {
                            width += 10.0
                        } else {
                            width += 60.0
                        }
                    } else {
                        x = (self.actionScrollView.frame.width / 2.0) - 60.0
                        width = (self.actionScrollView.frame.width / 2.0) + 60.0
                    }
                    
                    switch sectionActions[mainSection]!.count {
                    case 1:
                        switch section {
                        case mainSection:
                            offset =  0.5 * self.actionHeight
                        case infoSection:
                            offset = -1.0 * self.actionHeight
                        default:
                            break
                        }
                    case 2:
                        if section == infoSection {
                            offset = -1.0 * self.actionHeight
                        }
                    case 3:
                        if section == infoSection {
                            offset = -0.5 * self.actionHeight
                        }
                    default:
                        break
                    }
                }
                
                if !ScorecardUI.phoneSize() {
                    offset += 180.0
                }
                
                let totalSectionSpace = (CGFloat(column.sections - 1) * self.sectionSpace)
                
                // Update data structures
                self.sectionActions[section]![index].frame = CGRect(x: x, y: totalSectionSpace + offset + column.y, width: width, height: self.actionHeight)
                columnData[action.position]!.y += self.actionHeight
            }
        }
        
        self.scrollView.reloadData()
    }
    
    private func addAction(section: Int, title: String, highlight: Bool = false, isHidden: (()->Bool)? = nil, action: @escaping (WelcomeActionCell)->()) {
        let tag = self.actionButtons.count
        self.actionButtons.append(ActionButton(tag: tag, section: section, title: title, highlight: highlight, sequence: self.actionButtons.count, isHidden: isHidden, action: action))
    }
    
    // MARK: - Popover Overrides ================================================================ -
    
    func popoverPresentationControllerShouldDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) -> Bool {
        let viewController = popoverPresentationController.presentedViewController
        if viewController is ClientViewController {
            let clientViewController = viewController as! ClientViewController
            clientViewController.finishClient()
        }
        return true
    }

    // MARK: - Utility Routines ======================================================================== -
    
    private func setTitle() {
        if Scorecard.adminMode {
            self.titleLabel.text = "Admin Mode"
            self.titleLabel.textColor = Palette.textError
        } else {
            self.titleLabel.text = "Welcome ..."
            self.titleLabel.textColor = Palette.textEmphasised
        }
        
    }
    
    private func scoreGame() {
        if self.scorecard.recovery.checkRecovery() {
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
        self.showSelection()
    }
    
    private func showSelection() {
        self.selectionViewController = SelectionViewController.show(from: self, existing: self.selectionViewController, mode: .players, backText: "", backImage: "home", completion: { (_) in
            self.scorecard.checkNetworkConnection(button: nil, label: self.syncLabel)
            self.recoveryAvailable = false
            self.getCloudVersion(async: true)
            self.checkButtons()
        })
    }
    
    private func resumeGame(_ cell: WelcomeActionCell) {
        // Recover game
        if self.scorecard.recovery.checkRecovery() {
            self.setupButtons(allowRecovery: false)
            self.scorecard.loadGameDefaults()
            self.scorecard.recovery.loadSavedValues()
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
                self.showSelection()
            }
        }
    }
    
    private func newOnlineGame(_ cell: WelcomeActionCell) {
        if self.scorecard.recovery.checkRecovery() {
            // Warn that this is irreversible
            self.warnResumeGame(gameType: "online", okHandler: {
                self.scorecard.recoveryMode = false
                self.onlineGame(cell)
            })
        } else {
            self.onlineGame(cell)
        }
    }
    
    private func onlineGame(_ cell: WelcomeActionCell) {
        if Utility.compareVersions(version1: self.scorecard.settingVersion,
                                   version2: self.scorecard.latestVersion) == .lessThan {
            self.alertMessage("You must upgrade to the latest version of the app to use this option")
        } else if self.scorecard.settingSyncEnabled && (self.scorecard.settingNearbyPlaying || self.scorecard.settingOnlinePlayerEmail != nil) {
            self.joinGame()
        }
    }
    
    private func hostGame() -> Void {
        self.playingComputer = false
        let hostController = HostController(from: self)
        hostController.start(recoveryMode: true, completion: {
            self.getCloudVersion(async: true)
            self.setupButtons()
        })
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
            destination.preferredContentSize = CGSize(width: 400, height: 700)
            
            destination.returnSegue = "hideSettings"
            destination.backImage = "home"
            destination.backText = ""
            
        case "showClient":
            let destination = segue.destination as! ClientViewController
            
            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.isModalInPopover = true
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = welcomeView
            destination.preferredContentSize = CGSize(width: 400, height: 700)
            
            destination.returnSegue = "hideClient"
            destination.backImage = "home"
            destination.backText = ""
            destination.formTitle = self.clientTitle
            destination.commsPurpose = self.clientCommsPurpose
            destination.matchDeviceName = self.clientMatchDeviceName
            
        case "showHighScores":
            let destination = segue.destination as! HighScoresViewController
            
            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = welcomeView
            destination.preferredContentSize = CGSize(width: 400, height: 700)
            
            destination.returnSegue = "hideHighScores"
            destination.backImage = "home"
            destination.backText = ""
            
        case "showPlayers":
            let destination = segue.destination as! PlayersViewController
            destination.detailMode = .amend
            destination.refresh = true
            destination.returnSegue = "hidePlayers"
            destination.backImage = "home"
            destination.backText = ""
            
        case "showGetStarted":
            let destination = segue.destination as! GetStartedViewController
            
            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = welcomeView
            destination.preferredContentSize = CGSize(width: 400, height: 700)
            
        default:
            break
        }
    }
    
    // MARK: - Send email and delegate methods =========================================================== -
    
    func backupDevice() {
        Backup.sendEmail(from: self)
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
    
    private func backgroundShape(view: UIView, shape: Shape, strokeColor: UIColor, fillColor: UIColor, pointType: PolygonPointType = .rounded, lineWidth: CGFloat = 3.0, clipTop: Bool = false, clipBottom: Bool = false, reflected: Bool = false) -> UIBezierPath {
        
        var points: [PolygonPoint] = []
        let shiftTop = (clipTop ? 0.5 : 0) * lineWidth
        let shiftBottom = (clipBottom ? 0.5 : 0) * lineWidth
        let size = view.frame.size
        let width = size.width - 16.0
        let height = size.height
        let arrowWidth = height
        
        // Remove any previous view layers
        view.layer.sublayers?.removeAll()
        
        switch shape {
        case .arrowTop:
            points.append(PolygonPoint(x: 0.0, y: -shiftTop, pointType: .point))
            points.append(PolygonPoint(x: width - (arrowWidth * 1.5), y: -shiftTop, radius: 20.0))
            points.append(PolygonPoint(x: width - (arrowWidth * 0.5), y: height + shiftBottom, pointType: pointType))
            points.append(PolygonPoint(x: 0.0, y: height + shiftBottom, pointType: .point))
        case .arrowBottom:
            points.append(PolygonPoint(x: 0.0, y: -shiftTop, pointType: .point))
            points.append(PolygonPoint(x: 0.0, y: height + shiftBottom, pointType: .point))
            points.append(PolygonPoint(x: width - (arrowWidth * 1.5), y: height + shiftBottom, radius: 20.0))
            points.append(PolygonPoint(x: width - (arrowWidth * 0.5), y: -shiftTop, pointType: pointType))
        case .arrowMiddle, .shortArrowMiddle:
            points.append(PolygonPoint(x: 0.0, y: -shiftTop, pointType: .point))
            points.append(PolygonPoint(x: width - (arrowWidth * (shape == .arrowMiddle ? 0.5 : 1.5)), y: -shiftTop, pointType: pointType, radius: 20.0))
            points.append(PolygonPoint(x: width - (arrowWidth * (shape == .arrowMiddle ? 0.0 : 1.0)), y: (height * 0.5)))
            points.append(PolygonPoint(x: width - (arrowWidth * (shape == .arrowMiddle ? 0.5 : 1.5)), y: height + shiftBottom, pointType: pointType, radius: 20.0))
            points.append(PolygonPoint(x: 0.0, y: height + shiftBottom, pointType: .point))
        }
        
        return Polygon.roundedShapePath(in: view, definedBy: points, strokeColor: strokeColor, fillColor: fillColor, lineWidth: lineWidth, radius: 10.0, transform: (reflected ? .reflectCenterHorizontal : nil))
        
    }
    
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class WelcomeActionCell: ScrollViewCell {
    public var actionTitle: UILabel!
    public var actionShapeView: UIView!
    public var path: UIBezierPath!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    convenience init(frame: CGRect, position: Position, textInset: CGFloat) {
        
        self.init(frame: frame)
        
        self.actionShapeView = UIView(frame: frame)
        self.addSubview(self.actionShapeView)
        
        let titleWidth = self.actionShapeView.frame.width * 0.7
        self.actionTitle = UILabel(frame: CGRect(x: frame.minX + (position == .left ? textInset : frame.width - (textInset + titleWidth)), y: frame.minY, width: titleWidth, height: frame.height))
        self.actionTitle.textAlignment = (position == .left ? .left : .right)
        self.addSubview(self.actionTitle)
        self.bringSubviewToFront(self.actionTitle)
    }
}
