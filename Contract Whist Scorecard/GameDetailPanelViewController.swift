//
//  GameDetailPanelViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 13/09/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit
import Combine

protocol GameDetailDelegate {
    func refresh(activeView: ScorecardView?)
}

extension GameDetailDelegate {
    func refresh() {
        refresh(activeView: nil)
    }
}

class GameDetailPanelViewController: ScorecardViewController, UITableViewDataSource, UITableViewDelegate, GameDetailDelegate {
    
    private var scoresSubscription: AnyCancellable?
    private var latestScores: [Int:Int] = [:]
    private var sortedScores: [(score: Int?, playerNumber: Int)] = []
    private var latestRound: Int?
    private var gameComplete: Bool = false
    private var thisPlayer: Int?
    
    @IBOutlet private weak var roundLabel: UILabel!
    @IBOutlet private weak var overUnderLabel: UILabel!
    @IBOutlet private weak var roundLabelWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var playerTableView: UITableView!
    @IBOutlet private weak var lastHandLabel: UILabel!
    @IBOutlet private weak var lastHandView: DealView!
    @IBOutlet private var normalLabels: [UILabel]!
    @IBOutlet private var strongLabels: [UILabel]!
    @IBOutlet private weak var scoresView: UIView!
    @IBOutlet private weak var dealView: UIView!

    override internal func viewDidLoad() {
        super.viewDidLoad()
        
        self.setDefaultColors()
        self.thisPlayer = Scorecard.game.enteredPlayerNumber(playerUUID: Scorecard.settings.thisPlayerUUID)
        self.sortScores()
        self.refresh()
        self.setupScoresSubscription()
    }
    
    override internal func didDismiss() {
        self.cancelScoresSubscription()
    }
    
    internal func refresh(activeView: ScorecardView?) {
        let scorepadView = ((activeView ?? self.appController?.activeView) == .scorepad)
        self.scoresView.isHidden = scorepadView
        self.dealView.isHidden = !scorepadView
        if scorepadView {
            self.refreshTitle()
            self.refreshScores()
        } else {
            self.refreshHand()
        }
    }
    
    private func refreshTitle() {
    
        if Scorecard.game.gameComplete() {
            self.roundLabelWidthConstraint.constant = self.scoresView.frame.width
            self.roundLabel.text = "Game Complete"
            self.overUnderLabel.text = ""
        } else {
            self.roundLabelWidthConstraint.constant = 100
            let totalRemaining = Scorecard.game.remaining(playerNumber: 0, round: Scorecard.game.maxEnteredRound, mode: Mode.bid)
            let overUnder = NSMutableAttributedString("     \(abs(Int64(totalRemaining))) \(totalRemaining >= 0 ? "under" : "over")", color: (totalRemaining == 0 ? Palette.contractEqual : (totalRemaining > 0 ? Palette.contractUnder : Palette.contractOver)))
            self.roundLabel.attributedText = Scorecard.game.roundTitle(Scorecard.game.maxEnteredRound)
            self.overUnderLabel.attributedText = overUnder
        }
    }
    
    private func refreshScores() {
        // Player scores
        self.playerTableView.reloadData()
    }
    
    private func refreshHand(specificRound: Int? = nil) {
        var round: Int
        if specificRound != nil {
            round = specificRound!
        } else {
            // Use latest round
            round = Scorecard.game.maxEnteredRound
            if !Scorecard.game.roundComplete(round) {
                round -= 1
            }
        }
            
        if round < 1 || thisPlayer == nil || Scorecard.game?.dealHistory[round] == nil {
            self.lastHandLabel.text = ""
            self.lastHandView.isHidden = true
        } else {
            if specificRound == nil {
                self.lastHandLabel.text = "Last Hand"
            } else {
                self.lastHandLabel.attributedText = NSMutableAttributedString("Round \(Scorecard.game.maxEnteredRound - 1) - ") + Scorecard.game.roundTitle(Scorecard.game.maxEnteredRound - 1)
            }
            self.lastHandView.isHidden = false
            self.lastHandView.show(round: round, thisPlayer: self.thisPlayer!, color: Palette.rightGameDetailPanel)
        }
    }
    
    private func setDefaultColors() {
        self.view.backgroundColor = Palette.rightGameDetailPanel.background
        self.normalLabels.forEach{ (label) in label.textColor = Palette.rightGameDetailPanel.text}
        self.strongLabels.forEach{ (label) in label.textColor = Palette.rightGameDetailPanel.strongText}
    }
    
    private func setupScoresSubscription() {
        self.scoresSubscription = Scorecard.game?.scores.subscribe { (round, playerNumber) in
            // Refresh scores if changed
            Utility.mainThread {
                let score = Scorecard.game.scores.totalScore(playerNumber: playerNumber)
                if score != self.latestScores[playerNumber] {
                    self.refreshScores()
                    self.latestScores[playerNumber] = score
                    self.sortScores()
                }
            }
            
            // Refresh title regardless
            self.refreshTitle()
            
            // Refresh round if changed
            let round = Scorecard.game.scores.completedRound()
            let gameComplete = Scorecard.game.gameComplete()
            if self.latestRound != round || self.gameComplete != gameComplete {
                self.refreshHand()
                self.latestRound = round
                self.gameComplete = gameComplete
            }
        }
    }
    
    private func cancelScoresSubscription() {
        self.scoresSubscription?.cancel()
    }
    
    private func sortScores() {
        self.sortedScores = []
        for playerNumber in 1...Scorecard.game.currentPlayers {
            self.sortedScores.append((score: latestScores[playerNumber], playerNumber: playerNumber))
        }
        self.sortedScores.sort {($0.score ?? 0) > ($1.score ?? 0)}
    }
    
    // MARK: - TableView Overrides ===================================================================== -

    internal func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.sortedScores.count
    }
    
    internal func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    internal func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Player", for: indexPath) as! GameDetailPlayerCell
        
        var score: Int?
        let playerNumber = self.sortedScores[indexPath.row].playerNumber
        if Scorecard.game.roundComplete(1) {
            score = self.latestScores[playerNumber]
        }
        cell.set(playerNumber: playerNumber, score: score)
        
        return cell
    }
    
    // MARK: - Routines to show this view ============================================================== -

    public static func create() -> GameDetailPanelViewController {
        
        let storyboard = UIStoryboard(name: "GameDetailPanelViewController", bundle: nil)
        let gameDetailPanelViewController = storyboard.instantiateViewController(withIdentifier: "GameDetailPanelViewController") as! GameDetailPanelViewController
        return gameDetailPanelViewController
    }
    
}

class GameDetailPlayerCell: UITableViewCell {
    @IBOutlet fileprivate weak var thumbnailView: ThumbnailView!
    @IBOutlet fileprivate weak var nameLabel: UILabel!
    @IBOutlet fileprivate weak var scoreLabel: UILabel!
    
    override func awakeFromNib() {
        self.thumbnailView.set(frame: CGRect(x: 0, y: 16, width: 44, height: 44))
        self.nameLabel.textColor = Palette.rightGameDetailPanel.text
        self.scoreLabel.textColor = Palette.rightGameDetailPanel.text
    }
    
    fileprivate func set(playerNumber: Int, score: Int?) {
        let playerMO = Scorecard.game.player(enteredPlayerNumber: playerNumber).playerMO!
        self.thumbnailView.set(playerMO: playerMO, nameHeight: 0)
        self.nameLabel.text = playerMO.name
        self.scoreLabel.text = (score == nil ? "-" : "\(score!)")
    }
}
