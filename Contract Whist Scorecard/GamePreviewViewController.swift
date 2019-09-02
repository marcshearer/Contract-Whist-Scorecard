//
//  GamePreviewViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 27/11/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

@objc protocol GamePreviewDelegate {
    
    @objc optional var gamePreviewCanStartGame: Bool { get }
    
    @objc optional var gamePreviewHosting: Bool { get }
    
    @objc optional var gamePreviewWaitMessage: NSAttributedString { get }
    
    @objc optional func gamePreviewInitialisationComplete(gamePreviewViewController: GamePreviewViewController)
    
    @objc optional func gamePreviewCompletion(returnHome: Bool)
    
    @objc optional func gamePreviewStartGame()
    
    @objc optional func gamePreviewStopGame()
    
    @objc optional func gamePreview(isConnected playerMO: PlayerMO) -> Bool
    
    @objc optional func gamePreview(disconnect playerMO: PlayerMO)
    
    @objc optional func gamePreview(moved playerMO: PlayerMO, to slot: Int)
    
    @objc optional func gamePreviewShakeGestureHandler()
    
}

class GamePreviewViewController: CustomViewController, ImageButtonDelegate, SelectedPlayersViewDelegate {
    
    // MARK: - Class Properties ================================================================ -
    
    // Delegate
    public var delegate: GamePreviewDelegate?
    
    // Main state properties
    private let scorecard = Scorecard.shared
    private var recovery: Recovery!

    // Properties to determine how view operates
    public var selectedPlayers = [PlayerMO?]()          // Selected players passed in from player selection
    private var faceTimeAddress: [String] = []          // FaceTime addresses for the above
    private var rabbitMQService: RabbitMQService!
    private var computerPlayerDelegate: [Int: ComputerPlayerDelegate?]?
    private var readOnly = false
    private var formTitle = "Preview"
    private var backText = ""
    private var completion: ((Bool)->())?
    
    // Local class variables
    private var buttonMode = "Triangle"
    private var buttonRowHeight:CGFloat = 0.0
    private var playerRowHeight:CGFloat = 0.0
    private var thumbnailWidth: CGFloat!
    private var thumbnailHeight: CGFloat!
    private let labelHeight: CGFloat = 30.0
    private var cutCardWidth: CGFloat!
    private var cutCardHeight: CGFloat!
    private var haloWidth: CGFloat = 3.0
    private var dealerHaloWidth: CGFloat = 5.0
    private var observer: NSObjectProtocol?
    private var faceTimeAvailable = false
    private var initialising = true
    private var cutCardView: [UILabel] = []
    private var firstTime = true
    private var rotated = false
    private var cutting = false
    
    // MARK: - IB Outlets ================================================================ -
    
    @IBOutlet private weak var navigationBar: UINavigationBar!
    @IBOutlet private weak var navigationBarHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var navigationTitle: UINavigationItem!
    @IBOutlet private weak var bannerContinuationView: UIView!
    @IBOutlet private weak var bannerContinueButton: UIButton!
    @IBOutlet private weak var bannerContinuationLabel: UILabel!
    @IBOutlet private weak var continueButton: UIButton!
    @IBOutlet private weak var continueButtonHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var cancelButton: UIButton!
    @IBOutlet private weak var selectedPlayersView: SelectedPlayersView!
    @IBOutlet private weak var selectedPlayersTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var selectedPlayersHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var overrideSettingsButton: UIButton!
    @IBOutlet private weak var overrideSettingsBottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var actionButtonView: UIView!
    @IBOutlet private weak var cutForDealerButton: ImageButton!
    @IBOutlet private weak var nextDealerButton: ImageButton!

    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func finishGamePressed(_ sender: Any) {
        // Link back to selection
        if !self.scorecard.isHosting && !self.scorecard.hasJoined {
            NotificationCenter.default.removeObserver(observer!)
            self.scorecard.resetOverrideSettings()
        }
        self.dismiss()
    }
    
    @IBAction func continuePressed(_ sender: Any) {
        self.goToScorepad()
    }
    
    @IBAction func overrideSettingsButtonPressed(_ sender: Any) {
        let overrideViewController = OverrideViewController()
        overrideViewController.show()
    }
    
    internal func imageButtonPressed(_ sender: ImageButton) {
        switch sender.tag {
        case 1:
            // Cut for dealer
            self.executeCut()
        case 2:
            // Next dealer
            self.showDealer(playerNumber: scorecard.dealerIs, forceHide: true)
            self.scorecard.nextDealer()
            self.showCurrentDealer()
            
        default:
            break
        }
    }
    
    @IBAction func rotationGesture(recognizer:UIRotationGestureRecognizer) {
        if recognizer.state == .ended {
            if !self.readOnly {
                showDealer(playerNumber: scorecard.dealerIs, forceHide: true)
                if recognizer.rotation > 0 {
                    scorecard.nextDealer()
                } else {
                    scorecard.previousDealer()
                }
                showCurrentDealer()
            }
        }
    }
    
    // MARK: - View Overrides ================================================================ -

    override func viewDidLoad() {
        super.viewDidLoad()
        
        recovery = scorecard.recovery
        
        // Set title
        self.navigationTitle.title = self.formTitle
        
        // Update players
        self.updateSelectedPlayers(selectedPlayers)
        
        // Make sure dealer not too high
        if self.scorecard.dealerIs > self.scorecard.currentPlayers {
            self.scorecard.saveDealer(1)
        }
        
        // Setup screen
        self.setupScreen(size: self.view.frame.size)
        
        self.scorecard.saveMaxScores()
        
        // Set nofification for image download
        self.observer = setImageDownloadNotification()

        // Setup buttons
        self.setupButtons(animate: false)
        
        if !self.readOnly {
            self.checkFaceTimeAvailable()
        }
        
        self.createCutCards()
        
        // Become delegate of selected players view
        self.selectedPlayersView.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if (self.delegate?.gamePreviewHosting ?? false) && self.scorecard.recoveryMode && self.delegate?.gamePreviewCanStartGame ?? true {
            // If recovering and controller is happy then go to scorepad
            self.recoveryScorepad()
        } else if self.scorecard.recoveryMode && self.scorecard.recoveryOnlineMode != nil {
            // If recovering in scorepad mode go to scorepad
            self.recoveryScorepad()
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.rotated = true
        self.scorecard.reCenterPopup(self)
        self.view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let rotated = self.rotated
        let firstTime = self.firstTime
        self.rotated = false
        self.firstTime = false
        
        self.setupScreen(size: self.view.bounds.size)
        
        // Draw room
        self.drawRoom()
        
        if rotated || firstTime {
            // Update buttons
            self.updateButtons(animate: false)
        }
        
        if self.initialising {
            self.initialising = false
            self.delegate?.gamePreviewInitialisationComplete?(gamePreviewViewController: self)
        }
        self.refreshPlayers()
        self.showCurrentDealer()
    }
    
    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if let shakeGestureHandler = self.delegate?.gamePreviewShakeGestureHandler {
            shakeGestureHandler()
        } else {
            self.scorecard.motionBegan(motion, with: event)
        }
    }
    
    // MARK: - Action Handlers ================================================================ -
 
    @objc func faceTimePressed(_ button: UIButton) {
        let playerNumber = button.tag
        Utility.faceTime(phoneNumber: self.faceTimeAddress[playerNumber - 1])
    }
    
    // MARK: - Image download handlers =================================================== -
    
    func setImageDownloadNotification() -> NSObjectProtocol? {
        // Set a notification for images downloaded
        let observer = NotificationCenter.default.addObserver(forName: .playerImageDownloaded, object: nil, queue: nil) {
            (notification) in
            self.updateImage(objectID: notification.userInfo?["playerObjectID"] as! NSManagedObjectID)
        }
        return observer
    }
    
    func updateImage(objectID: NSManagedObjectID) {
        // Find any cells containing an image which has just been downloaded asynchronously and refresh it
        Utility.mainThread {
            if let slot = self.selectedPlayersView.playerViews.firstIndex(where: { $0.playerMO?.objectID == objectID } ) {
                self.selectedPlayersView.set(slot: slot, playerMO: self.selectedPlayersView.playerViews[slot].playerMO!)
            }
        }
    }
    
    // MARK: - Selected Players View delegate handlers =============================================== -
    
    func selectedPlayersView(moved playerMO: PlayerMO, to slot: Int) {
        // Update related list element
        self.selectedPlayers[slot] = playerMO
        self.updateSelectedPlayers(selectedPlayers)
        self.delegate?.gamePreview?(moved: playerMO, to: slot)
    }
    
    func selectedPlayersView(wasTappedOn slot: Int) {
        if slot > 0 && self.delegate?.gamePreviewHosting ?? false && self.selectedPlayersView.playerViews[slot].inUse && self.scorecard.commsDelegate?.connectionProximity == .nearby {
            // Allow disconnection of players if this is a 'nearby' host
            self.selectedPlayersView.startDeleteWiggle(slot: slot)
        }
    }
    
    func selectedPlayersView(wasDeleted slot: Int) {
        if let playerMO = self.selectedPlayersView.playerViews[slot].playerMO {
            self.delegate?.gamePreview?(disconnect: playerMO)
        }
    }
    
    // MARK: - Form Presentation / Handling Routines ================================================================ -
    
    func setupScreen(size: CGSize) {
        
        navigationBarHeightConstraint.constant = (ScorecardUI.landscapePhone() ? 32 : 44)
        
        let thumbnailSize = SelectionViewController.thumbnailSize(view: self.view, labelHeight: self.labelHeight)
        self.thumbnailWidth = thumbnailSize.width
        self.thumbnailHeight = self.thumbnailWidth + 25.0
        self.cutCardHeight = self.thumbnailWidth
        self.cutCardWidth = self.cutCardHeight * 2.0 / 3.0
        
        if size.width >= 530 {
            buttonMode = "Row"
            buttonRowHeight = 160
        } else {
            buttonMode = "Row"
            buttonRowHeight = 160
        }
        
        playerRowHeight = max(48, min(80, (size.height - buttonRowHeight - 100) / CGFloat(self.selectedPlayers.count)))
        
    }
    
    private func drawRoom() {
        
        // Configure selected players view
        self.selectedPlayersView.setHaloWidth(haloWidth: self.haloWidth, allowHaloWidth: self.dealerHaloWidth)
        self.selectedPlayersView.setHaloColor(color: Palette.halo)
        
        // Update layout to get correct size
        self.view.layoutIfNeeded()
        
        // Draw room
        let selectedFrame = self.selectedPlayersView.drawRoom(thumbnailWidth: thumbnailWidth, thumbnailHeight: thumbnailHeight, directions: (ScorecardUI.landscapePhone() ? ArrowDirection.none : ArrowDirection.up), (ScorecardUI.landscapePhone() ? ArrowDirection.none : ArrowDirection.down))
        
        // Reset height
        selectedPlayersHeightConstraint?.constant = selectedFrame.height
    }
    
    private func updateButtons(animate: Bool = true) {
        if self.readOnly {
            self.overrideSettingsButton.isHidden = true
            self.selectedPlayersTopConstraint.constant = (UIScreen.main.bounds.height * 0.10) + navigationBar.intrinsicContentSize.height
        } else if !cutting {
            self.bannerContinueButton.isHidden = !ScorecardUI.landscapePhone() && !ScorecardUI.smallPhoneSize()
            self.continueButton.isHidden = ScorecardUI.landscapePhone() || ScorecardUI.smallPhoneSize()
            self.overrideSettingsButton.isHidden = false
            if (self.delegate?.gamePreviewHosting ?? false) {
                var topConstraint: CGFloat
                let canStartGame = self.delegate?.gamePreviewCanStartGame ?? true
                if canStartGame {
                    topConstraint = 20.0
                    self.bannerContinuationLabel.isHidden = true
                    self.cutForDealerButton.isEnabled = true
                    self.cutForDealerButton.alpha = 1.0
                    self.nextDealerButton.isEnabled = true
                    self.nextDealerButton.alpha = 1.0
                } else {
                    topConstraint = (UIScreen.main.bounds.height * 0.15)
                    self.bannerContinueButton.isHidden = true
                    self.continueButton.isHidden = true
                    self.bannerContinuationLabel.isHidden = false
                    self.cutForDealerButton.isEnabled = false
                    self.cutForDealerButton.alpha = 0.5
                    self.nextDealerButton.isEnabled = false
                    self.nextDealerButton.alpha = 0.5
               }
                self.bannerContinuationLabel.attributedText = self.delegate?.gamePreviewWaitMessage
                if self.selectedPlayersTopConstraint.constant != topConstraint {
                    Utility.animate(if: animate) {
                        self.selectedPlayersTopConstraint.constant = topConstraint
                    }
                }
                if canStartGame && self.scorecard.recoveryMode {
                    // Controller happy for game to start in recovery mode - go straight to game
                    self.recoveryScorepad()
                }
            }
        }
        self.overrideSettingsBottomConstraint?.constant = (self.continueButton.isHidden ? 20.0 : 80.0)
        self.continueButtonHeightConstraint.constant = (self.continueButton.isHidden ? 0.0 : 50.0)
    }
    
    private func setupButtons(animate: Bool = true) {
        if self.readOnly {
            self.bannerContinueButton.isHidden = true
            self.continueButton.isHidden = true
            self.cutForDealerButton.isEnabled = false
            self.cutForDealerButton.alpha = 0.0
            self.cutForDealerButton.title = ""
            self.nextDealerButton.isHidden = true
            self.selectedPlayersView.isEnabled = false
        } else {
            self.cutForDealerButton.isEnabled = true
            self.cutForDealerButton.alpha = 1.0
            self.nextDealerButton.isHidden = false
            self.selectedPlayersView.isEnabled = true
            if (self.delegate?.gamePreviewHosting ?? false) {
                self.selectedPlayersView.setEnabled(slot: 0, enabled: false)
            }
        }
        self.cancelButton.setTitle(self.backText, for: .normal)
        self.updateButtons(animate: animate)
    }
    
    public func refreshPlayers() {
        if !self.initialising {
            self.selectedPlayersView.setAlpha(alpha: 1.0)
            for slot in 0..<self.scorecard.numberPlayers {
                if slot < self.selectedPlayers.count {
                    self.selectedPlayersView.set(slot: slot, playerMO: self.selectedPlayers[slot]!)
                    if !(self.delegate?.gamePreview?(isConnected: self.selectedPlayers[slot]!) ?? true) {
                        self.selectedPlayersView.setAlpha(slot: slot, alpha: 0.3)
                    }
                } else {
                    self.selectedPlayersView.clear(slot: slot)
                }
            }
            self.selectedPlayersView.positionSelectedPlayers(players: self.selectedPlayers.count)
            self.updateButtons()
        }
    }
    
    public func showStatus(status: String) {
        self.bannerContinuationLabel.text = status
    }
    
    private func goToScorepad() {
        if self.scorecard.overrideSelected {
            self.alertDecision("Overrides for the number of cards/rounds or stats/history inclusion have been selected. Are you sure you want to continue",
                               title: "Warning",
                               okButtonText: "Use Overrides",
                               okHandler: {
                               self.showScorepad()
            },
                               otherButtonText: "Use Settings",
                               otherHandler: {
                                self.scorecard.resetOverrideSettings()
                                self.showScorepad()
            },
                               cancelButtonText: "Cancel")
        } else {
            self.showScorepad()
        }
    }
    
    private func recoveryScorepad() {
        Utility.mainThread {
            self.alertMessage(if: self.scorecard.overrideSelected, "This game was being played with Override Settings", title: "Reminder", okHandler: {
                self.delegate?.gamePreviewStartGame?()
                self.showScorepadViewController()
            })
        }
    }
    
    func showScorepad() {
        recovery.saveInitialValues()
        self.scorecard.setGameInProgress(true)
        self.delegate?.gamePreviewStartGame?()
        self.showScorepadViewController()
    }
    
    func showCurrentDealer() {
        showDealer(playerNumber: scorecard.dealerIs)
    }
    
    public func showDealer(playerNumber: Int, forceHide: Bool = false) {
        
        if forceHide {
            self.selectedPlayersView.setHaloColor(slot: playerNumber - 1, color: Palette.halo)
            self.selectedPlayersView.setHaloWidth(slot: playerNumber - 1, haloWidth: haloWidth, allowHaloWidth: dealerHaloWidth)
        } else {
            self.selectedPlayersView.setHaloColor(slot: playerNumber - 1, color: Palette.haloDealer)
            self.selectedPlayersView.setHaloWidth(slot: playerNumber - 1, haloWidth: dealerHaloWidth)
        }
    }
    
    // MARK: - Utility Routines ================================================================ -

    private func updateSelectedPlayers(_ selectedPlayers: [PlayerMO?]) {
        scorecard.updateSelectedPlayers(selectedPlayers)
        scorecard.checkReady()

    }
    
    private func checkFaceTimeAvailable() {
        self.faceTimeAvailable = false
        if (self.delegate?.gamePreviewHosting ?? false) && self.scorecard.commsDelegate?.connectionProximity == .online && Utility.faceTimeAvailable() {
            var allBlank = true
            if self.faceTimeAddress.count > 0 {
                for address in self.faceTimeAddress {
                    if address != "" {
                        allBlank = false
                        break
                    }
                }
            }
            self.faceTimeAvailable = !allBlank
        }
    }
    
    // MARK: - Cut for Dealer ========================================================== -
    
    public func executeCut(preCutCards: [Card]? = nil) {
        var cutCards: [Card]
        self.cutting = true
        let statusIsHidden = bannerContinuationLabel.isHidden
        bannerContinuationLabel.isHidden = true
        
        // Remove current dealer halo
        self.showDealer(playerNumber: self.scorecard.dealerIs, forceHide: true)
        
        // Carry out cut and broadcast
        cutCards = self.cutCards(preCutCards: preCutCards)
        if self.scorecard.isHosting {
            self.scorecard.sendCut(cutCards: cutCards)
        }
        
       self.animateDealCards(cards: cutCards, afterDuration: 0.2, stepDuration: 0.3, completion: {
            self.animateTurnCards(afterDuration: 0.3, stepDuration: 0.5, completion: {
                self.animateHideOthers(afterDuration: 0.5, stepDuration: 0.5, completion: {
                    self.animateOutcome(cards: cutCards, afterDuration: 0.0, stepDuration: 1.0, completion: {
                        self.animateClear(afterDuration: 2.0, stepDuration: 0.5, completion: {
                            self.animateResume(statusIsHidden: statusIsHidden)
                        })
                    })
                })
            })
        })
    }
    
    private func cutOutcome(cutCards: [Card]) -> NSMutableAttributedString {
        
        let outcome = NSMutableAttributedString()
        let outcomeTextColor = [NSAttributedString.Key.foregroundColor: UIColor.white]
        
        outcome.append(NSMutableAttributedString(string: self.selectedPlayers[self.scorecard.dealerIs - 1]!.name!, attributes: outcomeTextColor))
        outcome.append(NSMutableAttributedString(string: " wins with ", attributes: outcomeTextColor))
        outcome.append(cutCards[scorecard.dealerIs-1].toAttributedString())
        
        return outcome
    }
    
    private func cutCards(preCutCards: [Card]?) -> [Card] {
        var cards: [Card] = []
        
        if preCutCards != nil {
            cards = preCutCards!
        } else {
            let deal = Pack.deal(numberCards: 1, numberPlayers: self.selectedPlayers.count)
            for playerLoop in 1...self.selectedPlayers.count {
                cards.append(deal.hands[playerLoop-1].cards[0])
            }
        }
        
        // Determine who won
        var dealerIs = 1
        for playerLoop in 1...self.selectedPlayers.count {
            if cards[playerLoop-1].toNumber() > cards[dealerIs-1].toNumber() {
                dealerIs = playerLoop
            }
        }
        
        // Save it
        self.scorecard.saveDealer(dealerIs)
        
        return cards
    }
    
    private func animateDealCards(cards: [Card], afterDuration: TimeInterval, stepDuration: TimeInterval, completion: @escaping ()->()) {
        
        if !self.readOnly {
            // Disable actions
            self.cutForDealerButton.isEnabled = false
            self.nextDealerButton.isEnabled = false
        }
        
        // Hide thumbnails
        for slot in 0..<self.self.selectedPlayers.count {
            self.selectedPlayersView.setThumbnailAlpha(slot: slot, alpha: 0.0)
        }
        
        // Set up hidden cards
        var slot = 1
        for _ in 0..<self.self.selectedPlayers.count {
            // Position a card on the deck and show back (only subview)
            let cardView = self.cutCardView[slot]
            let button = self.cutForDealerButton!
            cardView.frame = CGRect(origin: button.convert(CGPoint(x: (button.frame.width - cardView.frame.width) / 2.0,
                                                                   y: (button.frame.height - cardView.frame.height) * 0.1),
                                                           to: self.view),
                                    size: cardView.frame.size)
            cardView.alpha = 1.0
            let cardImageView = self.cutCardView[slot].subviews.first!
            cardImageView.alpha = 1.0
            cardView.attributedText = cards[slot].toAttributedString()
            
            slot = (slot + 1) % self.self.selectedPlayers.count
        }
        
        // Show deck
        self.view.bringSubviewToFront(self.actionButtonView)
        self.actionButtonView.bringSubviewToFront(self.cutForDealerButton)
        if self.readOnly {
            self.cutForDealerButton.alpha = 1.0
        }
        
        // Animate cards
        slot = 1
        for sequence in 0..<self.self.selectedPlayers.count {
            
            let animation = UIViewPropertyAnimator(duration: stepDuration, curve: .easeIn) {
                // Move card to player
                let cardView = self.cutCardView[slot]
                let origin = self.selectedPlayersView.origin(slot: slot, in: self.view)
                cardView.frame = CGRect(origin: CGPoint(x: origin.x + ((self.thumbnailWidth - cardView.frame.width) / 2.0),
                                                        y: origin.y),
                                        size: cardView.frame.size)
            }
            if slot == 0 {
                animation.addCompletion({ _ in
                    // Fade buttons
                    if !self.readOnly {
                        self.cutForDealerButton.alpha = 0.5
                        self.nextDealerButton.alpha = 0.5
                    }
                    completion()
                })
            }
            animation.startAnimation(afterDelay: Double(sequence) * afterDuration)
            
            slot = (slot + 1) % self.self.selectedPlayers.count
        }
    }
    
    private func animateTurnCards(afterDuration: TimeInterval = 0.0, stepDuration: TimeInterval, slot: Int = 1, completion: @escaping ()->()) {
        
        // Animate card turn
        let animation = UIViewPropertyAnimator(duration: stepDuration, curve: .easeIn) {
            // Fade out the back
            if slot == 1 && self.readOnly {
                // Hide pack
                self.cutForDealerButton.alpha = 0.0
            }
            // Hide card back (revealing front)
            self.cutCardView[slot].subviews.first!.alpha = 0.0
        }
        animation.addCompletion({ _ in
            if slot == 0 {
                completion()
            } else {
                // Next card
                self.animateTurnCards(afterDuration: afterDuration, stepDuration: stepDuration, slot: (slot + 1) % self.self.selectedPlayers.count, completion: completion)
            }
        })
        animation.startAnimation(afterDelay: afterDuration)
    }
    
    private func animateHideOthers(afterDuration: TimeInterval, stepDuration: TimeInterval, completion: @escaping ()->()) {
        let animation = UIViewPropertyAnimator(duration: stepDuration, curve: .easeIn) {
            for slot in 0..<self.self.selectedPlayers.count {
                self.selectedPlayersView.setAlpha(slot: slot, alpha: 0.0)
                if slot + 1 != self.scorecard.dealerIs {
                    self.cutCardView[slot].alpha = 0.0
                }
            }
        }
        animation.addCompletion({ _ in
            completion()
        })
        animation.startAnimation(afterDelay: afterDuration)
    }
    
    private func animateOutcome(cards: [Card], afterDuration: TimeInterval, stepDuration: TimeInterval, completion: @escaping ()->()) {
        
        // Animate outcome
        self.selectedPlayersView.message = self.cutOutcome(cutCards: cards)
        self.selectedPlayersView.messageAlpha = 0.0
        
        let animation = UIViewPropertyAnimator(duration: stepDuration, curve: .easeIn) {
            // Update the outcome
            self.selectedPlayersView.messageAlpha = 1.0
            let cutCard = self.cutCardView[self.scorecard.dealerIs - 1]
            cutCard.frame = self.selectedPlayersView.getMessageViewFrame(size: cutCard.frame.size, in: self.view)
        }
        animation.addCompletion({ _ in
            completion()
        })
        animation.startAnimation(afterDelay: afterDuration)
    }
    
    private func animateClear(afterDuration: TimeInterval, stepDuration: TimeInterval, completion: @escaping ()->()) {
        
        // Animate removal
        let animation = UIViewPropertyAnimator(duration: stepDuration, curve: .easeIn) {
            for slot in 0..<self.self.selectedPlayers.count {
                self.cutCardView[slot].alpha = 0.0
                self.selectedPlayersView.setAlpha(slot: slot, alpha: 1.0)
                self.selectedPlayersView.setThumbnailAlpha(slot: slot, alpha: 1.0)
            }
        }
        animation.addCompletion({ _ in
            completion()
        })
        animation.startAnimation(afterDelay: afterDuration)
    }
    
    private func animateResume(statusIsHidden: Bool) {
        self.selectedPlayersView.message = NSAttributedString()
        self.showCurrentDealer()
        self.cutForDealerButton.isEnabled = !self.readOnly
        self.nextDealerButton.isEnabled = !self.readOnly
        if !self.readOnly {
            self.cutForDealerButton.alpha = 1.0
            self.nextDealerButton.alpha = 1.0
        }
        self.selectedPlayersView.messageAlpha = 1.0
        self.bannerContinuationLabel.isHidden = statusIsHidden
        self.cutting = false
    }
    
    private func createCutCards() {
        for _ in 0..<self.scorecard.numberPlayers {
            let cardView = UILabel(frame: CGRect(origin: CGPoint(x: 100, y: 100), size: CGSize(width: cutCardWidth, height: cutCardHeight)))
            cardView.isUserInteractionEnabled = false
            cardView.backgroundColor = Palette.cardFace
            ScorecardUI.roundCorners(cardView)
            cardView.textAlignment = .center
            cardView.font = UIFont.systemFont(ofSize: 22.0)
            cardView.adjustsFontSizeToFitWidth = true
            let cardImageView = UIImageView(frame: cardView.frame)
            cardImageView.image = UIImage(named: "card back")
            cardView.addSubview(cardImageView)
            self.view.addSubview(cardView)
            cardView.alpha = 0.0
            cardImageView.alpha = 0.0
            self.cutCardView.append(cardView)
        }
    }
    
    // MARK: - Show scorepad ================================================================ -

    private func showScorepadViewController() {
        var cards: [Int]
        var bounce: Bool
        var rounds: Int
        
        if self.scorecard.checkOverride() {
            cards = scorecard.overrideCards
            bounce = scorecard.overrideBounceNumberCards
            rounds = scorecard.calculateRounds(cards: cards, bounce: bounce)
        } else {
            cards = scorecard.settingCards
            bounce = scorecard.settingBounceNumberCards
            rounds = scorecard.rounds
        }
        
        _ = ScorepadViewController.show(from: self, scorepadMode: (self.scorecard.isHosting || self.scorecard.hasJoined ? .display : .amend), rounds: rounds, cards: cards, bounce: bounce, bonus2: scorecard.settingBonus2, suits: scorecard.suits, rabbitMQService: self.rabbitMQService, recoveryMode: self.scorecard.recoveryMode, computerPlayerDelegate: self.computerPlayerDelegate, completion:
                { (returnHome) in
                    self.delegate?.gamePreviewStopGame?()
                    if returnHome {
                        self.dismiss(returnHome: true)
                    } else {
                        self.showCurrentDealer()
                        self.scorecard.setGameInProgress(false)
                    }
                })
        
        self.scorecard.recoveryMode = false
    }
    
    // MARK: - Function to present and dismiss this view ==============================================================
    
    class func show(from viewController: UIViewController, selectedPlayers: [PlayerMO], title: String = "Preview", backText: String = "", readOnly: Bool = true, faceTimeAddress: [String] = [], rabbitMQService: RabbitMQService? = nil, computerPlayerDelegates: [Int : ComputerPlayerDelegate]? = nil, delegate: GamePreviewDelegate? = nil, showCompletion: (()->())? = nil) -> GamePreviewViewController {
        let storyboard = UIStoryboard(name: "GamePreviewViewController", bundle: nil)
        let gamePreviewViewController = storyboard.instantiateViewController(withIdentifier: "GamePreviewViewController") as! GamePreviewViewController
        
        gamePreviewViewController.modalPresentationStyle = UIModalPresentationStyle.popover
        gamePreviewViewController.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
        gamePreviewViewController.popoverPresentationController?.sourceView = viewController.popoverPresentationController?.sourceView ?? viewController.view
        gamePreviewViewController.popoverPresentationController?.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0 ,height: 0)
        gamePreviewViewController.preferredContentSize = CGSize(width: 400, height: 700)
        gamePreviewViewController.popoverPresentationController?.delegate = viewController as? UIPopoverPresentationControllerDelegate
        
        gamePreviewViewController.selectedPlayers = selectedPlayers
        gamePreviewViewController.formTitle = title
        gamePreviewViewController.backText = backText
        gamePreviewViewController.readOnly = readOnly
        gamePreviewViewController.faceTimeAddress = faceTimeAddress
        gamePreviewViewController.rabbitMQService = rabbitMQService
        gamePreviewViewController.computerPlayerDelegate = computerPlayerDelegates
        gamePreviewViewController.delegate = delegate
        
        if let viewController = viewController as? SelectionViewController {
            // Animating from selection - use special view controller
            gamePreviewViewController.transitioningDelegate = viewController
        }
        
        gamePreviewViewController.firstTime =  true
        
        viewController.present(gamePreviewViewController, animated: true, completion: {
            showCompletion?()
        })
        return gamePreviewViewController
    }
    
    private func dismiss(returnHome: Bool = false) {
        self.dismiss(animated: true, completion: {
            self.delegate?.gamePreviewCompletion?(returnHome: returnHome)
        })
    }
}


