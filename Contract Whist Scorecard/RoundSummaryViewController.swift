//
//  RoundSummaryViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 22/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit

class RoundSummaryViewController: ScorecardViewController {
        
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var roundSummaryView: UIView!
    @IBOutlet private weak var trumpSuit: UILabel!
    @IBOutlet private weak var overUnder: UILabel!
    @IBOutlet private weak var player1Bid: UILabel!
    @IBOutlet private weak var player2Bid: UILabel!
    @IBOutlet private weak var player3Bid: UILabel!
    @IBOutlet private weak var player4Bid: UILabel!
    @IBOutlet private weak var finishButton: ClearButton!
    
    // MARK: - IB Actions ============================================================================== -

    @IBAction func finishPressed(_ sender: UIButton) {
        self.finishPressed()
    }
    
    @IBAction func rightSwipe(recognizer: UISwipeGestureRecognizer) {
        self.finishPressed()
    }
    
    @IBAction func tapGesture(recognizer: UITapGestureRecognizer) {
        self.finishPressed()
    }
    
    // MARK: - View Overrides ========================================================================== -
   
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup default colors (previously done in StoryBoard)
        self.defaultViewColors()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
       
        setupOverUnder()
        setupBidText(bids: player1Bid, player2Bid, player3Bid, player4Bid)
        
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        Scorecard.shared.reCenterPopup(self)
    }

    // MARK: - Gesture Action Handlers ================================================================= -

    func finishPressed() {
        self.controllerDelegate?.didCancel()
    }
    
    // MARK: - Form Presentation / Handling Routines =================================================== -
    
    public func refresh() {
        if self.overUnder != nil {
            setupOverUnder()
            setupBidText(bids: player1Bid, player2Bid, player3Bid, player4Bid)
        }
    }
    
    // MARK: - Utility Routines ======================================================================== -
    
    func setupOverUnder() {
        self.trumpSuit.textColor = UIColor.white
        self.trumpSuit.attributedText = Scorecard.game.roundSuit(Scorecard.game.selectedRound).toAttributedString(font: self.trumpSuit.font, noTrumpScale: 0.7)
        
        let totalRemaining = Scorecard.game.remaining(playerNumber: 0, round: Scorecard.game.selectedRound, mode: Mode.bid)
        self.overUnder.text = "\(abs(Int64(totalRemaining))) \(totalRemaining >= 0 ? "under" : "over")"
        self.overUnder.textColor = (totalRemaining == 0 ? Palette.contractEqual : (totalRemaining > 0 ? Palette.contractUnder : Palette.contractOver))
    }
    
    func setupBidText(bids: UILabel?...) {
        
        for playerNumber in 1...Scorecard.shared.maxPlayers {
            if playerNumber <= Scorecard.game.currentPlayers {
                let bid = Scorecard.game.scores.get(round: Scorecard.game.selectedRound, playerNumber: playerNumber, sequence: .entry).bid
                if bid != nil {
                    bids[playerNumber-1]?.text = "\(Scorecard.game.player(entryPlayerNumber: playerNumber).playerMO!.name!) bid \(bid!)"
                } else {
                    bids[playerNumber-1]?.text = ""
                }
            } else {
                bids[playerNumber-1]?.text = ""
            }
        }
    }
    
    // MARK: - Function to present and dismiss this view ==============================================================
    
    class public func show(from viewController: ScorecardViewController, appController: ScorecardAppController? = nil, existing roundSummaryViewController: RoundSummaryViewController! = nil) -> RoundSummaryViewController {
        
        var roundSummaryViewController: RoundSummaryViewController! = roundSummaryViewController
        
        if roundSummaryViewController == nil {
            let storyboard = UIStoryboard(name: "RoundSummaryViewController", bundle: nil)
            roundSummaryViewController = storyboard.instantiateViewController(withIdentifier: "RoundSummaryViewController") as? RoundSummaryViewController
        }
        
        roundSummaryViewController.preferredContentSize = CGSize(width: 400, height: Scorecard.shared.scorepadBodyHeight)
        roundSummaryViewController.modalPresentationStyle = (ScorecardUI.phoneSize() ? .fullScreen : .automatic)
        
        viewController.present(roundSummaryViewController, appController: appController, sourceView: viewController.popoverPresentationController?.sourceView ?? viewController.view, animated: true, completion: nil)
        
        return roundSummaryViewController
    }
    
    private func dismiss() {
        self.dismiss(animated: false, completion: nil)
    }
}

extension RoundSummaryViewController {

    /** _Note that this code was generated as part of the move to themed colors_ */

    private func defaultViewColors() {

        self.finishButton.setTitleColor(Palette.totalText, for: .normal)
        self.player1Bid.textColor = Palette.totalText
        self.player2Bid.textColor = Palette.totalText
        self.player3Bid.textColor = Palette.totalText
        self.player4Bid.textColor = Palette.totalText
        self.roundSummaryView.backgroundColor = Palette.total
    }

}

