//
//  HandViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 03/06/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit

protocol HandStatusDelegate {
    
    func handComplete()
    
}

class HandViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    // MARK: - Class Properties ======================================================================== -
    
    // Main state properties
    var scorecard: Scorecard!
    
    // Local state properties
    private var currentCards = 0
    internal var bidMode: Bool!
    private var firstBidRefresh = true
    private var firstHandRefresh = true
    private var resizing = false
    internal var state: HandState!               // local pointer to hand state object
    internal var enteredPlayerNumber: Int!       // local version of player number
    internal var round: Int!                     // local version of round number
    internal var suitEnabled = [Bool](repeating: false, count: 6)
    private var lastHand = false
    internal var handTestData = HandTestData()
    
    // Delegate
    public var delegate: HandStatusDelegate!
    
    // Component sizes
    private var viewWidth: CGFloat!
    private var viewHeight: CGFloat!
    private var handViewHeight: CGFloat!
    private var handViewWidth: CGFloat!
    private var tabletopViewHeight: CGFloat!
    private var bidViewHeight: CGFloat!
    private var bidViewWidth: CGFloat!
    private var handCardHeight: CGFloat!
    private var handCardWidth: CGFloat!
    private var handCardsPerRow: Int!
    private var tabletopCardHeight: CGFloat!
    private var tabletopCardWidth: CGFloat!
    private var tabletopCellWidth: CGFloat!
    private var bidButtonSize: CGFloat = 50.0
    private let instructionHeight: CGFloat = 50.0
    private var maxBidButton = 8
    private var moreMode = false
    private var handCardFontSize: CGFloat!
    private var statusTextFontSize: CGFloat!
    private var playedCardFontSize: CGFloat!
    private var tableTopLabelFontSize: CGFloat!
    
    // UI component pointers
    private var playerCardView: [UIView?] = []
    private var playerCardLabel: [UILabel?] = []
    private var playerNameLabel: [UILabel?] = []
    private var playerBidLabel: [UILabel?] = []
    private var playerMadeLabel: [UILabel?] = []
    private var statusPlayerBidLabel: [UILabel?] = []
    internal var suitCollectionView = [UICollectionView?](repeating: nil, count: 6)
    private var bidButton = [UILabel?](repeating: nil, count: 15)
    private var bidButtonEnabled = [Bool](repeating: false, count: 15)
    
    // MARK: - IB Outlets -
    
    @IBOutlet private weak var handView: UIView!
    @IBOutlet private weak var handTableView: UITableView!
    @IBOutlet private weak var handHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var handTableViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var tabletopView: UIView!
    @IBOutlet private weak var bidHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var statusWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var bidView: UIView!
    @IBOutlet private weak var bidCollectionView: UICollectionView!
    @IBOutlet private weak var bidSeparator: UIView!
    @IBOutlet private weak var instructionTextView: UITextView!
    @IBOutlet private weak var statusRoundLabel: UILabel!
    @IBOutlet private weak var statusOverUnderLabel: UILabel!
    @IBOutlet private weak var statusPlayer1BidLabel: UILabel!
    @IBOutlet private weak var statusPlayer2BidLabel: UILabel!
    @IBOutlet private weak var statusPlayer3BidLabel: UILabel!
    @IBOutlet private weak var statusPlayer4BidLabel: UILabel!
    @IBOutlet private weak var playedCardCollectionView: UICollectionView!
    @IBOutlet private weak var instructionView: UIView!
    @IBOutlet private weak var finishButton: UIButton!
    @IBOutlet weak var lastHandButton: UIButton!
    @IBOutlet weak var roundSummaryButton: UIButton!
    
    // MARK: - IB Unwind Segue Handlers ================================================================ -
    
    @IBAction private func hideHandRoundSummary(segue: UIStoryboardSegue) {
    }
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction private func finishPressed(_ sender: UIButton) {
        self.dismissHand()
    }
    
    @IBAction private func roundSummaryPressed(_ sender: UIButton) {
        self.performSegue(withIdentifier: "showHandRoundSummary", sender: self)
    }
    
    @IBAction func lastHandPressed(_ sender: UIButton) {
        self.lastHand = true
        self.playedCardCollectionView.reloadData()
    }
    
    @IBAction func lastHandReleased(_ sender: Any) {
        self.lastHand = false
        self.playedCardCollectionView.reloadData()
    }
    
    // MARK: - View Overrides ========================================================================== -

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup initial state and local references for global state
        self.state = self.scorecard.handState
        self.enteredPlayerNumber = self.state.enteredPlayerNumber
        self.round = self.state.round
        self.scorecard.selectedRound = self.round
        self.scorecard.maxEnteredRound = self.round
        
        setupArrays()
        if self.state.handSuits == nil {
            self.state.handSuits = Pack.sortHand(hand: self.state.hand)
        }
        self.currentCards = self.scorecard.roundCards(round, rounds: self.state.rounds, cards: self.state.cards, bounce: self.state.bounce)
        
        // Put suit on summary button
        self.roundSummaryButton.setTitle(self.scorecard.roundSuit(self.round, suits: self.state.suits).toString(), for: .normal)
        self.roundSummaryButton.titleLabel?.adjustsFontSizeToFitWidth = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        viewHeight = view.frame.height
        viewWidth = view.frame.width
        
        if self.scorecard.commsHandlerMode == .playHand {
            // Notify broadcast controller that hand display complete
            self.scorecard.commsHandlerMode = .none
            NotificationCenter.default.post(name: .broadcastHandlerCompleted, object: self, userInfo: nil)
        }
        
        self.stateController()
        
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        scorecard.reCenterPopup(self)
        resizing = true
        view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        viewHeight = view.frame.height
        viewWidth = view.frame.width
        if self.resizing {
            self.bidMode = nil
            self.firstBidRefresh = true
            self.firstHandRefresh = true
            self.stateController()
        }
        self.resizing = false
    }
    
    // MARK: - TableView Overrides ===================================================================== -
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (handCardWidth == nil ? 0 : self.state.handSuits.count)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return handCardHeight * CGFloat(Int((self.state.handSuits[indexPath.row].cards.count - 1) / handCardsPerRow) + 1)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell: SuitTableCell
        
        // Suits
        
        cell = tableView.dequeueReusableCell(withIdentifier: "Suit Table Cell", for: indexPath) as! SuitTableCell
        cell.setCollectionViewDataSourceDelegate(self, forRow: indexPath.row)
        suitCollectionView[indexPath.row] = cell.cardCollection
        suitEnable(enable: suitEnabled[indexPath.row], suitNumber: indexPath.row + 1)
        
        self.checkTestWait()
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        return nil
    }
    
    // MARK: - CollectionView Overrides ================================================================ -
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        if collectionView.tag == Int(1e6) {
            // Bid buttons
            if moreMode {
                return currentCards + 2
            } else {
                return min(maxBidButton + 2, currentCards + 1)
            }
        } else if collectionView.tag == Int(2e6) {
            // Played cards
            if bidMode == nil || bidMode {
                return 0
            } else {
                return self.scorecard.currentPlayers
            }
        } else {
            // Hand cards
            return self.state.handSuits[collectionView.tag].cards.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView.tag == Int(1e6) {
            // Bid buttons
            return CGSize(width: bidButtonSize, height: bidButtonSize)
        } else if collectionView.tag == Int(2e6) {
            // Played cards
            return CGSize(width: tabletopCellWidth, height: tabletopViewHeight - 8)
        } else {
            // Hand cards
            return CGSize(width: handCardWidth, height: handCardHeight)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView.tag == Int(1e6) {
            // Bid buttons
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Bid Collection Cell", for: indexPath) as! BidCollectionCell
            if indexPath.row <= maxBidButton || (moreMode && indexPath.row <= currentCards) {
                cell.bidButton.text = "\(indexPath.row)"
            } else if !moreMode {
                cell.bidButton.text = ">"
            } else {
                cell.bidButton.text = "<"
            }
            cell.bidButton.tag = indexPath.row
            ScorecardUI.roundCorners(cell.bidButton)
            bidButton[indexPath.row] = cell.bidButton
            self.bidEnable(indexPath.row, bidButtonEnabled[indexPath.row])
            return cell
            
        } else if collectionView.tag == Int(2e6) {
            // Played cards
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Played Card Collection Cell", for: indexPath) as! PlayedCardCollectionCell
            
            var toLead: Int
            var cards: [Card]
            if lastHand {
                toLead = self.state.lastToLead!
                cards = self.state.lastCards!
            } else {
                toLead = self.state.toLead!
                cards = self.state.trickCards!
            }
            
            // Name
            let playerNumber = ((indexPath.row + (toLead - 1)) % self.scorecard.currentPlayers) + 1
            let player = self.scorecard.enteredPlayer(playerNumber)
            cell.playerNameLabel.text = player.playerMO!.name!
            
            // Bid and made
            let bid = player.bid(self.round)
            if bid == nil {
                cell.playerBidLabel.text = ""
            } else {
                cell.playerBidLabel.text = "Bid \(bid!)"
            }
            cell.playerMadeLabel.text = playerMadeText(playerNumber)
            cell.playerMadeLabel.textColor = UIColor.black
            
            // Format card
            cell.playedCardWidthConstraint.constant = tabletopCardWidth
            cell.playedCardHeightConstraint.constant = tabletopCardHeight
            ScorecardUI.moreRoundCorners(cell.cardView)
            cell.cardLabel.font = UIFont.systemFont(ofSize: self.playedCardFontSize)
            
            // Show card
            if indexPath.row >= cards.count {
                // Card is blank
                cell.cardView.isHidden = true
            } else {
                // Show card
                cell.cardView.isHidden = false
                cell.cardLabel.attributedText = cards[indexPath.row].toAttributedString()
            }
            
            // Save UI elements
            self.playerCardView[indexPath.row] = cell.cardView
            self.playerCardLabel[indexPath.row] = cell.cardLabel
            self.playerNameLabel[indexPath.row] = cell.playerNameLabel
            self.playerBidLabel[indexPath.row] = cell.playerBidLabel
            self.playerMadeLabel[indexPath.row] = cell.playerMadeLabel
            
            return cell
            
        } else {
            // Hand cards
            let suit = collectionView.tag + 1
            let card = indexPath.row + 1
            
            var cell: CardCollectionCell
            
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Card Collection Cell", for: indexPath) as! CardCollectionCell
            
            cell.cardLabel.attributedText = self.state.handSuits[suit-1].cards[card - 1].toAttributedString()
            cell.cardLabel.font = UIFont.systemFont(ofSize: self.handCardFontSize)
            ScorecardUI.moreRoundCorners(cell.cardView)
            cell.tag = self.state.handSuits[suit-1].cards[card - 1].toNumber()
            
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if collectionView.tag == Int(1e6) {
                return (self.bidMode && bidButtonEnabled[indexPath.row])
        } else {
            return !self.bidMode
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView.tag == Int(1e6) {
            if indexPath.row <= maxBidButton || (moreMode && indexPath.row <= currentCards) {
                confirmBid(bid: indexPath.row)
            } else if !moreMode {
                // Switch to more mode
                moreMode = true
                setupBidSize()
                self.bidCollectionView.reloadData()
            } else {
                // Leave more mode
                moreMode = false
                setupBidSize()
                self.bidCollectionView.reloadData()
            }
            bidsEnable(true, blockRemaining: self.entryPlayerNumber(self.round) == self.scorecard.currentPlayers)
        } else {
            confirmCard(collectionView, indexPath)
        }
    }
    
    // MARK: - Main state controller  ================================================================ -
    
    // Works out what next, enables and disables controls and gives instructions
    
    func stateController() {
        // Check whether bidding finished
        var bids: [Int] = []
        for playerNumber in 1...self.scorecard.currentPlayers {
            let bid = scorecard.entryPlayer(playerNumber).bid(round)
            if bid != nil {
                bids.append(bid!)
            }
        }
        
        let newBidMode = (bids.count < self.scorecard.currentPlayers)
        if self.bidMode != newBidMode {
            if newBidMode == false && !firstBidRefresh {
                // About to exit bid mode - delay 3 seconds
                setupOverUnder()
                self.instructionView.backgroundColor = UIColor.darkGray
                self.instructionTextView.text = "Bidding Complete"
                self.finishButton.isHidden = true
                self.scorecard.commsHandlerMode = .viewTrick
                Utility.executeAfter(delay: (self.scorecard.autoPlay != 0 ? 0.1 : 3.0), completion: {
                    self.finishButton.isHidden = false
                    self.scorecard.commsHandlerMode = .none
                    NotificationCenter.default.post(name: .broadcastHandlerCompleted, object: self, userInfo: nil)
                    self.bidMode(newBidMode)
                    self.stateController()
                })
                return
            } else {
                self.bidMode(newBidMode)
            }
        }
        
        if bidMode {
        // Bidding
            cardsEnable(false)
            if self.entryPlayerNumber(self.enteredPlayerNumber) == bids.count + 1 {
                // Your bid
                bidsEnable(true, blockRemaining: bids.count == self.scorecard.currentPlayers - 1)
                self.instructionTextView.text = "You to bid \(self.scorecard.enteredPlayer(enteredPlayerNumber).playerMO!.name!)"
                self.instructionView.backgroundColor = UIColor.blue
                self.alertUser()
                self.autoBid()
            } else {
                bidsEnable(false)
                self.instructionTextView.text = "\(self.scorecard.entryPlayer(bids.count + 1).playerMO!.name!) to bid"
                self.instructionView.backgroundColor = UIColor.darkGray
            }
            setupOverUnder()
            lastHandButton.isHidden = true
        } else {
            // Playing cards
            if self.state.trickCards.count == self.scorecard.currentPlayers {
                // Hand complete - check who won
                let cardLed = self.state.trickCards[0]
                var highLed = cardLed.rank
                var highTrump: Int!
                var winner = 1
                var win2 = (cardLed.toRankString() == "2")
                for cardNumber in 2...self.scorecard.currentPlayers {
                    let cardPlayed = self.state.trickCards[cardNumber - 1]
                    if cardPlayed.suit == cardLed.suit {
                        if cardPlayed.rank > highLed! && highTrump == nil {
                            // Highest card in suit led and no trumps played
                            highLed = cardPlayed.rank
                            winner = cardNumber
                            win2 = (cardPlayed.toRankString() == "2")
                        }
                    } else if cardPlayed.suit == self.scorecard.roundSuit(self.round, suits: self.state.suits) && (highTrump == nil || cardPlayed.rank > highTrump) {
                        highTrump = cardPlayed.rank
                        winner = cardNumber
                        win2 = (cardPlayed.toRankString() == "2")
                    }
                }
                
                if self.scorecard.isHosting {
                    // Remove current trick from deal
                    for (index, card) in self.state.trickCards.enumerated() {
                        let playerNumber = self.state.playerNumber(index + 1)
                        _ = self.scorecard.deal.hands[playerNumber - 1].removeCard(card)
                    }
                }
                
                // Store and reset cards played / who led / trick
                self.state.nextTrick()
                
                // Set next to lead from winner
                self.state.toLead = self.state.playerNumber(winner)
                self.state.toPlay = self.state.toLead
                
                // Update tricks made
                self.state.made[self.state.toPlay - 1] += 1
                self.state.twos[self.state.toPlay - 1] += (self.state.bonus2 && win2 ? 1 : 0)
                
                // Save deal and current (blank) trick for recovery
                if self.scorecard.isHosting {
                    self.scorecard.recovery.saveHands(deal: self.scorecard.deal, made: self.state.made,twos: self.state.twos)
                }
                
                // Update tricks made on screen
                self.playerMadeLabel[winner-1]?.text = playerMadeText(self.state.toPlay)
                self.playerMadeLabel[winner-1]?.textColor = UIColor.white
                
                // Disable lookback
                lastHandButton.isHidden = true
                
                if self.state.trick <= self.currentCards {
                    // Get ready for the new trick - won't refresh until next card played
                    self.nextCard()
                    if self.state.toPlay != self.enteredPlayerNumber {
                        // Don't refresh (or exit) for at least 1 second
                        self.scorecard.commsHandlerMode = .viewTrick
                        self.finishButton.isHidden = true
                        Utility.executeAfter(delay: (self.scorecard.autoPlay != 0 ? 0.1 : 1.0), completion: {
                            self.finishButton.isHidden = false
                            self.scorecard.commsHandlerMode = .none
                            NotificationCenter.default.post(name: .broadcastHandlerCompleted, object: self, userInfo: nil)
                        })
                    }
                } else {
                    // Hand finished
                    self.finishButton.isHidden = true
                    self.scorecard.commsHandlerMode = .viewTrick
                    Utility.executeAfter(delay: (self.scorecard.autoPlay != 0 ? 0.1 : 2.0), completion: {
                        // Return to scorepad after 2 seconds
                        if self.scorecard.isHosting {
                            // Record scores (in the order they happened)
                            for playerNumber in 1...self.scorecard.currentPlayers {
                                let player = self.scorecard.roundPlayer(playerNumber: playerNumber, round: self.round)
                                player.setMade(self.round, self.state.made[player.playerNumber - 1])
                                player.setTwos(self.round, self.state.twos[player.playerNumber - 1], bonus2: self.state.bonus2)
                            }
                        }
                        self.state.finished = true
                        self.scorecard.commsHandlerMode = .dismiss
                        self.dismissHand()
                    })
                }
            } else {
                // Work out who should play
                self.state.toPlay = self.state.playerNumber(self.state.trickCards.count + 1)
                let hasPlayed = (self.enteredPlayerNumber + (self.state.toLead > self.enteredPlayerNumber ? self.scorecard.currentPlayers : 0)) >= (self.state.toLead + self.state.trickCards.count)
                lastHandButton.isHidden = (self.state.lastCards.count == 0 || !hasPlayed)
                    
                self.nextCard()
            }
            if self.scorecard.isHosting {
                // Save trick for recovery
                self.scorecard.recovery.saveTrick(toLead: self.state.toLead, trickCards: self.state.trickCards)
            }
        }
    }
    
    private func nextCard() {
        if self.state.toPlay == self.enteredPlayerNumber {
            // Me to play
            if self.state.trickCards.count == 0 {
                // Me to lead - can lead anything
                self.cardsEnable(true)
            } else {
                let cardLed = self.state.trickCards[0]
                let suitLedXref = self.state.xref[cardLed.suit]
                if  suitLedXref == nil || self.state.handSuits[suitLedXref!].cards.count == 0 {
                    // Dont' have this suit - can play anything
                    self.cardsEnable(true)
                } else {
                    // Got some of suit led - must follow suit
                    self.cardsEnable(true, suit: cardLed.suit)
                }
            }
            self.instructionTextView.text = "You to play \(self.scorecard.enteredPlayer(self.enteredPlayerNumber).playerMO!.name!)"
            self.instructionView.backgroundColor = UIColor.blue
            self.alertUser()
            self.autoPlay()
        } else {
            self.cardsEnable(false)
            self.instructionTextView.text = "\(self.scorecard.enteredPlayer(self.state.toPlay).playerMO!.name!) to play"
            self.instructionView.backgroundColor = UIColor.darkGray
        }
    }
    
    // MARK: - Routines to update UI from messages received ============================================ -
    
    public func reflectBid(round: Int, enteredPlayerNumber: Int) {
        // Must be in bid mode - simply fill in the right bid
        // Note that the player number sent will be the enterd player number and hence must be converted
        if bidMode != nil && bidMode && round == self.round {
            let entryPlayerNumber = self.entryPlayerNumber(enteredPlayerNumber)
            setupPlayerBidText(entryPlayerNumber: entryPlayerNumber, animate:true)
            self.stateController()
        }
    }
    
    public func reflectCardPlayed(round: Int, trick: Int, playerNumber: Int, card: Card) {
        if !bidMode && !self.state.finished && round == self.round && trick == self.state.trick && playerNumber == self.state.toPlay {
            // Play card
            self.playCard(card: card)
        }
    }
    
    // MARK: - Form Presentation / Handling Routines =================================================== -
    
    func setupArrays() {
        statusPlayerBidLabel.append(statusPlayer1BidLabel)
        statusPlayerBidLabel.append(statusPlayer2BidLabel)
        statusPlayerBidLabel.append(statusPlayer3BidLabel)
        statusPlayerBidLabel.append(statusPlayer4BidLabel)
        for _ in 1...scorecard.currentPlayers {
            playerCardView.append(nil)
            playerCardLabel.append(nil)
            playerNameLabel.append(nil)
            playerBidLabel.append(nil)
            playerMadeLabel.append(nil)
        }
    }

    func bidMode(_ mode: Bool!) {
        var buttonsAcross: Int
        var buttonsDown: Int
        
        self.bidMode = mode
        if ScorecardUI.landscapePhone() {
            buttonsAcross = 2
            buttonsDown = 4
            bidSeparator.isHidden = false
        } else {
            buttonsAcross = 3
            buttonsDown = 3
            bidSeparator.isHidden = true
        }
        maxBidButton = (buttonsAcross * buttonsDown) - 2
        if ScorecardUI.landscapePhone() {
            bidViewHeight = viewHeight - instructionHeight
            bidButtonSize = min(50.0, (((bidViewHeight * CGFloat(4.0/5.0)) - 8.0) / CGFloat(buttonsDown)) - 10.0)
        } else {
            bidButtonSize = min(50.0, CGFloat(((viewWidth - 16.0) / 6.0) - 10.0))
            bidViewHeight = ((bidButtonSize + 10.0) * CGFloat(buttonsDown)) + 6.0
        }
        bidViewWidth = ((bidButtonSize + 10.0) * CGFloat(buttonsAcross)) + 6.0

        handViewWidth = (self.viewWidth / (ScorecardUI.landscapePhone() ? 2 : 1))
        if ScorecardUI.landscapePhone() {
            handViewHeight = self.viewHeight - instructionHeight
            tabletopViewHeight = handViewHeight
        } else {
            handViewHeight = self.viewHeight - bidViewHeight - instructionHeight
            tabletopViewHeight = bidViewHeight
        }
        
        if bidMode {
            tabletopView.isHidden = true
            bidView.isHidden = false
            
            setupBidSize()
            setupHandSize()
            if self.firstBidRefresh {
                handTableView.reloadData()
                bidCollectionView.reloadData()
                firstBidRefresh = false
            }
            setupBidText()
        } else {
            bidView.isHidden = true
            tabletopView.isHidden = false
            setupTabletopSize()
            setupHandSize()
            if self.firstHandRefresh {
                handTableView.reloadData()
                playedCardCollectionView.reloadData()
                firstHandRefresh = false
            }
        }
    }
    
    func bidsEnable(_ enable: Bool, blockRemaining: Bool = false) {
        let remaining = scorecard.remaining(playerNumber: entryPlayerNumber(self.enteredPlayerNumber), round: self.round, mode: .bid, rounds: self.state.rounds, cards: self.state.cards, bounce: self.state.bounce)
        for bid in 0...bidButton.count - 1 {
            if !enable || (blockRemaining && (bid == remaining && (moreMode || bid <= maxBidButton))) {
                bidButtonEnabled[bid] = false
            } else {
                bidButtonEnabled[bid] = true
            }
            bidEnable(bid, bidButtonEnabled[bid])
        }
    }
    
    func bidEnable(_ bid: Int, _ enable: Bool) {
        if enable {
            bidButton[bid]?.alpha = 1.0
            bidButton[bid]?.backgroundColor = ScorecardUI.darkHighlightColor
        } else {
            bidButton[bid]?.alpha = 0.3
            bidButton[bid]?.backgroundColor = ScorecardUI.highlightColor
        }
    }
    
    func cardsEnable(_ enable: Bool, suit matchSuit: Suit! = nil) {
        if self.state.handSuits != nil && self.state.handSuits.count > 0 {
            for suitNumber in 1...self.state.handSuits.count {
                suitEnable(enable: enable, suitNumber: suitNumber, matchSuit: matchSuit)
            }
        }
    }
    
    func suitEnable(enable: Bool, suitNumber: Int, matchSuit: Suit! = nil) {
        let suit = self.state.handSuits[suitNumber - 1]
        if enable && suit.cards.count != 0 && (matchSuit == nil || matchSuit == suit.cards[0].suit) {
            suitCollectionView[suitNumber-1]?.isUserInteractionEnabled = true
            suitCollectionView[suitNumber-1]?.alpha = 1.0
            suitEnabled[suitNumber-1] = true
        } else {
            suitCollectionView[suitNumber-1]?.isUserInteractionEnabled = false
            if bidMode {
                suitCollectionView[suitNumber-1]?.alpha = 0.9
            } else {
                suitCollectionView[suitNumber-1]?.alpha = 0.5
            }
            suitEnabled[suitNumber-1] = false
        }
    }
    
    func setupHandSize() {
        // configure the hand section
        
        var maxSuitCards = 0
        handCardsPerRow = 5
        let handTableViewHeight = handViewHeight - 16
        let handTableViewWidth = handViewWidth! - 16
        // Set hand height
        self.handHeightConstraint.constant = handViewHeight
        
        for suit in self.state.handSuits {
            maxSuitCards = max(maxSuitCards, suit.cards.count)
        }
        
        var loop = 1
        while loop <= 2 {
            loop+=1
        
            var handRows = 0
            for suit in self.state.handSuits {
                handRows += Int((suit.cards.count - 1) / handCardsPerRow) + 1
            }
            handRows = max(4, handRows)
            
            self.handCardHeight = CGFloat(Int(handTableViewHeight / CGFloat(handRows))+1)
            self.handCardWidth = min(self.handCardHeight * CGFloat(2.0/3.0), handTableViewWidth / CGFloat(handCardsPerRow))
            
            handTableViewTrailingConstraint.constant = handTableViewWidth - (CGFloat(min(handCardsPerRow, maxSuitCards)) * handCardWidth) + 4 
            
            // Possibly see if more cards would fit on line
            if maxSuitCards <= handCardsPerRow || (CGFloat(handCardsPerRow) * handCardWidth) > handTableViewWidth {
                break
            }
            
            handCardsPerRow = Int(handTableViewWidth / handCardWidth)
        }
        self.handCardFontSize = self.handCardWidth / 2.5
    }
    
    func setupBidSize() {
        // Set bid height
        bidHeightConstraint.constant = bidViewHeight
        if moreMode {
            statusWidthConstraint.constant = 0
        } else {
            statusWidthConstraint.constant = (viewWidth / (ScorecardUI.landscapePhone() ? 2 : 1)) - bidViewWidth - 16.0
        }
        statusTextFontSize = min(24.0, (statusWidthConstraint.constant - 16.0) / 7.0)
        statusRoundLabel.font = UIFont.boldSystemFont(ofSize: statusTextFontSize)
        statusOverUnderLabel.font = UIFont.boldSystemFont(ofSize: statusTextFontSize)
        for playerNumber in 1...self.scorecard.currentPlayers {
            statusPlayerBidLabel[playerNumber - 1]!.font = UIFont.systemFont(ofSize: statusTextFontSize - 2.0)
        }
    }
    
    func setupTabletopSize() {
        // Set tabletop height
        let tableTopViewWidth = (self.viewWidth / (ScorecardUI.landscapePhone() ? 2 : 1)) - 72
        tabletopCellWidth = tableTopViewWidth / CGFloat(self.scorecard.currentPlayers)
        let maxTabletopCardHeight = tabletopViewHeight - (3 * 21) - (2 * 8)
        let maxTabletopCardWidth = tabletopCellWidth - 8
        if maxTabletopCardHeight * CGFloat(2.0/3.0) > maxTabletopCardWidth {
            tabletopCardWidth = maxTabletopCardWidth
            tabletopCardHeight = tabletopCardWidth * CGFloat(3.0/2.0)
        } else {
            tabletopCardHeight = maxTabletopCardHeight
            tabletopCardWidth = tabletopCardHeight * CGFloat(2.0/3.0)
        }
        self.playedCardFontSize = self.tabletopCardWidth / 2.5
        self.tableTopLabelFontSize = self.tabletopCellWidth / 5.0
    }
    
    func confirmCard(_ collectionView: UICollectionView, _ indexPath: IndexPath) {
        
        let cell = collectionView.cellForItem(at: indexPath)
        let card =  Card(fromNumber: cell!.tag)
        
        func playCard(alertAction: UIAlertAction) {
            Utility.mainThread { [unowned self] in
                self.isModalInPopover = true
                self.scorecard.sendCardPlayed(round: self.round, trick: self.state.trick, playerNumber: self.enteredPlayerNumber, card: card)
                self.playCard(card: card)
            }
        }
        
        func resetPopover(alertAction: UIAlertAction) {
            self.isModalInPopover = true
        }
        
        // Confirm card
        let alertController = UIAlertController(title: "", message: "\n\n\n\n\n", preferredStyle: UIAlertControllerStyle.alert)
        alertController.addAction(UIAlertAction(title: "Play card", style: UIAlertActionStyle.default, handler: playCard))
        alertController.addAction(UIAlertAction(title: "Change card", style: UIAlertActionStyle.default, handler: resetPopover))
        alertController.view.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
        let subview = (alertController.view.subviews.first?.subviews.first?.subviews.first!)! as UIView
        subview.backgroundColor = ScorecardUI.totalColor
        alertController.view.tintColor = UIColor.white
        self.present(alertController, animated: false, completion: {
            // Show the card
            let cardWidth: CGFloat = 60
            let label = UILabel(frame: CGRect(x: (alertController.view.frame.width - cardWidth) / CGFloat(2), y: 20, width: cardWidth, height: cardWidth * (3/2)))
            label.attributedText = card.toAttributedString()
            label.backgroundColor = UIColor.white
            label.font = UIFont.systemFont(ofSize: 30)
            label.textAlignment = .center
            ScorecardUI.roundCorners(label)
            alertController.view.addSubview(label)
        })
    }
    
    func playCard(card: Card) {
        // Disable rest of hand to avoid another play
        self.cardsEnable(false)

        // Remove the card from your hand
        if let (suitNumber, cardNumber) = Pack.findCard(hand: self.state.handSuits, card: card) {
            let collectionView = suitCollectionView[suitNumber]!
            let indexPath = IndexPath(row: cardNumber, section: 0)
            collectionView.performBatchUpdates({
                collectionView.deleteItems(at: [indexPath])
                self.state.handSuits[suitNumber].cards.remove(at: cardNumber)
            })
        }
        
        // Clear previous trick
        if self.state.trickCards.count == 0 {
            // Clear previous trick
            self.playedCardCollectionView.reloadData()
        }
    
        // Show the card on the tabletop
        let nextCard = self.state.trickCards.count
        if nextCard < self.scorecard.currentPlayers {
            self.playerCardView[nextCard]!.isHidden = false
            self.playerCardLabel[nextCard]!.attributedText = card.toAttributedString()
            
            // Store the cards played and move on
            self.state.trickCards.append(card)
        }
        
        self.stateController()
    }
    
    func confirmBid(bid: Int) {
        let alertController = UIAlertController(title: "", message: "\n\n\n", preferredStyle: UIAlertControllerStyle.alert)
        alertController.addAction(UIAlertAction(title: "Confirm bid", style: UIAlertActionStyle.default, handler: { (UIAlertAction) in
            self.makeBid(bid)
        }))
        alertController.addAction(UIAlertAction(title: "Change bid", style: UIAlertActionStyle.default, handler: { (UIAlertAction) in
            self.resetPopover()
        }))
        alertController.view.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
        let subview = (alertController.view.subviews.first?.subviews.first?.subviews.first!)! as UIView
        subview.backgroundColor = ScorecardUI.totalColor
        alertController.view.tintColor = UIColor.white
        self.present(alertController, animated: false, completion: {
            // Show the bid
            let label = UILabel(frame: CGRect(x: (alertController.view.frame.width - 50) / CGFloat(2), y: 20, width: 50, height: 50))
            label.text = "\(bid)"
            label.backgroundColor = ScorecardUI.darkHighlightColor
            label.textColor = UIColor.black
            label.font = UIFont.systemFont(ofSize: 30)
            label.textAlignment = .center
            ScorecardUI.roundCorners(label)
            alertController.view.addSubview(label)
        })
    }
    
    func makeBid(_ bid: Int) {
        self.isModalInPopover = true
        self.scorecard.enteredPlayer(enteredPlayerNumber).setBid(round, bid)
        let entryPlayerNumber = self.entryPlayerNumber(enteredPlayerNumber)
        setupPlayerBidText(entryPlayerNumber: entryPlayerNumber, animate: true)
        if moreMode {
            moreMode = false
            setupBidSize()
            self.bidCollectionView.reloadData()
        }
        self.stateController()
    }
    
    func resetPopover() {
        self.isModalInPopover = true
    }
    
    func playerMadeText(_ playerNumber: Int) -> String {
        var result: String
        let made = self.state.made[playerNumber - 1]
        if made == 0 {
            result = ""
        } else {
            result = "Made \(made)"
            if self.state.bonus2 {
                let twos = self.state.twos[playerNumber - 1]
                if twos > 0 {
                    for _ in 1...twos {
                        result = result + "*"
                    }
                }
            }
        }
        return result
    }
    
    // MARK: - Utility Routines ======================================================================= -
        
    func entryPlayerNumber(_ enteredPlayerNumber: Int) -> Int {
        // Everything in data is in entered player sequence but bids will be in entry player sequence this converts between them
        return self.scorecard.enteredPlayer(enteredPlayerNumber).entryPlayerNumber(round: self.round)
    }
    
    func setupOverUnder() {
        let totalRemaining = scorecard.remaining(playerNumber: 0, round: scorecard.selectedRound, mode: Mode.bid, rounds: self.state.rounds, cards: self.state.cards, bounce: self.state.bounce)
        if !self.scorecard.roundStarted(scorecard.selectedRound) {
            statusOverUnderLabel.text = ""
        } else {
            statusOverUnderLabel.textColor = (totalRemaining == 0 ? UIColor.black : (totalRemaining > 0 ? ScorecardUI.totalColor : UIColor.red))
            statusOverUnderLabel.text = " \(abs(Int64(totalRemaining))) \(totalRemaining >= 0 ? "under" : "over")"
        }
        statusRoundLabel.attributedText = self.scorecard.roundTitle(round, rounds: self.state.rounds, cards: self.state.cards, bounce: self.state.bounce)
    }
    
    func setupBidText() {
        
        for entryPlayerNumber in 1...scorecard.currentPlayers {
            setupPlayerBidText(entryPlayerNumber: entryPlayerNumber)
        }
    }
    
    func setupPlayerBidText(entryPlayerNumber: Int, animate: Bool = false) {
        let bid = scorecard.entryPlayer(entryPlayerNumber).bid(self.round)
        let name = scorecard.entryPlayer(entryPlayerNumber).playerMO!.name!
        if bid != nil {
            statusPlayerBidLabel[entryPlayerNumber - 1]!.text = "\(name) bid \(bid!)"
        } else {
            statusPlayerBidLabel[entryPlayerNumber - 1]!.text = "\(name)"
        }

    }
    
    private func dismissHand() {
        self.dismiss(animated: true, completion: {
            self.delegate?.handComplete()
            if self.scorecard.commsHandlerMode == .dismiss {
                self.scorecard.commsHandlerMode = .none
                NotificationCenter.default.post(name: .broadcastHandlerCompleted, object: self, userInfo: nil)
            }
        })
    }
    
    private func alertUser() {
        if self.scorecard.settingAlertVibrate {
            self.alertVibrate()
        }
        if self.scorecard.settingAlertFlash {
            self.view.alertFlash()
        }
    }
    
    // MARK: - Segue Prepare Handler =================================================================== -
    
    override internal func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier! {
        case "showHandRoundSummary":
            
            let destination  = segue.destination as! RoundSummaryViewController
            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = self.popoverPresentationController?.sourceView
            destination.preferredContentSize = CGSize(width: 400, height: 554)
            destination.returnSegue = "hideHandRoundSummary"
            destination.scorecard = self.scorecard
            destination.rounds = self.state.rounds
            destination.cards = self.state.cards
            destination.bounce = self.state.bounce
            destination.suits = self.state.suits
            
        case "showHandGameSummary":
            
            let destination = segue.destination as! GameSummaryViewController
            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = self.popoverPresentationController?.sourceView
            destination.preferredContentSize = CGSize(width: 400, height: 554)
            destination.scorecard = self.scorecard
            destination.firstGameSummary = false
            destination.gameSummaryMode = .display
            destination.rounds = self.state.rounds
            
        default:
            break
        }
    }
}



// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class SuitTableCell: UITableViewCell {
    
    @IBOutlet weak var cardCollection: UICollectionView!
    
    
    func setCollectionViewDataSourceDelegate
        <D: UICollectionViewDataSource & UICollectionViewDelegate>
        (_ dataSourceDelegate: D, forRow row: Int) {
        
        cardCollection.delegate = dataSourceDelegate
        cardCollection.dataSource = dataSourceDelegate
        cardCollection.tag = row
        cardCollection.reloadData()
    }
}

class CardCollectionCell: UICollectionViewCell {
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var cardLabel: UILabel!
}

class PlayedCardCollectionCell: UICollectionViewCell {
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var cardLabel: UILabel!
    @IBOutlet weak var playerNameLabel: UILabel!
    @IBOutlet weak var playerBidLabel: UILabel!
    @IBOutlet weak var playerMadeLabel: UILabel!
    @IBOutlet weak var playedCardHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var playedCardWidthConstraint: NSLayoutConstraint!
}

class BidCollectionCell: UICollectionViewCell {
    @IBOutlet weak var bidButton: UILabel!
}

class HandState {
    // Everything that needs to be preserved when playing online hand
    public let enteredPlayerNumber : Int
    public var round: Int
    private var players: Int
    public var rounds: Int
    public var cards: [Int]
    public var bounce: Bool
    public var bonus2: Bool
    public var suits: [Suit]
    private var dealerIs: Int
    public var trick: Int!
    public var trickCards: [Card]!
    public var lastCards: [Card]!
    public var made: [Int]!
    public var twos: [Int]!
    public var hand: Hand!
    public var toLead: Int!
    public var lastToLead: Int!
    public var toPlay: Int!
    
    public var xref: [Suit : Int]!
    private var _handSuits: [HandSuit]!
    public var handSuits: [HandSuit]! {
        get {
            return self._handSuits
        }
        set {
            self._handSuits = newValue
            xref = [:]
            if self._handSuits != nil && self._handSuits.count > 0 {
                for suitNumber in 1...self._handSuits.count {
                    if self._handSuits[suitNumber - 1].cards.count != 0 {
                        xref[self._handSuits[suitNumber - 1].cards[0].suit] = suitNumber - 1
                    }
                }
            }
        }
    }
    public var finished: Bool!
    
    init(enteredPlayerNumber: Int, round: Int, dealerIs: Int, players: Int, rounds: Int, cards: [Int], bounce: Bool, bonus2: Bool, suits: [Suit],
         trick: Int? = nil, made: [Int]? = nil, twos: [Int]? = nil, trickCards: [Card]? = nil, toLead: Int? = nil) {
        self.enteredPlayerNumber = enteredPlayerNumber
        self.round = round
        self.players = players
        self.rounds = rounds
        self.cards = cards
        self.bounce = bounce
        self.bonus2 = bonus2
        self.suits = suits
        self.dealerIs = dealerIs
        self.reset()
        // Optional elements
        if trick != nil {
            self.trick = trick
        }
        if made != nil {
            self.made = made
        }
        if twos != nil {
            self.twos = twos
        }
        if trickCards != nil {
            self.trickCards = trickCards
        }
        if toLead != nil {
            self.toLead = toLead
            self.toPlay = self.playerNumber(self.trickCards.count + 1)
        }
    }
    
    public func reset() {
        self.trick = 1
        self.trickCards = []
        self.lastCards = []
        self.made = []
        self.twos = []
        for _ in 1...self.players {
            self.made.append(0)
            self.twos.append(0)
        }
        self.toLead = (((self.dealerIs - 1) + (self.round - 1)) % self.players) + 1
        self.toPlay = self.toLead
        self.hand = nil
        self.handSuits = nil
        self.finished = false
    }
    
    public func nextTrick() {
        self.lastCards = []
        for card in self.trickCards {
            self.lastCards.append(card)
        }
        self.trickCards.removeAll()
        self.lastToLead = self.toLead
        self.trick = self.trick + 1
    }
    
    public func playerNumber(_ sequence: Int) -> Int {
        return (((self.toLead - 1) + (sequence - 1)) % self.players) + 1
    }
}
