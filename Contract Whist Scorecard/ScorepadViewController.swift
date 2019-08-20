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
    
class ScorepadViewController: CustomViewController,
                              UITableViewDataSource, UITableViewDelegate,
                              UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout,
                              HandStatusDelegate {
    
    // MARK: - Class Properties ======================================================================== -
    
    // Main state properties
    internal let scorecard = Scorecard.shared
    private var recovery: Recovery!
    
    // Properties to pass state
    public var scorepadMode: ScorepadMode!
    public var rounds: Int!
    public var cards: [Int]!
    public var bounce: Bool!
    public var bonus2: Bool!
    public var suits: [Suit]!
    public var parentView: UIView!
    public var rabbitMQService: RabbitMQService!
    public var recoveryMode = false
    public var computerPlayerDelegate: [Int : ComputerPlayerDelegate?]?
    public var completion: ((Bool)->())? = nil
    
    // Cell dimensions
    private let minCellHeight: CGFloat = 30
    private var cellHeight: CGFloat = 0
    private var roundWidth: CGFloat = 0.0
    private var cellWidth: CGFloat = 0.0
    private var singleColumn = false
    private var narrow = false
    private var imageRowHeight: CGFloat = 0.0
    private var headerHeight: CGFloat = 0.0
    private var bannerContinuationHeight: CGFloat = 10.0
    private let combinedTriggerWidth: CGFloat = 80.0
    private var scoresHeight: CGFloat = 0.0
    
    // Gradients
    let imageGradient: [(alpha: CGFloat, location: CGFloat)] =  [(0.0, 0.0), (0.0, 0.5), (0.8, 1.0)]
    let playerGradient: [(alpha: CGFloat, location: CGFloat)] = [(0.8, 0.0), (1.0, 0.5), (1.0, 1.0)]
    
    // Header description variables
    private let showThumbnail = true
    private var headerRows = 0
    private var imageRow = -1
    private var playerRow = -1
    
    // Body description variables
    private var bodyColumns = 0

    // Cell outline weights
    private let thickLineWeight: CGFloat = 3.0
    private let thinLineWeight: CGFloat = 1.0
    
    // Local class variables
    private var entryViewController: EntryViewController!
    private var lastNavBarHeight:CGFloat = 0.0
    private var lastViewHeight:CGFloat = 0.0
    private var firstTimeAppear = true
    private var rotated = false
    private var observer: NSObjectProtocol?
    private var firstGameSummary = true
    private var paddingGradientLayer: [CAGradientLayer] = []
    public let transition = FadeAnimator()
    
    // UI component pointers
    private var imageCollectionView: UICollectionView!
    public var roundSummaryViewController: RoundSummaryViewController!
    public var gameSummaryViewController: GameSummaryViewController!
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var bannerContinuationHeightConstraint: NSLayoutConstraint!
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
    @IBOutlet private var paddingViewLines: [UIView]!
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction internal func scorePressed(_ sender: Any) {
        if scorepadMode == .amend {
            makeEntry(true)
        } else if self.scorecard.isHosting || self.scorecard.hasJoined {
            if scorecard.gameComplete(rounds: self.rounds) {
                // Online game complete - go to game summary
                self.showGameSummary()
            } else {
                // Online game in progress - go back to hand
                self.playHand()
            }
        } else if self.scorecard.isViewing {
            if scorecard.gameComplete(rounds: self.rounds) {
                // Online game complete - go to game summary
                self.showGameSummary()
            }
        }
    }
    
    @IBAction private func finishGamePressed(_ sender: Any) {
        NotificationCenter.default.removeObserver(self.observer!)
        if scorepadMode == .amend || self.scorecard.isHosting {
            scorecard.finishGame(from: self, rounds: self.rounds, resetOverrides: true, completion: {
                self.tidyUp()
                self.completion?(false)
            })
        } else  {
            self.alertDecision(if: self.scorecard.hasJoined, "Warning: This will mean you exit from the game. You can rejoin by selecting the 'Play Game' option in the Home menu", okButtonText: "Exit",
                okHandler: {
                    self.tidyUp()
                    self.dismiss()
                })
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
                    self.showRoundSummary()
                } else if scorecard.gameComplete(rounds: self.rounds) {
                    self.showGameSummary()
                }
            }
        }
    }
    
    @IBAction private func rightSwipe(recognizer:UISwipeGestureRecognizer) {
        if scorepadMode == .amend {
            if recognizer.state == .ended && !finishButton.isHidden && finishButton.isEnabled {
                finishGamePressed(self.finishButton!)
            }
        }
    }
    
    @IBAction private func leftSwipe(recognizer:UISwipeGestureRecognizer) {
        if scorepadMode == .amend {
            if recognizer.state == .ended {
                self.scorePressed(scoreEntryButton!)
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
            if (scorepadMode == .amend || self.scorecard.isHosting) && !self.scorecard.isPlayingComputer && self.scorecard.settingSaveLocation &&
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
        self.view.setNeedsLayout()
        self.rotated = true
    }
    
    override internal func viewDidLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if lastNavBarHeight != navigationBar.frame.height || lastViewHeight != scorepadView.frame.height {
            setupSize(to: scorepadView.safeAreaLayoutGuide.layoutFrame.size)
            self.headerTableView.layoutIfNeeded()
            self.headerTableView.reloadData()
            self.bodyTableView.reloadData()
            self.footerTableView.reloadData()
            lastNavBarHeight = navigationBar.frame.height
            lastViewHeight = scorepadView.frame.height
            self.setupBorders()
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
                height = headerHeight - imageRowHeight - bannerContinuationHeight
            }
        case 2:
            // Body
            height = CGFloat(cellHeight)
        default:
            // Footer
            height = CGFloat(cellHeight + self.view.safeAreaInsets.bottom)
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
        cellWidth = CGFloat(Int(round((size.width - roundWidth) / (CGFloat(2.0) * CGFloat(scorecard.currentPlayers)))))
        
        if cellWidth <= combinedTriggerWidth {
            cellWidth *= 2
            bodyColumns = 1
            narrow = true
            imageRowHeight = 50.0
        } else {
            bodyColumns = 2
            narrow = false
            imageRowHeight = 50.0
        }
        
        roundWidth = size.width - (CGFloat(bodyColumns * scorecard.currentPlayers) * cellWidth)
        
        // work out what appears in which header row
        imageRow = -1
        playerRow = -1
        headerRows = 0
        headerHeight =  0.0
        bannerContinuationHeight = 0.0
        
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
        
        cellHeight = CGFloat(Int(floatCellHeight))
        
        if cellHeight < minCellHeight {
            cellHeight = minCellHeight
            headerHeight += CGFloat(cellHeight)
            bannerContinuationHeight = 0.0
        } else {
            headerHeight = size.height - (CGFloat(self.rounds+1) * cellHeight) - navigationBar.frame.height
            imageRowHeight = min(headerHeight - minCellHeight, 50.0)
            bannerContinuationHeight = headerHeight - imageRowHeight - minCellHeight
        }
        
        bannerContinuationHeightConstraint.constant = bannerContinuationHeight
        headerViewHeightConstraint.constant = headerHeight - bannerContinuationHeight
        footerViewHeightConstraint.constant = CGFloat(cellHeight) + self.view.safeAreaInsets.bottom

        scoresHeight = min(ScorecardUI.screenHeight, CGFloat(self.scorecard.rounds) * cellHeight, 600)
        scorecard.saveScorepadHeights(headerHeight: headerHeight + navigationBar.frame.height, bodyHeight: scoresHeight, footerHeight: CGFloat(cellHeight) + self.view.safeAreaInsets.bottom)
        
        // If moving to 1 column clear out stored bid cell pointers
        if bodyColumns == 1 {
            for playerNumber in 1...scorecard.currentPlayers {
                for round in 1...self.rounds {
                    scorecard.scorecardPlayer(playerNumber).setBidCell(round, cell: nil)
                }
            }
        }

    }
    
    private func setupBorders() {
        
        let line = self.paddingViewLines![0]
        let height: CGFloat = line.frame.height
        var gradient: [(alpha: CGFloat, location: CGFloat)] = []
        let tableViewTop: CGFloat = self.headerTableView.frame.minY
        for element in self.imageGradient {
            gradient.append((element.alpha, (tableViewTop + bannerContinuationHeight + (element.location * imageRowHeight)) / height))
        }
        for element in self.playerGradient {
            gradient.append((element.alpha, (tableViewTop + bannerContinuationHeight + imageRowHeight + (element.location * minCellHeight)) / height))
        }
        gradient.append((1.0, 1.0))
        
        self.paddingGradientLayer.forEach {
            $0.removeFromSuperlayer()
        }
        self.paddingGradientLayer = []
        self.paddingViewLines?.forEach {
            paddingGradientLayer.append(ScorecardUI.gradient($0, color: Palette.grid, gradients: gradient))
        }
    }
    
    private func makeEntry(_ fromButton: Bool = false) {
        if scorepadMode == .amend {
            if scorecard.gameComplete(rounds: self.rounds) && fromButton {
                self.showGameSummary()
            } else {
                self.showEntry()
            }
            rotated = false
        }
    }
    
    private func returnFromEntry(editedRound: Int? = nil) {
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
                let headerCell = self.headerCell(playerNumber: scorecard.isScorecardDealer(), row: row)
                highlightDealer(headerCell: headerCell, playerNumber: scorecard.isScorecardDealer(), row: row, forceClear: !highlight)
            }
        }
    }
    
    private func headerCell(playerNumber: Int, row: Int) -> ScorepadCollectionViewCell {
        let tableViewCell = headerTableView.cellForRow(at: IndexPath(row: row, section: 0)) as! ScorepadTableViewCell
        let collectionView = tableViewCell.scorepadCollectionView
        return collectionView?.cellForItem(at: IndexPath(item: playerNumber, section: 0)) as! ScorepadCollectionViewCell
    }
    
    private func highlightDealer(headerCell: ScorepadCollectionViewCell, playerNumber: Int, row: Int, forceClear: Bool = false) {
        if playerNumber >= 0 {
            headerCell.scorepadCellGradientLayer?.removeFromSuperlayer()
            if scorecard.isScorecardDealer() == playerNumber && !forceClear {
                if row == playerRow {
                    headerCell.scorepadCellLabel?.textColor = Palette.gameBannerText
                    headerCell.scorepadCellGradientLayer = ScorecardUI.gradient(headerCell, color: Palette.gameBanner, gradients: playerGradient)
                } else if row == imageRow {
                    headerCell.scorepadCellGradientLayer = ScorecardUI.gradient(headerCell, color: Palette.gameBanner, gradients: imageGradient)
                }
            } else {
                Palette.tableTopStyle(view: headerCell)
                
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
            scoreEntryButton.setTitle("Score")
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
                finishButton.setTitle("", for: .normal)
            }
        } else {
            if self.scorecard.gameInProgress {
                finishButton.setTitle("", for: .normal)
            } else {
                finishButton.setTitle("", for: .normal)
            }
        }
    }
    
    // MARK: - Utility Routines ======================================================================== -
    
    private func getLocation() {
        if self.scorecard.isHosting && self.scorecard.commsDelegate?.connectionProximity == .online {
            // Online - location not appropriate
            self.scorecard.gameLocation = GameLocation()
            self.scorecard.gameLocation.description = "Online"
            self.saveNewGame()
            self.playHand(setState: true)
        } else {
            // Prompt for location
            Utility.mainThread {
                // Get the other hands started
                self.saveNewGame()
                self.playHand(setState: true, show: false)
                // Link to location view
                self.showLocation()
            }
        }
    }
    
    public func returnToCaller() {
        // Called from another view controller to return control
        self.tidyUp()
        self.dismiss()
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
                self.showGameSummary()
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
    
    // MARK: - Show other views ======================================================= -
    
    private func showLocation() {
        LocationViewController.show(from: self, gameLocation: self.scorecard.gameLocation, useCurrentLocation: true, completion: { (location) in
            if let location = location {
                // Copy location back
                location.copy(to: self.scorecard.gameLocation)
                // Resave updated location
                self.saveLocationAndDate()
                // Play hand
                self.scorecard.playHand(from: self, sourceView: self.scorepadView, computerPlayerDelegate: self.computerPlayerDelegate)
            } else {
                // Exit
                self.dismiss()
            }
        })
    }
    
    private func showEntry() {
        self.notAllowedInDisplay()
        
        let reeditMode = scorecard.roundPlayer(playerNumber: scorecard.currentPlayers, round: scorecard.selectedRound).score(scorecard.selectedRound) != nil ? true : false
        
        entryViewController = EntryViewController.show(from: self, existing: self.entryViewController, reeditMode: reeditMode, rounds: self.rounds, cards: self.cards, bounce: self.bounce, bonus2: self.bonus2, suits: self.suits, completion:
            { (linkToGameSummary) in
                if linkToGameSummary {
                    self.formatButtons()
                    _ = self.scorecard.savePlayers(rounds: self.rounds)
                    self.scorecard.sendScores()
                    self.showGameSummary()
                } else {
                    let editedRound = self.scorecard.selectedRound
                    _ = self.scorecard.savePlayers(rounds: self.rounds)
                    self.highlightCurrentDealer(false)
                    self.scorecard.advanceMaximumRound(rounds: self.rounds)
                    self.highlightCurrentDealer(true)
                    self.returnFromEntry(editedRound: editedRound)
                }
            })
    }
    
    private func showReview(round: Int) {
        ReviewViewController.show(from: self, round: round, thisPlayer: self.scorecard.handState.enteredPlayerNumber)
    }
    
    public func showRoundSummary() {
        
        self.roundSummaryViewController = RoundSummaryViewController.show(from: self, existing: roundSummaryViewController, rounds: self.rounds, cards: self.cards, bounce: self.bounce, suits: self.suits)
    }
    
    public func showGameSummary() {
        self.gameSummaryViewController = GameSummaryViewController.show(from: self, firstGameSummary: self.firstGameSummary, gameSummaryMode: (self.scorecard.isHosting ? .amend : self.scorepadMode), rounds: self.rounds, completion: { (returnMode) in
            switch returnMode {
            case .resume:
                self.firstGameSummary=false
                self.gameSummaryViewController = nil
                self.returnFromEntry()
            case .newGame:
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
            case .returnHome:
                self.dismiss(returnHome: true)
            }
        })
        
    }
    
    private func notAllowedInDisplay() {
        if scorepadMode != .amend {
            // Shouldn't ever invoke this from display mode
            Utility.getActiveViewController()?.alertMessage("Unexpected action in scorepad display mode", title: "Error", okHandler: {
                self.dismiss(returnHome: true)
            })
        }
    }
   
    // MARK: - Function to present this view ==============================================================
    
    class func show(from viewController: UIViewController, existing scorepadViewController: ScorepadViewController? = nil, scorepadMode: ScorepadMode? = nil, rounds: Int? = nil, cards: [Int]? = nil, bounce: Bool? = nil, bonus2: Bool!, suits: [Suit]? = nil, rabbitMQService: RabbitMQService? = nil, recoveryMode: Bool = false, computerPlayerDelegate: [Int : ComputerPlayerDelegate?]? = nil ,completion: ((Bool)->())? = nil) -> ScorepadViewController {
        var scorepadViewController: ScorepadViewController! = scorepadViewController
        
        if scorepadViewController == nil {
            let storyboard = UIStoryboard(name: "ScorepadViewController", bundle: nil)
            scorepadViewController = storyboard.instantiateViewController(withIdentifier: "ScorepadViewController") as? ScorepadViewController
        }
        
        scorepadViewController.parentView = viewController.view
        scorepadViewController.scorepadMode = scorepadMode
        scorepadViewController.rounds = rounds
        scorepadViewController.cards = cards
        scorepadViewController.bounce = bounce
        scorepadViewController.bonus2 = bonus2
        scorepadViewController.suits = suits
        scorepadViewController.rabbitMQService = rabbitMQService
        scorepadViewController.recoveryMode = recoveryMode
        scorepadViewController.computerPlayerDelegate = computerPlayerDelegate
        scorepadViewController.completion = completion
        
        viewController.present(scorepadViewController, animated: true, completion: nil)
        
        return scorepadViewController
    }
    
    private func dismiss(returnHome: Bool = false) {
        self.dismiss(animated: true, completion: {
            self.completion?(returnHome)
        })
    }

    // MARK: - CollectionView Overrides ================================================================ -

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        if collectionView.tag >= 1000000 {
            return scorecard.currentPlayers + 1
        } else {
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
                width = cellWidth * CGFloat(bodyColumns)
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
        let row = collectionView.tag % 1000000
        let round = row + 1
        var headerCollection =  false
        var footerCollection = false
        var player = 0
        var reuseIdentifier = ""
        let column = indexPath.row
        
        if collectionView.tag >= 2000000 {
            footerCollection = true
        } else if collectionView.tag >= 1000000 {
            headerCollection = true
        }
        
        if headerCollection {
            
            // Header
            
            if column != 0 {
                // Thumbnail and/or name
                 player = column
                
                let playerDetail = scorecard.scorecardPlayer(player).playerMO
                
                if row == imageRow {
                    // Thumbnail cell
                    reuseIdentifier = "Header Collection Image Cell"
                } else {
                    reuseIdentifier = "Header Collection Cell"
                }
                
                headerCell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier,for: indexPath)   as! ScorepadCollectionViewCell
                
                headerCell.scorepadLeftLineGradientLayer?.removeFromSuperlayer()
                Palette.tableTopStyle(view: headerCell)
                headerCell.scorepadLeftLineWeight.constant = thickLineWeight
                headerCell.layoutIfNeeded()
                
                if row == playerRow {
                    // Setup label
                    headerCell.scorepadCellLabel.textColor = Palette.tableTopTextContrast
                    headerCell.scorepadCellLabel.text = scorecard.scorecardPlayer(player).playerMO!.name!
                    headerCell.scorepadLeftLineGradientLayer = ScorecardUI.gradient(headerCell.scorepadLeftLine, color: Palette.grid, gradients: playerGradient, overrideHeight: self.minCellHeight)
                    
                } else {
                    // Setup the thumbnail picture / disc
                    if playerDetail != nil {
                        Utility.setThumbnail(data: playerDetail!.thumbnail,
                                             imageView: headerCell.scorepadImage,
                                             initials: playerDetail!.name!,
                                             label: headerCell.scorepadDisc)
                        ScorecardUI.veryRoundCorners(headerCell.scorepadImage, radius: (imageRowHeight-9)/2)
                        ScorecardUI.veryRoundCorners(headerCell.scorepadDisc, radius: (imageRowHeight-9)/2)
                    }
                    headerCell.scorepadLeftLineGradientLayer = ScorecardUI.gradient(headerCell.scorepadLeftLine, color: Palette.grid, gradients: imageGradient, overrideHeight: self.imageRowHeight)
                }
    
            } else {
                // Title column
                headerCell = collectionView.dequeueReusableCell(withReuseIdentifier: "Header Collection Cell",for: indexPath) as! ScorepadCollectionViewCell
                
                headerCell.scorepadLeftLineGradientLayer?.removeFromSuperlayer()
                Palette.tableTopStyle(view: headerCell)
                headerCell.scorepadCellLabel?.textColor = Palette.tableTopTextContrast
                
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
            }
            
            if row == playerRow {
                // Setup the name font
                if narrow {
                    headerCell.scorepadCellLabel.font = UIFont.systemFont(ofSize: 20.0)
                } else {
                    headerCell.scorepadCellLabel.font = UIFont.systemFont(ofSize: 24.0)
                }
            }
            
            // Setup top line
            headerCell.scorepadTopLineWeight.constant = (row == 0 ? 0 /* was thickLineWeight*/ : 0)
            
            // Highlight current dealer
            highlightDealer(headerCell: headerCell, playerNumber: column, row: row)
            
            cell=headerCell
            
        } else if footerCollection {
            
            // Footer
            
            footerCell = collectionView.dequeueReusableCell(withReuseIdentifier: "Footer Collection Cell",for: indexPath) as! ScorepadCollectionViewCell
        
            footerCell.scorepadCellLabel.backgroundColor = Palette.roomInterior
            footerCell.scorepadCellLabel.textColor = Palette.roomInteriorText
            footerCell.scorepadCellLabelHeight.constant = cellHeight - thickLineWeight
            
            if column == 0 {
                // Row titles
                footerCell.scorepadCellLabel.text="Total"
                footerCell.scorepadLeftLineWeight.constant = 0
                footerCell.scorepadCellLabel.numberOfLines = 1
                footerCell.scorepadCellLabel.accessibilityIdentifier = ""
                if narrow {
                    footerCell.scorepadCellLabel.font = UIFont.systemFont(ofSize: 20.0)
                } else {
                    footerCell.scorepadCellLabel.font = UIFont.systemFont(ofSize: 24.0)
                }
            } else {
                // Row values
                player = column
                footerCell.scorepadCellLabel.text = "\(scorecard.scorecardPlayer(player).totalScore())"
                footerCell.scorepadLeftLineWeight.constant = thickLineWeight
                scorecard.scorecardPlayer(player).setTotalLabel(label: footerCell.scorepadCellLabel)
                footerCell.scorepadCellLabel.accessibilityIdentifier = "player\(indexPath.row)total"
                footerCell.scorepadCellLabel.font = UIFont.systemFont(ofSize: 26.0)
            }
            footerCell.scorepadTopLineWeight.constant = thinLineWeight
        
            cell=footerCell
            
        } else {
            
            // Body
            
            if column == 0 || (column % 2 == 1 && bodyColumns == 2) {
                reuseIdentifier = "Body Collection Text Cell"
            } else {
                reuseIdentifier = "Body Collection Image Cell"
            }
            
            bodyCell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! ScorepadCollectionViewCell
            
            if narrow {
                bodyCell.scorepadCellLabel.font = UIFont.systemFont(ofSize: 20.0)
            } else {
                bodyCell.scorepadCellLabel.font = UIFont.systemFont(ofSize: 24.0)
            }
            
            if column == 0 {
                Palette.tableTopStyle(bodyCell.scorepadCellLabel)
                bodyCell.scorepadCellLabel.attributedText = scorecard.roundTitle(round, rankColor: Palette.emphasisText, font: bodyCell.scorepadCellLabel.font, noTrumpScale: 0.8, rounds: self.rounds, cards: self.cards, bounce: self.bounce)
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
            }
           
            bodyCell.scorepadTopLineWeight.constant = thinLineWeight
            
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
                self.showReview(round: round)
            }
        }
        makeEntry()
    }
    
    func collectionView(_ collectionView: UICollectionView, willRotatetoInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        collectionView.collectionViewLayout.invalidateLayout()
        self.view.setNeedsDisplay()
    }
}

    
extension ScorepadViewController: UIViewControllerTransitioningDelegate {
    
    func animationController(
        forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        
        self.transition.presenting = true
        if presented is EntryViewController {
            return self.transition
        } else {
            return nil
        }
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if dismissed is EntryViewController {
            self.transition.presenting = false
            return self.transition
        } else {
            return nil
        }
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

    var scorepadCellGradientLayer: CAGradientLayer!
    var scorepadLeftLineGradientLayer: CAGradientLayer!
    
    @IBOutlet weak var scorepadCellLabel: UILabel!
    @IBOutlet weak var scorepadLeftLineWeight: NSLayoutConstraint!
    @IBOutlet weak var scorepadTopLineWeight: NSLayoutConstraint!
    @IBOutlet weak var scorepadCellLabelHeight: NSLayoutConstraint!
    @IBOutlet weak var scorepadImage: UIImageView!
    @IBOutlet weak var scorepadDisc: UILabel!
    @IBOutlet weak var scorepadLeftLine: UIView!
}


// MARK: - Enumerations ============================================================================ -

enum CellType {
    case bid
    case score
}

