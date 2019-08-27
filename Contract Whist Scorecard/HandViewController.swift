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

class HandViewController: CustomViewController, UITableViewDataSource, UITableViewDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, ScorecardAlertDelegate {

    // MARK: - Class Properties ======================================================================== -
    
    // Main state properties
    private let scorecard = Scorecard.shared
    
    // Local state properties
    private var currentCards = 0
    internal var bidMode: Bool!
    private var firstBidRefresh = true
    private var firstHandRefresh = true
    private var firstTime = true
    private var resizing = false
    internal var state: HandState!                  // local pointer to hand state object
    internal var enteredPlayerNumber: Int!          // local version of player number
    internal var round: Int!                        // local version of round number
    internal var suitEnabled = [Bool](repeating: false, count: 6)
    private var lastHand = false
    internal var handTestData = HandTestData()
    private var collectionHand: Hand!    // Mirror of the hand in state - updated to reflect in collection
    
    // Delegates
    public var delegate: HandStatusDelegate!
    public var computerPlayerDelegate: [ Int : ComputerPlayerDelegate? ]?
    
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
    private let separatorHeight: CGFloat = 0.0
    private let playedCardCollectionHorizontalMargins: CGFloat = 16.0
    private let playedCardCollectionVerticalMargins: CGFloat = 24.0
    private let playedCardStats: CGFloat = (3 * 21.0) + 4.0
    private let playedCardSpacing: CGFloat = 4.0
    private var maxBidButton: Int!
    private var buttonsAcross: Int!
    private var buttonsDown: Int!
    private var moreMode = false
    private var handCardFontSize: CGFloat!
    private var statusTextFontSize: CGFloat!
    private var playedCardFontSize: CGFloat!
    private var tableTopLabelFontSize: CGFloat!
    private var bidCollectionTag: Int!
    private var playedCardCollectionTag: Int!
    
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
    @IBOutlet private weak var handSourceView: UIView!
    @IBOutlet private weak var tabletopView: UIView!
    @IBOutlet private weak var statusWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var bidView: UIView!
    @IBOutlet private weak var bidCollectionView: UICollectionView!
    @IBOutlet private weak var bidSeparator: UIView!
    @IBOutlet private weak var instructionView: UIView!
    @IBOutlet private weak var instructionViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var instructionViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var separatorHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var instructionLabel: UILabel!
    @IBOutlet private weak var statusRoundLabel: UILabel!
    @IBOutlet private weak var statusOverUnderLabel: UILabel!
    @IBOutlet private weak var statusPlayer1BidLabel: UILabel!
    @IBOutlet private weak var statusPlayer2BidLabel: UILabel!
    @IBOutlet private weak var statusPlayer3BidLabel: UILabel!
    @IBOutlet private weak var statusPlayer4BidLabel: UILabel!
    @IBOutlet private weak var playedCardCollectionView: UICollectionView!
    @IBOutlet private weak var bannerPaddingView: UIView!
    @IBOutlet private weak var leftFooterPaddingView: UIView!
    @IBOutlet private weak var leftPaddingView: UIView!
    @IBOutlet private weak var finishButton: UIButton!
    @IBOutlet private weak var lastHandButton: UIButton!
    @IBOutlet private weak var overUnderButton: UIButton!
    @IBOutlet private weak var roundSummaryButton: UIButton!
    @IBOutlet private weak var titleBarLongPress: UILongPressGestureRecognizer!
    @IBOutlet private weak var tableTopLongPress: UILongPressGestureRecognizer!
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction private func finishPressed(_ sender: UIButton) {
        self.dismissHand()
    }
    
    @IBAction private func roundSummaryPressed(_ sender: UIButton) {
        self.showRoundSummary()
    }
    
    @IBAction func lastHandPressed(_ sender: Any) {
        self.lastHand = true
        self.playedCardCollectionView.reloadData()
    }
    
    @IBAction func lastHandReleased(_ sender: Any) {
        self.lastHand = false
        self.playedCardCollectionView.reloadData()
    }
    
    @IBAction func longPresssGesture(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            self.lastHandPressed(sender)
        } else if sender.state == .ended && self.lastHand {
            self.lastHandReleased(sender)
        }
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
        
        // Setup grid tags
        bidCollectionTag = bidCollectionView.tag
        playedCardCollectionTag = playedCardCollectionView.tag
        
        setupArrays()
       
        self.mirrorHandSuitsToCollection()
        self.currentCards = self.scorecard.roundCards(round, rounds: self.state.rounds, cards: self.state.cards, bounce: self.state.bounce)
        
        // Put suit on summary button
        self.roundSummaryButton.setTitle(self.scorecard.roundSuit(self.round, suits: self.state.suits).toString(), for: .normal)
        self.roundSummaryButton.titleLabel?.adjustsFontSizeToFitWidth = true
        
        // Setup over under
        self.overUnderButton.titleLabel?.adjustsFontSizeToFitWidth = true
        setupOverUnder()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        viewHeight = view.safeAreaLayoutGuide.layoutFrame.height
        viewWidth = view.safeAreaLayoutGuide.layoutFrame.width
        
        if self.scorecard.commsHandlerMode == .playHand {
            // Notify client controller that hand display complete
            self.scorecard.commsHandlerMode = .none
            NotificationCenter.default.post(name: .clientHandlerCompleted, object: self, userInfo: nil)
        }
        
        // Take responsibility for alerts
        self.scorecard.alertDelegate = self
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        scorecard.reCenterPopup(self)
        resizing = true
        view.setNeedsLayout()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        viewHeight = view.safeAreaLayoutGuide.layoutFrame.height
        viewWidth = view.safeAreaLayoutGuide.layoutFrame.width
        self.instructionViewLeadingConstraint.constant = self.view.safeAreaInsets.left
        self.instructionViewTrailingConstraint.constant = self.view.safeAreaInsets.right
        self.separatorHeightConstraint.constant = self.separatorHeight
        self.setButtonFormat()
        if self.resizing {
            self.bidMode = nil
            self.firstBidRefresh = true
            self.firstHandRefresh = true
        }
        if self.firstTime || self.resizing {
            self.stateController()
        }
        self.resizing = false
        self.firstTime = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Give up responsibility for alerts
        self.scorecard.alertDelegate = nil
    }
    
    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        self.scorecard.motionBegan(motion, with: event)
    }
    
    // MARK: - TableView Overrides ===================================================================== -
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (handCardWidth == nil ? 0 : self.collectionHand.handSuits.count)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return handCardHeight * CGFloat(Int((self.collectionHand.handSuits[indexPath.row].cards.count - 1) / handCardsPerRow) + 1)
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
        if collectionView.tag == bidCollectionTag {
            // Bid buttons
            if moreMode {
                return currentCards + 2
            } else {
                return min(maxBidButton + 2, currentCards + 1)
            }
        } else if collectionView.tag == playedCardCollectionTag {
            // Played cards
            if bidMode == nil || bidMode {
                return 0
            } else {
                return self.scorecard.currentPlayers
            }
        } else {
            // Hand cards
            return self.collectionHand.handSuits[collectionView.tag].cards.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView.tag == bidCollectionTag {
            // Bid buttons
            return CGSize(width: bidButtonSize, height: bidButtonSize)
        } else if collectionView.tag == playedCardCollectionTag {
            // Played cards
            return CGSize(width: tabletopCellWidth, height: tabletopViewHeight - playedCardCollectionVerticalMargins)
        } else {
            // Hand cards
            return CGSize(width: handCardWidth, height: handCardHeight)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView.tag == bidCollectionTag {
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
            
        } else if collectionView.tag == playedCardCollectionTag {
            // Played cards
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Played Card Collection Cell", for: indexPath) as! PlayedCardCollectionCell
            
            var toLead: Int!
            var cards: [Card]!
            if lastHand {
                toLead = self.state.lastToLead
                cards = self.state.lastCards
            } else {
                toLead = self.state.toLead
                cards = self.state.trickCards
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
            cell.playerMadeLabel.textColor = Palette.tableTopText
            
            // Format card
            cell.playedCardWidthConstraint.constant = tabletopCardWidth
            cell.playedCardHeightConstraint.constant = tabletopCardHeight
            ScorecardUI.roundCorners(cell.cardView, percent: 10)
            cell.cardLabel.font = UIFont.systemFont(ofSize: self.playedCardFontSize)
            
            // Show card
            if indexPath.row >= cards.count {
                // Card is blank
                cell.cardView.isHidden = true
            } else {
                // Show card
                cell.cardView.isHidden = false
                cell.cardLabel.textColor = UIColor.white
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
            
            cell.cardLabel.textColor = UIColor.white
            cell.cardLabel.attributedText = self.collectionHand.handSuits[suit-1].cards[card - 1].toAttributedString()
            cell.cardLabel.font = UIFont.systemFont(ofSize: self.handCardFontSize)
            ScorecardUI.roundCorners(cell.cardView, percent: 10)
            cell.tag = self.collectionHand.handSuits[suit-1].cards[card - 1].toNumber()
            
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        
        if collectionView.tag == bidCollectionTag {
            // Bid collection - enable if in bid mode and not disabled
            return (self.bidMode && bidButtonEnabled[indexPath.row])
            
        } else if collectionView.tag == playedCardCollectionTag {
            // Played cards never interactive
            return false
            
        } else {
            // Must be suits collection - enable if not in bid mode
            return !self.bidMode
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView.tag == bidCollectionTag {
            if indexPath.row <= maxBidButton || (moreMode && indexPath.row <= currentCards) {
                confirmBid(bid: indexPath.row)
            } else {
                if !moreMode {
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
                bidsEnable(true, blockRemaining: self.scorecard.entryPlayerNumber(self.enteredPlayerNumber, round: self.round) == self.scorecard.currentPlayers)
            }
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
                // About to exit bid mode - delay 1 second
                setupOverUnder()
                self.setInstructionsHighlight(to: false)
                self.instructionLabel.text = "Bidding Complete"
                self.instructionLabel.adjustsFontForContentSizeCategory = true
                self.finishButton.isHidden = true
                self.scorecard.commsHandlerMode = .viewTrick
                self.executeAfter(delay: 1.0) {
                    self.finishButton.isHidden = false
                    self.scorecard.commsHandlerMode = .none
                    NotificationCenter.default.post(name: .clientHandlerCompleted, object: self, userInfo: nil)
                    self.bidMode(newBidMode)
                    self.stateController()
                }
                return
            } else {
                self.bidMode(newBidMode)
            }
        }
        
        if bidMode {
        // Bidding
            cardsEnable(false)
            if self.scorecard.entryPlayerNumber(self.enteredPlayerNumber, round: self.round) == bids.count + 1 {
                // Your bid
                bidsEnable(true, blockRemaining: bids.count == self.scorecard.currentPlayers - 1)
                self.instructionLabel.text = "You to bid"
                self.setInstructionsHighlight(to: true)
                self.scorecard.alertUser(remindAfter: 10.0)
                self.autoBid()
            } else {
                bidsEnable(false)
                self.instructionLabel.text = "\(self.scorecard.entryPlayer(bids.count + 1).playerMO!.name!) to bid"
                self.setInstructionsHighlight(to: false)
                // Get computer player to bid
                self.computerPlayerDelegate?[self.scorecard.entryPlayer(bids.count + 1).playerNumber]??.autoBid()
            }
            setupOverUnder()
            lastHandButton.isHidden = true
            tableTopLongPress.isEnabled = false
            titleBarLongPress.isEnabled = false
        } else {
            // Playing cards - save current cards in trick
            let currentTrickCards = self.state.trickCards.count

            // Update state
            self.scorecard.updateState(alertUser: false)
            
            if currentTrickCards == self.scorecard.currentPlayers && self.state.trick > 1 {
                // Hand complete - update tricks made on screen
                self.playerMadeLabel[self.state.winner! - 1]?.text = playerMadeText(self.state.toPlay!)
                self.playerMadeLabel[self.state.winner! - 1]?.textColor = Palette.tableTopTextContrast
                
                // Disable lookback
                lastHandButton.isHidden = true
                tableTopLongPress.isEnabled = false
                titleBarLongPress.isEnabled = false

                
                if self.state.trick <= self.currentCards {
                    // Get ready for the new trick - won't refresh until next card played
                    self.nextCard()
                    if self.state.toPlay != self.enteredPlayerNumber {
                        // Don't refresh (or exit) for at least 1 second
                        self.scorecard.commsHandlerMode = .viewTrick
                        self.finishButton.isHidden = true
                        self.executeAfter(delay: 1.0) {
                            self.finishButton.isHidden = false
                            self.scorecard.commsHandlerMode = .none
                            NotificationCenter.default.post(name: .clientHandlerCompleted, object: self, userInfo: nil)
                        }
                    }	
                } else {
                    // Hand finished
                    self.finishButton.isHidden = true
                    self.scorecard.commsHandlerMode = .viewTrick
                    self.executeAfter(delay: 2.0) {
                        // Return to scorepad after 2 seconds
                            self.scorecard.commsHandlerMode = .dismiss
                            self.dismissHand()
                    }
                }
            } else {
                // Work out who should play
                let hasPlayed = (self.enteredPlayerNumber + (self.state.toLead! > self.enteredPlayerNumber ? self.scorecard.currentPlayers : 0)) >= (self.state.toLead! + self.state.trickCards.count)
                lastHandButton.isHidden = (self.state.lastCards.count == 0 || !hasPlayed || self.state.lastToLead == nil)
                tableTopLongPress.isEnabled = !lastHandButton.isHidden
                titleBarLongPress.isEnabled = !lastHandButton.isHidden

                self.nextCard()
            }
        }
    }
    
    private func executeAfter(delay: TimeInterval, closure: @escaping ()->()) {
        if self.firstTime {
            // Not finished layout - do it immediately
            closure()
        } else {
            Utility.executeAfter(delay: (self.scorecard.autoPlayHands != 0 ? 0.1 : delay), completion: closure)
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
                let suitLed = self.state.hand.xrefSuit[cardLed.suit]
                if suitLed == nil || suitLed!.cards.count == 0 {
                    // Dont' have this suit - can play anything
                    self.cardsEnable(true)
                } else {
                    // Got some of suit led - must follow suit
                    self.cardsEnable(true, suit: cardLed.suit)
                }
            }
            self.instructionLabel.text = "You to play"
            self.setInstructionsHighlight(to: true)
            self.scorecard.alertUser(remindAfter: 10.0)
            self.autoPlay()
        } else {
            self.cardsEnable(false)
            self.instructionLabel.text = "\(self.scorecard.enteredPlayer(self.state.toPlay).playerMO!.name!) to play"
            self.setInstructionsHighlight(to: false)
            // Get computer player to play
            self.computerPlayerDelegate?[self.state.toPlay]??.autoPlay()
        }
    }
    
    // MARK: - Routines to update UI from messages received ============================================ -
    
    public func reflectBid(round: Int, enteredPlayerNumber: Int) {
        // Must be in bid mode - simply fill in the right bid
        // Note that the player number sent will be the enterd player number and hence must be converted
        if bidMode != nil && bidMode && round == self.round {
            let entryPlayerNumber = self.scorecard.entryPlayerNumber(enteredPlayerNumber, round: self.round)
            setupPlayerBidText(entryPlayerNumber: entryPlayerNumber, animate:true)
            self.stateController()
        }
    }
    
    public func reflectCardPlayed(round: Int, trick: Int, playerNumber: Int, card: Card) {
        if !bidMode && !self.state.finished && round == self.round && trick == self.state.trick && playerNumber == self.state.toPlay {
            // Play card
            self.refreshCardPlayed(card: card)
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
    
    func setButtonFormat() {
        // Work out how many buttons across and down and how large buttons must be
        var bidWidthProportion: CGFloat
        var bidHeightProportion: CGFloat
        var extraRow: Int
        let startButtonSize: CGFloat = 50.0
        let minButtonSize: CGFloat = 42.0
        let maxButtonSize: CGFloat = 55.0
        
        if ScorecardUI.landscapePhone() {
            // Assume using all the height and approx 1/4 of the width - need to allow for an extra row for bid title
            bidWidthProportion = 0.25
            bidHeightProportion = 1.0
            extraRow = 1
        } else {
            // Assume using about 1/2 the width and 30% of the height - bid title is above the bid summary in this mode
            bidWidthProportion = 0.5
            bidHeightProportion = 0.30
            extraRow=0
        }
        
        // Work out the number of buttons that will fit across
        let bidWidthMax = ((viewHeight * bidWidthProportion) - 6.0)
        buttonsAcross = max(2, min(3, Int(bidWidthMax / startButtonSize)))
        
        // Work out the number of buttons that will fit down
        let bidHeightMax = (viewHeight * bidHeightProportion) - instructionHeight
        buttonsDown = max(3, min(4, Int(bidHeightMax / startButtonSize) - extraRow))
        
        // Calculate optimum button size
        bidButtonSize = max(minButtonSize, min(maxButtonSize, (bidHeightMax / CGFloat(buttonsDown + extraRow)) - 10.0))
        
        // Calculate width from button size and bumber of buttons
        bidViewWidth = ((bidButtonSize + 10.0) * CGFloat(buttonsAcross)) + 6.0
        
        if ScorecardUI.landscapePhone() {
            // Still need to use all the height
            bidViewHeight = bidHeightMax
        } else {
            // Calculate so that buttons only just fit in
            bidViewHeight = ((bidButtonSize + 10.0) * CGFloat(buttonsDown)) + 12.0
        }
        
        // Hide vertical separator if there are3 rows of buttons across
        bidSeparator.isHidden = (buttonsAcross > 2)
        
        // Calculate total buttons and max bid coped with
        let buttons = (buttonsAcross * buttonsDown)
        if buttons >= currentCards + 1 {
            // All available bids fit
            maxBidButton = currentCards
        } else {
            // Allow for more button
            maxBidButton = buttons - 2
        }
    }

    func bidMode(_ mode: Bool!) {
        
        self.bidMode = mode

        handViewWidth = (self.viewWidth / (ScorecardUI.landscapePhone() ? 2 : 1))
        if ScorecardUI.landscapePhone() {
            handViewHeight = self.viewHeight - instructionHeight
            tabletopViewHeight = handViewHeight
        } else {
            handViewHeight = self.viewHeight - bidViewHeight - instructionHeight - separatorHeight
            tabletopViewHeight = bidViewHeight
        }
        
        if bidMode {
            tabletopView.isHidden = true
            bidView.isHidden = false
            leftFooterPaddingView.backgroundColor = Palette.background
            leftPaddingView.backgroundColor = Palette.background
            
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
            leftFooterPaddingView.backgroundColor = Palette.tableTop
            leftPaddingView.backgroundColor = Palette.tableTop
            
            setupTabletopSize()
            setupHandSize()
            if self.firstHandRefresh {
                handTableView.reloadData()
                playedCardCollectionView.reloadData()
                firstHandRefresh = false
            }
        }
        self.overUnderButton.isHidden = bidMode
    }
    
    func bidsEnable(_ enable: Bool, blockRemaining: Bool = false) {
        let remaining = scorecard.remaining(playerNumber: self.scorecard.entryPlayerNumber(self.enteredPlayerNumber, round: self.round), round: self.round, mode: .bid, rounds: self.state.rounds, cards: self.state.cards, bounce: self.state.bounce)
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
            bidButton[bid]?.backgroundColor = Palette.bidButton.withAlphaComponent(1.0)
        } else {
            bidButton[bid]?.backgroundColor = Palette.bidButton.withAlphaComponent(0.3)
        }
    }
    
    func cardsEnable(_ enable: Bool, suit matchSuit: Suit! = nil) {
        if self.state.hand.handSuits != nil && self.state.hand.handSuits.count > 0 {
            for suitNumber in 1...self.state.hand.handSuits.count {
                suitEnable(enable: enable, suitNumber: suitNumber, matchSuit: matchSuit)
            }
        }
    }
    
    func suitEnable(enable: Bool, suitNumber: Int, matchSuit: Suit! = nil) {
        let suit = self.state.hand.handSuits[suitNumber - 1]
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
        let handTableViewHeight = handViewHeight - 16
        let handTableViewWidth = handViewWidth! - 16
        handCardsPerRow = (handTableViewWidth >= 350 ? 6 : 5)
        // Set hand height
        self.handHeightConstraint.constant = handViewHeight
        
        for suit in self.state.hand.handSuits {
            maxSuitCards = max(maxSuitCards, suit.cards.count)
        }
        
        var loop = 1
        while loop <= 2 {
            loop+=1
        
            var handRows = 0
            for suit in self.state.hand.handSuits {
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
 
        let statusWidth = (viewWidth / (ScorecardUI.landscapePhone() ? 2 : 1)) - bidViewWidth - 16.0
        
        if moreMode {
            statusWidthConstraint.constant = 0
        } else {
            statusWidthConstraint.constant = statusWidth
        }
        statusTextFontSize = min(24.0, (statusWidth - 16.0) / 7.0)
        statusRoundLabel.font = UIFont.boldSystemFont(ofSize: statusTextFontSize)
        statusOverUnderLabel.font = UIFont.boldSystemFont(ofSize: statusTextFontSize)
        for playerNumber in 1...self.scorecard.currentPlayers {
            statusPlayerBidLabel[playerNumber - 1]!.font = UIFont.systemFont(ofSize: statusTextFontSize - 2.0)
        }
    }
    
    func setupTabletopSize() {
        // Set tabletop height
        let tableTopViewWidth: CGFloat = (self.viewWidth / (ScorecardUI.landscapePhone() ? 2 : 1)) - playedCardCollectionHorizontalMargins - (CGFloat(self.scorecard.currentPlayers-1) * playedCardSpacing)
        tabletopCellWidth = tableTopViewWidth / CGFloat(self.scorecard.currentPlayers)
        let maxTabletopCardHeight: CGFloat = tabletopViewHeight - playedCardCollectionVerticalMargins - playedCardStats
        let maxTabletopCardWidth = tabletopCellWidth - 8
        if maxTabletopCardHeight > maxTabletopCardWidth * CGFloat(3.0/2.0){
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
        
        let timeLeft = self.scorecard.cancelReminder()
        
        let cell = collectionView.cellForItem(at: indexPath)
        let card =  Card(fromNumber: cell!.tag)
        
        let cardWidth: CGFloat = 60
        let label = UILabel(frame: CGRect(x: 0.0, y: 0.0, width: cardWidth, height: cardWidth * 3.0/2.0))
        _ = Constraint.setWidth(control: label, width: cardWidth)
        _ = Constraint.setHeight(control: label, height: cardWidth * (3.0/2.0))
        label.attributedText = card.toAttributedString()
        label.backgroundColor = Palette.cardFace
        label.font = UIFont.systemFont(ofSize: 30)
        label.textAlignment = .center
        ScorecardUI.roundCorners(label)
        
        ConfirmPlayedViewController.show(title: "Confirm Card", content: label, sourceView: self.handSourceView, confirmText: "Play card", cancelText: "Change card", offsets: (0.5, nil), backgroundColor: Palette.tableTop, confirmHandler: { self.playCard(card: card) }, cancelHandler: { self.scorecard.restartReminder(remindAfter: timeLeft) })
    }
    
    func playCard(card: Card) {
        // Update data structures
        let round = self.round!
        let trick = self.state.trick!
        self.scorecard.sendCardPlayed(round: round, trick: trick, playerNumber: self.enteredPlayerNumber, card: card)
        self.scorecard.playCard(card: card)
        self.refreshCardPlayed(card: card)
    }
    
    func refreshCardPlayed(card: Card) {
        // Disable rest of hand to avoid another play
        self.cardsEnable(false)

        // Remove the card from your hand
        if let (suitNumber, cardNumber) = self.collectionHand.find(card: card) {
            let collectionView = suitCollectionView[suitNumber]!
            let indexPath = IndexPath(row: cardNumber, section: 0)
            collectionView.performBatchUpdates({
                collectionView.deleteItems(at: [indexPath])
                self.mirrorHandSuitsToCollection()
            })
        }
        
        // Clear previous trick
        if self.state.trickCards.count == 1 {
            // Clear previous trick
            self.playedCardCollectionView.reloadData()
        }
    
        // Show the card on the tabletop
        let currentCard = self.state.trickCards.count - 1
        if currentCard < self.scorecard.currentPlayers {
            self.playerCardView[currentCard]!.isHidden = false
            self.playerCardLabel[currentCard]!.textColor = Palette.cardFace
            self.playerCardLabel[currentCard]!.attributedText = card.toAttributedString()
        }
        
        self.stateController()
    }
    
    func confirmBid(bid: Int) {
        
        let timeLeft = self.scorecard.cancelReminder()
        
        let label = UILabel()
        _ = Constraint.setWidth(control: label, width: 50)
        _ = Constraint.setHeight(control: label, height: 50)
        label.text = "\(bid)"
        Palette.bidButtonStyle(label)
        label.font = UIFont.systemFont(ofSize: 30)
        label.textAlignment = .center
        ScorecardUI.roundCorners(label)
        
        ConfirmPlayedViewController.show(title: "Confirm Bid", content: label, sourceView: self.handSourceView, confirmText: "Confirm bid", cancelText: "Change bid", offsets: (0.5, nil), confirmHandler: { self.makeBid(bid) }, cancelHandler: { self.scorecard.restartReminder(remindAfter: timeLeft) })
    }
    
    func makeBid(_ bid: Int) {
        _ = self.scorecard.enteredPlayer(enteredPlayerNumber).setBid(round, bid)
        let entryPlayerNumber = self.scorecard.entryPlayerNumber(enteredPlayerNumber, round: self.round)
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
    
    func setupOverUnder() {
        let totalRemaining = scorecard.remaining(playerNumber: 0, round: scorecard.selectedRound, mode: Mode.bid, rounds: self.state.rounds, cards: self.state.cards, bounce: self.state.bounce)

        overUnderButton.setTitle("\(totalRemaining >= 0 ? "-" : "+")\(abs(Int64(totalRemaining)))", for: .normal)
        overUnderButton.setTitleColor((totalRemaining >= 0 ? Palette.contractUnder : Palette.contractOver), for: .normal)

        if !self.scorecard.roundStarted(scorecard.selectedRound) {
            statusOverUnderLabel.text = ""
        } else {
            statusOverUnderLabel.textColor = (totalRemaining == 0 ? Palette.contractEqual : (totalRemaining > 0 ? Palette.contractUnderLight : Palette.contractOver))
            statusOverUnderLabel.text = " \(abs(Int64(totalRemaining))) \(totalRemaining >= 0 ? "under" : "over")"
        }
        statusRoundLabel.textColor = UIColor.white
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
                NotificationCenter.default.post(name: .clientHandlerCompleted, object: self, userInfo: nil)
            }
        })
    }
    
    internal func alertUser(reminder: Bool) {
        if reminder {
            self.instructionView.alertFlash(duration: 0.3, repeatCount: 3, backgroundColor: Palette.tableTop)
            self.bannerPaddingView.alertFlash(duration: 0.3, repeatCount: 3, backgroundColor: Palette.tableTop)
        }
    }
    
    private func mirrorHandSuitsToCollection() {
        // Copy the hand suits to the version used by the collection (inside performBatchUpdates)
        // Need to copy individual values rather than pointers
        self.collectionHand = self.scorecard.handState.hand.copy() as? Hand
    }
    
    func setInstructionsHighlight(to highlight: Bool) {
        let nonHighlightBackgroundColor = (highlight ? Palette.hand : Palette.tableTop)
        let nonHighlightTextColor = (highlight ? Palette.handText : Palette.tableTopTextContrast)
        self.instructionView.backgroundColor = nonHighlightBackgroundColor
        self.instructionLabel.textColor = nonHighlightTextColor
        self.bannerPaddingView.backgroundColor = nonHighlightBackgroundColor
        self.finishButton.imageView!.image = UIImage(named: (highlight || !self.bidMode ? "cross white" : "cross white"))
        self.roundSummaryButton.setTitleColor(nonHighlightTextColor, for: .normal)
    }
    
    // MARK: - Show other views =================================================================== -
    
    private func showRoundSummary() {
        _ = RoundSummaryViewController.show(from: self, rounds: self.state.rounds, cards: self.state.cards, bounce: self.state.bounce, suits: self.state.suits)
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
    public var winner: Int?
    public var finished: Bool!
    
    init(enteredPlayerNumber: Int, round: Int, dealerIs: Int, players: Int, rounds: Int, cards: [Int], bounce: Bool, bonus2: Bool, suits: [Suit],
         trick: Int? = nil, made: [Int]? = nil, twos: [Int]? = nil, trickCards: [Card]? = nil, toLead: Int? = nil, lastCards: [Card]! = nil, lastToLead: Int! = nil) {
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
        if lastCards != nil {
            self.lastCards = lastCards
        }
        if lastToLead != nil {
            self.lastToLead = lastToLead
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
