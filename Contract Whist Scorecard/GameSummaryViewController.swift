//
//  GameSummaryViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 09/01/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

enum GameSummaryReturnMode {
    case resume
    case returnHome
    case newGame
}

class GameSummaryViewController: CustomViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, SyncDelegate, UIPopoverControllerDelegate, ImageButtonDelegate {

    // Main state properties
    internal let scorecard = Scorecard.shared
    private let sync = Sync()
    
    // Properties to pass state
    private var firstGameSummary = false
    private var gameSummaryMode: ScorepadMode!
    private var rounds: Int!
    private var completion: ((GameSummaryReturnMode)->())?
    
    // Constants
    private let stopPlayingTag = 1
    private let playAgainTag = 2
    private let winnersTag = 1
    private let othersTag = 2
    
    // Local class variables
    private var xref: [(playerNumber: Int, score: Int64, place: Int, ranking: Int, personalBest: Bool)] = []
    private var firstTime = true
    private var rotated = false
    private var winners = 0 // Allow for ties
    private var others = 0
    
    // Control heights
    private var winnerWidth: CGFloat = 0.0
    private var winnerCellHeight: CGFloat = 0.0
    private var winnerCellWidth: CGFloat = 0.0
    private var otherWidth: CGFloat = 0.0
    private var otherCellHeight: CGFloat = 0.0
    private var otherCellWidth: CGFloat = 0.0
    private let winnerNameHeight: CGFloat = 35.0
    private let crownHeight: CGFloat = 60.0
    private let otherNameHeight: CGFloat = 30.0
    private let winnerScoreHeight: CGFloat = 40.0
    private let otherScoreHeight: CGFloat = 20.0
    private let winnerSpacing: CGFloat = 30.0
    private let otherSpacing: CGFloat = 20.0
    
    // Completion state
    private var completionMode: GameSummaryReturnMode = .resume
    private var completionAdvanceDealer: Bool = false
    private var completionResetOverrides: Bool = false
    
    // Overrides
    var excludeHistory = false
    var excludeStats = false

    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet weak var syncMessage: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var winnerCollectionView: UICollectionView!
    @IBOutlet weak var winnerCollectionViewWidth: NSLayoutConstraint!
    @IBOutlet weak var otherCollectionView: UICollectionView!
    @IBOutlet weak var otherCollectionViewWidth: NSLayoutConstraint!
    @IBOutlet weak var stopPlayingButton: ImageButton!
    @IBOutlet weak var playAgainButton: ImageButton!
    @IBOutlet weak var scorecardButton: UIButton!
    @IBOutlet weak var leftSwipeGesture: UISwipeGestureRecognizer!
    @IBOutlet weak var rightSwipeGesture: UISwipeGestureRecognizer!
    @IBOutlet weak var tapGesture: UITapGestureRecognizer!
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func scorecardPressed(_ sender: Any) {
        // Unwind to scorepad with current game intact
        self.dismiss()
    }
    
    @IBAction func rightSwipe(recognizer:UISwipeGestureRecognizer) {
        self.playAgainPressed()
    }
    
    @IBAction func lefttSwipe(recognizer:UISwipeGestureRecognizer) {
        self.scorecardPressed(self)
    }
    
    @IBAction func tapGestureReceived(recognizer:UITapGestureRecognizer) {
        self.scorecardPressed(self)
    }
    
    // MARK: - View Overrides ========================================================================== -
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.excludeHistory = (self.scorecard.overrideSelected && self.scorecard.overrideExcludeHistory != nil && self.scorecard.overrideExcludeHistory)
        self.excludeStats = self.excludeHistory || (self.scorecard.overrideSelected && self.scorecard.overrideExcludeStats != nil && self.scorecard.overrideExcludeStats)
        
        if gameSummaryMode != .amend {
            leftSwipeGesture.isEnabled = false
            rightSwipeGesture.isEnabled = false
            self.playAgainButton.isEnabled = false
            self.playAgainButton.alpha = 0.3
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
        self.rotated = true
        scorecard.reCenterPopup(self)
        self.view.setNeedsLayout()
    }
    
    override func viewWillLayoutSubviews() {
        
        if firstTime || rotated {
            self.setupSize()
            firstTime = false
            rotated = false
        }
    }

   // MARK: - TableView Overrides ================================================================ -
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch collectionView.tag {
        case winnersTag:
            return self.winners
        case othersTag:
            return self.scorecard.currentPlayers - winners
        default:
            return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        switch collectionView.tag {
        case winnersTag:
            return CGSize(width: self.winnerCellWidth,
                          height: self.winnerCellHeight)
        case othersTag:
            return CGSize(width: self.otherCellWidth,
                          height: self.otherCellHeight)
        default:
            return CGSize()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        switch collectionView.tag {
        case winnersTag:
            return winnerSpacing
        case othersTag:
            return otherSpacing
        default:
            return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var cell: GameSummaryCollectionCell
        
        let winnersCollection = (collectionView.tag == winnersTag)
        let width = (winnersCollection ? self.winnerCellWidth : self.otherCellWidth)
        let nameHeight = (winnersCollection ? self.winnerNameHeight : self.otherNameHeight)
        let index = indexPath.row + (winnersCollection ? 0 : winners)
        let playerResults = xref[index]
        
        cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Game Summary Cell", for: indexPath) as! GameSummaryCollectionCell
        
        cell.thumbnailView.set(frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: width + nameHeight - 5.0)))
        cell.thumbnailView.set(playerMO: self.scorecard.enteredPlayer(playerResults.playerNumber).playerMO!, nameHeight: nameHeight)
        cell.thumbnailView.set(font: UIFont.systemFont(ofSize: nameHeight * 0.67, weight: .semibold))
        cell.thumbnailView.set(textColor: Palette.roomInteriorTextContrast)
        
        cell.playerScoreButton.setTitle("\(playerResults.score)", for: .normal)
        cell.playerScoreButton.addTarget(self, action: #selector(GameSummaryViewController.selectPlayer(_:)), for: UIControl.Event.touchUpInside)
        cell.playerScoreButton.tag = index
        
        return cell
        
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        let index = indexPath.row + (collectionView.tag == winnersTag ? 0 : winners)
        self.playerSelected(index: index)
    }
    
    @objc private func selectPlayer(_ sender: UIButton) {
        self.playerSelected(index: sender.tag)
    }
        
    private func playerSelected(index: Int) {
        let playerResults = xref[index]
        
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
                self.showHighScores()
            }
        }
    }
    
    // MARK: - Image Button delegate handlers ========================================================== -
    
    internal func imageButtonPressed(_ sender: ImageButton) {
        switch sender.tag {
        case stopPlayingTag:
            self.stopPlayingPressed()
            
        case playAgainTag:
            self.playAgainPressed()
            
        default:
            break
        }
    }
    
    private func stopPlayingPressed() {
        // Unwind to home screen clearing current game
        if !self.scorecard.isViewing {
            UIApplication.shared.isIdleTimerDisabled = false
            if self.scorecard.hasJoined {
                // Link to home via client (no sync)
                self.dismiss(returnMode: .returnHome)
            } else {
                finishGame(from: self, returnMode: .returnHome, resetOverrides: true)
            }
        }
    }
    
    private func playAgainPressed() {
        // Unwind to scorepad clearing current game and advancing dealer
        if gameSummaryMode == .amend {
            finishGame(from: self, returnMode: .newGame, advanceDealer: true, resetOverrides: false)
        }
    }
    
    public func refresh() {
        self.winnerCollectionView.reloadData()
        self.otherCollectionView.reloadData()
    }
    
   // MARK: - Utility Routines ======================================================================== -

    private func setupSize() {
        
        let totalWidth = self.view.safeAreaLayoutGuide.layoutFrame.width
        
        self.winnerCellWidth = min(100.0, (totalWidth - (self.winnerSpacing * (CGFloat(self.winners) + 1))) / CGFloat(self.winners))
        self.winnerCellHeight = self.winnerCellWidth + (self.winnerNameHeight - 5.0) + winnerScoreHeight + crownHeight
        self.winnerWidth = (winnerCellWidth * CGFloat(self.winners)) + (winnerSpacing * CGFloat(self.winners - 1))
        self.winnerCollectionViewWidth.constant = self.winnerWidth
        
        self.otherCellWidth = min(60.0, self.winnerCellWidth - 10.0, (totalWidth - (self.otherSpacing * (CGFloat(self.others) + 1))) / CGFloat(self.others))
        self.otherCellHeight = self.otherCellWidth + self.otherNameHeight + otherScoreHeight
        self.otherWidth = (otherCellWidth * CGFloat(self.others)) + (otherSpacing * CGFloat(self.others - 1))
        self.otherCollectionViewWidth.constant = self.otherWidth
        
    }
    
    private func calculateWinner() {
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
        self.winners = 0
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
        self.others = self.scorecard.currentPlayers - winners
        
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
    
    func finishGame(from: UIViewController, returnMode: GameSummaryReturnMode, advanceDealer: Bool = false, resetOverrides: Bool = true, confirm: Bool = true) {
        
        func finish() {
            self.synchroniseAndReturn(returnMode: returnMode, advanceDealer: advanceDealer, resetOverrides: resetOverrides)
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
    
    func synchroniseAndReturn(returnMode: GameSummaryReturnMode, advanceDealer: Bool = false, resetOverrides: Bool) {
        completionMode = returnMode
        completionAdvanceDealer = advanceDealer
        completionResetOverrides = resetOverrides
        if scorecard.settingSyncEnabled && scorecard.isNetworkAvailable && scorecard.isLoggedIn && !self.excludeHistory && !self.scorecard.isPlayingComputer {
            view.isUserInteractionEnabled = false
            activityIndicator.startAnimating()
            self.sync.delegate = self
            self.scorecardButton.isHidden = true
            _ = self.sync.synchronise(waitFinish: true)
        } else {
            syncCompletion(0)
        }
    }
    
    internal func syncStageComplete(_ stage: SyncStage) {
        Utility.mainThread {
            if let nextStage = SyncStage(rawValue: stage.rawValue + 1) {
                let message = Sync.stageActionDescription(stage: nextStage)
                self.syncMessage.text = "Syncing: \(message)"
            }
        }
    }
    
    internal func syncAlert(_ message: String, completion: @escaping ()->()) {
        self.alertMessage(message, title: "Contract Whist Scorecard", okHandler: {
            completion()
        })
    }
    
    internal func syncCompletion(_ errors: Int) {
        Utility.mainThread {
            self.activityIndicator.stopAnimating()
            self.scorecard.exitScorecard(from: self, advanceDealer: self.completionAdvanceDealer, rounds: self.rounds, resetOverrides: self.completionResetOverrides, completion: {
                self.completion?(self.completionMode)
            })
        }
    }
    
    // MARK: - Show other views ============================================================= -
    
    private func showHighScores() {
        HighScoresViewController.show(from: self, backText: "", backImage: "cross white")
    }
    
    // MARK: - Function to present and dismiss this view ==============================================================
    
    class public func show(from viewController: CustomViewController, firstGameSummary: Bool = false, gameSummaryMode: ScorepadMode? = nil, rounds: Int? = nil, completion: ((GameSummaryReturnMode)->())?) -> GameSummaryViewController {
        
        let storyboard = UIStoryboard(name: "GameSummaryViewController", bundle: nil)
        let gameSummaryViewController: GameSummaryViewController = storyboard.instantiateViewController(withIdentifier: "GameSummaryViewController") as! GameSummaryViewController
 
        gameSummaryViewController.preferredContentSize = CGSize(width: 400, height: Scorecard.shared.scorepadBodyHeight)
        
        gameSummaryViewController.firstGameSummary = firstGameSummary
        gameSummaryViewController.gameSummaryMode = gameSummaryMode
        gameSummaryViewController.rounds = rounds
        gameSummaryViewController.completion = completion
        
        viewController.present(gameSummaryViewController, sourceView: viewController.popoverPresentationController?.sourceView ?? viewController.view, animated: true, completion: nil)
        
        return gameSummaryViewController
    }
    
    private func dismiss(returnMode: GameSummaryReturnMode = .resume) {
        self.dismiss(animated: false, completion: {
            self.completion?(returnMode)
        })
    }
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class GameSummaryCollectionCell: UICollectionViewCell {
    @IBOutlet weak var thumbnailView: ThumbnailView!
    @IBOutlet weak var playerScoreButton: UIButton!
}
