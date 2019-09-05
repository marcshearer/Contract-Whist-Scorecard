//
//  RoundSummaryViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 22/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit

class RoundSummaryViewController: CustomViewController {

    // MARK: - Class Properties ======================================================================== -

    private let scorecard = Scorecard.shared
    
    // Main state properties
    public var rounds: Int!
    public var cards: [Int]!
    public var bounce: Bool!
    public var suits: [Suit]!
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet weak var roundSummaryView: UIView!
    @IBOutlet weak var trumpSuit: UILabel!
    @IBOutlet weak var overUnder: UILabel!
    @IBOutlet weak var player1Bid: UILabel!
    @IBOutlet weak var player2Bid: UILabel!
    @IBOutlet weak var player3Bid: UILabel!
    @IBOutlet weak var player4Bid: UILabel!
    
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
   
    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
       
        setupOverUnder()
        setupBidText(bids: player1Bid, player2Bid, player3Bid, player4Bid)
        
        if self.scorecard.commsHandlerMode == .roundSummary {
            // Notify client controller that round summary display complete
            self.scorecard.commsHandlerMode = .none
            NotificationCenter.default.post(name: .clientHandlerCompleted, object: self, userInfo: nil)
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        scorecard.reCenterPopup(self)
    }

    // MARK: - Gesture Action Handlers ================================================================= -

    func finishPressed() {
        self.dismiss()
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
        self.trumpSuit.attributedText = scorecard.roundSuit(scorecard.selectedRound, suits: self.suits).toAttributedString(font: self.trumpSuit.font, noTrumpScale: 0.7)
        
        let totalRemaining = scorecard.remaining(playerNumber: 0, round: scorecard.selectedRound, mode: Mode.bid, rounds: self.rounds, cards: self.cards, bounce: self.bounce)
        self.overUnder.text = "\(abs(Int64(totalRemaining))) \(totalRemaining >= 0 ? "under" : "over")"
        self.overUnder.textColor = (totalRemaining == 0 ? Palette.contractEqual : (totalRemaining > 0 ? Palette.contractUnder : Palette.contractOver))
    }
    
    func setupBidText(bids: UILabel?...) {
        
        for playerNumber in 1...scorecard.numberPlayers {
            if playerNumber <= scorecard.currentPlayers {
                let bid = scorecard.entryPlayer(playerNumber).bid(scorecard.selectedRound)
                if bid != nil {
                    bids[playerNumber-1]?.text = "\(scorecard.entryPlayer(playerNumber).playerMO!.name!) bid \(bid!)"
                } else {
                    bids[playerNumber-1]?.text = ""
                }
            } else {
                bids[playerNumber-1]?.text = ""
            }
        }
    }
    
    // MARK: - Function to present and dismiss this view ==============================================================
    
    class public func show(from viewController: CustomViewController, existing roundSummaryViewController: RoundSummaryViewController! = nil, rounds: Int? = nil, cards: [Int]? = nil, bounce: Bool? = nil, suits: [Suit]? = nil) -> RoundSummaryViewController {
        
        var roundSummaryViewController: RoundSummaryViewController! = roundSummaryViewController
        
        if roundSummaryViewController == nil {
            let storyboard = UIStoryboard(name: "RoundSummaryViewController", bundle: nil)
            roundSummaryViewController = storyboard.instantiateViewController(withIdentifier: "RoundSummaryViewController") as? RoundSummaryViewController
        }
        
        roundSummaryViewController.preferredContentSize = CGSize(width: 400, height: Scorecard.shared.scorepadBodyHeight)
        
        roundSummaryViewController.rounds = rounds
        roundSummaryViewController.cards = cards
        roundSummaryViewController.bounce = bounce
        roundSummaryViewController.suits = suits
        
        viewController.present(roundSummaryViewController, sourceView: viewController.popoverPresentationController?.sourceView ?? viewController.view, animated: true, completion: nil)
        
        return roundSummaryViewController
    }
    
    private func dismiss() {
        self.dismiss(animated: false, completion: nil)
    }
}
