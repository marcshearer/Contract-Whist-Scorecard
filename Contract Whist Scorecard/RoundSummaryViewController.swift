//
//  RoundSummaryViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 22/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit

class RoundSummaryViewController: UIViewController {

    // MARK: - Class Properties ======================================================================== -
    
    // Main state properties
    public var scorecard: Scorecard!
    public var returnSegue: String!
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
    
    @IBAction func rightSwipe(recognizer:UISwipeGestureRecognizer) {
        self.finishPressed()
    }
    
    @IBAction func tapGesture(recognizer:UITapGestureRecognizer) {
        self.finishPressed()
    }
    
    // MARK: - View Overrides ========================================================================== -
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupOverUnder()
        setupBidText(bids: player1Bid, player2Bid, player3Bid, player4Bid)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if self.scorecard.commsHandlerMode == .roundSummary {
            // Notify broadcast controller that round summary display complete
            self.scorecard.commsHandlerMode = .none
            NotificationCenter.default.post(name: .broadcastHandlerCompleted, object: self, userInfo: nil)
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        scorecard.reCenterPopup(self)
    }

    // MARK: - Gesture Action Handlers ================================================================= -

    func finishPressed() {
        self.performSegue(withIdentifier: returnSegue, sender: self)
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
        self.trumpSuit.attributedText = scorecard.roundSuit(scorecard.selectedRound, suits: self.suits).toAttributedString()
        
        let totalRemaining = scorecard.remaining(playerNumber: 0, round: scorecard.selectedRound, mode: Mode.bid, rounds: self.rounds, cards: self.cards, bounce: self.bounce)
        self.overUnder.text = "\(abs(Int64(totalRemaining))) \(totalRemaining >= 0 ? "under" : "over")"
        self.overUnder.textColor = (totalRemaining == 0 ? UIColor.black : (totalRemaining > 0 ? UIColor.green : UIColor.red))
    }
    
    func setupBidText(bids: UILabel!...) {
        
        for playerNumber in 1...scorecard.numberPlayers {
            if playerNumber <= scorecard.currentPlayers {
                let bid = scorecard.entryPlayer(playerNumber).bid(scorecard.selectedRound)
                if bid != nil {
                    bids[playerNumber-1].text = "\(scorecard.entryPlayer(playerNumber).playerMO!.name!) bid \(bid!)"
                } else {
                    bids[playerNumber-1].text = ""
                }
            } else {
                bids[playerNumber-1].text = ""
            }
        }
    }
}
