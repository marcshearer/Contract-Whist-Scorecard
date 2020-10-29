//
//  RoundSummaryViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 22/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit

class RoundSummaryViewController: ScorecardViewController, BannerDelegate {
        
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var banner: Banner!
    @IBOutlet private weak var roundSummaryView: UIView!
    @IBOutlet private weak var trumpSuit: UILabel!
    @IBOutlet private weak var overUnder: UILabel!
    @IBOutlet private weak var player1Bid: UILabel!
    @IBOutlet private weak var player2Bid: UILabel!
    @IBOutlet private weak var player3Bid: UILabel!
    @IBOutlet private weak var player4Bid: UILabel!
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func rightSwipe(recognizer: UISwipeGestureRecognizer) {
        self.finishPressed()
    }
    
    @IBAction func tapGesture(recognizer: UITapGestureRecognizer) {
        self.finishPressed()
    }
    
    // MARK: - View Overrides ========================================================================== -
   
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup banner
        self.setupBanner()
        
        // Setup help
        self.setupHelpView()
        
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
    
    private func setupBanner() {
        self.banner.set(
            leftButtons: [
                BannerButton(image: UIImage(named: "back"), width: 22, action: self.finishPressed, id: Banner.finishButton)],
            rightButtons: [
                BannerButton(action: self.helpPressed, type: .help)]
        )
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
        
        viewController.present(roundSummaryViewController, appController: appController, animated: true, completion: nil)
        
        return roundSummaryViewController
    }
    
    private func dismiss() {
        self.dismiss(animated: false, completion: nil)
    }
}

extension RoundSummaryViewController {

    /** _Note that this code was generated as part of the move to themed colors_ */

    private func defaultViewColors() {

        self.banner.set(backgroundColor: PaletteColor(.total))
        self.player1Bid.textColor = Palette.total.text
        self.player2Bid.textColor = Palette.total.text
        self.player3Bid.textColor = Palette.total.text
        self.player4Bid.textColor = Palette.total.text
        self.roundSummaryView.backgroundColor = Palette.total.background
    }

}

extension RoundSummaryViewController {
    
    internal func setupHelpView() {
        
        self.helpView.reset()
                
        self.helpView.add("This screen gives you a quick summary of the round currently being played.\n\nIt is designed to be set in the middle of the table as you play the cards.")
        
        self.helpView.add("This shows the @*/Trump Suit@*/ for the current round.", views: [self.trumpSuit])
        
        self.helpView.add("This shows the total of all bids compared to the number of cards in each hand in the round.", views: [self.overUnder])
        
        var bids = [self.player1Bid, self.player2Bid, self.player3Bid]
        if Scorecard.game.currentPlayers >= 4 {
            bids.append(self.player4Bid)
        }
        self.helpView.add("This area shows the bids for each player for this round.", views: bids )
        
        self.helpView.add("The {} takes you back to the @*/Score Entry@*/ screen", bannerId: Banner.finishButton)
    }
}
