//
//  EntryViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 30/11/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit

class EntryViewController: CustomViewController, UITableViewDataSource, UITableViewDelegate {
    
    // MARK: - Class Properties ======================================================================== -
    
    private let scorecard = Scorecard.shared
        
    // Properties to pass state
    private var reeditMode = false
    private var rounds: Int!
    private var cards: [Int]!
    private var bounce: Bool!
    private var bonus2: Bool!
    private var suits: [Suit]!
    private var completion: ((Bool)->())? = nil
    
    // Main state properties
    private var selection = Selection(player: 0, mode: Mode.bid)

    // UI component pointers
    private var playerBidCell = [EntryPlayerCell?]()
    private var playerMadeCell = [EntryPlayerCell?]()
    private var playerTwosCell = [EntryPlayerCell?]()
    private var playerScoreCell = [EntryPlayerCell?]()
    private var scoreCell = [EntryScoreCell?]()
    private var instructionLabel: UILabel!
    private var scoreCollection: UICollectionView?
    private var playerCollection: UICollectionView?
    private var flow: Flow!
    private var undo = Flow()
    
    // Local class variables
    private var bidOnlyMode = false
    private var instructionSection = true
    private var firstTime = true
    private var roundSummaryViewController: RoundSummaryViewController!
    
    // Cell sizes
    private let scoreWidth: CGFloat = 50.0
    private var buttonWidth: CGFloat = 0.0
    private var nameWidth: CGFloat = 0.0
    
    // Column descriptors
    private let playerColumn = 0
    private let bidColumn = 1
    private let madeColumn = 2
    private var twosColumn = 0
    private var scoreColumn = 0
    private var columns = 0
 
    // MARK: - IB Outlets ============================================================================== -

    @IBOutlet private weak var toolbarHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var bannerHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var navigationImageHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var footerView: Footer!
    @IBOutlet private weak var footerHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var entryView: UIView!
    @IBOutlet private weak var entryTableView: UITableView!
    @IBOutlet private var footerRoundTitle: [UILabel]!
    @IBOutlet private var undoButton: [RoundedButton]!
    @IBOutlet private var finishButton: [RoundedButton]!
    @IBOutlet private var errorsButton: [RoundedButton]!
    @IBOutlet private var summaryButton: [RoundedButton]!
    
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
        if self.scorecard.scorecardPlayer(self.scorecard.currentPlayers).bid(self.scorecard.selectedRound) != nil {
            self.showRoundSummary()
        }
    }
    
    @IBAction func saveScorePressed(_ sender: Any) {
        if canFinish() {
            self.dismiss()
        }
    }
    
    @IBAction func rightSwipe(recognizer:UISwipeGestureRecognizer) {
        self.saveScorePressed(finishButton!)
    }
        
// MARK: - View Overrides ========================================================================== -
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.view.setNeedsLayout()
        self.entryTableView.reloadData()
        firstTime = true
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        self.scorecard.reCenterPopup(self)
        self.view.setNeedsLayout()
        self.entryTableView.reloadData()
    }

    override func viewWillLayoutSubviews() {
        
        self.setupScreen()
        
        if firstTime {
            self.bidOnlyMode = !self.scorecard.roundBiddingComplete(self.scorecard.selectedRound) ? true : false
            self.setupColumns()
            self.setupFlow()
            self.getInitialState()
        }
        
        self.setForm(!firstTime)
        
        for _ in 1...self.scorecard.roundCards(self.scorecard.selectedRound, rounds: self.rounds, cards: self.cards, bounce: self.bounce) + 1 {
            self.scoreCell.append(nil)
        }
        for _ in 1...self.scorecard.currentPlayers {
            self.playerBidCell.append(nil)
            self.playerMadeCell.append(nil)
            self.playerTwosCell.append(nil)
            self.playerScoreCell.append(nil)
        }
        
        self.summaryButton.forEach { self.scorecard.showSummaryImage($0) }
        
        // Send state to watch
        self.scorecard.watchManager.updateScores()
        
        self.setupSize(to: entryView.safeAreaLayoutGuide.layoutFrame.size)
     
        self.firstTime = false
        
    }

    func setupSize(to size: CGSize) {
        self.nameWidth = size.width - CGFloat(20 + (columns - 1) * 50)
        self.buttonWidth = (ScorecardUI.landscapePhone() ? min(50.0, (ScorecardUI.screenWidth / 10.0) - 12.0) : 50.0)
    }
    
    // MARK: - TableView Overrides ===================================================================== -

    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return self.scorecard.currentPlayers + 1
        case 1:
            return (self.instructionSection ? 1 : 0)
        case 2:
            return 1
        default:
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            return min(ScorecardUI.screenHeight / 7.0, 50.0)
        case 1:
            return 96.0
        case 2:
            return 180.0
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell
        
        switch indexPath.section {

        case 0:
            // Score summary
            let entryPlayerTableCell = tableView.dequeueReusableCell(withIdentifier: "Entry Player Table Cell", for: indexPath) as! EntryPlayerTableCell
            entryPlayerTableCell.setCollectionViewDataSourceDelegate(self, forRow: indexPath.row)
            if indexPath.row==0 {
                Palette.tableTopStyle(view: entryPlayerTableCell)
                entryPlayerTableCell.entryPlayerSeparator.isHidden = true
            } else {
                Palette.normalStyle(entryPlayerTableCell)
            }
            self.playerCollection = entryPlayerTableCell.playerCollection
            cell = entryPlayerTableCell as UITableViewCell
        
        case 1:
            // Instructions
            let instructionCell = tableView.dequeueReusableCell(withIdentifier: "Entry Instruction Cell", for: indexPath) as! EntryInstructionCell
            let frame = CGRect(x: 8.0, y: 16.0, width: instructionCell.frame.width - 16.0, height: instructionCell.frame.height - 32.0)
            instructionCell.hexagonShapeLayer?.removeFromSuperlayer()
            instructionCell.hexagonShapeLayer = Polygon.hexagonFrame(in: instructionCell, frame: frame, strokeColor: Palette.instruction, fillColor: Palette.instruction, radius: 10.0)
            self.instructionLabel = instructionCell.instructionLabel
            self.instructionLabel.superview?.bringSubviewToFront(instructionLabel)
            self.issueInstruction()
            
            cell = instructionCell as UITableViewCell

        default:
            // Score buttons
            let scoreCell = tableView.dequeueReusableCell(withIdentifier: "Entry Score Table Cell", for: indexPath) as! EntryScoreTableCell
            scoreCell.setCollectionViewDataSourceDelegate(self, forRow: indexPath.row)
            self.scoreCollection = scoreCell.scoreCollection
            cell = scoreCell as UITableViewCell
        }
        
        return cell
    }
        
    // MARK: - Form Presentation / Handling Routines =================================================== -
    func setupFlow() {
        // Set up flow of cursor round screen
        self.flow = Flow()
        if self.reeditMode {
            for player in 1...self.scorecard.currentPlayers {
                self.flow.append(player: player, mode: Mode.bid)
                self.flow.append(player: player, mode: Mode.made)
                if self.bonus2 {
                    self.flow.append(player: player, mode: Mode.twos)
                }
            }
        } else {
            for player in 1...self.scorecard.currentPlayers {
                self.flow.append(player: player, mode: Mode.bid)
            }
            if !bidOnlyMode {
                for player in 1...self.scorecard.currentPlayers {
                    self.flow.append(player: player, mode: Mode.made)
                    if self.bonus2 {
                        self.flow.append(player: player, mode: Mode.twos)
                    }
                }
            }
        }
    }
    
    func setupScreen() {
        let title = self.scorecard.roundTitle(self.scorecard.selectedRound, rankColor: Palette.roomInteriorText, rounds: self.rounds, cards: self.cards, bounce: self.bounce)
        footerRoundTitle.forEach { $0.attributedText = title }
        if ScorecardUI.screenHeight < 667.0 || !ScorecardUI.phoneSize() {
            // Smaller than an iPhone 7 portrait or on a tablet
            self.bannerHeightConstraint.constant = 0.0
            self.navigationImageHeightConstraint.constant = 0.0
            self.footerHeightConstraint.constant = 0.0
            self.toolbarHeightConstraint.constant = 44.0
            instructionSection = !ScorecardUI.landscapePhone()
        } else {
            self.bannerHeightConstraint.constant = 44.0
            self.navigationImageHeightConstraint.constant = 44.0 + self.view.safeAreaInsets.top
            self.footerHeightConstraint.constant = 88.0
            self.toolbarHeightConstraint.constant = 0.0
            instructionSection = true
        }
        self.errorsButton.forEach { ScorecardUI.veryRoundCorners($0, radius: $0.frame.width / 2.0) }
    }
    
    func setupColumns() {
        self.twosColumn = (!self.bonus2 ? -1 : 3)
        self.scoreColumn = (!self.bonus2 ? 3 : 4)
        self.columns = (bidOnlyMode ? 2 : (!self.bonus2 ? 4 : 5))
    }
    
    func issueInstruction() {
        if self.selection.player == 0 {
            self.instructionLabel.text = "Tap a player to edit their score"
        } else {
            switch selection.mode {
            case Mode.bid:
                self.instructionLabel.text = "Enter the bid for \(self.scorecard.entryPlayer(selection.player).playerMO!.name!)"
            case Mode.made:
                self.instructionLabel.text = "Enter the tricks made for \(self.scorecard.entryPlayer(selection.player).playerMO!.name!)"
            case Mode.twos:
                self.instructionLabel.text = "Enter the number of 2s for \(self.scorecard.entryPlayer(selection.player).playerMO!.name!)"
            }
        }
    }
    
    func enableMovementButtons() {
        if self.undo.first == nil {
            self.undoButton.forEach { $0.isHidden = true }
        } else {
            self.undoButton.forEach { $0.isHidden = false }
        }
        self.summaryButton.forEach { $0.isEnabled(!bidOnlyMode) }
    }
    
    func setForm(_ tableLoaded: Bool) {
        
        if tableLoaded {
            self.issueInstruction()
        }
        
        if self.scoreCollection != nil {
            for scoreCell in scoreCollection?.visibleCells as! [EntryScoreCell] {
                self.formatScore(scoreCell)
            }
        }
        
        self.enableMovementButtons()
        
        if tableLoaded && self.checkErrors() {
            self.finishButton.forEach { $0.isHidden = true }
            self.errorsButton.forEach { $0.isHidden = false }
        } else {
            self.finishButton.forEach { $0.isHidden = false }
            self.errorsButton.forEach { $0.isHidden = true }
        }
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
            self.scorecard.entryPlayer(selection.player).made(self.scorecard.selectedRound) != nil &&
            scoreCell.scoreButton.tag > self.scorecard.entryPlayer(selection.player).made(self.scorecard.selectedRound)! {
            // Never show more twos than made
            scoreCell.scoreButton.isHidden = true
            
        } else if selection.mode == Mode.twos && scoreCell.scoreButton.tag > self.scorecard.numberSuits {
            // Never show more than 4 twos
            scoreCell.scoreButton.isHidden = true
            
        } else if (selection.mode == Mode.made && scoreCell.scoreButton.tag==self.scorecard.entryPlayer(selection.player).bid(self.scorecard.selectedRound) ||
            self.selection.mode == Mode.twos && scoreCell.scoreButton.tag==0) {
            // Highlight made exactly button and zeros twos button
            scoreCell.scoreButton.isHidden = false
            scoreCell.scoreButton.toCircle()
            
        } else {
            scoreCell.scoreButton.isHidden = false
            scoreCell.scoreButton.toRounded()
        }
        
        
        // Disable specific buttons to avoid error input
        
        switch self.selection.mode {
        case Mode.bid:
            // Last bid must not make bids add up to number of tricks
            
            let remaining = self.scorecard.remaining(playerNumber: self.selection.player, round: self.scorecard.selectedRound, mode: self.selection.mode, rounds: self.rounds, cards: self.cards, bounce: self.bounce)
            
            if  (self.selection.player == self.scorecard.currentPlayers
                && scoreCell.scoreButton.tag == remaining) {
                scoreCell.scoreButton.isEnabled(false)
            } else {
                scoreCell.scoreButton.isEnabled(true)
            }
            
        case Mode.made:
            // Last made must make total made add up to number of tricks and total made must never exceed number of tricks
            
            let remaining = self.scorecard.remaining(playerNumber: selection.player, round: self.scorecard.selectedRound, mode: selection.mode, rounds: self.rounds, cards: self.cards, bounce: self.bounce)
            
            if (self.selection.player == self.scorecard.currentPlayers
                && scoreCell.scoreButton.tag != remaining) ||
                (self.scorecard.entryPlayer(self.scorecard.currentPlayers).made(self.scorecard.selectedRound) == nil && scoreCell.scoreButton.tag > remaining) {
                scoreCell.scoreButton.isEnabled(false)
            } else {
                scoreCell.scoreButton.isEnabled(true)
            }
            
        case Mode.twos:
            // Total number of twos must never exceed the lower of 4 and the number of tricks
            
            let remaining = self.scorecard.remaining(playerNumber: selection.player, round: self.scorecard.selectedRound, mode: selection.mode, rounds: self.rounds, cards: self.cards, bounce: self.bounce)
            
            if (self.selection.player == self.scorecard.currentPlayers || self.scorecard.entryPlayer(self.scorecard.currentPlayers).twos(self.scorecard.selectedRound) == nil) && scoreCell.scoreButton.tag > remaining {
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
            self.scorecard.entryPlayer(selection!.player).value(round: self.scorecard.selectedRound, mode: selection!.mode))
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
            self.scorecard.entryPlayer(selection.player).setBid(self.scorecard.selectedRound, value)
            self.playerBidCell[self.selection.player-1]?.entryPlayerLabel.text = (value == nil  ? "" : "\(value!)")
        case Mode.made:
            self.scorecard.entryPlayer(selection.player).setMade(self.scorecard.selectedRound, value)
            self.playerMadeCell[self.selection.player-1]?.entryPlayerLabel.text = (value == nil  ? "" : "\(value!)")
        case Mode.twos:
            self.scorecard.entryPlayer(selection.player).setTwos(self.scorecard.selectedRound, value, bonus2: self.bonus2)
            self.playerTwosCell[self.selection.player-1]?.entryPlayerLabel.text = (value == nil  ? "" : "\(value!)")
        }
        
        if !self.bidOnlyMode {
            let score = self.scorecard.entryPlayer(self.selection.player).score(self.scorecard.selectedRound)
            self.playerScoreCell[self.selection.player-1]?.entryPlayerLabel.text = (score == nil ? "" : "\(score!)")
        }
    }
    
    func getScore() -> Int! {
        var score: Int!
        
        switch self.selection.mode {
        case Mode.bid:
            score = self.scorecard.entryPlayer(self.selection.player).bid(self.scorecard.selectedRound)
        case Mode.made:
            score = self.scorecard.entryPlayer(self.selection.player).made(self.scorecard.selectedRound)
        case Mode.twos:
            score = self.scorecard.entryPlayer(self.selection.player).twos(self.scorecard.selectedRound)
        }
        
        return score
    }
    
    func canFinish() -> Bool {
        var canFinish = true

            if self.scorecard.roundError(self.scorecard.selectedRound) {
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
        }
    }
    
    func checkErrors() -> Bool {
        var roundError = false
        roundError = errorHighlight(Mode.bid, self.checkError(Mode.bid))
        if !bidOnlyMode {
            roundError = errorHighlight(Mode.made, self.checkError(Mode.made)) || roundError
            if self.bonus2 {
                roundError = errorHighlight(Mode.twos, self.checkError(Mode.twos)) || roundError
            }
        }
        self.scorecard.setRoundError(self.scorecard.selectedRound, roundError)
        
        return roundError
        
    }
    
    func checkError(_ mode: Mode) -> Bool {
        if self.scorecard.entryPlayer(self.scorecard.currentPlayers).value(round: self.scorecard.selectedRound, mode: mode) == nil {
            // Column not yet complete - can't be an error
            return false
        } else {
            switch mode {
            case Mode.bid:
                return self.scorecard.remaining(playerNumber: 0, round: self.self.scorecard.selectedRound, mode: Mode.bid, rounds: self.rounds, cards: self.cards, bounce: self.bounce) == 0
            case Mode.made:
                return self.scorecard.remaining(playerNumber: 0, round: self.scorecard.selectedRound, mode: Mode.made, rounds: self.rounds, cards: self.cards, bounce: self.bounce) != 0
            case Mode.twos:
                return self.scorecard.remaining(playerNumber: 0, round: self.scorecard.selectedRound, mode: Mode.twos, rounds: self.rounds, cards: self.cards, bounce: self.bounce) < 0
            }
        }
    }
    
    func errorDescription(_ mode: Mode) -> String {
        let cards = self.scorecard.roundCards(self.scorecard.selectedRound, rounds: self.rounds, cards: self.cards, bounce: self.bounce)
        
        switch mode {
        case Mode.bid:
            return "Total bids must not equal \(cards). Increase or reduce one of the bids."
        case Mode.made:
            let madeVariance = -self.scorecard.remaining(playerNumber: 0, round: self.scorecard.selectedRound, mode: Mode.made, rounds: self.rounds, cards: self.cards, bounce: self.bounce)
            return "Total tricks made must equal \(cards). \(madeVariance < 0 ? "Increase" : "Reduce") the number of tricks made by exactly \(abs(madeVariance))"
        case Mode.twos:
            let twosVariance = -self.scorecard.remaining(playerNumber: 0, round: self.scorecard.selectedRound, mode: Mode.twos, rounds: self.rounds, cards: self.cards, bounce: self.bounce)
            return "Total twos made must be less than or equal to \(min(self.scorecard.numberSuits, cards)). Reduce the number of twos made by at least \(twosVariance)"
        }
    }
    
    // MARK: - Show round summary =================================================================== -

    private func showRoundSummary() {
    
        self.roundSummaryViewController = RoundSummaryViewController.show(from: self, existing: roundSummaryViewController, rounds: self.rounds, cards: self.cards, bounce: self.bounce, suits: self.suits)
        
    }
    
    // MARK: - Function to present and dismiss this view ==============================================================
    
    class public func show(from viewController: UIViewController, existing entryViewController: EntryViewController! = nil, reeditMode: Bool = false, rounds: Int? = nil, cards: [Int]? = nil, bounce: Bool? = nil, bonus2: Bool? = nil, suits: [Suit]? = nil, completion: ((Bool)->())? = nil) -> EntryViewController {
        
        var entryViewController: EntryViewController! = entryViewController
        
        if entryViewController == nil {
            let storyboard = UIStoryboard(name: "EntryViewController", bundle: nil)
            entryViewController = storyboard.instantiateViewController(withIdentifier: "EntryViewController") as? EntryViewController
        }
        
        entryViewController.modalPresentationStyle = UIModalPresentationStyle.popover
        entryViewController.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
        entryViewController.popoverPresentationController?.sourceView = viewController.popoverPresentationController?.sourceView ?? viewController.view
        entryViewController.popoverPresentationController?.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0 ,height: 0)
        entryViewController.preferredContentSize = CGSize(width: 400, height: Scorecard.shared.scorepadBodyHeight)
        entryViewController.popoverPresentationController?.delegate = viewController as? UIPopoverPresentationControllerDelegate
        
        entryViewController.reeditMode = reeditMode
        entryViewController.rounds = rounds
        entryViewController.cards = cards
        entryViewController.bounce = bounce
        entryViewController.bonus2 = bonus2
        entryViewController.suits = suits
        entryViewController.completion = completion
        
        viewController.present(entryViewController, animated: true, completion: nil)
        
        return entryViewController
    }
    
    private func dismiss(linkToGameSummary: Bool = false) {
        self.dismiss(animated: false, completion: {
            self.completion?(linkToGameSummary)
        })
    }
}

extension EntryViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    // MARK: - CollectionView Overrides ================================================================ -
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        if collectionView.tag < 1000000 {
        // Player summary
            return self.columns
        } else {
            return self.scorecard.roundCards(self.scorecard.selectedRound, rounds: self.rounds, cards: self.cards, bounce: self.bounce) + 1
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let totalHeight: CGFloat = collectionView.bounds.size.height
        var width: CGFloat = 0.0
        var height: CGFloat = 0.0
        
        if collectionView.tag < 1000000 {
            // Player score summary
            let column = indexPath.row
            if column == self.playerColumn {
                // Name
                width = self.nameWidth
            } else {
                // Values
                width = self.scoreWidth
            }
            height = totalHeight
        } else {
            // Score buttons
            
            width = self.buttonWidth
            height = self.buttonWidth
        }
        
        return CGSize(width: width, height: height)
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView.tag<1000000 {
            // Player summary table
        
            let entryPlayerCell = collectionView.dequeueReusableCell(withReuseIdentifier: "Entry Player Cell", for: indexPath) as! EntryPlayerCell
            let playerLabel = entryPlayerCell.entryPlayerLabel!
            let instructionLabel = entryPlayerCell.entryInstructionLabel!
            instructionLabel.text = ""
            let column = indexPath.row
            
            if collectionView.tag==0 {
                // Title row
                switch column {
                case playerColumn:
                    playerLabel.text="Player"
                    playerLabel.textAlignment = .left
                    if !self.instructionSection {
                        self.instructionLabel = instructionLabel
                        entryPlayerCell.entryPlayerWidthConstraint.constant = min(self.nameWidth - 6.0, 64.0)
                        Palette.tableTopStyle(instructionLabel)
                        instructionLabel.textAlignment = .center
                        self.issueInstruction()
                    } else {
                        entryPlayerCell.entryPlayerWidthConstraint.constant = self.nameWidth - 6.0
                    }
                case bidColumn:
                    playerLabel.text="Bid"
                case madeColumn:
                    playerLabel.text="Made"
                case twosColumn:
                    playerLabel.text="Twos"
                default:
                    playerLabel.text="Score"
                }
                Palette.tableTopStyle(playerLabel)
                entryPlayerCell.isUserInteractionEnabled = false
                
            } else {
                // Player row
                let player = collectionView.tag
                entryPlayerCell.tag = player
                Palette.normalStyle(playerLabel, setFont: false)
                entryPlayerCell.entryPlayerWidthConstraint.constant = self.nameWidth - 6.0
                
                switch column {
                case playerColumn:
                    playerLabel.text = self.scorecard.entryPlayer(player).playerMO!.name!
                    playerLabel.textAlignment = .left
                case bidColumn:
                    let bid: Int? = self.scorecard.entryPlayer(player).bid(self.scorecard.selectedRound)
                    playerLabel.text = (bid==nil ? " " : "\(bid!)")
                    playerLabel.textAlignment = .center
                    ScorecardUI.roundCorners(playerLabel)
                    self.playerBidCell[player-1] = entryPlayerCell
                    _ = self.checkErrors()
                    
                case madeColumn:
                    let made: Int? = self.scorecard.entryPlayer(player).made(self.scorecard.selectedRound)
                    playerLabel.text = (made==nil ? " " : "\(made!)")
                    playerLabel.textAlignment = .center
                    ScorecardUI.roundCorners(playerLabel)
                    self.playerMadeCell[player-1] = entryPlayerCell
                    _ = self.checkErrors()

                case twosColumn:
                    let twos: Int? = self.scorecard.entryPlayer(player).twos(self.scorecard.selectedRound)
                    playerLabel.textAlignment = .center
                    playerLabel.text = (twos==nil ? " " : "\(twos!)")
                    ScorecardUI.roundCorners(playerLabel)
                    self.playerTwosCell[player-1] = entryPlayerCell
                    _ = self.checkErrors()
                    
                default:
                    let score: Int? = self.scorecard.entryPlayer(player).score(self.scorecard.selectedRound)
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
        
        if collectionView.tag < 1000000 {
            // Player score summary - should only select if already a value or previous cell already a value
            
            let tappedPlayer = collectionView.tag
            var tappedMode = columnMode(indexPath.row)
            if tappedMode == nil {
                tappedMode = Mode.bid
            }
            let previousSelection: Selection? = flow.find(player: tappedPlayer, mode: tappedMode!).previous
            
            if tappedMode != nil &&
                    (self.scorecard.entryPlayer(tappedPlayer).value(round: self.scorecard.selectedRound, mode: tappedMode!) != nil ||
                        (previousSelection != nil &&
                            self.scorecard.entryPlayer(previousSelection!.player).value(round: self.scorecard.selectedRound, mode: previousSelection!.mode) != nil)) {
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
        if collectionView.tag < 1000000 {
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
        self.scorecard.setGameInProgress(true)
        
        let oldValue = getScore()
        setScore(button.tag)
        
        // Add the current selection to the undo sequence
        undo.append(player: selection.player, mode: selection.mode, oldValue: oldValue)
        
        highlightCursor(false)
        if !moveToNext() {
            if !self.reeditMode && !self.scorecard.roundError(self.scorecard.selectedRound) {
                // Finished - return
                if bidOnlyMode {
                    self.showRoundSummary()
                    self.leaveBidOnlyMode()
                } else {
                    self.scorecard.formatRound(self.scorecard.selectedRound)
                    self.dismiss(linkToGameSummary: self.scorecard.gameComplete(rounds: self.rounds))
                }
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
        setupSize(to: CGSize(width: entryView.frame.width - entryView.safeAreaInsets.left - entryView.safeAreaInsets.right, height: entryView.frame.height))
        entryTableView.reloadData()
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
    @IBOutlet weak var entryInstructionLabel: UILabel!
    @IBOutlet weak var entryPlayerWidthConstraint: NSLayoutConstraint!
}

class EntryInstructionCell: UITableViewCell {
    var hexagonShapeLayer: CAShapeLayer!
    @IBOutlet weak var instructionLabel: UILabel!
}

class EntryScoreTableCell: UITableViewCell {
    
    @IBOutlet weak var scoreCollection: UICollectionView!
    
    func setCollectionViewDataSourceDelegate
        <D: UICollectionViewDataSource & UICollectionViewDelegate>
        (_ dataSourceDelegate: D, forRow row: Int) {
        
        self.scoreCollection.delegate = dataSourceDelegate
        self.scoreCollection.dataSource = dataSourceDelegate
        self.scoreCollection.tag = 1000000 + row
        self.scoreCollection.reloadData()
    }
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
