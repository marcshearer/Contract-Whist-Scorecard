    //
//  ScorepadViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 25/11/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

enum ScorepadMode {
    case display
    case amend
}

class ScorepadViewController: UIViewController,
                              UITableViewDataSource, UITableViewDelegate,
                              UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout,
                              HandStatusDelegate {
    
    // MARK: - Class Properties ======================================================================== -
    
    // Main state properties
    var scorecard: Scorecard! = nil
    private var recovery: Recovery!
    
    // Properties to pass state to / from segues
    public var scorepadMode: ScorepadMode!
    public var rounds: Int!
    public var cards: [Int]!
    public var bounce: Bool!
    public var bonus2: Bool!
    public var suits: [Suit]!
    public var returnSegue: String!
    public var parentView: UIView!
    public var rabbitMQService: RabbitMQService!
    public var recoveryMode = false
    public var reviewRound: Int!
    public var computerPlayerDelegate: [Int : ComputerPlayerDelegate?]?
    
    // Cell dimensions
    private let minCellHeight = 30
    private var cellHeight = 0
    private var roundWidth: CGFloat = 0.0
    private var cellWidth = 0
    private var singleColumn = false
    private var narrow = false
    private var imageRowHeight: CGFloat = 0.0
    private var headerHeight: CGFloat = 0.0
    private let combinedTriggerWidth = 80
    
    // Header description variables
    private let showThumbnail = true
    private var headerRows = 0
    private var imageRow = -1
    private var playerRow = -1
    
    // Body description variables
    private var bodyColumns = 0

    // Cell outline weights
    private let thickLineWeight: CGFloat = 2
    private let thinLineWeight: CGFloat = 1
    
    // Local class variables
    private var lastNavBarHeight:CGFloat = 0.0
    private var lastViewHeight:CGFloat = 0.0
    private var firstTimeAppear = true
    private var rotated = false
    private var observer: NSObjectProtocol?
    private var firstGameSummary = true
    
    // UI component pointers
    private var entryThumbnail = [UIImageView?]()
    private var entryDisc = [UILabel?]()
    private var headerCell = [[ScorepadCollectionViewCell?]]()
    private var imageCollectionView: UICollectionView!
    public var roundSummaryViewController: RoundSummaryViewController!
    public var gameSummaryViewController: GameSummaryViewController!
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var headerViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var footerViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var headerTableView: UITableView!
    @IBOutlet private weak var bodyTableView: UITableView!
    @IBOutlet private weak var footerTableView: UITableView!
    @IBOutlet public weak var scorepadView: UIView!
    @IBOutlet private weak var scoreEntryButton: RoundedButton!
    @IBOutlet private weak var finishButton: UIButton!
    @IBOutlet private weak var navigationBar: UINavigationBar!
    @IBOutlet private weak var tapGestureRecognizer: UITapGestureRecognizer!

    // MARK: - IB Unwind Segue Handlers ================================================================ -
 
    @IBAction private func hideLocation(segue:UIStoryboardSegue) {
        var complete = false
                if let segue = segue as? UIStoryboardSegueWithCompletion {
            segue.completion = {
                if let sourceViewController = segue.source as? LocationViewController {
                    if sourceViewController.complete {
                        complete = true
                    }
                }
                if complete {
                    // Resave updated location
                    self.saveLocationAndDate()
                    // Play hand
                    self.scorecard.playHand(from: self, sourceView: self.scorepadView, computerPlayerDelegate: self.computerPlayerDelegate)
                } else {
                    // Exit
                    self.performSegue(withIdentifier: "hideScorepad", sender: self)
                }
            }
        }
    }
    
    @IBAction private func hideEntry(segue:UIStoryboardSegue) {
        _ = scorecard.savePlayers(rounds: self.rounds)
        highlightCurrentDealer(false)
        scorecard.advanceMaximumRound(rounds: self.rounds)
        highlightCurrentDealer(true)
        returnEntry()
    }
    
    @IBAction func hideClientRoundSummary(segue:UIStoryboardSegue) {
        // Only used in client
        roundSummaryViewController = nil
        formatButtons()
    }
    
    @IBAction private func hideGameSummary(segue:UIStoryboardSegue) {
        firstGameSummary=false
        gameSummaryViewController = nil
        returnEntry()
    }
    
    @IBAction private func hideReview(segue:UIStoryboardSegue) {
    }
    
    @IBAction private func newGame(segue:UIStoryboardSegue) {
        // New game started - refresh the screen
        self.recovery.saveInitialValues()
        self.scorecard.setGameInProgress(true)
        self.firstGameSummary = true
        self.headerTableView.reloadData()
        self.bodyTableView.reloadData()
        self.footerTableView.reloadData()
        self.saveNewGame()
        self.formatButtons()
        if self.scorecard.isHosting {
            // Start new game
            self.playHand(setState: true)
        } else {
            // Re-send players to sharing device to trigger new game
            self.scorecard.sendPlay(rounds: self.rounds, cards: self.cards, bounce: self.bounce, bonus2: self.bonus2, suits: self.suits)
        }
    }
    
    @IBAction private func linkGameSummary(segue:UIStoryboardSegue) {
        if let segue = segue as? UIStoryboardSegueWithCompletion {
            segue.completion = {
                _ = self.scorecard.savePlayers(rounds: self.rounds)
                self.scorecard.sendScores()
                self.performSegue(withIdentifier: "showGameSummary", sender: self)
            }
        }
        formatButtons()
    }
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction internal func scorePressed(_ sender: Any) {
        if scorepadMode == .amend {
            makeEntry(true)
        } else if self.scorecard.isHosting || self.scorecard.hasJoined {
            if scorecard.gameComplete(rounds: self.rounds) {
                // Online game complete - go to game summary
                self.performSegue(withIdentifier: "showGameSummary", sender: self)
            } else {
                // Online game in progress - go back to hand
                self.playHand()
            }
        } else if self.scorecard.isViewing {
            if scorecard.gameComplete(rounds: self.rounds) {
                // Online game complete - go to game summary
                self.performSegue(withIdentifier: "showGameSummary", sender: self)
            }
        }
    }
    
    @IBAction private func finishGamePressed(_ sender: Any) {
        NotificationCenter.default.removeObserver(self.observer!)
        if scorepadMode == .amend || self.scorecard.isHosting {
            scorecard.finishGame(from: self, toSegue: returnSegue, rounds: self.rounds, resetOverrides: true, completion: tidyUp)
        } else if self.scorecard.hasJoined {
            self.alertDecision("Warning: This will mean you exit from the game. You can rejoin by selecting the 'Join a Game' option from 'Online Game' in the Home menu", okButtonText: "Exit",
                okHandler: {
                self.performSegue(withIdentifier: self.returnSegue, sender: self)
            })
        } else {
            tidyUp()
            self.performSegue(withIdentifier: returnSegue, sender: self)
        }
    }
    
    @IBAction private func tapGesture(recognizer: UITapGestureRecognizer) {
        if scorepadMode != .amend {
            if self.scorecard.isHosting || self.scorecard.hasJoined {
                // Online game in progress - go back to hand
                if !self.scorecard.handState.finished && self.scorecard.handState.hand != nil {
                    self.playHand()
                }
            } else {
                // Popup the round summary unless we have a made for the current round or we haven't got any bids yet
                if self.scorecard.roundStarted(self.scorecard.maxEnteredRound) &&
                        !self.scorecard.roundMadeStarted(self.scorecard.maxEnteredRound) {
                    self.performSegue(withIdentifier: "showClientRoundSummary", sender: self)
                } else if scorecard.gameComplete(rounds: self.rounds) {
                    self.performSegue(withIdentifier: "showGameSummary", sender: self)
                }
            }
        }
    }
    
    @IBAction private func rightSwipe(recognizer:UISwipeGestureRecognizer) {
        if scorepadMode == .amend {
            if recognizer.state == .ended && !finishButton.isHidden && finishButton.isEnabled {
                finishGamePressed(self.finishButton)
            }
        }
    }
    
    @IBAction private func leftSwipe(recognizer:UISwipeGestureRecognizer) {
        if scorepadMode == .amend {
            if recognizer.state == .ended {
                self.scorePressed(scoreEntryButton)
            }
        }
    }
    
    // MARK: - View Overrides ========================================================================== -
    
    override internal func viewDidLoad() {
        super.viewDidLoad()
        
        // Set flag to show that sharing available
        scorecard.inScorepad = true
        
        // Link to recovery class
        recovery = scorecard.recovery

        // Set up label pointers
        for _ in 1...scorecard.currentPlayers {
            entryThumbnail.append(UIImageView())
            entryDisc.append(UILabel())
            headerCell.append(Array(repeating: nil, count: 4)) // Maximum of 4 rows in header
        }
        
        // Set nofification for image download
        observer = setImageDownloadNotification()
        
        // Don't sleep
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override internal func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if firstTimeAppear {
            firstTimeAppear = false
            // Link to location
            if (scorepadMode == .amend || self.scorecard.isHosting) && self.scorecard.settingSaveLocation &&
                (self.scorecard.gameLocation == nil || self.scorecard.gameLocation.description == nil || self.scorecard.gameLocation.description == "" ||
                    (self.scorecard.selectedRound == 1 &&
                        !self.scorecard.roundStarted(self.scorecard.selectedRound))) {
                self.getLocation()
            } else {
                
                self.saveNewGame()
                self.playHand(setState: true, recoveryMode: recoveryMode)
            }
        }

        if scorepadMode != .amend {
            headerTableView.isUserInteractionEnabled = false
            footerTableView.isUserInteractionEnabled = false
            tapGestureRecognizer.isEnabled = false
        } else {
            tapGestureRecognizer.isEnabled = false
        }
        formatButtons()
        
        if self.scorecard.commsHandlerMode == .scorepad {
            // Notify client controller that scorepad display complete
            self.scorecard.commsHandlerMode = .none
            NotificationCenter.default.post(name: .clientHandlerCompleted, object: self, userInfo: nil)
        }
        self.view.setNeedsLayout()
    }
    
    override internal func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { (context) in
            self.view.setNeedsLayout()
            self.headerTableView.reloadData()
            self.bodyTableView.reloadData()
            self.footerTableView.reloadData()
            self.rotated = true
        }, completion: nil)
    }
    
    override internal func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if lastNavBarHeight != navigationBar.frame.height || lastViewHeight != scorepadView.frame.height {
            setupSize(to: scorepadView.safeAreaLayoutGuide.layoutFrame.size)
            self.headerTableView.reloadData()
            self.bodyTableView.reloadData()
            self.footerTableView.reloadData()
            lastNavBarHeight = navigationBar.frame.height
            lastViewHeight = scorepadView.frame.height
        }
    }
    
    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        self.scorecard.motionBegan(motion, with: event)
    }
    
    // MARK: - TableView Overrides ===================================================================== -

    internal func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height: CGFloat = 0.0
        
        switch tableView.tag {
        case 1:
            // Header
            switch indexPath.row {
            case imageRow:
                height = imageRowHeight
            default:
                height = headerHeight - imageRowHeight
            }
        default:
            // Body and footer
            height = CGFloat(cellHeight)
        }
        return height
    }
    
    internal func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        var rows = 0
        
        switch tableView.tag {
        case 1:
            // Header
            rows = headerRows
        case 2:
            // Body contains a row for each round
            rows = self.rounds
        default:
            // Footer
            rows = 1
        }
        return rows
    }
    
    internal func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell: UITableViewCell
        
        switch tableView.tag {
        case 1:
            // Header
            cell = tableView.dequeueReusableCell(withIdentifier: "Header Table Cell", for: indexPath)
        case 2:
            // Body
            cell = tableView.dequeueReusableCell(withIdentifier: "Body Table Cell", for: indexPath)
        default:
            // Footer
            cell = tableView.dequeueReusableCell(withIdentifier: "Footer Table Cell", for: indexPath)
        }
        
        return cell
    }
    
    internal func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath)
    {
        
        switch tableView.tag {
        case 1:
            // Header
            guard let tableViewCell = cell as? ScorepadTableViewCell else { return }
            tableViewCell.setCollectionViewDataSourceDelegate(self, forRow: indexPath.row + 1000000)
            if indexPath.row == imageRow {
                imageCollectionView = tableViewCell.scorepadCollectionView
            }
        case 2:
            // Body
            guard let tableViewCell = cell as? ScorepadTableViewCell else { return }
            tableViewCell.setCollectionViewDataSourceDelegate(self, forRow: indexPath.row)
        default:
            // Footer
            guard let tableViewCell = cell as? ScorepadTableViewCell else { return }
            tableViewCell.setCollectionViewDataSourceDelegate(self, forRow: indexPath.row + 2000000)
        }
    }
    
    // MARK: - Image download handlers =================================================== -
    
    private func setImageDownloadNotification() -> NSObjectProtocol? {
        // Set a notification for images downloaded
        let observer = NotificationCenter.default.addObserver(forName: .playerImageDownloaded, object: nil, queue: nil) {
            (notification) in
            self.updateImage(objectID: notification.userInfo?["playerObjectID"] as! NSManagedObjectID)
        }
        return observer
    }
    
    private func updateImage(objectID: NSManagedObjectID) {
        // Find any cells containing an image which has just been downloaded asynchronously
        Utility.mainThread {
            let index = self.scorecard.scorecardIndex(objectID)
            if index != nil {
                // Found it - reload the cell
                self.imageCollectionView.reloadItems(at: [IndexPath(row: index!+1, section: 0)])
            }
        }
    }
    
    // MARK: - Form Presentation / Handling Routines =================================================== -
    
    private func setupSize(to size: CGSize) {
        
        // Calculate columns
        
        // Set cell widths
        roundWidth = round(size.width > CGFloat(600) ? size.width / CGFloat(10) : 60)
        cellWidth = Int(round((size.width - roundWidth) / (CGFloat(2.0) * CGFloat(scorecard.currentPlayers))))
        
        if cellWidth <= combinedTriggerWidth {
            cellWidth *= 2
            bodyColumns = 1
            narrow = true
            imageRowHeight = 50.0
        } else {
            bodyColumns = 2
            narrow = false
            imageRowHeight = 84.0
        }
        
        roundWidth = size.width - CGFloat(bodyColumns * scorecard.currentPlayers * cellWidth)
        
        // work out what appears in which header row
        imageRow = -1
        playerRow = -1
        headerRows = 0
        headerHeight =  0.0
        
        if showThumbnail {
            headerHeight += imageRowHeight
            imageRow = headerRows
            headerRows += 1
        }
        
       
        playerRow = headerRows
        headerRows += 1
        
        // Note headerHeight does not include the player name row since we haven't
        // worked this out yet
        
        var floatCellHeight: CGFloat = (size.height - imageRowHeight - navigationBar.frame.height) / CGFloat(self.rounds+2) // Adding 2 for name row in header and total row
        floatCellHeight.round()
        
        cellHeight = Int(floatCellHeight)
        
        if cellHeight < minCellHeight {
            cellHeight = minCellHeight
            headerHeight += CGFloat(cellHeight)
        } else {
            headerHeight = size.height - CGFloat((self.rounds+1) * cellHeight) - navigationBar.frame.height
            imageRowHeight = headerHeight - CGFloat(cellHeight)
        }
        
        headerViewHeightConstraint.constant = headerHeight
        footerViewHeightConstraint.constant = CGFloat(cellHeight)

        scorecard.saveHeaderHeight(headerHeight + navigationBar.frame.height)
        
        // If moving to 1 column clear out stored bid cell pointers
        if bodyColumns == 1 {
            for playerNumber in 1...scorecard.currentPlayers {
                for round in 1...self.rounds {
                    scorecard.scorecardPlayer(playerNumber).setBidCell(round, cell: nil)
                }
            }
        }
    }
    
    private func makeEntry(_ fromButton: Bool = false) {
        if scorepadMode == .amend {
            if scorecard.gameComplete(rounds: self.rounds) && fromButton {
                self.performSegue(withIdentifier: "showGameSummary", sender: self)
            } else {
                self.performSegue(withIdentifier: "showEntry", sender: self)
            }
            rotated = false
        }
    }
    
    private func returnEntry() {
        if rotated {
            headerTableView.reloadData()
            bodyTableView.reloadData()
            footerTableView.reloadData()
        }
        formatButtons()
    }
    
    public func highlightCurrentDealer(_ highlight: Bool) {
        if headerRows > 0 {
            for row in 0...headerRows-1 {
                let headerCell = self.headerCell[scorecard.isScorecardDealer()-1][row]!
                highlightDealer(headerCell: headerCell, playerNumber: scorecard.isScorecardDealer(), row: row, forceClear: !highlight)
            }
        }
    }
    
    private func highlightDealer(headerCell: ScorepadCollectionViewCell, playerNumber: Int, row: Int, forceClear: Bool = false) {
        if playerNumber >= 0 {
            if scorecard.isScorecardDealer() == playerNumber && !forceClear {
                ScorecardUI.totalStyleView(headerCell)
            } else {
                ScorecardUI.emphasisStyleView(headerCell)
            }
        }
    }
    
    public func reloadScorepad() {
        self.headerTableView.reloadData()
        self.bodyTableView.reloadData()
        self.footerTableView.reloadData()
    }

    private func formatButtons() {
        scoreEntryButton.isHidden = true
        
        if scorecard.gameComplete(rounds: self.rounds) {
            // Game complete - allow return to game summary
            scoreEntryButton.setTitle("Scores")
            scoreEntryButton.isHidden = false
            
        } else if scorepadMode == .amend {
            // Amend mode - enter score
            scoreEntryButton.setTitle("Continue")
            scoreEntryButton.isHidden = false
            
        } else if self.scorecard.isHosting {
            // Hosting a shared game
            if self.scorecard.handState != nil && self.scorecard.handState.finished {
                scoreEntryButton.setTitle("Deal")
            } else {
                scoreEntryButton.setTitle("Play")
            }
            scoreEntryButton.isHidden = false
            
        } else if self.scorecard.hasJoined {
            // Joined a shared game
            if !self.scorecard.handState.finished && self.scorecard.handState.hand != nil && self.scorecard.handState.hand.cards.count != 0 {
                scoreEntryButton.setTitle("Play")
                scoreEntryButton.isHidden = false
            }
            
        } else if self.scorecard.isViewing {
            // Viewing a game
            scoreEntryButton.isHidden = true
        }
        
        if self.scorecard.isHosting || self.scorecard.hasJoined {
            if scorecard.gameComplete(rounds: self.rounds) {
                finishButton.isHidden = true
            } else {
                finishButton.setTitle("Exit", for: .normal)
            }
        } else {
            if self.scorecard.gameInProgress {
                finishButton.setTitle("Exit", for: .normal)
            } else {
                finishButton.setTitle("Back", for: .normal)
            }
        }
    }
    
    // MARK: - Utility Routines ======================================================================== -
    
    private func getLocation() {
        if self.scorecard.isHosting && self.scorecard.commsDelegate?.connectionProximity == .online {
            // Online - location not appropriate
            self.scorecard.gameLocation.description = "Online"
            self.scorecard.gameLocation = GameLocation()
            self.saveNewGame()
            self.playHand(setState: true)
        } else {
            // Prompt for location
            Utility.mainThread {
                // Get the other hands started
                self.saveNewGame()
                self.playHand(setState: true, show: false)
                // Link to location view
                self.performSegue(withIdentifier: "showLocation", sender: self)
            }
        }
    }
    
    public func returnToCaller() {
        // Called from another view controller to return control
        tidyUp()
        self.performSegue(withIdentifier: returnSegue, sender: self)
    }
    
    private func saveNewGame() {
        if !self.scorecard.hasJoined && !self.scorecard.isViewing {
            self.scorecard.gameDatePlayed = Date()
            self.scorecard.gameUUID = UUID().uuidString
            self.saveLocationAndDate()
            self.recovery.saveOverride()
        }
    }
    
    private func saveLocationAndDate() {
         self.recovery.saveLocationAndDate()
    }
    
    private func tidyUp() {
        // Tidy up before exiting
        self.scorecard.scorepadHeaderHeight = 0
        scorecard.inScorepad = false
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    private func playHand(setState: Bool = false, recoveryMode: Bool = false, show: Bool = true) {
        // Send players if hosting or sharing
        if self.scorecard.isHosting {
            self.scorecard.setGameInProgress(true)
            if setState {
                // Need to set hand state
                self.scorecard.handState = HandState(enteredPlayerNumber: 1, round: self.scorecard.maxEnteredRound, dealerIs: self.scorecard.dealerIs, players: self.scorecard.currentPlayers, rounds: self.rounds, cards: self.cards, bounce: self.bounce, bonus2: self.bonus2, suits: self.suits)
                if recoveryMode && self.scorecard.deal != nil {
                    // Hand has been recovered - Check if finished
                    var finished = true
                    for hand in self.scorecard.deal.hands {
                        if hand.cards.count != 0 {
                            finished = false
                        }
                    }
                    if finished {
                        self.scorecard.handState.hand = nil
                    } else {
                        self.scorecard.handState.hand = self.scorecard.deal.hands[0]
                    }
                }
                self.scorecard.sendPlay(rounds: self.rounds, cards: self.cards, bounce: self.bounce, bonus2: self.bonus2, suits: self.suits)
            } else if scorecard.handState.finished {
                // Clear last hand
                scorecard.handState.hand = nil
            }
        }
        self.scorecard.setGameInProgress(true)
        self.scorecard.dealHand()
        if show {
            self.scorecard.playHand(from: self, sourceView: self.scorepadView, computerPlayerDelegate: self.computerPlayerDelegate)
        }
        if setState {
            // Bids already entered - resend all scores
            self.scorecard.sendScores()
            if recoveryMode && self.scorecard.isHosting {
                // Recovering - resend hand state to other players
                self.recovery.loadCurrentTrick()
                self.recovery.loadLastTrick()
                self.scorecard.sendHandState()
            }
        }
    }
    
    public func handComplete() {
        self.scorecard.handViewController = nil
        self.formatButtons()
        if self.scorecard.handState.finished {
            if self.scorecard.gameComplete(rounds: self.rounds) {
                // Game complete
                if self.scorecard.isHosting {
                    _ = self.scorecard.savePlayers(rounds: self.rounds)
                }
                self.performSegue(withIdentifier: "showGameSummary", sender: self)
            } else if self.scorecard.handState.round != self.rounds {
                // Reset state and prepare for next round
                self.highlightCurrentDealer(false)
                self.scorecard.handState.round += 1
                self.scorecard.selectedRound = self.scorecard.handState.round
                self.scorecard.maxEnteredRound = self.scorecard.handState.round
                self.highlightCurrentDealer(true)
                self.scorecard.handState.reset()
                self.autoDeal()
            }
        }
    }
    
    // MARK: - Segue Prepare Handler =================================================================== -
    override internal func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        
        switch segue.identifier! {
            
        case "showEntry":
            
            notAllowedInDisplay()
            let destination = segue.destination as! EntryViewController

            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = scorepadView
            destination.preferredContentSize = CGSize(width: 400, height: 554)

            destination.scorecard = self.scorecard
            destination.rounds = self.rounds
            destination.cards = self.cards
            destination.bounce = self.bounce
            destination.bonus2 = self.bonus2
            destination.suits = self.suits
            destination.reeditMode = scorecard.roundPlayer(playerNumber: scorecard.currentPlayers, round: scorecard.selectedRound).score(scorecard.selectedRound) != nil ? true : false
            
        case "showClientRoundSummary":
            
            roundSummaryViewController  = segue.destination as? RoundSummaryViewController

            roundSummaryViewController.modalPresentationStyle = UIModalPresentationStyle.popover
            roundSummaryViewController.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            roundSummaryViewController.popoverPresentationController?.sourceView = scorepadView
            roundSummaryViewController.preferredContentSize = CGSize(width: 400, height: 554)

            roundSummaryViewController.returnSegue = "hideClientRoundSummary"
            roundSummaryViewController.scorecard = self.scorecard
            roundSummaryViewController.rounds = self.rounds
            roundSummaryViewController.cards = self.cards
            roundSummaryViewController.bounce = self.bounce
            roundSummaryViewController.suits = self.suits
            
        case "showGameSummary":
            
            gameSummaryViewController = segue.destination as? GameSummaryViewController

            gameSummaryViewController.modalPresentationStyle = UIModalPresentationStyle.popover
            gameSummaryViewController.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            gameSummaryViewController.popoverPresentationController?.sourceView = scorepadView

            gameSummaryViewController.preferredContentSize = CGSize(width: 400, height: 554)
            gameSummaryViewController.scorecard = self.scorecard
            gameSummaryViewController.firstGameSummary = self.firstGameSummary
            gameSummaryViewController.gameSummaryMode = (self.scorecard.isHosting ? .amend : self.scorepadMode)
            gameSummaryViewController.rounds = self.rounds
            NotificationCenter.default.removeObserver(observer!)
            
        case "showLocation":
            
            let destination = segue.destination as! LocationViewController

            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.isModalInPopover = true
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = scorepadView
            destination.preferredContentSize = CGSize(width: 400, height: 600)

            destination.gameLocation = self.scorecard.gameLocation
            destination.scorecard = self.scorecard
            destination.returnSegue = "hideLocation"
            destination.useCurrentLocation = true
            
        case "showReview":
            
            let destination = segue.destination as! ReviewViewController
  
            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = scorepadView
            destination.preferredContentSize = CGSize(width: 400, height: 554)
  
            destination.scorecard = self.scorecard
            destination.round = self.reviewRound
            destination.thisPlayer = self.scorecard.handState.enteredPlayerNumber
            
        default:
            break
        }
    }
    
    func notAllowedInDisplay() {
        if scorepadMode != .amend {
            // Shouldn't ever invoke this from display mode
            Utility.getActiveViewController()?.alertMessage("Unexpected action in scorepad display mode", title: "Error", okHandler: {
                self.dismiss(animated: true, completion: nil)
            })
        }
    }

    // MARK: - CollectionView Overrides ================================================================ -

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        if collectionView.tag >= 1000000
        {
            return scorecard.currentPlayers + 1
        }
        else
        {
            return (scorecard.currentPlayers * bodyColumns) + 1
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let totalHeight: CGFloat = collectionView.bounds.size.height
        var width: CGFloat = 0.0
        let column = indexPath.row
        var headerCollection =  false
        var footerCollection = false
        
        if collectionView.tag >= 2000000 {
            footerCollection = true
        } else if collectionView.tag >= 1000000 {
            headerCollection = true
        }
        
        if headerCollection || footerCollection
        {
            if column == 0
            {
                width = roundWidth
            }
            else
            {
                width = CGFloat(cellWidth * bodyColumns)
            }
        }
        else
        {
            if column == 0
            {
                width = roundWidth
            }
            else
            {
                width = CGFloat(cellWidth)
            }
        }
        return CGSize(width: width, height: totalHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        var headerCell: ScorepadCollectionViewCell
        var footerCell: ScorepadCollectionViewCell
        var bodyCell: ScorepadCollectionViewCell
        var cell: UICollectionViewCell
        var column = 0
        let row = collectionView.tag % 1000000
        let round = row + 1
        var headerCollection =  false
        var footerCollection = false
        var player = 0
        var reuseIdentifier = ""
        column = indexPath.row
        var topLine = true
        
        if collectionView.tag >= 2000000 {
            footerCollection = true
        } else if collectionView.tag >= 1000000 {
            headerCollection = true
        }
        
        if headerCollection {
            
            // Header
            
            if (row == imageRow || row == playerRow) && column != 0 {
                // Thumbnail and/or name
                 player = column
                
                let playerDetail = scorecard.scorecardPlayer(player).playerMO
                
                if row == imageRow {
                    // Thumbnail cell
                    reuseIdentifier = "Header Collection Image Cell"
                } else {
                    reuseIdentifier = "Header Collection Cell"
                    topLine = false
                }
                
                headerCell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier,for: indexPath)   as! ScorepadCollectionViewCell
                ScorecardUI.emphasisStyleView(headerCell)
                
                if row != playerRow {
                    
                    // Setup the thumbnail picture / disc
                    if playerDetail != nil {
                        Utility.setThumbnail(data: playerDetail!.thumbnail,
                                             imageView: headerCell.scorepadImage,
                                             initials: playerDetail!.name!,
                                             label: headerCell.scorepadDisc)
                        ScorecardUI.veryRoundCorners(headerCell.scorepadImage, radius: (imageRowHeight-9)/2)
                        ScorecardUI.veryRoundCorners(headerCell.scorepadDisc, radius: (imageRowHeight-9)/2)
                        entryThumbnail[column-1] = headerCell.scorepadImage
                        entryDisc[column-1] = headerCell.scorepadDisc
                        headerCell.scorepadDiscHeight.constant = 10000 // Force resize
                    }
                }
                
                headerCell.scorepadTopLineWeight.constant = (row == 0 || !topLine ? 0 : thickLineWeight)
                headerCell.scorepadLeftLineWeight.constant = thickLineWeight
       
                if row == playerRow {
                    // Setup the name
                    headerCell.scorepadCellLabel.text = scorecard.scorecardPlayer(player).playerMO!.name!
                }
            } else {
                headerCell = collectionView.dequeueReusableCell(withReuseIdentifier: "Header Collection Cell",for: indexPath) as! ScorepadCollectionViewCell
                
                ScorecardUI.emphasisStyleView(headerCell)
                
                if column == 0 {
                    // Row titles
                    switch row {
                    case imageRow:
                        headerCell.scorepadCellLabel.text=""
                    case playerRow:
                        headerCell.scorepadCellLabel.text="Player"
                    default:
                        break
                    }
                    headerCell.scorepadLeftLineWeight.constant = 0
                    headerCell.scorepadCellLabel.numberOfLines = 1
                } else {
                    // Row values
                    player = column
                    
                    headerCell.scorepadLeftLineWeight.constant = thickLineWeight
                }
                
                headerCell.scorepadCellLabel.textColor = UIColor.white
                headerCell.scorepadTopLineWeight.constant =
                    (row == 0 || (row == playerRow && imageRowHeight != 0) ? 0 : thickLineWeight)
            }
            
            if row != imageRow {
                if narrow {
                    headerCell.scorepadCellLabel.font = UIFont.systemFont(ofSize: 20.0)
                } else {
                    headerCell.scorepadCellLabel.font = UIFont.systemFont(ofSize: 26.0)
                }
            }
            
            highlightDealer(headerCell: headerCell, playerNumber: column, row: row)
            if player > 0 {
                self.headerCell[player-1][row] = headerCell
            }
            
            cell=headerCell
            
        } else if footerCollection {
            
            // Footer
            
            footerCell = collectionView.dequeueReusableCell(withReuseIdentifier: "Footer Collection Cell",for: indexPath) as! ScorepadCollectionViewCell
        
            ScorecardUI.totalStyleView(footerCell)
            
            if column == 0 {
                // Row titles
                footerCell.scorepadCellLabel.text="Total"
                footerCell.scorepadLeftLineWeight.constant = 0
                footerCell.scorepadCellLabel.numberOfLines = 1
                footerCell.scorepadCellLabel.accessibilityIdentifier = ""
            } else {
                // Row values
                player = column
                footerCell.scorepadCellLabel.text = "\(scorecard.scorecardPlayer(player).totalScore())"
                footerCell.scorepadLeftLineWeight.constant = thickLineWeight
                scorecard.scorecardPlayer(player).setTotalLabel(label: footerCell.scorepadCellLabel)
                footerCell.scorepadCellLabel.accessibilityIdentifier = "player\(indexPath.row)total"
            }
            
            footerCell.scorepadCellLabel.textColor = UIColor.white
            footerCell.scorepadTopLineWeight.constant = thickLineWeight
        
            if narrow {
                footerCell.scorepadCellLabel.font = UIFont.systemFont(ofSize: (column == 0 ? 20.0 : 26.0))
            } else {
                footerCell.scorepadCellLabel.font = UIFont.systemFont(ofSize: (column == 0 ? 26.0 : 36.0))
            }
           
            cell=footerCell
            
        } else {
            
            // Body
            
            if column == 0 || (column % 2 == 1 && bodyColumns == 2) {
                reuseIdentifier = "Body Collection Text Cell"
            } else {
                reuseIdentifier = "Body Collection Image Cell"
            }
            
            bodyCell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! ScorepadCollectionViewCell
            if column == 0
            {
                ScorecardUI.emphasisStyle(bodyCell.scorepadCellLabel)
                bodyCell.scorepadCellLabel.attributedText = scorecard.roundTitle(round, rankColor: UIColor.white, rounds: self.rounds, cards: self.cards, bounce: self.bounce)
                bodyCell.scorepadLeftLineWeight.constant = 0
                bodyCell.scorepadCellLabel.accessibilityIdentifier = ""
            } else {
                player = ((column - 1) / bodyColumns) + 1
                if column % 2 == 1 && bodyColumns == 2 {
                    // Bid
                    let bid: Int? = scorecard.scorecardPlayer(player).bid(round)
                    bodyCell.scorepadCellLabel.text = bid != nil ? "\(bid!)" : ""
                    scorecard.scorecardPlayer(player).setBidCell(round, cell: bodyCell)
                    bodyCell.scorepadLeftLineWeight.constant = thickLineWeight
                    scorecard.formatCell(round: round, playerNumber: player, mode: Mode.bid)
                    bodyCell.scorepadCellLabel.accessibilityIdentifier = ""
                } else {
                    // Score
                    let score: Int? = scorecard.scorecardPlayer(player).score(round)
                    bodyCell.scorepadCellLabel.text = score != nil ? "\(score!)" : ""
                    scorecard.scorecardPlayer(player).setScoreCell(round, cell: bodyCell)
                    bodyCell.scorepadLeftLineWeight.constant = (bodyColumns == 2 ? thinLineWeight : thickLineWeight)
                    scorecard.formatCell(round: round, playerNumber: player, mode: Mode.made)
                    bodyCell.scorepadCellLabel.accessibilityIdentifier = "player\(player)round\(round)"
                }
                bodyCell.scorepadCellLabel.textColor = UIColor.black
            }
            bodyCell.scorepadTopLineWeight.constant = thickLineWeight
            if narrow {
                bodyCell.scorepadCellLabel.font = UIFont.systemFont(ofSize: 20.0)
            } else {
                bodyCell.scorepadCellLabel.font = UIFont.systemFont(ofSize: 26.0)
            }
            
            cell=bodyCell
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if self.scorepadMode == .amend {
            return true
        } else {
            if collectionView.tag < 1000000 {
                let round = collectionView.tag + 1
                if (self.scorecard.isHosting || self.scorecard.hasJoined) && self.scorecard.dealHistory[round] != nil && (round < self.scorecard.handState.round || (round == self.scorecard.handState.round && self.scorecard.handState.finished)) {
                    return true
                } else {
                    return false
                }
            } else {
                return false
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView.tag >= 1000000 {
            // Header row tapped - edit last row
            self.scorecard.selectedRound = scorecard.maxEnteredRound
        } else {
            // Body row tapped
            let round = collectionView.tag+1
            if self.scorepadMode == .amend {
                if round >= scorecard.maxEnteredRound {
                    // Row which is not yet entered tapped - edit last row
                    self.scorecard.selectedRound = scorecard.maxEnteredRound
                  } else {
                    self.scorecard.selectedRound = round
                }
            } else if self.scorecard.isHosting || self.scorecard.hasJoined { 
                self.reviewRound = round
                self.performSegue(withIdentifier: "showReview", sender: self)
            }
        }
        makeEntry()
    }
    
    func collectionView(_ collectionView: UICollectionView, willRotatetoInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        collectionView.collectionViewLayout.invalidateLayout()
        self.view.setNeedsDisplay()
    }
}


// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class ScorepadTableViewCell: UITableViewCell {
    
    @IBOutlet weak var scorepadCollectionView: UICollectionView!
    
    func setCollectionViewDataSourceDelegate
        <D: UICollectionViewDataSource & UICollectionViewDelegate>
        (_ dataSourceDelegate: D, forRow row: Int) {
        
        scorepadCollectionView.delegate = dataSourceDelegate
        scorepadCollectionView.dataSource = dataSourceDelegate
        scorepadCollectionView.tag = row
        if row < 1000000 {
            scorepadCollectionView.accessibilityIdentifier = "round\(row+1)"
        } else if row < 2000000 {
            scorepadCollectionView.accessibilityIdentifier = "header\(row+1)"
        } else {
            scorepadCollectionView.accessibilityIdentifier = "total"
        }
        scorepadCollectionView.reloadData()
    }
    
}

class ScorepadCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var scorepadCellLabel: UILabel!
    @IBOutlet weak var scorepadLeftLineWeight: NSLayoutConstraint!
    @IBOutlet weak var scorepadTopLineWeight: NSLayoutConstraint!
    @IBOutlet weak var scorepadImage: UIImageView!
    @IBOutlet weak var scorepadDisc: UILabel!
    @IBOutlet weak var scorepadDiscHeight: NSLayoutConstraint!
}


// MARK: - Enumerations ============================================================================ -

enum CellType {
    case bid
    case score
}

