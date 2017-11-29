//
//  EntryViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 30/11/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit

class EntryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    // MARK: - Class Properties ======================================================================== -
    
    // Properties to pass state to / from segues
    var scorecard: Scorecard!
    var reeditMode = false
    var rounds: Int!
    var cards: [Int]!
    var bounce: Bool!
    var bonus2: Bool!
    var suits: [Suit]!
    
    // Main state properties
    var selection = Selection(player: 0, mode: Mode.bid)

    // UI component pointers
    var playerBidCell = [EntryPlayerCell!]()
    var playerMadeCell = [EntryPlayerCell!]()
    var playerTwosCell = [EntryPlayerCell!]()
    var playerScoreCell = [EntryPlayerCell!]()
    var scoreCell = [EntryScoreCell!]()
    var instructionTextView: UITextView!
    var scoreCollection: UICollectionView?
    var playerCollection: UICollectionView?
    var flow: Flow!
    var undo = Flow()
    
    // Local class variables
    var firstTime=true
    var bidOnlyMode = false
    
    // Cell sizes
    let scoreWidth: CGFloat = 50.0
    var nameWidth: CGFloat = 0.0
    
    // Column descriptors
    let playerColumn = 0
    let bidColumn = 1
    let madeColumn = 2
    var twosColumn = 0
    var scoreColumn = 0
    var columns = 0
 
    // MARK: - IB Outlets ============================================================================== -

    @IBOutlet var entryView: UIView!
    @IBOutlet weak var entryTableView: UITableView!
    @IBOutlet weak var barTitle: UILabel!
    @IBOutlet weak var backButton: RoundedButton!
    @IBOutlet weak var forwardButton: RoundedButton!
    @IBOutlet weak var undoButton: RoundedButton!
    @IBOutlet weak var finishButton: RoundedButton!
    @IBOutlet weak var errorsButton: RoundedButton!
    @IBOutlet weak var summaryButton: RoundedButton!
    
    // MARK: - IB Unwind Segue Handlers ================================================================ -
    
    @IBAction func hideRoundSummary(segue:UIStoryboardSegue) {
        let returningAuto = bidOnlyMode
        if returningAuto {
            bidOnlyMode = false
            setupColumns()
            setupFlow()
            selection = flow.find(player: 1, mode: Mode.made)
            setForm(false)
            setupSize(to: entryView.frame.size)
            entryTableView.reloadData()
        }
    }
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func backButtonClicked(_ sender: Any) {
        // Back key
        highlightCursor(false)
        _ = moveToPrevious()
        highlightCursor(true)
        setForm(true)
    }
    
    @IBAction func forwardButtonClicked(_ sender: Any) {
        // Forward key
        highlightCursor(false)
        _ = moveToNext()
        highlightCursor(true)
        setForm(true)
    }

    @IBAction func undoButtonClicked(_ sender: Any) {
        // Undo key
        highlightCursor(false)
        undoLast()
        highlightCursor(true)
        setForm(true)
    }
    
    @IBAction func summaryClicked(_ sender: Any) {
        // Round in toolbar - show summary
        if scorecard.scorecardPlayer(scorecard.currentPlayers).bid(scorecard.selectedRound) != nil {
            self.performSegue(withIdentifier: "showRoundSummary", sender: self )
        }
    }
    
    @IBAction func saveScorePressed(_ sender: Any) {
        if canFinish() {
            self.performSegue(withIdentifier: "hideEntry", sender: self )
        }
    }
    
    @IBAction func rightSwipe(recognizer:UISwipeGestureRecognizer) {
        self.saveScorePressed(finishButton)
    }
        
// MARK: - View Overrides ========================================================================== -
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
                
        setupScreen()
        
        bidOnlyMode = !scorecard.roundBiddingComplete(scorecard.selectedRound) ? true : false
        setupColumns()
        setupFlow()
        getInitialState()
        setForm(false)
        
        for _ in 1...self.scorecard.roundCards(scorecard.selectedRound, rounds: self.rounds, cards: self.cards, bounce: self.bounce) + 1 {
            scoreCell.append(nil)
        }
        for _ in 1...scorecard.currentPlayers {
            playerBidCell.append(nil)
            playerMadeCell.append(nil)
            playerTwosCell.append(nil)
            playerScoreCell.append(nil)
        }
        
        self.scorecard.showSummaryImage(summaryButton)
        
        // Send state to watch
        self.scorecard.watchManager.updateScores()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        scorecard.reCenterPopup(self)
        entryTableView.reloadData()
    }

    override func viewWillLayoutSubviews() {
        
        if firstTime {
            setupSize(to: entryView.frame.size)
            firstTime = false
        }
    }

    func setupSize(to size: CGSize) {
        nameWidth = size.width - CGFloat(20 + (columns - 1) * 50)
    }
    
    // MARK: - TableView Overrides ===================================================================== -

    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return scorecard.currentPlayers + 1
        case 1:
            return 1
        case 2:
            return 1
        default:
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            return 50
        case 1:
            return 80
        case 2:
            return 180
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
                ScorecardUI.bannerStyle(entryPlayerTableCell)
                entryPlayerTableCell.entryPlayerSeparator.isHidden = true
            } else {
                ScorecardUI.normalStyle(entryPlayerTableCell)
            }
            playerCollection = entryPlayerTableCell.playerCollection
            cell = entryPlayerTableCell as UITableViewCell
        
        case 1:
            // Instructions
            let instructionCell = tableView.dequeueReusableCell(withIdentifier: "Entry Instruction Cell", for: indexPath) as! EntryInstructionCell
            instructionTextView = instructionCell.instructionTextView
            formatinstructionTextView()
            issueInstruction()
            
            cell = instructionCell as UITableViewCell

        default:
            // Score buttons
            let scoreCell = tableView.dequeueReusableCell(withIdentifier: "Entry Score Table Cell", for: indexPath) as! EntryScoreTableCell
            scoreCell.setCollectionViewDataSourceDelegate(self, forRow: indexPath.row)
            scoreCollection = scoreCell.scoreCollection
            cell = scoreCell as UITableViewCell
        }
        
        return cell
    }
        
    // MARK: - Form Presentation / Handling Routines =================================================== -
    func setupFlow() {
        // Set up flow of cursor round screen
        flow = Flow()
        if self.reeditMode {
            for player in 1...scorecard.currentPlayers {
                flow.append(player: player, mode: Mode.bid)
                flow.append(player: player, mode: Mode.made)
                if self.bonus2 {
                    flow.append(player: player, mode: Mode.twos)
                }
            }
        } else {
            for player in 1...scorecard.currentPlayers {
                flow.append(player: player, mode: Mode.bid)
            }
            if !bidOnlyMode {
                for player in 1...scorecard.currentPlayers {
                    flow.append(player: player, mode: Mode.made)
                    if self.bonus2 {
                        flow.append(player: player, mode: Mode.twos)
                    }
                }
            }
        }
    }
    
    func formatinstructionTextView() {
        ScorecardUI.largeBoldStyle(instructionTextView)
        ScorecardUI.roundCorners(instructionTextView)
        ScorecardUI.emphasisStyle(instructionTextView)
    }
    
    func setupScreen() {
        barTitle.attributedText = scorecard.roundTitle(scorecard.selectedRound, rounds: self.rounds, cards: self.cards, bounce: self.bounce)
    }
    
    func setupColumns() {
        twosColumn = (!self.bonus2 ? -1 : 3)
        scoreColumn = (!self.bonus2 ? 3 : 4)
        columns = (bidOnlyMode ? 2 : (!self.bonus2 ? 4 : 5))
    }
    
    func issueInstruction() {
        if self.selection.player == 0 {
            instructionTextView.text = "Tap a player to edit their score"
        } else {
            switch selection.mode {
            case Mode.bid:
                instructionTextView.text = "Enter the bid for \(scorecard.entryPlayer(selection.player).playerMO!.name!)"
            case Mode.made:
                instructionTextView.text = "Enter the tricks made for \(scorecard.entryPlayer(selection.player).playerMO!.name!)"
            case Mode.twos:
                instructionTextView.text = "Enter the number of 2s for \(scorecard.entryPlayer(selection.player).playerMO!.name!)"
            }
        }
    }
    
    func enableMovementButtons() {
        if undo.first == nil {
            backButton.isHidden = false
            backButton.isEnabled(selection.previous != nil)
            forwardButton.isHidden = false
            forwardButton.isEnabled(selection.next != nil && currentSelectionValue() != nil)
            undoButton.isHidden = true
        } else {
            undoButton.isHidden = false
            backButton.isHidden = true
            forwardButton.isHidden = true
        }
        summaryButton.isEnabled(!bidOnlyMode)
    }
    
    func setForm(_ tableLoaded: Bool) {
        
        if tableLoaded {
            issueInstruction()
        }
        
        if scoreCollection != nil {
            for scoreCell in scoreCollection?.visibleCells as! [EntryScoreCell] {
                formatScore(scoreCell)
            }
        }
        
        enableMovementButtons()
        
        if tableLoaded && checkErrors() {
            finishButton.isHidden = true
            errorsButton.isHidden = false
        } else {
            finishButton.isHidden = false
            errorsButton.isHidden = true
        }
    }
    
    func errorHighlight(_ mode: Mode, _ highlight: Bool) -> Bool{
        var label: UILabel!
        
        for playerCell: EntryPlayerCell in self.playerBidCell {
            
            let player = playerCell.tag
            
            switch mode {
            case Mode.bid:
                label = playerBidCell[player - 1].entryPlayerLabel
            case Mode.made:
                label = playerMadeCell[player - 1].entryPlayerLabel
            case Mode.twos:
                label = playerTwosCell[player - 1].entryPlayerLabel
            }
            
            ScorecardUI.errorStyle(label!, errorCondtion: highlight)
        }
        
        return highlight
    }
    
    func formatScore(_ scoreCell: EntryScoreCell) {
        if self.selection.player == 0 {
            // No player selected - hide the scores
            scoreCell.scoreButton.isHidden = true
            
        } else if selection.mode == Mode.twos &&
            scorecard.entryPlayer(selection.player).made(scorecard.selectedRound) != nil &&
            scoreCell.scoreButton.tag > scorecard.entryPlayer(selection.player).made(scorecard.selectedRound)! {
            // Never show more twos than made
            scoreCell.scoreButton.isHidden = true
            
        } else if selection.mode == Mode.twos && scoreCell.scoreButton.tag > scorecard.numberSuits {
            // Never show more than 4 twos
            scoreCell.scoreButton.isHidden = true
            
        } else if (selection.mode == Mode.made && scoreCell.scoreButton.tag==scorecard.entryPlayer(selection.player).bid(scorecard.selectedRound) ||
            selection.mode == Mode.twos && scoreCell.scoreButton.tag==0) {
            // Highlight made exactly button and zeros twos button
            scoreCell.scoreButton.isHidden = false
            scoreCell.scoreButton.toCircle()
            
        } else {
            scoreCell.scoreButton.isHidden = false
            scoreCell.scoreButton.toRounded()
        }
        
        
        // Disable specific buttons to avoid error input
        
        switch selection.mode {
        case Mode.bid:
            // Last bid must not make bids add up to number of tricks
            
            let remaining = scorecard.remaining(playerNumber: selection.player, round: scorecard.selectedRound, mode: selection.mode, rounds: self.rounds, cards: self.cards, bounce: self.bounce)
            
            if  (self.selection.player == scorecard.currentPlayers
                && scoreCell.scoreButton.tag == remaining) {
                scoreCell.scoreButton.isEnabled(false)
            } else {
                scoreCell.scoreButton.isEnabled(true)
            }
            
        case Mode.made:
            // Last made must make total made add up to number of tricks and total made must never exceed number of tricks
            
            let remaining = scorecard.remaining(playerNumber: selection.player, round: scorecard.selectedRound, mode: selection.mode, rounds: self.rounds, cards: self.cards, bounce: self.bounce)
            
            if (self.selection.player == scorecard.currentPlayers
                && scoreCell.scoreButton.tag != remaining) ||
                (scorecard.entryPlayer(scorecard.currentPlayers).made(scorecard.selectedRound) == nil && scoreCell.scoreButton.tag > remaining) {
                scoreCell.scoreButton.isEnabled(false)
            } else {
                scoreCell.scoreButton.isEnabled(true)
            }
            
        case Mode.twos:
            // Total number of twos must never exceed the lower of 4 and the number of tricks
            
            let remaining = scorecard.remaining(playerNumber: selection.player, round: scorecard.selectedRound, mode: selection.mode, rounds: self.rounds, cards: self.cards, bounce: self.bounce)
            
            if (self.selection.player == scorecard.currentPlayers || scorecard.entryPlayer(scorecard.currentPlayers).twos(scorecard.selectedRound) == nil) && scoreCell.scoreButton.tag > remaining {
                scoreCell.scoreButton.isEnabled(false)
            } else {
                scoreCell.scoreButton.isEnabled(true)
            }
        }
        
    }
    
    func highlightCursor(_ highlight: Bool) {
        var label: UILabel!
        if selection.player != 0 {
            switch selection.mode {
            case Mode.bid:
                label = playerBidCell[selection.player-1].entryPlayerLabel
            case Mode.made:
                label = playerMadeCell[selection.player-1].entryPlayerLabel
            case Mode.twos:
                label = playerTwosCell[selection.player-1].entryPlayerLabel
            }
            
            if highlight {
                ScorecardUI.darkHighlightStyle(label)
            } else {
                ScorecardUI.normalStyle(label)
            }
        }
    }

    // MARK: - Utility Routines ======================================================================== -

    func currentSelectionValue() -> Int? {
        return selectionValue(selection)
    }
    
    func selectionValue(_ selection: Selection?) -> Int? {
        return selection == nil ? nil :
            scorecard.entryPlayer(selection!.player).value(round: scorecard.selectedRound, mode: selection!.mode)
    }

    func moveToNext() -> Bool{
    
        // Only move forward if current complete and next not end of list
        if currentSelectionValue() != nil && selection.next != nil {
            selection = selection.next!
            return true
        } else {
            return false
        }
    }
    
    func moveToPrevious() -> Bool {
        
        // Only move backward if current complete and previous not end of list
        if selection.previous != nil {
            selection = selection.previous!
            return true
        } else {
            return false
        }
    }
    
    func undoLast() {
        
        // Move to the last value entered
        if undo.last != nil {
            selection = flow.find(player: undo.last!.player, mode: undo.last!.mode)
            setScore(undo.last!.oldValue)
            undo.removeLast()
            enableMovementButtons()
        }
        
    }
    
    func setScore(_ value: Int!) {
        
        switch selection.mode {
        case Mode.bid:
            scorecard.entryPlayer(selection.player).setBid(scorecard.selectedRound, value)
            playerBidCell[selection.player-1].entryPlayerLabel.text = (value == nil  ? "" : "\(value!)")
        case Mode.made:
            scorecard.entryPlayer(selection.player).setMade(scorecard.selectedRound, value)
            playerMadeCell[selection.player-1].entryPlayerLabel.text = (value == nil  ? "" : "\(value!)")
        case Mode.twos:
            scorecard.entryPlayer(selection.player).setTwos(scorecard.selectedRound, value, bonus2: self.bonus2)
            playerTwosCell[selection.player-1].entryPlayerLabel.text = (value == nil  ? "" : "\(value!)")
        }
        
        if !self.bidOnlyMode {
            let score = scorecard.entryPlayer(selection.player).score(scorecard.selectedRound)
            playerScoreCell[selection.player-1].entryPlayerLabel.text = (score == nil ? "" : "\(score!)")
        }
    }
    
    func getScore() -> Int! {
        var score: Int!
        
        switch selection.mode {
        case Mode.bid:
            score = scorecard.entryPlayer(selection.player).bid(scorecard.selectedRound)
        case Mode.made:
            score = scorecard.entryPlayer(selection.player).made(scorecard.selectedRound)
        case Mode.twos:
            score = scorecard.entryPlayer(selection.player).twos(scorecard.selectedRound)
        }
        
        return score
    }
    
    func canFinish() -> Bool {
        var canFinish = true

            if scorecard.roundError(scorecard.selectedRound) {
                var message="This round does not satisfy the following conditions"
                for loopMode in allModes {
                    if checkError(loopMode) {
                        message = "\(message)\n\n\(errorDescription(loopMode))"
                    }
                }
                message="\(message)\n\nYou must correct all errors before exiting"
                let alertController = UIAlertController(title: "Warning", message: message, preferredStyle: UIAlertControllerStyle.alert)
                alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
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
            selection = flow.first!
            while moveToNext() {
            }
        }
    }
    
    func checkErrors() -> Bool {
        var roundError = false
        roundError = errorHighlight(Mode.bid, checkError(Mode.bid))
        if !bidOnlyMode {
            roundError = errorHighlight(Mode.made, checkError(Mode.made)) || roundError
            if self.bonus2 {
                roundError = errorHighlight(Mode.twos, checkError(Mode.twos)) || roundError
            }
        }
        scorecard.setRoundError(scorecard.selectedRound, roundError)
        
        return roundError
        
    }
    
    func checkError(_ mode: Mode) -> Bool {
        if scorecard.entryPlayer(scorecard.currentPlayers).value(round: scorecard.selectedRound, mode: mode) == nil {
            // Column not yet complete - can't be an error
            return false
        } else {
            switch mode {
            case Mode.bid:
                return scorecard.remaining(playerNumber: 0, round: scorecard.selectedRound, mode: Mode.bid, rounds: self.rounds, cards: self.cards, bounce: self.bounce) == 0
            case Mode.made:
                return scorecard.remaining(playerNumber: 0, round: scorecard.selectedRound, mode: Mode.made, rounds: self.rounds, cards: self.cards, bounce: self.bounce) != 0
            case Mode.twos:
                return scorecard.remaining(playerNumber: 0, round: scorecard.selectedRound, mode: Mode.twos, rounds: self.rounds, cards: self.cards, bounce: self.bounce) < 0
            }
        }
    }
    
    func errorDescription(_ mode: Mode) -> String {
        let cards = self.scorecard.roundCards(scorecard.selectedRound, rounds: self.rounds, cards: self.cards, bounce: self.bounce)
        
        switch mode {
        case Mode.bid:
            return "Total bids must not equal \(cards). Increase or reduce one of the bids."
        case Mode.made:
            let madeVariance = -scorecard.remaining(playerNumber: 0, round: scorecard.selectedRound, mode: Mode.made, rounds: self.rounds, cards: self.cards, bounce: self.bounce)
            return "Total tricks made must equal \(cards). \(madeVariance < 0 ? "Increase" : "Reduce") the number of tricks made by exactly \(abs(madeVariance))"
        case Mode.twos:
            let twosVariance = -scorecard.remaining(playerNumber: 0, round: scorecard.selectedRound, mode: Mode.twos, rounds: self.rounds, cards: self.cards, bounce: self.bounce)
            return "Total twos made must be less than or equal to \(min(scorecard.numberSuits, cards)). Reduce the number of twos made by at least \(twosVariance)"
        }
    }
    
    // MARK: - Segue Prepare Handler =================================================================== -

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier! {
            
        case "showRoundSummary":
            
            let destination = segue.destination as! RoundSummaryViewController
            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = self.popoverPresentationController?.sourceView
            destination.preferredContentSize = CGSize(width: 400, height: 554)
            destination.returnSegue = "hideRoundSummary"
            destination.scorecard = self.scorecard
            destination.rounds = self.rounds
            destination.cards = self.cards
            destination.bounce = self.bounce
            destination.suits = self.suits
            
        default:
            break
        }
    }
}

extension EntryViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    // MARK: - CollectionView Overrides ================================================================ -
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        if collectionView.tag < 1000000 {
        // Player summary
            return columns
        } else {
            return scorecard.roundCards(scorecard.selectedRound, rounds: self.rounds, cards: self.cards, bounce: self.bounce) + 1
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
            if column == playerColumn {
                // Name
                width = nameWidth
            } else {
                // Values
                width = scoreWidth
            }
            height = totalHeight
        } else {
            // Score buttons
            
            width = scoreWidth
            height = scoreWidth
        }
        
        return CGSize(width: width, height: height)
    }
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView.tag<1000000 {
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
                ScorecardUI.bannerStyle(playerLabel)
                entryPlayerCell.isUserInteractionEnabled = false
                
            } else {
                // Player row
                let player = collectionView.tag
                entryPlayerCell.tag = player
                ScorecardUI.normalStyle(playerLabel)
                
                switch column {
                case playerColumn:
                    playerLabel.text = scorecard.entryPlayer(player).playerMO!.name!
                    playerLabel.textAlignment = .left
                case bidColumn:
                    let bid: Int? = scorecard.entryPlayer(player).bid(scorecard.selectedRound)
                    playerLabel.text = (bid==nil ? " " : "\(bid!)")
                    playerLabel.textAlignment = .center
                    ScorecardUI.roundCorners(playerLabel)
                    playerBidCell[player-1] = entryPlayerCell
                    
                case madeColumn:
                    let made: Int? = scorecard.entryPlayer(player).made(scorecard.selectedRound)
                    playerLabel.text = (made==nil ? " " : "\(made!)")
                    playerLabel.textAlignment = .center
                    ScorecardUI.roundCorners(playerLabel)
                    playerMadeCell[player-1] = entryPlayerCell

                case twosColumn:
                    let twos: Int? = scorecard.entryPlayer(player).twos(scorecard.selectedRound)
                    playerLabel.textAlignment = .center
                    playerLabel.text = (twos==nil ? " " : "\(twos!)")
                    ScorecardUI.roundCorners(playerLabel)
                    playerTwosCell[player-1] = entryPlayerCell
                    
                default:
                    let score: Int? = scorecard.entryPlayer(player).score(scorecard.selectedRound)
                    playerLabel.textAlignment = .center
                    playerLabel.text = (score==nil ? " " : "\(score!)")
                    playerScoreCell[player-1] = entryPlayerCell
                }
                
                let selectedMode = columnMode(indexPath.row)
                if selectedMode != nil && player == selection.player && selection.mode == selectedMode! {
                    highlightCursor(true)
                } else {
                    ScorecardUI.normalStyle(playerLabel)
                }
                entryPlayerCell.isUserInteractionEnabled = true
               
            }
            
            return entryPlayerCell
        
        } else {
        
            scoreCell[indexPath.row] = collectionView.dequeueReusableCell(withReuseIdentifier: "Entry Score Cell",for: indexPath) as! EntryScoreCell
            ScorecardUI.roundCorners(scoreCell[indexPath.row].scoreButton)
            scoreCell[indexPath.row].scoreButton.setTitle("\(indexPath.row)", for: .normal)
            scoreCell[indexPath.row].scoreButton.addTarget(self, action: #selector(EntryViewController.scoreActionButtonPressed(_:)), for: UIControlEvents.touchUpInside)
            scoreCell[indexPath.row].scoreButton.tag = indexPath.row
            scoreCell[indexPath.row].scoreButton.accessibilityIdentifier = "score\(indexPath.row)"

            formatScore(scoreCell[indexPath.row])
            
            return scoreCell[indexPath.row]
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
                    (scorecard.entryPlayer(tappedPlayer).value(round: scorecard.selectedRound, mode: tappedMode!) != nil ||
                        (previousSelection != nil &&
                            scorecard.entryPlayer(previousSelection!.player).value(round: scorecard.selectedRound, mode: previousSelection!.mode) != nil)) {
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
            selection = flow.find(player: collectionView.tag, mode: mode!)
            highlightCursor(true)
            setForm(true)
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
            if !self.reeditMode && !scorecard.roundError(scorecard.selectedRound) {
                // Finished - return
                if bidOnlyMode {
                    self.performSegue(withIdentifier: "showRoundSummary", sender: self )
                } else if scorecard.gameComplete(rounds: self.rounds) {
                    scorecard.formatRound(scorecard.selectedRound)
                    self.performSegue(withIdentifier: "linkGameSummary", sender: self )
                } else {
                    scorecard.formatRound(scorecard.selectedRound)
                    self.performSegue(withIdentifier: "hideEntry", sender: self )
                }
            } else {
                selection = Selection(player: 0, mode: Mode.bid)
            }
        }
        highlightCursor(true)
        setForm(true)
        
    }
    
    // MARK: - Collection View Utility Routines ===================================================== -
    
    func columnMode(_ column: Int) -> Mode? {
        var columnMode: Mode?
        
        switch column {
        case bidColumn:
            columnMode = Mode.bid
        case madeColumn:
            columnMode = Mode.made
        case twosColumn:
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
        
        playerCollection.delegate = dataSourceDelegate
        playerCollection.dataSource = dataSourceDelegate
        playerCollection.tag = row
        playerCollection.reloadData()
    }
    
}

class EntryPlayerCell: UICollectionViewCell {
    @IBOutlet weak var entryPlayerLabel: UILabel!
}

class EntryInstructionCell: UITableViewCell {
    @IBOutlet weak var instructionTextView: UITextView!
}

class EntryScoreTableCell: UITableViewCell {
    
    @IBOutlet weak var scoreCollection: UICollectionView!
    
    func setCollectionViewDataSourceDelegate
        <D: UICollectionViewDataSource & UICollectionViewDelegate>
        (_ dataSourceDelegate: D, forRow row: Int) {
        
        scoreCollection.delegate = dataSourceDelegate
        scoreCollection.dataSource = dataSourceDelegate
        scoreCollection.tag = 1000000 + row
        scoreCollection.reloadData()
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
        
        map[player-1][element-1] = Selection(player: player, mode: mode, oldValue: oldValue)
        
        if let tailNode = tail {
            
            map[player-1][element-1].previous = tailNode
            tailNode.next = map[player-1][element-1]
        }
        else {
            head = map[player-1][element-1]
        }
        tail = map[player-1][element-1]
    }
    
    func removeLast() {
        if let tailNode = tail {
            tail = tailNode.previous
            if tail == nil {
                head = nil
            } else {
                tail!.next = nil
            }
        }
    }
    
    func find(player: Int, mode: Mode) -> Selection {
        return map[player-1][intMode(mode)-1]
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
