//
//  HandViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 03/06/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit
import Combine

class HandViewController: ScorecardViewController, UITableViewDataSource, UITableViewDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, ScorecardAlertDelegate, BannerDelegate {
    
    // MARK: - Class Properties ======================================================================== -
    
    // Local state properties
    private var currentCards = 0
    internal var bidMode: Bool!
    private var firstBidRefresh = true
    private var firstHandRefresh = true
    internal var firstTime = true
    private var resizing = false
    internal var enteredPlayerNumber: Int!          // local version of player number
    internal var round: Int!                        // local version of round number
    internal var suitEnabled = [Bool](repeating: false, count: 6)
    private var lastHand = false
    internal var handTestData = HandTestData()
    private var mirroredHand: Hand!                 // Mirror of the hand in state - updated to reflect in collection
    private var mirroredTrickCards: [Card]!         // Mirror of the played cards in state - updated to reflect in collection
    private var bidSubscription: AnyCancellable?
    private var whisper = Whisper()
    
    // Component sizes
    private var viewWidth: CGFloat!
    private var viewHeight: CGFloat!
    private var handViewHeight: CGFloat!
    private var handViewWidth: CGFloat!
    private var tabletopViewHeight: CGFloat!
    private var bidViewHeight: CGFloat!
    private var bidCollectionViewWidth: CGFloat!
    private var handCardHeight: CGFloat!
    private var handCardWidth: CGFloat!
    private var handCardsPerRow: Int!
    private var tabletopCardHeight: CGFloat!
    private var tabletopCardWidth: CGFloat!
    private var tabletopCellWidth: CGFloat!
    private var bidButtonSize: CGFloat = 50.0
    private let separatorHeight: CGFloat = 0.0
    private let playedCardCollectionVerticalMargins: CGFloat = 24.0
    private let playedCardStats: CGFloat = (3 * 21.0) + 4.0
    private let playedCardSpacing: CGFloat = 4.0
    private let bidButtonSpacing: CGFloat = 10.0
    private let bidButtonVerticalSpace: CGFloat = 8.0
    private var horizontalMargins: CGFloat = 8.0
    private var handTableViewVerticalMargins: CGFloat = 8.0
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
    private var lastTitle: String?
    private var firstSuitLength: Int!
    
    private let finishButton = Banner.finishButton
    private let homeButton = 1
    private let lastHandButton = 2
    private let roundSummaryButton = 3
    private let overUnderButton = 4
    
    // UI component pointers
    private var bidButtonEnabled = [Bool](repeating: false, count: 15)
    
    // MARK: - IB Outlets -
    
    @IBOutlet private weak var banner: Banner!
    @IBOutlet private weak var handView: UIView!
    @IBOutlet private weak var separator: UIView!
    @IBOutlet private weak var handTableView: UITableView!
    @IBOutlet private weak var handHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var handSourceView: UIView!
    @IBOutlet private weak var tabletopView: UIView!
    @IBOutlet private weak var statusWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var bidView: UIView!
    @IBOutlet private weak var bidCollectionView: UICollectionView!
    @IBOutlet private weak var bidSeparator: UIView!
    @IBOutlet private weak var bidTitleSeparator: UIView!
    @IBOutlet private weak var separatorHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var statusRoundLabel: UILabel!
    @IBOutlet private weak var statusOverUnderLabel: UILabel!
    @IBOutlet private weak var statusTitleHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var statusPlayer1BidLabel: UILabel!
    @IBOutlet private weak var statusPlayer2BidLabel: UILabel!
    @IBOutlet private weak var statusPlayer3BidLabel: UILabel!
    @IBOutlet private weak var statusPlayer4BidLabel: UILabel!
    @IBOutlet private weak var playedCardCollectionView: UICollectionView!
    @IBOutlet private weak var footerPaddingView: UIView!
    @IBOutlet private weak var leftFooterPaddingView: UIView!
    @IBOutlet private weak var leftPaddingView: UIView!
    @IBOutlet private weak var titleBarLongPress: UILongPressGestureRecognizer!
    @IBOutlet private weak var tableTopLongPress: UILongPressGestureRecognizer!
    @IBOutlet private var viewInsets: [NSLayoutConstraint]!
    @IBOutlet private weak var helpButton: ShadowButton!
    @IBOutlet private weak var helpButtonTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var helpButtonBottomConstraint: NSLayoutConstraint!
    
    // MARK: - IB Actions ============================================================================== -
    
    internal func finishPressed() {
        self.proceed()
    }
    
    internal func homePressed() {
        self.cancel()
    }
    
    @IBAction func helpPressed(_ sender: UIButton) {
        self.helpPressed()
    }
    
    internal func showScorepadPressed() {
        self.proceed()
    }
    
    internal func lastHandPressed() {
        if !self.lastHand {
            self.lastHand = true
            self.playedCardCollectionView.reloadData()
            self.setBanner(title: "Last Trick", updateLast: false)
            if self.menuController?.isVisible ?? false {
                self.handTableView.isUserInteractionEnabled = false
            }
        }
    }
    
    internal func lastHandReleased() {
        if self.lastHand {
            self.lastHand = false
            self.playedCardCollectionView.reloadData()
            self.setBanner(title: self.lastTitle!)
            self.handTableView.isUserInteractionEnabled = true
        }
    }
    
    @IBAction func longPresssGesture(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            self.lastHandPressed()
        } else if sender.state == .ended && self.lastHand {
            self.lastHandReleased()
        }
    }
    
    // MARK: - View Overrides ========================================================================== -

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup default colors (previously done in StoryBoard) and whisper
        self.defaultViewColors()
        
        // Setup initial state and local references for global state
        self.enteredPlayerNumber = Scorecard.game.handState.enteredPlayerNumber
        self.round = Scorecard.game.handState.round
        Scorecard.game.selectedRound = self.round
        Scorecard.game.maxEnteredRound = self.round
        self.updatedMirroredTrickCards()
        
        // Setup banner and buttons
        self.setupBanner()
        
        // Setup help
        self.setupHelpView()
        
        // Setup grid tags
        bidCollectionTag = bidCollectionView.tag
        playedCardCollectionTag = playedCardCollectionView.tag
        
        self.updateMirroredHand()
        self.currentCards = Scorecard.game.roundCards(round)
        
        // Setup over under
        setupOverUnder()
        
        // Fix postion of help button on portrait phone
        self.firstSuitLength = (Scorecard.game.handState.hand.handSuits.first?.cards.count ?? 0)
        
        // Subscribe to score changes
        self.setupBidSubscriptions()
        
        self.view.becomeFirstResponder()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        // Take responsibility for alerts
        Scorecard.shared.alertDelegate = self
        
        super.viewDidAppear(true)
        
        // Catch up on any auto bids that arrived too early
        NotificationCenter.default.post(name: .checkAutoPlayInput, object: self, userInfo: nil)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        Scorecard.shared.reCenterPopup(self)
        resizing = true
        // Release last trick if pressed
        self.menuController?.didDisappear()
        view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.horizontalMargins = (self.containerBanner ? 20 : 8)
        viewHeight = view.safeAreaLayoutGuide.layoutFrame.height
        viewWidth = view.safeAreaLayoutGuide.layoutFrame.width
        self.viewInsets.forEach{ (constraint) in constraint.constant = horizontalMargins}
        self.separatorHeightConstraint.constant = self.separatorHeight
        self.statusTitleHeightConstraint.constant = (self.containerBanner ? 0 : 50)
        self.setBidButtonFormat()
        self.setupSizes()
        self.handTableView.reloadData()
        if self.resizing {
            self.bidMode = nil
            self.firstBidRefresh = true
            self.firstHandRefresh = true
        }
        if self.firstTime || self.resizing {
            self.resizing = false
            self.firstTime = false
            self.stateController()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Give up responsibility for alerts
        Scorecard.shared.alertDelegate = nil
    }
    
    override internal func willDismiss() {
        self.cancelBidSubscriptions()
    }
    
    // MARK: - TableView Overrides ===================================================================== -
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (handCardWidth == nil ? 0 : self.mirroredHand.handSuits.count)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return handCardHeight * CGFloat(Int((self.mirroredHand.handSuits[indexPath.row].cards.count - 1) / handCardsPerRow) + 1)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell: SuitTableCell
        
        // Suits
        
        cell = tableView.dequeueReusableCell(withIdentifier: "Suit Table Cell", for: indexPath) as! SuitTableCell

        cell.setCollectionViewDataSourceDelegate(self, forRow: indexPath.row)
        self.suitEnable(suitCollectionView: cell.cardCollection, enable: suitEnabled[indexPath.row], suitNumber: indexPath.row + 1)
        let cardsInRow = min(self.mirroredHand.handSuits[indexPath.row].cards.count, self.handCardsPerRow)
        cell.cardCollectionWidthConstraint.constant = (CGFloat(cardsInRow) * self.handCardWidth) + 1.0
        
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
                return Scorecard.game.currentPlayers
            }
        } else {
            // Hand cards
            return self.mirroredHand.handSuits[collectionView.tag].cards.count
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
            // Setup default colors (previously done in StoryBoard)
            self.defaultCellColors(cell: cell)

            if indexPath.row <= maxBidButton || (moreMode && indexPath.row <= currentCards) {
                cell.bidButton.text = "\(indexPath.row)"
            } else if !moreMode {
                cell.bidButton.text = ">"
            } else {
                cell.bidButton.text = "<"
            }
            cell.bidButton.tag = indexPath.row
            ScorecardUI.roundCorners(cell.bidButton)
            self.bidEnable(cell, bidButtonEnabled[indexPath.row])
            return cell
            
        } else if collectionView.tag == playedCardCollectionTag {
            // Played cards
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Played Card Collection Cell", for: indexPath) as! PlayedCardCollectionCell
            // Setup default colors (previously done in StoryBoard)
            self.defaultCellColors(cell: cell)

            var toLead: Int!
            var cards: [Card]!
            if lastHand || self.mirroredTrickCards.count == Scorecard.game.currentPlayers {
                toLead = Scorecard.game.handState.lastToLead ?? Scorecard.game.handState.toLead
                cards = Scorecard.game.handState.lastCards ?? Scorecard.game.handState.lastCards
            } else {
                toLead = Scorecard.game.handState.toLead
                cards = mirroredTrickCards
            }
            
            // Name
            let playerNumber = ((indexPath.row + (toLead - 1)) % Scorecard.game.currentPlayers) + 1
            let player = Scorecard.game.player(enteredPlayerNumber: playerNumber)
            cell.playerNameLabel.text = player.playerMO!.name!
            
            // Bid and made
            let bid = Scorecard.game.scores.get(round: self.round, playerNumber: playerNumber).bid
            if bid == nil {
                cell.playerBidLabel.text = ""
            } else {
                cell.playerBidLabel.text = "Bid \(bid!)"
            }
            cell.playerMadeLabel.text = playerMadeText(playerNumber)
            cell.playerMadeLabel.textColor = (cards.count == Scorecard.game.currentPlayers && Scorecard.game.handState.winner == indexPath.row + 1 ? Palette.tableTop.text : Palette.tableTop.contrastText)
            
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
                    
            return cell
            
        } else {
            // Hand cards
            let suit = collectionView.tag + 1
            let card = indexPath.row + 1
            
            var cell: CardCollectionCell
            
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Card Collection Cell", for: indexPath) as! CardCollectionCell
            // Setup default colors (previously done in StoryBoard)
            self.defaultCellColors(cell: cell)

            cell.cardLabel.textColor = UIColor.white
            cell.cardLabel.attributedText = self.mirroredHand.handSuits[suit-1].cards[card - 1].toAttributedString()
            cell.cardLabel.font = UIFont.systemFont(ofSize: self.handCardFontSize)
            ScorecardUI.roundCorners(cell.cardView, percent: 10)
            cell.tag = self.mirroredHand.handSuits[suit-1].cards[card - 1].toNumber()
            
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
                bidsEnable(true, blockRemaining: Scorecard.game.roundPlayerNumber(enteredPlayerNumber: self.enteredPlayerNumber, round: self.round) == Scorecard.game.currentPlayers)
            }
        } else {
            confirmCard(collectionView, indexPath)
        }
    }
    
    // MARK: - Main state controller  ================================================================ -
    
    /**
        __Works out what next, enables and disables controls and gives instructions__
        - parameters
           - currentTrickCards: No of cards currently played. Normally taken from state, but passed in when playing a card from a remote hand
    */
    func stateController(updateState: Bool = true, currentTrickCards: Int = Scorecard.game.handState.trickCards.count) {
        // Check whether bidding finished
        let bidsMade = Scorecard.game.scores.bidsMade(round: round)
        let newBidMode = (bidsMade < Scorecard.game.currentPlayers)
        if self.bidMode != newBidMode {
            if newBidMode == false && !firstBidRefresh {
                // About to exit bid mode - delay 1 second
                setupOverUnder()
                self.setInstructionsHighlight(to: false)
                self.setBanner(title: "Bidding Complete")
                self.banner.setButton(finishButton, isHidden: true)
                self.controllerDelegate?.lock(true)
                self.executeAfter(delay: 1.0) {
                    self.banner.setButton(self.finishButton, isHidden: false)
                    self.controllerDelegate?.lock(false)
                    NotificationCenter.default.post(name: .checkAutoPlayInput, object: self, userInfo: nil)
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
            if Scorecard.game.roundPlayerNumber(enteredPlayerNumber: self.enteredPlayerNumber, round: self.round) == bidsMade + 1 {
                // Your bid
                bidsEnable(true, blockRemaining: bidsMade == Scorecard.game.currentPlayers - 1)
                self.setBanner(title: "You to bid")
                self.setInstructionsHighlight(to: true)
                Scorecard.shared.alertUser(remindAfter: 10.0)
                self.autoBid()
            } else {
                bidsEnable(false)
                self.setBanner(title: "\(Scorecard.game.player(entryPlayerNumber: bidsMade + 1).playerMO!.name!) to bid")
                self.setInstructionsHighlight(to: false)
                // Get computer player to bid
                self.controllerDelegate?.robotAction(playerNumber: Scorecard.game.player(entryPlayerNumber: bidsMade + 1).playerNumber, action: .bid)
            }
            setupOverUnder()
            self.banner.setButton(lastHandButton, isHidden: true)
            tableTopLongPress.isEnabled = false
            titleBarLongPress.isEnabled = false
        } else {
            // Update state
            if updateState {
                // Might have already been update when remote action reflected
                Scorecard.shared.updateState(alertUser: false)
            }
            
            if currentTrickCards == Scorecard.game.currentPlayers && Scorecard.game.handState.trick > 1 {
                // Hand complete - update tricks made on screen
                let playerMadeLabel = self.playedCardCell(Scorecard.game.handState.winner! - 1)?.playerMadeLabel
                playerMadeLabel?.text = playerMadeText(Scorecard.game.handState.toPlay!)
                playerMadeLabel?.textColor = Palette.tableTop.text
                
                // Disable lookback
                self.banner.setButton(lastHandButton, isHidden: true)
                tableTopLongPress.isEnabled = false
                titleBarLongPress.isEnabled = false

                if Scorecard.game.handState.trick <= self.currentCards {
                    // Get ready for the new trick - won't refresh until next card played
                    self.nextCard()
                    if Scorecard.game.handState.toPlay != self.enteredPlayerNumber {
                        // Don't refresh (or exit) for at least 1 second
                        self.controllerDelegate?.lock(true)
                        self.banner.setButton(finishButton, isHidden: true)
                        self.executeAfter(delay: 1.0) {
                            self.banner.setButton(self.finishButton, isHidden: false)
                            self.controllerDelegate?.lock(false)
                            NotificationCenter.default.post(name: .checkAutoPlayInput, object: self, userInfo: nil)
                        }
                    }	
                } else {
                    // Hand finished
                    self.banner.setButton(finishButton, isHidden: true)
                    self.controllerDelegate?.lock(true)
                    self.setBanner(title: "Hand Complete")
                    let round = Scorecard.game.handState.round
                    Utility.executeAfter(delay: 1.0) {
                        // Proceed after 2 seconds
                        self.controllerDelegate?.lock(false)
                        self.proceed(round: round + 1)
                    }
                }
            } else {
                // Work out who should play
                let hasPlayed = (self.enteredPlayerNumber + (Scorecard.game.handState.toLead! > self.enteredPlayerNumber ? Scorecard.game.currentPlayers : 0)) >= (Scorecard.game.handState.toLead! + Scorecard.game.handState.trickCards.count)
                let lastHandButtonHidden = (Scorecard.game.handState.lastCards.count == 0 || !hasPlayed || Scorecard.game.handState.lastToLead == nil)
                self.banner.setButton(lastHandButton, isHidden: lastHandButtonHidden)
                tableTopLongPress.isEnabled = !lastHandButtonHidden
                titleBarLongPress.isEnabled = !lastHandButtonHidden

                self.nextCard()
            }
        }
    }
    
    private func proceed(round: Int? = nil) {
        self.controllerDelegate?.didProceed(context: (round == nil ? nil : ["round" : round!]))
    }
    
    private func cancel() {
        Scorecard.shared.warnExitGame(from: self) {
            self.willDismiss()
            self.controllerDelegate?.didCancel()
        }
    }
        
    private func executeAfter(delay: TimeInterval, closure: @escaping ()->()) {
        if self.firstTime {
            // Not finished layout - do it immediately
            closure()
        } else {
            Utility.executeAfter(delay: (Scorecard.shared.autoPlayGames != 0 ? 0.1 : delay), completion: closure)
        }
    }
    
    private func nextCard() {
        if Scorecard.game.handState.toPlay == self.enteredPlayerNumber {
            // Me to play
            if Scorecard.game.handState.trickCards.count == 0 {
                // Me to lead - can lead anything
                self.cardsEnable(true)
            } else {
                let cardLed = Scorecard.game.handState.trickCards[0]
                let suitLed = Scorecard.game.handState.hand.xrefSuit[cardLed.suit]
                if suitLed == nil || suitLed!.cards.count == 0 {
                    // Dont' have this suit - can play anything
                    self.cardsEnable(true)
                } else {
                    // Got some of suit led - must follow suit
                    self.cardsEnable(true, suit: cardLed.suit)
                }
            }
            self.setBanner(title: "You to play")
            self.setInstructionsHighlight(to: true)
            Scorecard.shared.alertUser(remindAfter: 10.0)
            self.autoPlay()
        } else {
            self.cardsEnable(false)
            self.setBanner(title: "\(Scorecard.game.player(enteredPlayerNumber: Scorecard.game.handState.toPlay).playerMO!.name!) to play")
            self.setInstructionsHighlight(to: false)
            // Get computer player to play
            self.controllerDelegate?.robotAction(playerNumber: Scorecard.game.handState.toPlay, action: .play)
        }
    }
    
    // MARK: - Routines to update UI from messages received ============================================ -
    
    public func reflectBid(round: Int, enteredPlayerNumber: Int) {
        // Must be in bid mode - simply fill in the right bid
        // Note that the player number sent will be the enterd player number and hence must be converted
        if bidMode != nil && bidMode && round == self.round {
            let entryPlayerNumber = Scorecard.game.roundPlayerNumber(enteredPlayerNumber: enteredPlayerNumber, round: self.round)
            setupPlayerBidText(entryPlayerNumber: entryPlayerNumber, animate:true)
            self.stateController()
        }
    }
    
    public func reflectCardPlayed(round: Int, trick: Int, playerNumber: Int, card: Card) {
        self.refreshCardPlayed(card: card)
    }
    
    public func reflectCurrentState(currentTrickCards: Int) {
        self.stateController(updateState: false, currentTrickCards: currentTrickCards)

        // Refresh played cards
        self.playedCardCollectionView.reloadData()
    }
    
    // MARK: - Bid / card publisher subscription =========================================================== -
    
    private func setupBidSubscriptions() {
        self.bidSubscription = Scorecard.shared.subscribeBid { [unowned self] (round, enteredPlayerNumber, bid) in
            self.reflectBid(round: round, enteredPlayerNumber: enteredPlayerNumber)
        }
    }
    
    private func cancelBidSubscriptions() {
        self.bidSubscription?.cancel()
        self.bidSubscription = nil
    }
    
    // MARK: - Form Presentation / Handling Routines =================================================== -
    
    public func setupBanner() {
        let roundSuit = Scorecard.game.roundSuit(self.round).toAttributedString()
        let roundWidth = roundSuit.labelWidth(font: Banner.defaultFont)
        self.banner.set(title: "Play Hand",
                        leftButtons: [
                            BannerButton(image: UIImage(named: "back"), action: self.finishPressed, menuHide: true, menuText: "Show Scorepad", id: finishButton),
                            BannerButton(image: UIImage(named: "two"), asTemplate: false, action: self.lastHandPressed, releaseAction: self.lastHandReleased, menuHide: true, menuText: "Show last trick", releaseMenuText: "Hide last trick", id: lastHandButton)],
                        rightButtons: [
                            BannerButton(action: self.helpPressed, type: .help),
                            BannerButton(width: 60, action: self.showScorepadPressed, gameDetailHide: true, font: Banner.defaultFont, id: overUnderButton),
                            BannerButton(attributedTitle: roundSuit, width: roundWidth, action: self.showScorepadPressed, gameDetailHide: true, font: Banner.defaultFont, id: roundSummaryButton)],
                        nonBannerButtonsAfter: [
                            BannerButton(action: self.homePressed, menuText: "Abandon Game", menuSpaceBefore: 20.0, id: homeButton)],
                        menuOption: .playGame,
                        normalOverrideHeight: 50)
    }
    
    public func refreshAll() {
        self.round = Scorecard.game.handState.round
        self.bidMode = nil
        self.updateMirroredHand()
        self.updatedMirroredTrickCards()
        self.handTableView.reloadData()
        self.bidCollectionView.reloadData()
        self.playedCardCollectionView.reloadData()
        self.stateController()
    }
    
    func setBidButtonFormat() {
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
            bidHeightProportion = 0.25
            extraRow=0
        }
        
        
        // Work out the number of buttons that will fit across
        let bidWidthMax = ((viewHeight * bidWidthProportion) - 6.0)
        buttonsAcross = max(2, min(3, Int(bidWidthMax / startButtonSize)))
        
        // Work out the number of buttons that will fit down
        let bidHeightMax = (viewHeight - self.banner.height) * bidHeightProportion
        buttonsDown = max(3, min(4, Int(bidHeightMax / startButtonSize) - extraRow))
        
        // Calculate optimum button size
        bidButtonSize = max(minButtonSize, min(maxButtonSize, ((bidHeightMax + bidButtonSpacing) / CGFloat(buttonsDown + extraRow)) - bidButtonSpacing))
        
        // Calculate width from button size and number of buttons
        bidCollectionViewWidth = ((bidButtonSize + self.bidButtonSpacing) * CGFloat(buttonsAcross)) - self.bidButtonSpacing
        
        if ScorecardUI.landscapePhone() {
            // Still need to use all the height
            bidViewHeight = bidHeightMax
        } else {
            // Calculate so that buttons only just fit in
            bidViewHeight = ((bidButtonSize + self.bidButtonSpacing) * CGFloat(buttonsDown)) - self.bidButtonSpacing + (self.bidButtonVerticalSpace * 2)
        }
        
        // Hide vertical separator if there are3 rows of buttons across and hid both separators in container mode
        bidSeparator.isHidden = (buttonsAcross > 2) || self.containerBanner
        bidTitleSeparator.isHidden = self.containerBanner
        
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
    
    private func setupSizes() {
        self.handView.layoutIfNeeded()
        self.handViewWidth = self.handView.frame.width
        let bannerHeight = self.banner.height
        if ScorecardUI.landscapePhone() {
            self.handViewHeight = self.viewHeight - bannerHeight
            self.tabletopViewHeight = handViewHeight
        } else {
            self.handViewHeight = self.viewHeight - bidViewHeight - bannerHeight - separatorHeight
            self.tabletopViewHeight = bidViewHeight
        }
        self.setupBidSize()
        self.setupTabletopSize()
        self.setupHandSize()
    }
    
    private func setupHelpButton() {
        if ScorecardUI.portraitPhone() {
            self.helpButton.isHidden = false
            let fullSuit = (self.firstSuitLength >= self.handCardsPerRow)
            Constraint.setActive([self.helpButtonTopConstraint], to: !fullSuit)
            Constraint.setActive([self.helpButtonBottomConstraint], to: fullSuit)
            self.banner.setButton(Banner.helpButton, isHidden: true)
        } else {
            self.helpButton.isHidden = true
            self.banner.setButton(Banner.helpButton, isHidden: false)
        }
    }

    func bidMode(_ mode: Bool!) {
        
        self.bidMode = mode
        
        if bidMode {
            tabletopView.isHidden = true
            bidView.isHidden = false
            leftFooterPaddingView.backgroundColor = Palette.normal.background
            leftPaddingView.backgroundColor = Palette.normal.background
            
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
            leftFooterPaddingView.backgroundColor = Palette.tableTop.background
            leftPaddingView.backgroundColor = Palette.tableTop.background
            
            setupTabletopSize()
            setupHandSize()
            if self.firstHandRefresh {
                handTableView.reloadData()
                playedCardCollectionView.reloadData()
                firstHandRefresh = false
            }
        }
        self.banner.setButton(overUnderButton, isHidden: bidMode)
    }
    
    func bidsEnable(_ enable: Bool, blockRemaining: Bool = false) {
        let remaining = Scorecard.game.remaining(playerNumber: Scorecard.game.roundPlayerNumber(enteredPlayerNumber: self.enteredPlayerNumber, round: self.round), round: self.round, mode: .bid)
        for bid in 0..<bidButtonEnabled.count {
            if !enable || (blockRemaining && (bid == remaining && (moreMode || bid <= maxBidButton))) {
                bidButtonEnabled[bid] = false
            } else {
                bidButtonEnabled[bid] = true
            }
            bidEnable(bid, bidButtonEnabled[bid])
        }
    }
    
    func bidEnable(_ bid: Int, _ enable: Bool) {
        if let bidCell = bidCollectionView.cellForItem(at: IndexPath(item: bid, section: 0)) as? BidCollectionCell {
            self.bidEnable(bidCell,enable)
        }
    }
    
    func bidEnable(_ bidCell: BidCollectionCell, _ enable: Bool) {
        if enable {
            bidCell.bidButton.backgroundColor = Palette.bidButton.background
        } else {
            bidCell.bidButton.backgroundColor = Palette.bidButton.background.withAlphaComponent(0.25)
        }
    }
    
    func cardsEnable(_ enable: Bool, suit matchSuit: Suit! = nil) {
        if Scorecard.game.handState.hand.handSuits != nil && Scorecard.game.handState.hand.handSuits.count > 0 {
            for suitNumber in 1...Scorecard.game.handState.hand.handSuits.count {
                suitEnable(enable: enable, suitNumber: suitNumber, matchSuit: matchSuit)
            }
        }
    }
    
    func suitEnable(enable: Bool, suitNumber: Int, matchSuit: Suit! = nil) {
        suitEnable(suitCollectionView: suitCollectionView(suitNumber-1), enable: enable, suitNumber: suitNumber, matchSuit: matchSuit)
    }
    
    func suitEnable(suitCollectionView: UICollectionView?, enable: Bool, suitNumber: Int, matchSuit: Suit! = nil) {
        if suitNumber <= Scorecard.game.handState.hand?.handSuits?.count ?? 0 {
            let suit = Scorecard.game.handState.hand.handSuits[suitNumber - 1]
            if enable && suit.cards.count != 0 && (matchSuit == nil || matchSuit == suit.cards[0].suit) {
                suitCollectionView?.isUserInteractionEnabled = true
                suitCollectionView?.alpha = 1.0
                suitEnabled[suitNumber-1] = true
            } else {
                suitCollectionView?.isUserInteractionEnabled = false
                if bidMode ?? false {
                    suitCollectionView?.alpha = 0.9
                } else {
                    suitCollectionView?.alpha = 0.5
                }
                suitEnabled[suitNumber-1] = false
            }
        }
    }
    
    func setupHandSize() {
        // configure the hand section
        
        var maxSuitCards = 0
        let handTableViewHeight = handViewHeight - (2 * self.handTableViewVerticalMargins)
        let handTableViewWidth = handViewWidth! - (2 * self.horizontalMargins)
        self.handCardsPerRow = (handTableViewWidth >= 350 ? 6 : 5)
        // Set hand height
        self.handHeightConstraint.constant = handViewHeight
        
        for suit in Scorecard.game.handState.hand.handSuits {
            maxSuitCards = max(maxSuitCards, suit.cards.count)
        }
        
        var loop = 1
        while loop <= 2 {
            loop+=1
            
            var handRows = 0
            for suit in Scorecard.game.handState.hand.handSuits {
                handRows += Int((suit.cards.count - 1) / self.handCardsPerRow) + 1
            }
            handRows = max(4, handRows)
            
            self.handCardHeight = CGFloat(Int(handTableViewHeight / CGFloat(handRows))+1)
            self.handCardWidth = min(self.handCardHeight * CGFloat(2.0/3.0), handTableViewWidth / CGFloat(self.handCardsPerRow))
                        
            // Possibly see if more cards would fit on line
            if maxSuitCards <= self.handCardsPerRow || (CGFloat(self.handCardsPerRow) * handCardWidth) > handTableViewWidth {
                break
            }
            
            self.handCardsPerRow = Int(handTableViewWidth / handCardWidth)
        }
        self.handCardFontSize = self.handCardWidth / 2.5
        self.setupHelpButton()
    }
    
    func setupBidSize() {
        let bidViewWidth = (viewWidth / (ScorecardUI.landscapePhone() ? 2 : 1))
        let statusWidth =  bidViewWidth - (2 * horizontalMargins) - bidCollectionViewWidth - 8.0
        
        if moreMode {
            statusWidthConstraint.constant = 0
        } else {
            statusWidthConstraint.constant = statusWidth
        }
        statusTextFontSize = min(24.0, (statusWidth - 16.0) / 7.0)
        statusRoundLabel.font = UIFont.boldSystemFont(ofSize: statusTextFontSize)
        statusOverUnderLabel.font = UIFont.boldSystemFont(ofSize: statusTextFontSize)
        for playerNumber in 1...Scorecard.game.currentPlayers {
            statusPlayerBidLabel(playerNumber)!.font = UIFont.systemFont(ofSize: statusTextFontSize - 2.0)
        }
    }
    
    func setupTabletopSize() {
        // Set tabletop sizes
        let tableTopViewWidth: CGFloat = ((self.viewWidth - (2 * self.horizontalMargins)) / (ScorecardUI.landscapePhone() ? 2 : 1)) - (CGFloat(Scorecard.game.currentPlayers-1) * playedCardSpacing)
        tabletopCellWidth = tableTopViewWidth / CGFloat(Scorecard.game.currentPlayers)
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
        
        let timeLeft = Scorecard.shared.cancelReminder()
        
        let cell = collectionView.cellForItem(at: indexPath)
        let card =  Card(fromNumber: cell!.tag)
        
        let cardWidth: CGFloat = 60
        let label = UILabel(frame: CGRect(x: 0.0, y: 0.0, width: cardWidth, height: cardWidth * 3.0/2.0))
        Constraint.setWidth(control: label, width: cardWidth)
        Constraint.setHeight(control: label, height: cardWidth * (3.0/2.0))
        label.attributedText = card.toAttributedString()
        label.backgroundColor = Palette.cardFace.background
        label.font = UIFont.systemFont(ofSize: 30)
        label.textAlignment = .center
        ScorecardUI.roundCorners(label)
        
        self.confirmPlayed(title: "Confirm Card", content: label, sourceView: self.handSourceView, confirmText: "Play card", cancelText: "Change card", titleOffset: 8.0, backgroundColor: Palette.tableTop.background, bannerColor: Palette.tableTop.background, bannerTextColor: Palette.tableTop.text, buttonColor: Palette.roomInterior.background, buttonTextColor: Palette.roomInterior.text, confirmHandler: { self.playCard(card: card) }, cancelHandler: { Scorecard.shared.restartReminder(remindAfter: timeLeft) })
    }
    
    func playCard(card: Card) {
        // Update data structures
        let round = self.round!
        let trick = Scorecard.game.handState.trick!
        Scorecard.shared.sendCardPlayed(round: round, trick: trick, playerNumber: self.enteredPlayerNumber, card: card)
        Scorecard.shared.playCard(card: card)
        self.refreshCardPlayed(card: card)
        self.stateController()
    }
    
    func refreshCardPlayed(card: Card) {
        // Disable rest of hand to avoid another play
        self.cardsEnable(false)

        // Remove the card from your hand
        if let (suitNumber, cardNumber) = self.mirroredHand.find(card: card) {
            let collectionView = suitCollectionView(suitNumber)!
            let indexPath = IndexPath(row: cardNumber, section: 0)
            collectionView.performBatchUpdates({
                collectionView.deleteItems(at: [indexPath])
                self.updateMirroredHand()
            })
        }
        
        if Scorecard.game.handState.trickCards.count > 0 {
            // Show current state unless have just started a new trick
            self.updatedMirroredTrickCards()
        }
        
        // Refresh played cards
        self.playedCardCollectionView.reloadData()
    }
    
    func confirmBid(bid: Int) {
        
        let timeLeft = Scorecard.shared.cancelReminder()
        
        let label = UILabel()
        Constraint.setWidth(control: label, width: 50)
        Constraint.setHeight(control: label, height: 50)
        label.text = "\(bid)"
        Palette.bidButtonStyle(label)
        label.font = UIFont.systemFont(ofSize: 30)
        label.textAlignment = .center
        ScorecardUI.roundCorners(label)
        
        self.confirmPlayed(title: "Confirm Bid", content: label, sourceView: self.handSourceView, confirmText: "Confirm Bid", cancelText: "Change Bid", titleOffset: 15.0, backgroundColor: Palette.normal.background, bannerColor: Palette.normal.background, bannerTextColor: Palette.roomInterior.background, buttonColor: Palette.roomInterior.background, buttonTextColor: Palette.roomInterior.text, confirmHandler: { self.makeBid(bid) }, cancelHandler: { Scorecard.shared.restartReminder(remindAfter: timeLeft) })
    }
    
    func makeBid(_ bid: Int) {
        _ = Scorecard.game.scores.set(round: round, playerNumber: enteredPlayerNumber, bid: bid)
        Scorecard.shared.sendBid(playerNumber: enteredPlayerNumber, round: round)
        let entryPlayerNumber = Scorecard.game.roundPlayerNumber(enteredPlayerNumber: enteredPlayerNumber, round: self.round)
        setupPlayerBidText(entryPlayerNumber: entryPlayerNumber, animate: true)
        if moreMode {
            moreMode = false
            setupBidSize()
            self.bidCollectionView.reloadData()
        }
        self.stateController()
    }
    
    private func confirmPlayed(title: String, content: UIView, sourceView: UIView, confirmText: String, cancelText: String, offsets: (CGFloat?, CGFloat?)? = (0.5, nil), titleOffset: CGFloat = 5.0, contentOffset: CGPoint? = nil, backgroundColor: UIColor, bannerColor: UIColor, bannerTextColor: UIColor, buttonColor: UIColor, buttonTextColor: UIColor, confirmHandler: (()->())? = nil, cancelHandler: (()->())? = nil) {
     
        let context: [String : Any?] =
            ["title" : title,
             "label" : content,
             "sourceView" : sourceView,
             "confirmText" : confirmText,
             "cancelText" : cancelText,
             "backgroundColor" : backgroundColor,
             "buttonColor": buttonColor,
             "buttonTextColor": buttonTextColor,
             "bannerColor": bannerColor,
             "bannerTextColor": bannerTextColor,
             "offsets": offsets,
             "contentOffset": contentOffset,
             "titleOffset": titleOffset
        ]
        
        self.controllerDelegate?.didInvoke(.confirmPlayed, context: context, completion: { (context) in
            if context?["confirm"] as? Bool == true {
                confirmHandler?()
            } else {
                cancelHandler?()
            }
        })
    }
    
    func resetPopover() {
        self.isModalInPopover = true
    }
    
    func playerMadeText(_ playerNumber: Int) -> String {
        var result: String
        let made = Scorecard.game.handState.made[playerNumber - 1]
        if made == 0 {
            result = ""
        } else {
            result = "Made \(made)"
            if Scorecard.activeSettings.bonus2 {
                let twos = Scorecard.game.handState.twos[playerNumber - 1]
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
        let totalRemaining = Scorecard.game.remaining(playerNumber: 0, round: Scorecard.game.selectedRound, mode: Mode.bid)

        let overUnder = NSAttributedString("\(totalRemaining >= 0 ? "-" : "+")\(abs(Int64(totalRemaining)))", color: (totalRemaining >= 0 ? Palette.contractUnder : Palette.contractOver))
        self.banner.setButton(overUnderButton, attributedTitle: overUnder, width: overUnder.labelWidth(font: Banner.defaultFont))

        if !Scorecard.game.roundStarted(Scorecard.game.selectedRound) {
            statusOverUnderLabel.text = ""
        } else {
            statusOverUnderLabel.textColor = (totalRemaining == 0 ? Palette.contractEqual : (totalRemaining > 0 ? Palette.contractUnder : Palette.contractOver))
            statusOverUnderLabel.text = " \(abs(Int64(totalRemaining))) \(totalRemaining >= 0 ? "under" : "over")"
        }
        statusRoundLabel.attributedText = Scorecard.game.roundTitle(round)
    }
    
    func setupBidText() {
        
        for entryPlayerNumber in 1...Scorecard.game.currentPlayers {
            setupPlayerBidText(entryPlayerNumber: entryPlayerNumber)
        }
    }
    
    func setupPlayerBidText(entryPlayerNumber: Int, animate: Bool = false) {
        let bid = Scorecard.game.scores.get(round: self.round, playerNumber: entryPlayerNumber, sequence: .entry).bid
        let name = Scorecard.game.player(entryPlayerNumber: entryPlayerNumber).playerMO!.name!
        if bid != nil {
            statusPlayerBidLabel(entryPlayerNumber)!.text = "\(name) bid \(bid!)"
        } else {
            statusPlayerBidLabel(entryPlayerNumber)!.text = "\(name)"
        }

    }
    
    internal func alertUser(reminder: Bool) {
        if Utility.isSimulator && Scorecard.shared.autoPlayGames == 0 {
            self.whisper.show("Buzz", from: self.view, hideAfter: 2.0)
        }
        if reminder {
            self.banner.alertFlash(duration: 0.3, repeatCount: 3, backgroundColor: Palette.tableTop.background)
        }
    }
    
    private func updateMirroredHand() {
        // Copy the hand to the version used by the collection (inside performBatchUpdates)
        // Need to copy individual values rather than pointers
        self.mirroredHand = Scorecard.game.handState.hand.copy() as? Hand
    }
    
    private func updatedMirroredTrickCards() {
        // Copy the trick cards to the version used by the collection (inside performBatchUpdates)
        // Need to copy individual values rather than pointers
        self.mirroredTrickCards = []
        if var cards = Scorecard.game.handState.trickCards {
            if cards.count == 0 {
                cards = Scorecard.game.handState.lastCards
            }
            for card in cards {
                self.mirroredTrickCards.append(Card(fromNumber: card.toNumber()))
            }
        }
    }
    
    private func setInstructionsHighlight(to highlight: Bool) {
        let textType = (highlight ? ThemeTextType.normal : ThemeTextType.strong)
        let backgroundColor = ((bidMode ?? false) ? Palette.normal : Palette.tableTop)
        self.banner.set(backgroundColor: backgroundColor, titleColor: backgroundColor.textColor(textType))
    }
    
    private func setBanner(title: String, updateLast: Bool = true) {
        if updateLast {
            self.lastTitle = title
        }
        self.banner.set(title: title, updateMenuTitle: false)
    }
    
    // MARK: - Helper routines to access cells and contents ================================================================= -
    
    private func playedCardCell(_ currentCard: Int) -> PlayedCardCollectionCell? {
        self.playedCardCollectionView.layoutIfNeeded()
        return playedCardCollectionView.cellForItem(at: IndexPath(item: currentCard, section: 0)) as? PlayedCardCollectionCell
    }
    
    private func statusPlayerBidLabel(_ playerNumber: Int) -> UILabel? {
        switch playerNumber {
        case 1:
            return self.statusPlayer1BidLabel
        case 2:
            return self.statusPlayer2BidLabel
        case 3:
            return self.statusPlayer3BidLabel
        case 4:
            return self.statusPlayer4BidLabel
        default:
            return nil
        }
    }
    
    internal func suitCollectionView(_ suitNumber: Int) -> UICollectionView? {
        let cell = self.handTableView.cellForRow(at: IndexPath(row: suitNumber, section: 0)) as? SuitTableCell
        return cell?.cardCollection
    }

    // MARK: - Function to present this view ==============================================================
    
    class func show(from viewController: ScorecardViewController, appController: ScorecardAppController? = nil, existing handViewController: HandViewController? = nil, RobotDelegate: [Int : RobotDelegate?]? = nil, animated: Bool = true) -> HandViewController {
        var handViewController: HandViewController! = handViewController
        
        if handViewController == nil {
            let storyboard = UIStoryboard(name: "HandViewController", bundle: nil)
            handViewController = storyboard.instantiateViewController(withIdentifier: "HandViewController") as? HandViewController
        }
        
        handViewController!.controllerDelegate = appController
        
        Utility.mainThread("playHand", execute: {
            viewController.present(handViewController!, appController: appController, animated: animated, completion: nil)
        })
        
        return handViewController
    }
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class SuitTableCell: UITableViewCell {
    
    @IBOutlet fileprivate weak var cardCollection: UICollectionView!
    @IBOutlet fileprivate weak var cardCollectionWidthConstraint: NSLayoutConstraint!
    
    
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
    
    init(enteredPlayerNumber: Int, round: Int, dealerIs: Int, players: Int, trick: Int? = nil, made: [Int]? = nil, twos: [Int]? = nil, trickCards: [Card]? = nil, toLead: Int? = nil, lastCards: [Card]! = nil, lastToLead: Int! = nil) {
        self.enteredPlayerNumber = enteredPlayerNumber
        self.round = round
        self.players = players
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

extension HandViewController {

    /** _Note that this code was generated as part of the move to themed colors_ */

    private func defaultViewColors() {

        self.bidSeparator.backgroundColor = Palette.hand.background
        self.bidTitleSeparator.backgroundColor = Palette.hand.background
        self.bidView.backgroundColor = Palette.normal.background
        self.footerPaddingView.backgroundColor = Palette.hand.background
        self.handView.backgroundColor = Palette.hand.background
        self.leftFooterPaddingView.backgroundColor = Palette.hand.background
        self.leftPaddingView.backgroundColor = Palette.hand.background
        self.separator.backgroundColor = Palette.hand.background
        self.statusPlayer1BidLabel.textColor = Palette.normal.text
        self.statusPlayer2BidLabel.textColor = Palette.normal.text
        self.statusPlayer3BidLabel.textColor = Palette.normal.text
        self.statusPlayer4BidLabel.textColor = Palette.normal.text
        self.tabletopView.backgroundColor = Palette.tableTop.background
        self.view.backgroundColor = Palette.hand.background
    }

    private func defaultCellColors(cell: BidCollectionCell) {
        switch cell.reuseIdentifier {
        case "Bid Collection Cell":
            cell.bidButton.textColor = Palette.bidButton.text
        default:
            break
        }
    }

    private func defaultCellColors(cell: CardCollectionCell) {
        switch cell.reuseIdentifier {
        case "Card Collection Cell":
            cell.cardView.backgroundColor = Palette.cardFace.background
        default:
            break
        }
    }

    private func defaultCellColors(cell: PlayedCardCollectionCell) {
        switch cell.reuseIdentifier {
        case "Played Card Collection Cell":
            cell.cardView.backgroundColor = Palette.cardFace.background
            cell.playerBidLabel.textColor = Palette.tableTop.contrastText
            cell.playerMadeLabel.textColor = Palette.tableTop.contrastText
            cell.playerNameLabel.textColor = Palette.tableTop.contrastText
        default:
            break
        }
    }

}

extension HandViewController {
    
    internal func setupHelpView() {
        
        self.helpView.reset()
                
        self.helpView.add("This screen allows you to play a hand of Whist. It operates in 2 modes.\n\n \(self.bidMode ? "You are currently in" : "In" ) @*/Bid@*/ mode \(self.bidMode ? "where " : "")each player enters their bid in turn.\n\n\(!self.bidMode ? "You are currently in" : "In" ) @*/Play@*/ mode \(!self.bidMode ? "where " : "")you play the cards.\n\nIf the network hangs for any reason during bid or play you can shake your device to reset the connection.")
        
        self.helpView.add("Tap the {} to go to the @*/Scorepad@*/ screen where you can check the score in detail or review previous hands.", bannerId: Banner.finishButton)
        
        self.helpView.add("During play the {} will appear if you have not yet played to the current trick.\n\nPressing and holding it will show you the last trick.\n\nAlternatively, when this button is visible, you can press and hold anywhere on the current trick to see the last trick.", bannerId: self.lastHandButton, horizontalBorder: 8, verticalBorder: 4)
        
        self.helpView.add("The top of the screen will tell you who's turn it is to bid or play.\n\n\(Scorecard.activeSettings.alertVibrate ? "Your" : "You can turn on a setting so that your") device will vibrate and the banner will flash when it is your turn to bid or play.", bannerId: Banner.titleControl)
        
        self.helpView.add("During play you can see how the total of all players' bids compares to the number of cards in this round.\n\nFor example " + NSAttributedString("-1", color: Palette.contractUnder) + " means that the total of all bids is 1 less that the number of tricks in the round.\n\nIn this case players will probably be trying to lose tricks, whereas when the total is more than the number of cards, players will be trying to win tricks.", bannerId: self.overUnderButton, horizontalBorder: 8, verticalBorder: 4)
        
        self.helpView.add("The @*/Trump Suit@*/ for the current round is displayed here.", bannerId: roundSummaryButton, horizontalBorder: 8, verticalBorder: 4)
        
        self.helpView.add("During bidding the current number of cards in the round and the trump suit are displayed here.", views: [self.statusRoundLabel], condition: { self.bidMode }, horizontalBorder: 4)
        
        self.helpView.add("Once bids have been made you can see how the total of all bids compares to the number of cards in this round.\n\nFor example " + NSAttributedString("1 Under", color: Palette.contractUnder) + " means that the total of all bids is 1 less that the number of tricks in the round.\n\nIn this case players will probably be trying to lose tricks, whereas when the total is more than the number of cards, players will be trying to win tricks.", views: [self.statusOverUnderLabel], condition: { Scorecard.game.roundStarted(Scorecard.game.selectedRound) && self.bidMode }, horizontalBorder: 4)
        
        self.helpView.add("The players' names in the order they should bid are displayed here.\n\nAs they bid their bids are displayed alongside their name.", views: [self.statusPlayer1BidLabel, self.statusPlayer2BidLabel, self.statusPlayer3BidLabel, self.statusPlayer4BidLabel], condition: { self.bidMode }, horizontalBorder: 4)
        
        self.helpView.add("When it is your turn to bid, tap on a bid button and then tap the confirm button to make your bid.\n\nIf not all bids are shown, then the '>' button can be used to show higher bid values.\n\nIf you are the last person to bid, then you cannot make the total of the bids equal the number of tricks and one of the buttons will be disabled.", views: [self.bidCollectionView], condition: { self.bidMode }, border: 4)
        
        self.helpView.add("During play the current trick will be displayed here.\n\nUnderneath each card will be the name of the player who played it. Underneath their name is their bid for this round and, if they have won any tricks, the number of tricks they have won.\n\nThe winner of the current trick is highlighted.", views: [self.tabletopView])
        
        self.helpView.add("Your hand is displayed here.\n\nWhen it is your turn to play, tap on a card and then tap the confirm button to play the card.\n\nAt that point the card will move into the current trick.", views: [self.handTableView], border: 8, shrink: true)
    }
}
