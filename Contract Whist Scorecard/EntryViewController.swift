//
//  EntryViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 30/11/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit

class EntryViewController: ScorecardViewController, UITableViewDataSource, UITableViewDelegate {
    
    // MARK: - Class Properties ======================================================================== -
    
    // Properties to pass state
    private var reeditMode = false
    
    // Main state properties
    private var selection = Selection(player: 0, mode: Mode.bid)

    // UI component pointers
    private var playerBidCell = [EntryPlayerCell?]()
    private var playerMadeCell = [EntryPlayerCell?]()
    private var playerTwosCell = [EntryPlayerCell?]()
    private var playerScoreCell = [EntryPlayerCell?]()
    private var scoreCell = [EntryScoreCell?]()
    private var flow: Flow!
    private var undo = Flow()
    
    // Local class variables
    private var bidOnlyMode = false
    private var instructionSection = true
    private var firstTime = true
    private var rotated = false
    private var lastViewHeight: CGFloat = 0.0
    private var roundSummaryViewController: RoundSummaryViewController!
    private var smallScreen = false
    
    // Cell sizes
    private let scoreWidth: CGFloat = 50.0
    private var buttonSize: CGFloat = 0.0
    private var buttonSpacing: CGFloat = 10.0
    private var rowHeight: CGFloat = 50.0
    
    // Column descriptors
    private let playerColumn = 0
    private let bidColumn = 1
    private let madeColumn = 2
    private var twosColumn = 0
    private var scoreColumn = 0
    private var columns = 0
 
    // MARK: - IB Outlets ============================================================================== -

    @IBOutlet private weak var bannerLogoView: BannerLogoView!
    @IBOutlet private weak var titleView: UIView!
    @IBOutlet private weak var titleViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var bannerPaddingView: InsetPaddingView!
    @IBOutlet private weak var toolbarView: UIView!
    @IBOutlet private weak var toolbarButtonViewGroup: ViewGroup!
    @IBOutlet private weak var entryView: UIView!
    @IBOutlet private weak var playerTableView: UITableView!
    @IBOutlet private weak var playerTableViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var instructionLabel: UILabel!
    @IBOutlet private weak var instructionContainerView: UIView!
    @IBOutlet private weak var instructionContainerViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var separatorView: UIView!
    @IBOutlet private weak var scoreButtonCollectionView: UICollectionView!
    @IBOutlet private weak var footerRoundTitle: UILabel!
    @IBOutlet private weak var undoButton: RoundedButton!
    @IBOutlet private weak var finishButton: RoundedButton!
    @IBOutlet private weak var errorsButton: RoundedButton!
    @IBOutlet private weak var summaryButton: RoundedButton!
    @IBOutlet private weak var toolbarFinishButton: RoundedButton!
    @IBOutlet private weak var toolbarErrorsButton: RoundedButton!
    @IBOutlet private weak var toolbarSummaryButton: RoundedButton!
    @IBOutlet private var errorsButtons: [RoundedButton]!
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func undoButtonClicked(_ sender: Any) {
        // Undo key
        highlightCursor(false)
        undoLast()
        highlightCursor(true)
        setForm(true)
    }
    
    @IBAction func summaryClicked(_ sender: Any) {
        // Round in toolbar - show summary
        self.controllerDelegate?.didProceed()
    }
    
    @IBAction func saveScorePressed(_ sender: Any) {
        if canFinish() {
            self.controllerDelegate?.didCancel()
        }
    }
    
    @IBAction func rightSwipe(recognizer:UISwipeGestureRecognizer) {
        self.saveScorePressed(finishButton!)
    }
        
// MARK: - View Overrides ========================================================================== -
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup default colors (previously done in StoryBoard
        self.defaultViewColors()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        self.rotated = true
        Scorecard.shared.reCenterPopup(self)
        self.view.setNeedsLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.playerTableView.layoutIfNeeded()
        self.refreshScreen(firstTime: self.firstTime)
        
        self.firstTime = false
        self.rotated = false
    }
    
    private func refreshScreen(firstTime: Bool) {
        self.setupScreen()
           
        if firstTime {
            self.bidOnlyMode = !Scorecard.game.roundBiddingComplete(Scorecard.game.selectedRound) ? true : false
            self.setupColumns()
            self.setupFlow()
            self.getInitialState()
        }
        
        self.setForm(true)
        
        for _ in 1...Scorecard.game.roundCards(Scorecard.game.selectedRound) + 1 {
            self.scoreCell.append(nil)
        }
        for _ in 1...Scorecard.game.currentPlayers {
            self.playerBidCell.append(nil)
            self.playerMadeCell.append(nil)
            self.playerTwosCell.append(nil)
            self.playerScoreCell.append(nil)
        }
        
        // Send state to watch
        Scorecard.shared.watchManager.updateScores()
        
        self.setupSize()

        if self.lastViewHeight != self.view.frame.height || self.firstTime {
            self.playerTableView.reloadData()
            self.lastViewHeight = self.view.frame.height
        }
    }
    
    func setupSize() {
        
        self.buttonSize = 50.0
        let buttonsAcross = 5
        self.buttonSize = ((self.scoreButtonCollectionView.frame.width + self.buttonSpacing) / CGFloat(buttonsAcross)) - self.buttonSpacing
        
        let buttonsDown = ((Scorecard.game.roundCards(Scorecard.game.selectedRound) + buttonsAcross) / buttonsAcross)
        let buttonsHeight = (CGFloat(buttonsDown) * (self.buttonSize + self.buttonSpacing) + CGFloat(buttonSpacing))
        let tableViewHeight = CGFloat(Scorecard.game.currentPlayers + 1) * self.rowHeight
        let minTitleViewHeight: CGFloat = (smallScreen ? 0 : 44)
        
        var availableHeight = self.view.safeAreaLayoutGuide.layoutFrame.height // Safe area height
        availableHeight -= tableViewHeight // Subtract out table view
        availableHeight -= buttonsHeight // Subtract out score buttons
        availableHeight -= self.toolbarView.frame.height // Subtract out toolbar
        
        if availableHeight < (90 + minTitleViewHeight) && !ScorecardUI.landscapePhone() {
            self.instructionContainerViewHeightConstraint.constant = min(50, availableHeight - minTitleViewHeight)
        }
        self.instructionContainerView.layoutIfNeeded()
        self.instructionContainerView.roundCorners(cornerRadius: (ScorecardUI.landscapePhone() ? 0.0 : 12.0))
        
        availableHeight -= self.instructionContainerViewHeightConstraint.constant // Subtract out (reduced) instruction
        if smallScreen {
            self.titleViewHeightConstraint.constant = 0.0
        } else {
            self.titleViewHeightConstraint.constant = min(80, max(minTitleViewHeight, availableHeight))
        }
    }
    
    // MARK: - TableView Overrides ===================================================================== -
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Scorecard.game.currentPlayers + 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            return self.rowHeight
        case 1:
            return 96.0
        case 2:
            let buttons = Scorecard.game.roundCards(Scorecard.game.selectedRound) + 1
            let buttonsAcross = Int((self.view.safeAreaLayoutGuide.layoutFrame.width - self.buttonSpacing) / (self.buttonSize + self.buttonSpacing))
            let buttonRows = (CGFloat(buttons) / CGFloat(buttonsAcross)).rounded(.up)
            return (buttonRows * (buttonSize + buttonSpacing)) + 16.0
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Score summary
        let entryPlayerTableCell = tableView.dequeueReusableCell(withIdentifier: "Entry Player Table Cell", for: indexPath) as! EntryPlayerTableCell
        
        // Setup default colors (previously done in StoryBoard
        self.defaultCellColors(cell: entryPlayerTableCell)
        
        entryPlayerTableCell.setCollectionViewDataSourceDelegate(self, forRow: indexPath.row)
        if indexPath.row==0 {
            Palette.bannerStyle(view: entryPlayerTableCell)
            entryPlayerTableCell.entryPlayerSeparator.isHidden = true
        } else {
            Palette.normalStyle(entryPlayerTableCell)
        }
        
        return entryPlayerTableCell
    }
        
    // MARK: - Form Presentation / Handling Routines =================================================== -
    func setupFlow() {
        // Set up flow of cursor round screen
        self.flow = Flow()
        if self.reeditMode {
            for player in 1...Scorecard.game.currentPlayers {
                self.flow.append(player: player, mode: Mode.bid)
                self.flow.append(player: player, mode: Mode.made)
                if Scorecard.activeSettings.bonus2 {
                    self.flow.append(player: player, mode: Mode.twos)
                }
            }
        } else {
            for player in 1...Scorecard.game.currentPlayers {
                self.flow.append(player: player, mode: Mode.bid)
            }
            if !bidOnlyMode {
                for player in 1...Scorecard.game.currentPlayers {
                    self.flow.append(player: player, mode: Mode.made)
                    if Scorecard.activeSettings.bonus2 {
                        self.flow.append(player: player, mode: Mode.twos)
                    }
                }
            }
        }
    }
    
    func setupScreen() {
        let title = Scorecard.game.roundTitle(Scorecard.game.selectedRound, rankColor: Palette.totalText)
        footerRoundTitle.attributedText = title
        if ScorecardUI.screenHeight < 667.0 || !ScorecardUI.phoneSize() {
            // Smaller than an iPhone 7 portrait or on a tablet
            self.smallScreen = true
        } else {
            self.smallScreen = false
        }
        self.errorsButtons.forEach { ScorecardUI.veryRoundCorners($0, radius: $0.frame.width / 2.0) }
        
        self.rowHeight = min(ScorecardUI.screenHeight / 7.0, 50.0)
        self.instructionContainerViewHeightConstraint.constant = (ScorecardUI.landscapePhone() ? self.rowHeight : 90)
        self.instructionContainerView.layoutIfNeeded()
        self.playerTableViewHeightConstraint.constant = CGFloat(Scorecard.game.currentPlayers + 1) * self.rowHeight
    }
    
    func setupColumns() {
        self.twosColumn = (!Scorecard.activeSettings.bonus2 ? -1 : 3)
        self.scoreColumn = (!Scorecard.activeSettings.bonus2 ? 3 : 4)
        self.columns = (bidOnlyMode ? 2 : (!Scorecard.activeSettings.bonus2 ? 4 : 5))
    }
    
    func issueInstruction() {
        if self.selection.player == 0 {
            self.instructionLabel?.text = "Tap a player to edit their score"
        } else {
            switch selection.mode {
            case Mode.bid:
                self.instructionLabel?.text = "Enter the bid for \(Scorecard.game.player(entryPlayerNumber: selection.player).playerMO!.name!)"
            case Mode.made:
                self.instructionLabel?.text = "Enter the tricks made for \(Scorecard.game.player(entryPlayerNumber: selection.player).playerMO!.name!)"
            case Mode.twos:
                self.instructionLabel?.text = "Enter the number of 2s for \(Scorecard.game.player(entryPlayerNumber: selection.player).playerMO!.name!)"
            }
        }
    }
    
    func enableMovementButtons() {
        self.toolbarButtonViewGroup.isHidden(view: self.undoButton, (self.undo.first == nil))
        self.summaryButton.isHidden = smallScreen || bidOnlyMode
        self.toolbarButtonViewGroup.isHidden(view: self.toolbarSummaryButton, (!smallScreen || bidOnlyMode))
    }
    
    func setForm(_ tableLoaded: Bool) {
        
        if tableLoaded {
            self.issueInstruction()
        }
        
        if self.scoreButtonCollectionView != nil {
            for scoreCell in scoreButtonCollectionView?.visibleCells as! [EntryScoreCell] {
                self.formatScore(scoreCell)
            }
        }
        
        self.enableMovementButtons()
        
        self.hideFinishButtons(errors: tableLoaded && self.checkErrors())
    }
    
    private func hideFinishButtons(errors: Bool) {
        self.finishButton.isHidden = (smallScreen || errors)
        self.errorsButton.isHidden = (smallScreen || !errors)
        self.toolbarFinishButton.isHidden = (!smallScreen || errors)
        self.toolbarErrorsButton.isHidden = (!smallScreen || !errors)
    }
    
    func errorHighlight(_ mode: Mode, _ highlight: Bool) -> Bool{
        var label: UILabel!
        
        for playerCell in self.playerBidCell {
            
            if let player = playerCell?.tag {
                
                switch mode {
                case Mode.bid:
                    label = self.playerBidCell[player - 1]?.entryPlayerLabel
                case Mode.made:
                    label = self.playerMadeCell[player - 1]?.entryPlayerLabel
                case Mode.twos:
                    label = self.playerTwosCell[player - 1]?.entryPlayerLabel
                }
                
                if let label = label {
                    Palette.errorStyle(label, errorCondtion: highlight)
                    if highlight {
                        label.font = UIFont.boldSystemFont(ofSize: 17.0)
                    } else {
                        label.font = UIFont.systemFont(ofSize: 17.0)
                    }
                }
            }
        }
        
        return highlight
    }
    
    func formatScore(_ scoreCell: EntryScoreCell) {
        if self.selection.player == 0 {
            // No player selected - hide the scores
            scoreCell.scoreButton.isHidden = true
            
        } else if selection.mode == Mode.twos &&
            Scorecard.game.scores.get(round: Scorecard.game.selectedRound, playerNumber: selection.player, sequence: .entry).made != nil &&
            scoreCell.scoreButton.tag > Scorecard.game.scores.get(round: Scorecard.game.selectedRound, playerNumber: selection.player, sequence: .entry).made! {
            // Never show more twos than made
            scoreCell.scoreButton.isHidden = true
            
        } else if selection.mode == Mode.twos && scoreCell.scoreButton.tag > Scorecard.shared.numberSuits {
            // Never show more than 4 twos
            scoreCell.scoreButton.isHidden = true
            
        } else if (selection.mode == Mode.made && scoreCell.scoreButton.tag==Scorecard.game.scores.get(round: Scorecard.game.selectedRound, playerNumber: selection.player, sequence: .entry).bid ||
            self.selection.mode == Mode.twos && scoreCell.scoreButton.tag==0) {
            // Highlight made exactly button and zeros twos button
            scoreCell.scoreButton.isHidden = false
            scoreCell.scoreButton.layoutIfNeeded()
            scoreCell.scoreButton.toCircle()
            
        } else {
            scoreCell.scoreButton.isHidden = false
            scoreCell.scoreButton.toRounded(cornerRadius: 8.0)
        }
        
        
        // Disable specific buttons to avoid error input
        
        switch self.selection.mode {
        case Mode.bid:
            // Last bid must not make bids add up to number of tricks
            
            let remaining = Scorecard.game.remaining(playerNumber: self.selection.player, round: Scorecard.game.selectedRound, mode: self.selection.mode)
            
            if  (self.selection.player == Scorecard.game.currentPlayers
                && scoreCell.scoreButton.tag == remaining) {
                scoreCell.scoreButton.isEnabled(false)
            } else {
                scoreCell.scoreButton.isEnabled(true)
            }
            
        case Mode.made:
            // Last made must make total made add up to number of tricks and total made must never exceed number of tricks
            
            let remaining = Scorecard.game.remaining(playerNumber: selection.player, round: Scorecard.game.selectedRound, mode: selection.mode)
            
            if (self.selection.player == Scorecard.game.currentPlayers
                && scoreCell.scoreButton.tag != remaining) ||
                (Scorecard.game.scores.get(round: Scorecard.game.selectedRound, playerNumber: Scorecard.game.currentPlayers, sequence: .entry).made == nil && scoreCell.scoreButton.tag > remaining) {
                scoreCell.scoreButton.isEnabled(false)
            } else {
                scoreCell.scoreButton.isEnabled(true)
            }
            
        case Mode.twos:
            // Total number of twos must never exceed the lower of 4 and the number of tricks
            
            let remaining = Scorecard.game.remaining(playerNumber: selection.player, round: Scorecard.game.selectedRound, mode: selection.mode)
            
            if (self.selection.player == Scorecard.game.currentPlayers || Scorecard.game.scores.get(round: Scorecard.game.selectedRound, playerNumber: Scorecard.game.currentPlayers, sequence: .entry).twos == nil) && scoreCell.scoreButton.tag > remaining {
                scoreCell.scoreButton.isEnabled(false)
            } else {
                scoreCell.scoreButton.isEnabled(true)
            }
        }
        
    }
    
    func highlightCursor(_ highlight: Bool) {
        var label: UILabel!
        if self.selection.player != 0 {
            switch self.selection.mode {
            case Mode.bid:
                label = self.playerBidCell[selection.player-1]?.entryPlayerLabel
            case Mode.made:
                label = self.playerMadeCell[selection.player-1]?.entryPlayerLabel
            case Mode.twos:
                label = self.playerTwosCell[selection.player-1]?.entryPlayerLabel
            }
            
            if label != nil {
                if highlight {
                    Palette.bidButtonStyle(label)
                } else {
                    Palette.normalStyle(label, setFont: false)
                }
            }
        }
    }

    // MARK: - Utility Routines ======================================================================== -

    func currentSelectionValue() -> Int? {
        return self.selectionValue(selection)
    }
    
    func selectionValue(_ selection: Selection?) -> Int? {
        return (selection == nil ? nil :
         Scorecard.game.scores.get(round: Scorecard.game.selectedRound, playerNumber: selection!.player, sequence: .entry, mode: selection!.mode))
    }

    func moveToNext() -> Bool{
    
        // Only move forward if current complete and next not end of list
        if currentSelectionValue() != nil && self.selection.next != nil {
            self.selection = self.selection.next!
            return true
        } else {
            return false
        }
    }
    
    func moveToPrevious() -> Bool {
        
        // Only move backward if current complete and previous not end of list
        if self.selection.previous != nil {
            self.selection = self.selection.previous!
            return true
        } else {
            return false
        }
    }
    
    func undoLast() {
        
        // Move to the last value entered
        if self.undo.last != nil {
            self.selection = flow.find(player: self.undo.last!.player, mode: self.undo.last!.mode)
            self.setScore(self.undo.last!.oldValue)
            self.undo.removeLast()
            self.enableMovementButtons()
        }
        
    }
    
    func setScore(_ value: Int!) {
        
        switch self.selection.mode {
        case Mode.bid:
            _ = Scorecard.game.scores.set(round: Scorecard.game.selectedRound, playerNumber: selection.player, bid: value, sequence: .entry)
            self.playerBidCell[self.selection.player-1]?.entryPlayerLabel.text = (value == nil  ? "" : "\(value!)")
            Scorecard.shared.sendBid(playerNumber: selection.player, round: Scorecard.game.selectedRound)
        case Mode.made:
            _ = Scorecard.game.scores.set(round: Scorecard.game.selectedRound, playerNumber: selection.player, made: value, sequence: .entry)
            self.playerMadeCell[self.selection.player-1]?.entryPlayerLabel.text = (value == nil  ? "" : "\(value!)")
        case Mode.twos:
            _ = Scorecard.game.scores.set(round: Scorecard.game.selectedRound, playerNumber: selection.player, twos: value, sequence: .entry)
            self.playerTwosCell[self.selection.player-1]?.entryPlayerLabel.text = (value == nil  ? "" : "\(value!)")
        }
        
        if !self.bidOnlyMode {
            let score = Scorecard.game.scores.score(round: Scorecard.game.selectedRound, playerNumber: self.selection.player, sequence: .entry)
            self.playerScoreCell[self.selection.player-1]?.entryPlayerLabel.text = (score == nil ? "" : "\(score!)")
        }
    }
    
    func getScore() -> Int! {
        var score: Int!
        
        switch self.selection.mode {
        case Mode.bid:
            score = Scorecard.game.scores.get(round: Scorecard.game.selectedRound, playerNumber: self.selection.player, sequence: .entry).bid
        case Mode.made:
            score = Scorecard.game.scores.get(round: Scorecard.game.selectedRound, playerNumber: self.selection.player, sequence: .entry).made
        case Mode.twos:
            score = Scorecard.game.scores.get(round: Scorecard.game.selectedRound, playerNumber: self.selection.player, sequence: .entry).twos
        }
        
        return score
    }
    
    func canFinish() -> Bool {
        var canFinish = true

        if Scorecard.game.scores.error(round: Scorecard.game.selectedRound) {
            var message="This round does not satisfy the following conditions"
            for loopMode in allModes {
                if self.checkError(loopMode) {
                    message = "\(message)\n\n\(self.errorDescription(loopMode))"
                }
            }
            message="\(message)\n\nYou must correct all errors before exiting"
            let alertController = UIAlertController(title: "Warning", message: message, preferredStyle: UIAlertController.Style.alert)
            alertController.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
            present(alertController, animated: true, completion: nil)
            canFinish=false
        } else {
            canFinish=true
        }
        return canFinish
    }
    
    func getInitialState() {
        
        if !self.reeditMode {
            // Move through cells to last one
            self.selection = flow.first!
            while self.moveToNext() {
            }
        } else {
            self.selection = Selection(player: 0, mode: Mode.bid)
        }
    }
    
    func checkErrors() -> Bool {
        var roundError = false
        roundError = errorHighlight(Mode.bid, self.checkError(Mode.bid))
        if !bidOnlyMode {
            roundError = errorHighlight(Mode.made, self.checkError(Mode.made)) || roundError
            if Scorecard.activeSettings.bonus2 {
                roundError = errorHighlight(Mode.twos, self.checkError(Mode.twos)) || roundError
            }
        }
        return roundError
    }
    
    func checkError(_ mode: Mode) -> Bool {
        if Scorecard.game.scores.get(round: Scorecard.game.selectedRound, playerNumber: Scorecard.game.currentPlayers, sequence: .entry, mode: mode) == nil {
            // Column not yet complete - can't be an error
            return false
        } else {
            switch mode {
            case Mode.bid:
                return Scorecard.game.remaining(playerNumber: 0, round: Scorecard.game.selectedRound, mode: Mode.bid) == 0
            case Mode.made:
                return Scorecard.game.remaining(playerNumber: 0, round: Scorecard.game.selectedRound, mode: Mode.made) != 0
            case Mode.twos:
                return Scorecard.game.remaining(playerNumber: 0, round: Scorecard.game.selectedRound, mode: Mode.twos) < 0
            }
        }
    }
    
    func errorDescription(_ mode: Mode) -> String {
        let cards = Scorecard.game.roundCards(Scorecard.game.selectedRound)
        
        switch mode {
        case Mode.bid:
            return "Total bids must not equal \(cards). Increase or reduce one of the bids."
        case Mode.made:
            let madeVariance = -Scorecard.game.remaining(playerNumber: 0, round: Scorecard.game.selectedRound, mode: Mode.made)
            return "Total tricks made must equal \(cards). \(madeVariance < 0 ? "Increase" : "Reduce") the number of tricks made by exactly \(abs(madeVariance))"
        case Mode.twos:
            let twosVariance = -Scorecard.game.remaining(playerNumber: 0, round: Scorecard.game.selectedRound, mode: Mode.twos)
            return "Total twos made must be less than or equal to \(min(Scorecard.shared.numberSuits, cards)). Reduce the number of twos made by at least \(twosVariance)"
        }
    }
    
    // MARK: - Function to present and dismiss this view ==============================================================
    
    class public func show(from viewController: ScorecardViewController, appController: ScorecardAppController? = nil, existing entryViewController: EntryViewController! = nil, reeditMode: Bool = false) -> EntryViewController {
        
        var entryViewController: EntryViewController! = entryViewController
        
        if entryViewController == nil {
            let storyboard = UIStoryboard(name: "EntryViewController", bundle: nil)
            entryViewController = storyboard.instantiateViewController(withIdentifier: "EntryViewController") as? EntryViewController
        } else {
            entryViewController.refreshScreen(firstTime: true)
        }
        
        entryViewController.preferredContentSize = CGSize(width: 400, height: Scorecard.shared.scorepadBodyHeight)
        entryViewController.modalPresentationStyle = (ScorecardUI.phoneSize() ? .fullScreen : .automatic)
        
        entryViewController.reeditMode = reeditMode
        entryViewController.firstTime = true
        
        viewController.present(entryViewController, appController: appController, sourceView: viewController.popoverPresentationController?.sourceView ?? viewController.view, animated: true, completion: nil)
        
        return entryViewController
    }
}

extension EntryViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    // MARK: - CollectionView Overrides ================================================================ -
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        if collectionView.tag >= 0 {
        // Player summary
            return self.columns
        } else {
            return Scorecard.game.roundCards(Scorecard.game.selectedRound) + 1
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        collectionView.setNeedsLayout()
        collectionView.layoutIfNeeded()
        let totalHeight: CGFloat = collectionView.bounds.size.height
        let totalWidth: CGFloat = collectionView.bounds.size.width
        var width: CGFloat = 0.0
        var height: CGFloat = 0.0
        
        let nameWidth = totalWidth - (CGFloat(columns - 1) * self.scoreWidth)
        
        if collectionView.tag >= 0 {
            // Player score summary
            let column = indexPath.row
            if column == self.playerColumn {
                // Name
                width = nameWidth
            } else {
                // Values
                width = self.scoreWidth
            }
            height = totalHeight
        } else {
            // Score buttons
            
            width = self.buttonSize
            height = self.buttonSize
        }
        
        return CGSize(width: width, height: height)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return self.buttonSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView.tag >= 0 {
            // Player summary table
        
            let entryPlayerCell = collectionView.dequeueReusableCell(withReuseIdentifier: "Entry Player Cell", for: indexPath) as! EntryPlayerCell
            
            let playerLabel = entryPlayerCell.entryPlayerLabel!
            let column = indexPath.row
            
            if collectionView.tag==0 {
                // Title row
                switch column {
                case playerColumn:
                    playerLabel.text="Player"
                    playerLabel.textAlignment = .left
                case bidColumn:
                    playerLabel.text="Bid"
                case madeColumn:
                    playerLabel.text="Made"
                case twosColumn:
                    playerLabel.text="Twos"
                default:
                    playerLabel.text="Score"
                }
                Palette.bannerStyle(playerLabel)
                entryPlayerCell.isUserInteractionEnabled = false
                
            } else {
                // Player row
                let player = collectionView.tag
                entryPlayerCell.tag = player
                Palette.normalStyle(playerLabel, setFont: false)
                
                switch column {
                case playerColumn:
                    playerLabel.text = Scorecard.game.player(entryPlayerNumber: player).playerMO!.name!
                    playerLabel.textAlignment = .left
                case bidColumn:
                    let bid: Int? = Scorecard.game.scores.get(round: Scorecard.game.selectedRound, playerNumber: player, sequence: .entry).bid
                    playerLabel.text = (bid==nil ? " " : "\(bid!)")
                    playerLabel.textAlignment = .center
                    ScorecardUI.roundCorners(playerLabel)
                    self.playerBidCell[player-1] = entryPlayerCell
                    _ = self.checkErrors()
                    
                case madeColumn:
                    let made: Int? = Scorecard.game.scores.get(round: Scorecard.game.selectedRound, playerNumber: player, sequence: .entry).made
                    playerLabel.text = (made==nil ? " " : "\(made!)")
                    playerLabel.textAlignment = .center
                    ScorecardUI.roundCorners(playerLabel)
                    self.playerMadeCell[player-1] = entryPlayerCell
                    _ = self.checkErrors()

                case twosColumn:
                    let twos: Int? = Scorecard.game.scores.get(round: Scorecard.game.selectedRound, playerNumber: player, sequence: .entry).twos
                    playerLabel.textAlignment = .center
                    playerLabel.text = (twos==nil ? " " : "\(twos!)")
                    ScorecardUI.roundCorners(playerLabel)
                    self.playerTwosCell[player-1] = entryPlayerCell
                    _ = self.checkErrors()
                    
                default:
                    let score: Int? = Scorecard.game.scores.score(round: Scorecard.game.selectedRound, playerNumber: player, sequence: .entry)
                    playerLabel.textAlignment = .center
                    playerLabel.text = (score==nil ? " " : "\(score!)")
                    self.playerScoreCell[player-1] = entryPlayerCell
                }
                
                let selectedMode = columnMode(indexPath.row)
                if selectedMode != nil && player == self.selection.player && self.selection.mode == selectedMode! {
                    self.highlightCursor(true)
                } else {
                    Palette.normalStyle(playerLabel, setFont: false)
                }
                entryPlayerCell.isUserInteractionEnabled = true
               
            }
            
            return entryPlayerCell
        
        } else {
        
            self.scoreCell[indexPath.row] = collectionView.dequeueReusableCell(withReuseIdentifier: "Entry Score Cell",for: indexPath) as? EntryScoreCell
            
            ScorecardUI.roundCorners(self.scoreCell[indexPath.row]!.scoreButton)
            self.scoreCell[indexPath.row]!.scoreButton.setTitle("\(indexPath.row)", for: .normal)
            self.scoreCell[indexPath.row]!.scoreButton.addTarget(self, action: #selector(EntryViewController.scoreActionButtonPressed(_:)), for: UIControl.Event.touchUpInside)
            self.scoreCell[indexPath.row]!.scoreButton.tag = indexPath.row
            self.scoreCell[indexPath.row]!.scoreButton.accessibilityIdentifier = "score\(indexPath.row)"

            self.formatScore(scoreCell[indexPath.row]!)
            
            return self.scoreCell[indexPath.row]!
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool
    {
        
        if collectionView.tag >= 0 {
            // Player score summary - should only select if already a value or previous cell already a value
            
            let tappedPlayer = collectionView.tag
            var tappedMode = columnMode(indexPath.row)
            if tappedMode == nil {
                tappedMode = Mode.bid
            }
            let previousSelection: Selection? = flow.find(player: tappedPlayer, mode: tappedMode!).previous
            
            if tappedMode != nil &&
                (Scorecard.game.scores.get(round: Scorecard.game.selectedRound, playerNumber: tappedPlayer, sequence: .entry, mode: tappedMode!) != nil ||
                        (previousSelection != nil &&
                            Scorecard.game.scores.get(round: Scorecard.game.selectedRound, playerNumber: previousSelection!.player, sequence: .entry, mode: previousSelection!.mode) != nil)) {
                return true
            } else {
                return false
            }
        } else {
            // Score buttons
            return false
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                   didSelectItemAt indexPath: IndexPath) {
        if collectionView.tag >= 0 {
            // User (in re-edit mode) has selected a specific player
            highlightCursor(false)
            var mode = columnMode(indexPath.row)
            if mode == nil {
                mode = Mode.bid
            }
            self.selection = flow.find(player: collectionView.tag, mode: mode!)
            self.highlightCursor(true)
            self.setForm(true)
        }
    }
    
    
    // MARK: - Collection View Action Handlers ====================================================== -
    
    @objc func scoreActionButtonPressed(_ button: UIButton) {
        
        // Mark as in progress
        Scorecard.game.setGameInProgress(true)
        
        let oldValue = getScore()
        setScore(button.tag)
        
        // Add the current selection to the undo sequence
        undo.append(player: selection.player, mode: selection.mode, oldValue: oldValue)
        
        highlightCursor(false)
        if !moveToNext() {
            if !self.reeditMode && !Scorecard.game.scores.error(round: Scorecard.game.selectedRound) {
                // Finished - return
                if bidOnlyMode {
                    self.leaveBidOnlyMode()
                }
                self.controllerDelegate?.didProceed()
            } else {
                self.selection = Selection(player: 0, mode: Mode.bid)
            }
        }
        highlightCursor(true)
        setForm(true)
        
    }
    
    private func leaveBidOnlyMode() {
        bidOnlyMode = false
        setupColumns()
        setupFlow()
        selection = flow.find(player: 1, mode: Mode.made)
        setForm(false)
        setupSize()
        playerTableView.reloadData()
    }
    
    // MARK: - Collection View Utility Routines ===================================================== -
    
    func columnMode(_ column: Int) -> Mode? {
        var columnMode: Mode?
        
        switch column {
        case self.bidColumn:
            columnMode = Mode.bid
        case self.madeColumn:
            columnMode = Mode.made
        case self.twosColumn:
            columnMode = Mode.twos
        default:
            columnMode = nil
        }
        return columnMode
    }
    
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class EntryPlayerTableCell: UITableViewCell {
    @IBOutlet weak var playerCollection: UICollectionView!
    @IBOutlet weak var entryPlayerSeparator: UIView!
    
    func setCollectionViewDataSourceDelegate
        <D: UICollectionViewDataSource & UICollectionViewDelegate>
        (_ dataSourceDelegate: D, forRow row: Int) {
        
        self.playerCollection.delegate = dataSourceDelegate
        self.playerCollection.dataSource = dataSourceDelegate
        self.playerCollection.tag = row
        self.playerCollection.reloadData()
    }
    
}

class EntryPlayerCell: UICollectionViewCell {
    @IBOutlet weak var entryPlayerLabel: UILabel!
}

class EntryScoreCell: UICollectionViewCell {
    @IBOutlet weak var scoreButton: RoundedButton!
}

// MARK: - Enumerations ============================================================================ -

enum Mode {
    case bid
    case made
    case twos
}
let allModes = [Mode.bid, Mode.made, Mode.twos]

// MARK: - Utility Classes ========================================================================= -

class Selection {
    var player = 0
    var mode = Mode.bid
    var next: Selection?
    weak var previous: Selection?
    var oldValue: Int!
    
    init(player: Int, mode: Mode, oldValue: Int! = nil) {
        self.player = player
        self.mode = mode
        self.oldValue = oldValue
    }
}

class Flow {
    // Linked list data structure to contain the cells to be edited
    
    private var head: Selection?
    private var tail: Selection?
    private var map = Array(repeating: Array(repeating: Selection(player: 0, mode: Mode.bid), count: allModes.count), count: 4)
    var first: Selection? { return head }
    var last: Selection? { return tail }
    
    func append(player: Int, mode: Mode, oldValue: Int! = nil) {
        let element = intMode(mode)
        
        self.map[player-1][element-1] = Selection(player: player, mode: mode, oldValue: oldValue)
        
        if let tailNode = self.tail {
            
            self.map[player-1][element-1].previous = tailNode
            tailNode.next = self.map[player-1][element-1]
        }
        else {
            self.head = map[player-1][element-1]
        }
        self.tail = map[player-1][element-1]
    }
    
    func removeLast() {
        if let tailNode = self.tail {
            self.tail = tailNode.previous
            if self.tail == nil {
                self.head = nil
            } else {
                self.tail!.next = nil
            }
        }
    }
    
    func find(player: Int, mode: Mode) -> Selection {
        return self.map[player-1][intMode(mode)-1]
    }
    
    func intMode(_ mode: Mode) -> Int {
        
        var intMode: Int
        switch mode {
        case Mode.bid:
            intMode = 1
        case Mode.made:
            intMode = 2
        case Mode.twos:
            intMode = 3
        }
        return intMode
    }
    
}

extension EntryViewController {

    /** _Note that this code was generated as part of the move to themed colors_ */

    private func defaultViewColors() {

        self.bannerLogoView.fillColor = Palette.bannerShadow
        self.bannerLogoView.strokeColor = Palette.bannerText
        self.bannerPaddingView.bannerColor = Palette.banner
        self.entryView.backgroundColor = Palette.background
        self.errorsButtons.forEach { $0.backgroundColor = Palette.error }
        self.titleView.backgroundColor = Palette.banner
        self.toolbarView.backgroundColor = Palette.total
        self.instructionContainerView.backgroundColor = Palette.banner
        self.instructionLabel.textColor = Palette.bannerText
        self.separatorView.backgroundColor = Palette.separator
    }

    private func defaultCellColors(cell: EntryPlayerTableCell) {
        switch cell.reuseIdentifier {
        case "Entry Player Table Cell":
            cell.entryPlayerSeparator.backgroundColor = Palette.separator
        default:
            break
        }
    }

    private func defaultCellColors(cell: EntryScoreCell) {
        switch cell.reuseIdentifier {
        case "Entry Score Cell":
            cell.scoreButton.backgroundColor = Palette.bidButton
            cell.scoreButton.setTitleColor(Palette.bidButtonText, for: .normal)
        default:
            break
        }
    }

}
