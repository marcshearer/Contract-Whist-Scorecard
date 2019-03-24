//
//  GameSummaryViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 09/01/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

class GameSummaryViewController: CustomViewController, UITableViewDelegate, UITableViewDataSource, SyncDelegate, UIPopoverControllerDelegate {

    // Main state properties
    public var scorecard: Scorecard!
    private let sync = Sync()
    
    // Properties to pass state to / from segues
    public var firstGameSummary = false
    public var gameSummaryMode: ScorepadMode!
    public var rounds: Int!
    
    // Local class variables
    private var xref: [(playerNumber: Int, score: Int64, place: Int, ranking: Int, personalBest: Bool)] = []
    private var firstTime = true
    private var winners = 0 // Allow for ties
    
    // Control heights
    private let headerHeight: CGFloat = 140
    private let winnerHeight: CGFloat = 80
    private let separatorHeight: CGFloat = 30
    private let othersHeight: CGFloat = 50
    private var trailerHeight: CGFloat = 80
    private let defaultTrailerHeight: CGFloat = 100
    private var completionToSegue: String = ""
    private var completionAdvanceDealer: Bool = false
    private var completionResetOverrides: Bool = false
    
    // Overrides
    var excludeHistory = false
    var excludeStats = false

    // MARK: - IB Unwind Segue Handlers ================================================================ -
    
    @IBAction func returnGameSummary(segue:UIStoryboardSegue) {
    }

    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet weak var gameSummaryView: UIView!
    @IBOutlet weak var syncMessage: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var leftSwipeGesture: UISwipeGestureRecognizer!
    @IBOutlet weak var rightSwipeGesture: UISwipeGestureRecognizer!
    @IBOutlet weak var tapGesture: UITapGestureRecognizer!
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func scorecardPressed(_ sender: Any) {
        // Unwind to scorepad with current game intact
        self.performSegue(withIdentifier: "hideGameSummary", sender: self)
    }
    
    @IBAction func homePressed(_ sender: Any) {
        // Unwind to home screen clearing current game
        if !self.scorecard.isViewing {
            UIApplication.shared.isIdleTimerDisabled = false
            var toSegue: String
            if self.scorecard.hasJoined {
                // Link to home via client (no sync)
                self.performSegue(withIdentifier: "linkFinishGame", sender: self)
            } else {
                if self.scorecard.isHosting {
                    // Sync and link to home screen via host
                    toSegue = "linkFinishGame"
                } else {
                    // Sync and link straight to home screen
                    toSegue = "finishGame"
                }
                finishGame(from: self, toSegue: toSegue, resetOverrides: true)
            }
        }
    }
    
    @IBAction func newGamePressed(_ sender: Any) {
        // Unwind to scorepad clearing current game and advancing dealer
        if gameSummaryMode == .amend {
            finishGame(from: self, toSegue: "newGame", advanceDealer: true, resetOverrides: false)
        }
    }
    
    @IBAction func leftSwipe(recognizer:UISwipeGestureRecognizer) {
        self.newGamePressed(self)
    }
    
    @IBAction func rightSwipe(recognizer:UISwipeGestureRecognizer) {
        self.scorecardPressed(self)
    }
    
    @IBAction func tapGestureReceived(recognizer:UITapGestureRecognizer) {
        self.scorecardPressed(self)
    }
    
    // MARK: - View Overrides ========================================================================== -
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sync.initialise(scorecard: scorecard)
        
        self.excludeHistory = (self.scorecard.overrideSelected && self.scorecard.overrideExcludeHistory != nil && self.scorecard.overrideExcludeHistory)
        self.excludeStats = self.excludeHistory || (self.scorecard.overrideSelected && self.scorecard.overrideExcludeStats != nil && self.scorecard.overrideExcludeStats)
        
        if gameSummaryMode != .amend {
            leftSwipeGesture.isEnabled = false
            rightSwipeGesture.isEnabled = false
        }
        if self.scorecard.hasJoined || self.gameSummaryMode == .amend {
            // Disable tap gesture as individual buttons active
            tapGesture.isEnabled = false
        }
        
        // Work out who's won
        calculateWinner()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if self.scorecard.commsHandlerMode == .gameSummary {
            // Notify client controller that game summary display complete
            self.scorecard.commsHandlerMode = .none
            NotificationCenter.default.post(name: .clientHandlerCompleted, object: self, userInfo: nil)
        }
        self.autoNewGame()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        scorecard.reCenterPopup(self)
        self.view.setNeedsLayout()
    }
    
    override func viewWillLayoutSubviews() {
        
        if firstTime {
            // Calculate heights
            calculateHeights(size: gameSummaryView.safeAreaLayoutGuide.layoutFrame.size)
            firstTime = false
        }
    }

   // MARK: - TableView Overrides ================================================================ -
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        switch section{
        case 0:
            // Crown header
            return 1
        case 1:
            // Players
            return scorecard.currentPlayers
        case 2:
            // Footer
            return 1
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            // Header
            return headerHeight
        case 1:
            //Players
            switch xref[indexPath.row].place {
            case 1:
                if indexPath.row + 1 == winners {
                    // Last winner - add some extra height
                    return winnerHeight + separatorHeight
                } else {
                    return winnerHeight
                }
            default:
                return othersHeight
            }
        case 2:
            // Footer
            return trailerHeight
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell: GameSummaryTableCell
        
        switch indexPath.section {
        case 0: // Header
            cell = tableView.dequeueReusableCell(withIdentifier: "Game Summary Header", for: indexPath) as! GameSummaryTableCell

        case 1: // Players
        // Player names
            let playerResults = xref[indexPath.row]
            let playerNumber = playerResults.playerNumber
            
            let reuseIdentifier = "Game Summary " + (playerResults.place == 1 ? "Winner" : "Others")
            cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! GameSummaryTableCell
            
            // Setup the thumbnail picture
            var thumbnail: Data?
            if let playerDetail = scorecard.enteredPlayer(playerNumber).playerMO {
                if playerDetail.thumbnail != nil {
                    thumbnail = playerDetail.thumbnail! as Data
                }
            }
            
            Utility.setThumbnail(data: thumbnail,
                                 imageView: cell.playerThumbnail,
                                 initials: scorecard.enteredPlayer(playerNumber).playerMO!.name!,
                                 label: cell.playerDisc)
            // Setup name and score
            cell.playerName.text  = scorecard.enteredPlayer(playerNumber).playerMO!.name!
            cell.playerScore.text = "\(scorecard.enteredPlayer(playerNumber).totalScore())"
            if !self.scorecard.isPlayingComputer {
                // Setup high score / PB icon
                if playerResults.ranking != 0 {
                    cell.playerImage.image = UIImage(named: "high score \(playerResults.ranking)")
                } else if playerResults.personalBest {
                    cell.playerImage.image = UIImage(named: "personal best")
                } else {
                    cell.playerImage.image = nil
                }
            } else {
                cell.playerImage.image = nil
            }
            cell.playerScore.accessibilityIdentifier = "player\(indexPath.row+1)total"
            
        default:
            // Footer
            cell = tableView.dequeueReusableCell(withIdentifier: "Game Summary Footer", for: indexPath) as! GameSummaryTableCell
            if self.scorecard.isViewing {
                // Don't allow exit if viewing
                cell.homeButton.isEnabled = false
            }
            if self.gameSummaryMode != .amend {
                // Only allow new game if hosting or ordinary scoring (not joining or viewing)
                cell.newGameButton.isEnabled = false
            }
            
        }
        
        
        // Show selected cell in same color as deselected
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor.clear
        cell.selectedBackgroundView = backgroundView

        return cell

    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if indexPath.section < 2 && gameSummaryMode == .amend && !self.scorecard.isPlayingComputer {
            return indexPath
        } else {
            return nil
        }
    }
   
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if gameSummaryMode == .amend {
            if indexPath.section == 1 {
                // Players section
                let playerResults = xref[indexPath.row]
                if playerResults.personalBest {
                    let playerNumber = playerResults.playerNumber
                    var message: String

                    // New PB / First Timer
                    let name = scorecard.enteredPlayer(playerNumber).playerMO?.name!
                    if scorecard.enteredPlayer(playerNumber).previousMaxScore == 0 {
                        // First timer
                        message = "Congratulations \(name!) on completing your first game.\n\nYour score was \(playerResults.score)."
                    } else {
                        // PB - - show previous one
                        let formatter = DateFormatter()
                        formatter.setLocalizedDateFormatFromTemplate("dd/MM/yyyy")
                        let date = formatter.string(from: scorecard.enteredPlayer(playerNumber).previousMaxScoreDate)
                        message = "Congratulations \(name!) on your new personal best of \(playerResults.score).\n\nYour previous best was \(scorecard.enteredPlayer(playerNumber).previousMaxScore) which you achieved on \(date)"
                    }
                    let alertController = UIAlertController(title: "Congratulations", message: message, preferredStyle: UIAlertController.Style.alert)
                    alertController.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
                    present(alertController, animated: true, completion: nil)
                } else {
                    // Not a PB - Link to high scores
                    if self.scorecard.settingSaveHistory {
                        self.performSegue(withIdentifier: "showHighScores", sender: self)
                    }
                }
            } else if indexPath.section == 0 {
                // Crown image - Link to high scores
                if self.scorecard.settingSaveHistory {
                    self.performSegue(withIdentifier: "showHighScores", sender: self)
                }
            }
        }
    }
    
    // MARK: - Form Presentation / Handling Routines =================================================== -

    func calculateHeights(size: CGSize) {
        let totalHeight = headerHeight + (CGFloat(winners) * winnerHeight) + separatorHeight + CGFloat(scorecard.currentPlayers - winners) * othersHeight + defaultTrailerHeight
        if totalHeight < size.height {
            // Just add it to the footer
            trailerHeight = size.height - totalHeight + defaultTrailerHeight
            tableView.isScrollEnabled = false
        } else {
            trailerHeight = defaultTrailerHeight
            tableView.isScrollEnabled = true
        }
    }
    
    public func refresh() {
        tableView.reloadData()
    }
    
    // MARK: - Utility Routines ======================================================================== -

    func calculateWinner() {
        struct HighScoreEntry {
            var gameUUID: String
            var email: String
            var totalScore: Int16
        }

        var highScoreParticipantMO: [ParticipantMO]!
        var highScoreEntry: [HighScoreEntry] = []
        var highScoreRanking: [Int] = []
        var newHighScore = false
        var winnerNames = ""
        var winnerEmail = ""
        
        // Clear cross reference array
        xref.removeAll()
    
        if !self.excludeStats && !self.excludeHistory && !self.scorecard.isPlayingComputer {
            if self.scorecard.settingSaveHistory {
                // Load high scores - get 10 to allow for lots of ties
                // Note - this assumes this game's participants have been placed in the database already
                highScoreParticipantMO = History.getHighScores(type: .totalScore, limit: 10, playerEmailList: self.scorecard.playerEmailList(getPlayerMode: .getAll))
                for participant in highScoreParticipantMO {
                    highScoreEntry.append(HighScoreEntry(gameUUID: participant.gameUUID!, email: participant.email!, totalScore: participant.totalScore))
                }
            }
            
            if gameSummaryMode != .amend || !self.scorecard.settingSaveHistory {
                // Need to add current game since not written on this device
                for playerNumber in 1...scorecard.currentPlayers {
                    highScoreEntry.append(HighScoreEntry(gameUUID: (scorecard.gameUUID==nil ? "" : scorecard.gameUUID),
                                                         email: scorecard.enteredPlayer(playerNumber).playerMO!.email!,
                                                         totalScore: Int16(scorecard.enteredPlayer(playerNumber).totalScore())))
                }
            }
            
            // Sort high score entries
            highScoreEntry.sort(by: { $0.totalScore > $1.totalScore })
            
            // Now resolve ties
            var lastRanking = 0
            for loopCount in 1...highScoreEntry.count {
                if loopCount == 1 || highScoreEntry[loopCount - 1].totalScore != highScoreEntry[loopCount - 2].totalScore {
                    // New score
                    lastRanking = loopCount
                }
                if lastRanking > 3 {
                    break
                }
                highScoreRanking.append(lastRanking)
            }
        }
        
        // Check for high scores and PBs and create cross-reference
        for playerNumber in 1...scorecard.currentPlayers {
            var personalBest = false
            let score = Int64(scorecard.enteredPlayer(playerNumber).totalScore())
            var ranking = 0
            
            if !self.excludeStats && !self.excludeHistory && !self.scorecard.isPlayingComputer {
                for loopCount in 1...highScoreRanking.count {
                    // No need to check if already got a high place
                    if self.scorecard.settingSaveHistory && ranking == 0 {
                        // Check if it is a score for this player
                        if highScoreEntry[loopCount-1].email == scorecard.enteredPlayer(playerNumber).playerMO?.email {
                            // Check that it is this score that has done it - not an old one
                            if highScoreEntry[loopCount-1].gameUUID == (scorecard.gameUUID==nil ? "" : scorecard.gameUUID) {
                                ranking = highScoreRanking[loopCount - 1]
                                if ranking == 1 {
                                    newHighScore = true
                                }
                            }
                        }
                    }
                
                    if ranking == 0 {
                        let previousPersonalBest = scorecard.enteredPlayer(playerNumber).previousMaxScore
                        personalBest = (score > previousPersonalBest)
                    }
                }
            }

            xref.append((playerNumber, score, 0, ranking, personalBest))
        }
            
        // Sort players
        xref.sort(by: { $0.score > $1.score })
        
        // Now fill in places
        var place = 0
        winners = 0
        for playerNumber in 1...scorecard.currentPlayers {
            if playerNumber == 1 || xref[playerNumber - 2].score != xref[playerNumber - 1].score {
                place = playerNumber
            }
            xref[playerNumber - 1].place = place
            if place == 1 {
                winners += 1
                if winners == 1 {
                    winnerEmail = self.scorecard.enteredPlayer(xref[playerNumber-1].playerNumber).playerMO!.email!
                    winnerNames = self.scorecard.enteredPlayer(xref[playerNumber-1].playerNumber).playerMO!.name!
                } else {
                    winnerNames = winnerNames + " and " + self.scorecard.enteredPlayer(xref[playerNumber-1].playerNumber).playerMO!.name!
                }
            }
        }
        if firstGameSummary && gameSummaryMode == .amend {
            // Save notification message
            self.saveGameNotification(newHighScore: newHighScore, winnerEmail: winnerEmail, winner: winnerNames, winningScore: Int(xref[0].score))
        }
    }
    
    public func saveGameNotification(newHighScore: Bool, winnerEmail: String, winner: String, winningScore: Int) {
        if self.scorecard.settingSyncEnabled && self.scorecard.isNetworkAvailable && self.scorecard.isLoggedIn && !self.excludeHistory && !self.scorecard.isPlayingComputer {
            var message = ""
            
            for playerNumber in 1...self.scorecard.currentPlayers {
                let name = self.scorecard.enteredPlayer(playerNumber).playerMO!.name!
                if playerNumber == 1 {
                    message = name
                } else if playerNumber == self.scorecard.currentPlayers {
                    message = message + " and " + name
                    
                } else {
                    message = message + ", " + name
                }
            }
            
            let locationDescription = self.scorecard.gameLocation.description
            message = message + " just finished a game of Contract Whist"
            if locationDescription != nil && locationDescription! != "" {
                if locationDescription == "Online" {
                    message = message + " online"
                } else {
                    message = message + " in " + locationDescription!
                }
            }
            message = message + ". " + winner + " won with a score of \(winningScore)."
            
            if newHighScore {
                message = message + " This was a new high score! Congratulations \(winner)."
            }
            
            Notifications.updateHighScoreNotificationRecord(winnerEmail: winnerEmail, message: message)
        }
    }
    
    func finishGame(from: UIViewController, toSegue: String, advanceDealer: Bool = false, resetOverrides: Bool = true, confirm: Bool = true) {
        
        func finish() {
            self.synchroniseAndSegueTo(toSegue: toSegue, advanceDealer: advanceDealer, resetOverrides: resetOverrides)
        }
        
        if confirm {
            var message: String
            if self.excludeHistory || !self.scorecard.settingSaveHistory {
                message = "If you continue you will not be able to return to this game.\n\n Are you sure you want to do this?"
            } else {
                message = "Your game has been saved. However if you continue you will not be able to return to it.\n\n Are you sure you want to do this?"
            }
            let alertController = UIAlertController(title: "Finish Game", message: message, preferredStyle: UIAlertController.Style.alert)
            alertController.addAction(UIAlertAction(title: "Confirm", style: UIAlertAction.Style.default,
                                                    handler: { (action:UIAlertAction!) -> Void in
                finish()
            }))
            alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel,
                                                    handler:nil))
            from.present(alertController, animated: true, completion: nil)
        } else {
            finish()
        }
    }

    // MARK: - Sync routines including the delegate methods ======================================== -
    
    func synchroniseAndSegueTo(toSegue: String, advanceDealer: Bool = false, resetOverrides: Bool) {
        completionToSegue = toSegue
        completionAdvanceDealer = advanceDealer
        completionResetOverrides = resetOverrides
        if scorecard.settingSyncEnabled && scorecard.isNetworkAvailable && scorecard.isLoggedIn && !self.excludeHistory && !self.scorecard.isPlayingComputer {
            view.isUserInteractionEnabled = false
            activityIndicator.startAnimating()
            self.sync.delegate = self
            if self.sync.connect() {
                self.syncMessage("Started...")
                self.sync.synchronise()
            } else {
                self.alertMessage("Error syncing scores. Try later.")
            }
        } else {
            syncCompletion(0)
        }
    }
    
    func syncMessage(_ message: String) {
        Utility.mainThread {
            self.syncMessage.text = "Syncing: \(message)"
        }
    }
    
    func syncAlert(_ message: String, completion: @escaping ()->()) {
        self.alertMessage(message, title: "Contract Whist Scorecard", okHandler: {
            completion()
        })
    }
    
    func syncCompletion(_ errors: Int) {
        Utility.mainThread {
            self.activityIndicator.stopAnimating()
            self.scorecard.exitScorecard(from: self, toSegue: self.completionToSegue, advanceDealer: self.completionAdvanceDealer, rounds: self.rounds,                resetOverrides: self.completionResetOverrides)
        }
    }
    
    func syncReturnPlayers(_ playerList: [PlayerDetail]!) {
    }

    // MARK: - Segue Prepare Handler =================================================================== -
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier! {
        
        case "showHighScores":
            
            let destination = segue.destination as! HighScoresViewController
            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = self.popoverPresentationController?.sourceView
            destination.preferredContentSize = CGSize(width: 400, height: 554)
            destination.returnSegue = "returnGameSummary"
            destination.scorecard = self.scorecard
            
        default:
            break
        }
    }
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class GameSummaryTableCell: UITableViewCell {
    @IBOutlet weak var playerThumbnail: UIImageView!
    @IBOutlet weak var playerDisc: UILabel!
    @IBOutlet weak var playerName: UILabel!
    @IBOutlet weak var playerScore: UILabel!
    @IBOutlet weak var playerImage: UIImageView!
    @IBOutlet weak var scorecardButton: UIButton!
    @IBOutlet weak var homeButton: UIButton!
    @IBOutlet weak var newGameButton: UIButton!
}
