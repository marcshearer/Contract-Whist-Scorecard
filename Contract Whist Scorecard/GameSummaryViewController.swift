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

class GameSummaryViewController: ScorecardViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, SyncDelegate, UIPopoverControllerDelegate, ButtonDelegate {

    // Main state properties
    private let sync = Sync()
    
    // Properties to pass state
    private var gameSummaryMode: ScorepadMode!
    
    // Constants
    private let stopPlayingTag = 1
    private let playAgainTag = 2
    private let winnersTag = 1
    private let othersTag = 2
    private let awardsTag = 3
    
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
    private var winnerCrownHeight: CGFloat = 50.0
    private var winnerImageHeight: CGFloat = 100.0
    private var winnerNameHeight: CGFloat = 40.0
    private var winnerScoreHeight: CGFloat = 30.0
    private var otherImageHeight: CGFloat = 60.0
    private var otherNameHeight: CGFloat = 24.0
    private var otherScoreHeight: CGFloat = 20.0
    private let winnerSpacing: CGFloat = 30.0
    private let otherSpacing: CGFloat = 20.0
    private let awardSpacing: CGFloat = 10.0
    private let awardNameHeight: CGFloat = 10.0
    private var awardCellSize = CGSize()
    private let awardMaxList = 1
    private let awards = Awards()
    private var awardList: [Award] = []
    
    // Completion state
    private var completionMode: GameSummaryReturnMode = .resume
    private var completionAdvanceDealer: Bool = false
    private var completionResetOverrides: Bool = false
    
    // Overrides
    var excludeHistory = false
    var excludeStats = false

    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var topArea: UIView!
    @IBOutlet private weak var middleArea: UIView!
    @IBOutlet private weak var bottomArea: UIView!
    @IBOutlet private weak var actionButtonView: UIView!
    @IBOutlet private var actionButtonViewHeight: NSLayoutConstraint!
    @IBOutlet private weak var syncMessage: UILabel!
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet private weak var winnerCollectionView: UICollectionView!
    @IBOutlet private weak var winnerCollectionViewWidth: NSLayoutConstraint!
    @IBOutlet private weak var winnerCollectionViewHeight: NSLayoutConstraint!
    @IBOutlet private weak var otherCollectionView: UICollectionView!
    @IBOutlet private weak var otherCollectionViewWidth: NSLayoutConstraint!
    @IBOutlet private weak var otherCollectionViewHeight: NSLayoutConstraint!
    @IBOutlet private weak var awardsTitleBar: TitleBar!
    @IBOutlet private weak var awardsTitleBarHeight: NSLayoutConstraint!
    @IBOutlet private weak var awardsCollectionView: UICollectionView!
    @IBOutlet private weak var awardsCollectionViewHeight: NSLayoutConstraint!
    @IBOutlet private weak var playAgainButton: ImageButton!
    @IBOutlet private var actionButtons: [ImageButton]!
    @IBOutlet private weak var scorecardButton: UIButton!
    @IBOutlet private weak var rightSwipeGesture: UISwipeGestureRecognizer!
    @IBOutlet private weak var tapGesture: UITapGestureRecognizer!
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func scorecardPressed(_ sender: Any) {
        // Unwind to scorepad with current game intact
        self.controllerDelegate?.didCancel()
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
        
        // Setup default colors (previously done in StoryBoard)
        self.defaultViewColors()

        // Setup awards
        self.setupAwards()
        
        // Check exclusions
        self.excludeHistory = !Scorecard.activeSettings.saveHistory
        self.excludeStats = self.excludeHistory || !Scorecard.activeSettings.saveStats
        
        // Setup buttons / swipes
        if gameSummaryMode != .scoring && gameSummaryMode != .hosting {
            self.playAgainButton.isEnabled = false
            self.playAgainButton.alpha = 0.3
        }
        
        // Setup tap gesture
        if gameSummaryMode != .viewing {
            // Disable tap gesture as individual buttons active
            tapGesture.isEnabled = false
        }
        
        // Work out who's won
        calculateWinner()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.autoNewGame()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.rotated = true
        Scorecard.shared.reCenterPopup(self)
        self.view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.topArea.layoutIfNeeded()
        self.middleArea.layoutIfNeeded()
        self.bottomArea.layoutIfNeeded()
        self.setupSize()
        self.winnerCollectionView.reloadData()
        self.awardsCollectionView.reloadData()
        firstTime = false
        rotated = false
        
        self.awardsTitleBar.set(title: (awardList.isEmpty ? "No New Awards" : "New Awards"))
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
            return Scorecard.game.currentPlayers - winners
        case awardsTag:
            return self.awardList.count
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
            
        case awardsTag:
            return self.awardCellSize
            
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
        case awardsTag:
            return awardSpacing
        default:
            return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if collectionView.tag != awardsTag {
            var cell: GameSummaryPlayerCollectionCell
            
            let winnersCollection = (collectionView.tag == winnersTag)
            let width = (winnersCollection ? self.winnerCellWidth : self.otherCellWidth)
            let crownHeight = (winnersCollection ? self.winnerCrownHeight : 0)
            let imageHeight = (winnersCollection ? self.winnerImageHeight : self.otherImageHeight)
            let nameHeight = (winnersCollection ? self.winnerNameHeight : self.otherNameHeight)
            let scoreHeight = (winnersCollection ? self.winnerScoreHeight : self.otherScoreHeight)
            let index = indexPath.row + (winnersCollection ? 0 : winners)
            let playerResults = xref[index]
            
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Game Summary Cell", for: indexPath) as! GameSummaryPlayerCollectionCell
            
            cell.crownHeight?.constant = crownHeight
            cell.scoreHeight.constant = scoreHeight
            cell.playerViewHeight.constant = imageHeight + (nameHeight - 5.0)
            
            cell.thumbnailView.set(frame: CGRect(x: 0.0, y: crownHeight, width: width, height: width + nameHeight - 5.0))
            cell.thumbnailView.set(playerMO: Scorecard.game.player(enteredPlayerNumber: playerResults.playerNumber).playerMO!, nameHeight: nameHeight)
            cell.thumbnailView.set(font: UIFont.systemFont(ofSize: nameHeight * 0.7, weight: .semibold))
            cell.thumbnailView.set(textColor: Palette.roomInterior.contrastText)
            
            cell.playerScoreButton.setTitle("\(playerResults.score)", for: .normal)
            cell.thumbnailView.set(font: UIFont.systemFont(ofSize: nameHeight * 0.7, weight: .semibold))
            
            cell.playerScoreButton.addTarget(self, action: #selector(GameSummaryViewController.selectPlayer(_:)), for: UIControl.Event.touchUpInside)
            cell.playerScoreButton.titleLabel?.font = UIFont.systemFont(ofSize: scoreHeight * 1.2, weight: .semibold)
            cell.playerScoreButton.tag = index
            
            return cell
            
        } else {
            var cell: AwardCollectionCell
            
            cell = AwardCollectionCell.dequeue(collectionView, for: indexPath, mode: (awardList.count <= self.awardMaxList ? .list : .grid))
            cell.bind(award: awardList[indexPath.row], showBadge: true)
        
            return cell
        }
        
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        if collectionView.tag != self.awardsTag {
            let index = indexPath.row + (collectionView.tag == winnersTag ? 0 : winners)
            self.playerSelected(index: index)
        } else {
            let awardView = AwardDetailView(frame: self.view.frame)
            let award = self.awardList[indexPath.row]
            awardView.set(awards: self.awards, playerUUID: Scorecard.settings.thisPlayerUUID, award: award, mode: .awarding, backgroundColor: Palette.buttonFace.background, textColor: Palette.buttonFace.text)
            awardView.show(from: self.view)
        }
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
            let name = Scorecard.game.player(enteredPlayerNumber: playerNumber).playerMO?.name!
            if Scorecard.game.player(enteredPlayerNumber: playerNumber).previousMaxScore == 0 {
                // First timer
                message = "Congratulations \(name!) on completing your first game.\n\nYour score was \(playerResults.score)."
            } else {
                // PB - - show previous one
                let formatter = DateFormatter()
                formatter.setLocalizedDateFormatFromTemplate("dd/MM/yyyy")
                let date = formatter.string(from: Scorecard.game.player(enteredPlayerNumber: playerNumber).previousMaxScoreDate)
                message = "Congratulations \(name!) on your new personal best of \(playerResults.score).\n\nYour previous best was \(Scorecard.game.player(enteredPlayerNumber: playerNumber).previousMaxScore) which you achieved on \(date)"
            }
            let alertController = UIAlertController(title: "Congratulations", message: message, preferredStyle: UIAlertController.Style.alert)
            alertController.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
            present(alertController, animated: true, completion: nil)
        } else {
            // Not a PB - Link to high scores
            if Scorecard.activeSettings.saveHistory {
                self.showHighScores()
            }
        }
    }
    
    // MARK: - Image Button delegate handlers ========================================================== -
    
    internal func buttonPressed(_ sender: UIView) {
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
        if gameSummaryMode != .viewing {
            UIApplication.shared.isIdleTimerDisabled = false
            if gameSummaryMode == .joining {
                // Link to home via client (no sync)
                self.controllerDelegate?.didProceed()
            } else {
                self.finishGame(returnMode: .returnHome, resetOverrides: true, confirm: self.gameSummaryMode == .scoring)
            }
        }
    }
    
    private func playAgainPressed() {
        // Unwind to scorepad clearing current game and advancing dealer
        if gameSummaryMode == .scoring || gameSummaryMode == .hosting {
            self.finishGame(returnMode: .newGame, advanceDealer: true, resetOverrides: false, confirm: self.gameSummaryMode == .scoring)
        }
    }
    
    public func refresh() {
        self.winnerCollectionView.reloadData()
        self.otherCollectionView.reloadData()
    }
    
   // MARK: - Utility Routines ======================================================================== -

    private func setupSize() {
        
        let totalWidth = self.topArea.frame.width
        var totalHeight = self.topArea.frame.height - 10.0
        var idealHeight = self.winnerCrownHeight + self.winnerImageHeight + self.winnerNameHeight - 5.0 + self.winnerScoreHeight
        if totalHeight < idealHeight {
            let factor = totalHeight / idealHeight
            self.winnerCrownHeight *= factor
            self.winnerNameHeight *= factor
            self.winnerImageHeight *= factor
            self.winnerScoreHeight *= factor
        }
                
        self.winnerCellWidth = min(100.0, (totalWidth - (self.winnerSpacing * (CGFloat(self.winners) + 1))) / CGFloat(self.winners), self.winnerImageHeight)
        self.winnerImageHeight = self.winnerCellWidth
        self.winnerCellHeight = self.winnerImageHeight + (self.winnerNameHeight - 5.0) + self.winnerScoreHeight + self.winnerCrownHeight
        self.winnerWidth = (self.winnerCellWidth * CGFloat(self.winners)) + (self.winnerSpacing * CGFloat(self.winners - 1)) + 1
        self.winnerCollectionViewWidth.constant = self.winnerWidth
        self.winnerCollectionViewHeight.constant = self.winnerCrownHeight + self.winnerImageHeight + self.winnerNameHeight - 5.0 + self.winnerScoreHeight
        
        totalHeight = self.middleArea.frame.height - 10.0
        idealHeight = self.self.otherImageHeight + (self.otherNameHeight - 5.0) + self.otherScoreHeight
        if totalHeight < idealHeight {
            let factor = totalHeight / idealHeight
            self.otherImageHeight *= factor
            self.otherNameHeight *= factor
            self.otherScoreHeight *= factor
        }
                
        self.otherCellWidth = min(100.0, (totalWidth - (self.otherSpacing * (CGFloat(self.others) + 1))) / CGFloat(self.others), self.otherImageHeight)
        self.otherImageHeight = self.otherCellWidth
        self.otherCellHeight = self.otherImageHeight + (self.otherNameHeight - 5.0) + self.otherScoreHeight
        self.otherWidth = (self.otherCellWidth * CGFloat(self.others)) + (self.otherSpacing * CGFloat(self.others - 1)) + 1
        self.otherCollectionViewWidth.constant = self.otherWidth
        self.otherCollectionViewHeight.constant = self.otherImageHeight + (self.otherNameHeight - 5.0) + self.otherScoreHeight
        
        self.actionButtons.forEach{(button) in button.set(titleFont: UIFont.systemFont(ofSize: 18.0, weight: .semibold))}
        self.actionButtons.first!.layoutIfNeeded()
        
        let size = self.bottomArea.frame.height / 2
        if self.awardList.count == 0 {
                        
            self.actionButtonViewHeight.constant = size
            self.actionButtons.forEach{(button) in button.setProportions(top: 0.15, image: 0.6, imageBottom: 0.05, title: 0.2, bottom: 0.1)}
            
            self.awardsTitleBarHeight.constant = size * 0.4
            self.awardsTitleBar.set(labelProportion: 1.0)
        } else {
            self.actionButtonViewHeight.constant = size * 0.4
            self.actionButtons.forEach{(button) in button.setProportions(top: 0.1, title: 0.2, bottom: 0.1)}
            
            self.awardsTitleBarHeight.constant = size
            self.awardsTitleBar.set(labelProportion: 0.4)
            
            self.awardsCollectionViewHeight.constant = 0.5 * self.awardsTitleBarHeight.constant + (self.awardList.count <= self.awardMaxList ? 0 : self.awardNameHeight)
            self.awardsTitleBar.layoutIfNeeded()
            self.awardCellSize = AwardCollectionCell.sizeForCell(self.awardsCollectionView, mode: (self.awardList.count <= self.awardMaxList ? .list : .grid), across: 3.2, spacing: self.awardSpacing, labelHeight: self.awardNameHeight)
            self.awardsCollectionViewHeight.constant = (self.awardCellSize.height)
        }
        
        self.actionButtonView.layoutIfNeeded()
        self.bottomArea.addShadow()
    }
    
    private func setupAwards() {
        // Save awards for 'this' player if hosting / joined
        // or all players if scoring. Load awards for this player
        
        self.awardList = []
        for playerNumber in 1...Scorecard.game.currentPlayers {
            let player = Scorecard.game.player(enteredPlayerNumber: playerNumber)
            let isThisPlayer = (player.playerMO!.playerUUID == Scorecard.activeSettings.thisPlayerUUID)
            if controllerDelegate?.controllerType == .scoring || ((Scorecard.game.isHosting || Scorecard.game.hasJoined) && isThisPlayer) {
                let awardList = self.awards.calculate(playerUUID: player.playerMO!.playerUUID!)
                self.awards.save(playerUUID: player.playerMO!.playerUUID!, achieved: awardList)
                if isThisPlayer {
                    self.awardList = awardList
                }
            }
        }

        // Register award cells
        AwardCollectionCell.register(awardsCollectionView, modes: .grid, .list)
        
        // Set title bar
        self.awardsTitleBar.set(bottomRounded: true)
        self.awardsTitleBar.set(font: UIFont.systemFont(ofSize: 18.0, weight: .semibold))

    }
    
    private func calculateWinner() {
        struct HighScoreEntry {
            var gameUUID: String
            var playerUUID: String
            var totalScore: Int16
        }

        var highScoreParticipantMO: [ParticipantMO]!
        var highScoreEntry: [HighScoreEntry] = []
        var highScoreRanking: [Int] = []
        var newHighScore = false
        var winnerNames = ""
        var winnerPlayerUUID = ""
        
        // Clear cross reference array
        xref.removeAll()
    
        if !self.excludeStats && !self.excludeHistory && !(Scorecard.game?.isPlayingComputer ?? false) {
            if Scorecard.activeSettings.saveHistory {
                // Load high scores - get 10 to allow for lots of ties
                // Note - this assumes this game's participants have been placed in the database already
                highScoreParticipantMO = History.getHighScores(type: .totalScore, limit: 10, playerUUIDList: Scorecard.shared.playerUUIDList(getPlayerMode: .getAll))
                for participant in highScoreParticipantMO {
                    highScoreEntry.append(HighScoreEntry(gameUUID: participant.gameUUID!, playerUUID: participant.playerUUID!, totalScore: participant.totalScore))
                }
            }
            
            if (gameSummaryMode != .scoring && gameSummaryMode != .hosting) || !Scorecard.activeSettings.saveHistory {
                // Need to add current game since not written on this device
                for playerNumber in 1...Scorecard.game.currentPlayers {
                    let totalScore = Scorecard.game.scores.totalScore(playerNumber: playerNumber)
                    highScoreEntry.append(HighScoreEntry(gameUUID: (Scorecard.game.gameUUID==nil ? "" : Scorecard.game.gameUUID),
                                                         playerUUID: Scorecard.game.player(enteredPlayerNumber: playerNumber).playerMO!.playerUUID!,
                                                         totalScore: Int16(totalScore)))
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
        for playerNumber in 1...Scorecard.game.currentPlayers {
            var personalBest = false
            let score = Int64(Scorecard.game.scores.totalScore(playerNumber: playerNumber))
            var ranking = 0
            
            if !self.excludeStats && !self.excludeHistory && !(Scorecard.game?.isPlayingComputer ?? false) {
                for loopCount in 1...highScoreRanking.count {
                    // No need to check if already got a high place
                    if Scorecard.activeSettings.saveHistory && ranking == 0 {
                        // Check if it is a score for this player
                        if highScoreEntry[loopCount-1].playerUUID == Scorecard.game.player(enteredPlayerNumber: playerNumber).playerMO?.playerUUID {
                            // Check that it is this score that has done it - not an old one
                            if highScoreEntry[loopCount-1].gameUUID == (Scorecard.game.gameUUID==nil ? "" : Scorecard.game.gameUUID) {
                                ranking = highScoreRanking[loopCount - 1]
                                if ranking == 1 {
                                    newHighScore = true
                                }
                            }
                        }
                    }
                
                    if ranking == 0 {
                        let previousPersonalBest = Scorecard.game.player(enteredPlayerNumber: playerNumber).previousMaxScore
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
        for playerNumber in 1...Scorecard.game.currentPlayers {
            if playerNumber == 1 || xref[playerNumber - 2].score != xref[playerNumber - 1].score {
                place = playerNumber
            }
            xref[playerNumber - 1].place = place
            if place == 1 {
                winners += 1
                if winners == 1 {
                    winnerPlayerUUID = Scorecard.game.player(enteredPlayerNumber: xref[playerNumber-1].playerNumber).playerMO!.playerUUID!
                    winnerNames = Scorecard.game.player(enteredPlayerNumber: xref[playerNumber-1].playerNumber).playerMO!.name!
                } else {
                    winnerNames = winnerNames + " and " + Scorecard.game.player(enteredPlayerNumber: xref[playerNumber-1].playerNumber).playerMO!.name!
                }
            }
        }
        self.others = Scorecard.game.currentPlayers - winners
        
        if !Scorecard.game.gameCompleteNotificationSent && (gameSummaryMode == .scoring || gameSummaryMode == .hosting) {
            // Save notification message
            self.saveGameNotification(newHighScore: newHighScore, winnerPlayerUUID: winnerPlayerUUID, winner: winnerNames, winningScore: Int(xref[0].score))
            Scorecard.game.gameCompleteNotificationSent = true
        }
    }
    
    public func saveGameNotification(newHighScore: Bool, winnerPlayerUUID: String, winner: String, winningScore: Int) {
        if Scorecard.activeSettings.syncEnabled && Scorecard.shared.isNetworkAvailable && Scorecard.shared.isLoggedIn && !self.excludeHistory && !(Scorecard.game?.isPlayingComputer ?? false) {
            var message = ""
            
            for playerNumber in 1...Scorecard.game.currentPlayers {
                let name = Scorecard.game.player(enteredPlayerNumber: playerNumber).playerMO!.name!
                if playerNumber == 1 {
                    message = name
                } else if playerNumber == Scorecard.game.currentPlayers {
                    message = message + " and " + name
                    
                } else {
                    message = message + ", " + name
                }
            }
            
            let locationDescription = Scorecard.game.location.description
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
            
            Notifications.updateHighScoreNotificationRecord(winnerPlayerUUID: winnerPlayerUUID, message: message)
        }
    }
    
    func finishGame(returnMode: GameSummaryReturnMode, advanceDealer: Bool = false, resetOverrides: Bool = true, confirm: Bool = false) {
        
        func finish() {
            self.synchroniseAndReturn(returnMode: returnMode, advanceDealer: advanceDealer, resetOverrides: resetOverrides)
        }
        
        if confirm {
            var message: String
            if self.excludeHistory {
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
            self.present(alertController, animated: true, completion: nil)
        } else {
            finish()
        }
    }

    // MARK: - Sync routines including the delegate methods ======================================== -
    
    func synchroniseAndReturn(returnMode: GameSummaryReturnMode, advanceDealer: Bool = false, resetOverrides: Bool) {
        completionMode = returnMode
        completionAdvanceDealer = advanceDealer
        completionResetOverrides = resetOverrides
        if Scorecard.activeSettings.syncEnabled && Scorecard.shared.isNetworkAvailable && Scorecard.shared.isLoggedIn && !self.excludeHistory && !(Scorecard.game?.isPlayingComputer ?? false && !Sync.temporaryPlayerUUIDs) {
            view.isUserInteractionEnabled = false
            activityIndicator.startAnimating()
            self.sync.delegate = self
            self.scorecardButton.isHidden = true
            _ = self.sync.synchronise(waitFinish: true, okToSyncWithTemporaryPlayerUUIDs: true)
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
            self.controllerDelegate?.didProceed(context: ["mode" : self.completionMode,
                                                          "advanceDealer" : self.completionAdvanceDealer,
                                                          "resetOverrides" : self.completionResetOverrides])
        }
    }
    
    // MARK: - Show other views ============================================================= -
    
    private func showHighScores() {
        self.controllerDelegate?.didInvoke(.highScores)
    }
    
    // MARK: - Function to present and dismiss this view ==============================================================
    
    class public func show(from viewController: ScorecardViewController, appController: ScorecardAppController? = nil, gameSummaryMode: ScorepadMode? = nil) -> GameSummaryViewController {
        
        let storyboard = UIStoryboard(name: "GameSummaryViewController", bundle: nil)
        let gameSummaryViewController: GameSummaryViewController = storyboard.instantiateViewController(withIdentifier: "GameSummaryViewController") as! GameSummaryViewController
 
        gameSummaryViewController.preferredContentSize = CGSize(width: 400, height: Scorecard.shared.scorepadBodyHeight)
        gameSummaryViewController.modalPresentationStyle = (ScorecardUI.phoneSize() ? .fullScreen : .automatic)

        gameSummaryViewController.gameSummaryMode = gameSummaryMode
        gameSummaryViewController.controllerDelegate = appController
       
        viewController.present(gameSummaryViewController, appController: appController, sourceView: viewController.popoverPresentationController?.sourceView ?? viewController.view, animated: true, completion: nil)
        
        return gameSummaryViewController
    }
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class GameSummaryPlayerCollectionCell: UICollectionViewCell {
    @IBOutlet fileprivate weak var thumbnailView: ThumbnailView!
    @IBOutlet fileprivate weak var playerScoreButton: UIButton!
    @IBOutlet fileprivate weak var crownHeight: NSLayoutConstraint!
    @IBOutlet fileprivate weak var playerViewHeight: NSLayoutConstraint!
    @IBOutlet fileprivate weak var scoreHeight: NSLayoutConstraint!
}

extension GameSummaryViewController {

    /** _Note that this code was generated as part of the move to themed colors_ */

    private func defaultViewColors() {

        self.activityIndicator.color = Palette.darkHighlight.text
        self.awardsTitleBar.set(faceColor: Palette.buttonFace.background)
        self.awardsTitleBar.set(textColor: Palette.buttonFace.text)
        self.actionButtons.forEach{(button) in button.set(titleColor: Palette.buttonFace.text)}
        self.actionButtons.forEach{(button) in button.set(faceColor: Palette.buttonFace.background)}
        self.syncMessage.textColor = Palette.darkHighlight.text
        self.view.backgroundColor = Palette.roomInterior.background
    }

    private func defaultCellColors(cell: GameSummaryPlayerCollectionCell) {
        switch cell.reuseIdentifier {
        case "Game Summary Cell":
            cell.playerScoreButton.setTitleColor(Palette.roomInterior.text, for: .normal)
        default:
            break
        }
    }

}
