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
        
    @objc optional var gamePreviewHosting: Bool { get }
    
    @objc optional var gamePreviewWaitMessage: NSAttributedString { get }
    
    @objc optional func gamePreview(isConnected playerMO: PlayerMO) -> Bool
    
    @objc optional func gamePreview(disconnect playerMO: PlayerMO)
    
    @objc optional func gamePreview(moved playerMO: PlayerMO, to slot: Int)
    
    @objc optional func gamePreviewShakeGestureHandler() 
    
}

class GamePreviewViewController: ScorecardViewController, ButtonDelegate, SelectedPlayersViewDelegate, BannerDelegate, ShakeDelegate {
    
    // MARK: - Class Properties ================================================================ -
    
    // Delegate
    public weak var delegate: GamePreviewDelegate?
    
    // Properties to determine how view operates
    public var selectedPlayers = [PlayerMO?]()          // Selected players passed in from player selection
    private var faceTimeAddress: [String] = []          // FaceTime addresses for the above
    private var readOnly = false
    private var formTitle = "Preview"
    private var smallFormTitle = "Preview"
    private var backText: String?
    
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
    private weak var observer: NSObjectProtocol?
    private var faceTimeAvailable = false
    private var initialising = true
    private var cutCardView: [UILabel] = []
    private var smallScreen = false
    private var firstTime = true
    private var rotated = false
    private var exiting = false
    private var cutting = false
    private var autoStarting = false
    private var alreadyDrawing = false
    
    // MARK: - IB Outlets ================================================================ -
    
    @IBOutlet private weak var banner: Banner!
    @IBOutlet private weak var topSectionView: UIView!
    @IBOutlet private weak var messageLabel: UILabel!
    @IBOutlet private weak var continueButton: ShadowButton!
    @IBOutlet public weak var selectedPlayersView: SelectedPlayersView!
    @IBOutlet private weak var overrideSettingsButton: ShadowButton!
    @IBOutlet private weak var lowerMiddleSectionView: UIView!
    @IBOutlet private weak var actionButtonView: UIView!
    @IBOutlet private weak var rightViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var leftViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var bottomSectionHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var cutForDealerButton: ImageButton!
    @IBOutlet private weak var nextDealerButton: ImageButton!
    @IBOutlet private weak var infoButton: ShadowButton!
    @IBOutlet private var actionButtons: [ImageButton]!
    @IBOutlet private var sideBySideConstraints: [NSLayoutConstraint]!
    @IBOutlet private var aboveAndBelowConstraints: [NSLayoutConstraint]!
    @IBOutlet private var sideBySideTabletConstraints: [NSLayoutConstraint]!
    @IBOutlet private var notSideBySideTabletConstraints: [NSLayoutConstraint]!
    
    // MARK: - IB Actions ============================================================================== -
    
    internal func finishPressed() {
        self.finish(false)
    }
    
    internal func returnHomePressed() {
        self.finish(true)
    }
    
    internal func finish(_ returnHome: Bool) {
        // Link back to selection
        self.willDismiss()
        self.controllerDelegate?.didCancel(context: ["home" : returnHome])
    }
    
    @IBAction func continuePressed(_ sender: UIButton) {
        self.continuePressed()
    }
    
    internal func continuePressed() {
        self.willDismiss()
        self.controllerDelegate?.didProceed()
    }
    
    @IBAction func infoPressed(_ sender: UIButton) {
        self.helpView.show()
    }
        
    internal func overrideSettingsPressed() {
        self.controllerDelegate?.didInvoke(.overrideSettings)
    }
    
    internal func buttonPressed(_ sender: UIView) {
        switch sender.tag {
        case 1:
            // Cut for dealer
            self.executeCut()
        case 2:
            // Next dealer
            self.showDealer(playerNumber: Scorecard.game.dealerIs, forceHide: true)
            Scorecard.game.nextDealer(currentPlayers: selectedPlayers.count)
            self.showCurrentDealer()
            
        default:
            break
        }
    }
    
    @IBAction func rotationGesture(recognizer:UIRotationGestureRecognizer) {
        if recognizer.state == .ended {
            if !self.readOnly {
                showDealer(playerNumber: Scorecard.game.dealerIs, forceHide: true)
                if recognizer.rotation > 0 {
                    Scorecard.game.nextDealer()
                } else {
                    Scorecard.game.previousDealer()
                }
                showCurrentDealer()
            }
        }
    }
    
    // MARK: - View Overrides ================================================================ -

    override internal func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup default colors (previously done in StoryBoard)
        self.defaultViewColors()
                
        // Update players
        self.updateSelectedPlayers(selectedPlayers)
        
        // Make sure dealer not too high
        if Scorecard.game.dealerIs > Scorecard.game.currentPlayers {
            Scorecard.game.saveDealer(1)
        }
        
        // Setup screen
        self.setupScreen(size: self.view.frame.size)
        
        Scorecard.shared.saveMaxScores()
        
        // Set nofification for image download
        self.observer = setImageDownloadNotification()

        // Call controller delegate to notify loading complete
        self.controllerDelegate?.didLoad()
        
        // Setup buttons
        self.setupButtons()
        
        if !self.readOnly {
            self.checkFaceTimeAvailable()
        }
        
        // Become delegate of selected players view
        self.selectedPlayersView.delegate = self
        
        // Set up help
        self.setupHelpView()
    }
        
    override internal func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.rotated = true
        self.view.setNeedsLayout()
    }
    
    override internal func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        Scorecard.shared.reCenterPopup(self)
        
        if !exiting {
            
            let rotated = self.rotated
            let firstTime = self.firstTime
            self.rotated = false
            self.firstTime = false
            
            self.setupScreenSize()
            
            if firstTime || rotated {
                self.setupConstraints()
            }
            
            if !self.alreadyDrawing {
                self.selectedPlayersView.layoutIfNeeded()
            }
            
            self.setupScreen(size: self.view.bounds.size)
            
            if firstTime {
                self.createCutCards()
            }
            
            // Draw room
            self.drawRoom()
            
            if rotated || firstTime {
                // Update buttons
                self.updateButtons()
            }
            
            if self.initialising {
                self.initialising = false
                self.controllerDelegate?.didAppear()
            }
            if !cutting && (rotated || firstTime) {
                self.refreshPlayers()
                self.showCurrentDealer()
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Scorecard.shared.shakeDelegate = self
    }
    
    internal func shakeGestureHandler() -> Bool {
        if let shakeGestureHandler = self.delegate?.gamePreviewShakeGestureHandler {
            shakeGestureHandler()
            return true
        } else {
            return false
        }
    }
    
    override internal func willDismiss() {
        if observer != nil {
            NotificationCenter.default.removeObserver(observer!)
            observer = nil
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
        let observer = NotificationCenter.default.addObserver(forName: .playerImageDownloaded, object: nil, queue: nil) { [unowned self]
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
        if self.delegate?.gamePreviewHosting ?? false {
            self.updateSelectedPlayers(selectedPlayers)
        }
        self.delegate?.gamePreview?(moved: playerMO, to: slot)
    }
    
    func selectedPlayersView(wasTappedOn slot: Int) {
        if slot > 0 && self.delegate?.gamePreviewHosting ?? false && self.selectedPlayersView.playerViews[slot].inUse && Scorecard.shared.commsDelegate?.connectionProximity == .nearby {
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
                
        self.actionButtons.forEach{(button) in button.setProportions(top: 20, image: 70, imageBottom: 4, title: 20, titleBottom: 0, message: 0, bottom: 20)}
        self.actionButtonView.addShadow()
        
        let thumbnailSize = SelectionViewController.thumbnailSize(from: self, labelHeight: self.labelHeight)
        self.thumbnailWidth = thumbnailSize.width
        self.thumbnailHeight = thumbnailSize.height
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
    
    private func setupConstraints() {
        var sideBySide = false
        var sideBySideTablet = false
        if ScorecardUI.landscapePhone() {
            sideBySide = true
        } else if self.container == .mainRight && self.view.frame.width > 700 {
            sideBySide = true
            sideBySideTablet = true
        }
        Constraint.setActive(self.sideBySideConstraints, to: sideBySide)
        Constraint.setActive(self.aboveAndBelowConstraints, to: !sideBySide)
        Constraint.setActive(self.sideBySideTabletConstraints, to: sideBySideTablet)
        Constraint.setActive(self.notSideBySideTabletConstraints, to: !sideBySideTablet)
    }
    
    
    private func drawRoom() {
        let wasAlreadyDrawing = self.alreadyDrawing
        self.alreadyDrawing = true
        
        // Configure selected players view
        self.selectedPlayersView.roundCorners(cornerRadius: 40.0)
        self.selectedPlayersView.setHaloWidth(haloWidth: self.haloWidth, allowHaloWidth: self.dealerHaloWidth)
        self.selectedPlayersView.setHaloColor(color: Palette.halo.background)
        
        // Update layout to get correct size
        if !wasAlreadyDrawing {
           // self.view.layoutIfNeeded()
        }

        // Draw room
        self.selectedPlayersView.drawRoom(thumbnailWidth: self.thumbnailWidth, thumbnailHeight: self.thumbnailHeight, players: self.selectedPlayers.count)
        
        self.alreadyDrawing = wasAlreadyDrawing
    }
    
    private func updateButtons() {
        if self.readOnly {
            self.banner.setButton("override", isHidden: true)
            self.leftViewLeadingConstraint.constant = actionButtonView.frame.width * 0.25
                        
        } else if !cutting {
            // Hide / show buttons dependent on format
            self.banner.setButton("continue", isHidden: !ScorecardUI.landscapePhone() && !ScorecardUI.smallPhoneSize())
            self.continueButton.isHidden = ScorecardUI.landscapePhone() || ScorecardUI.smallPhoneSize()
            self.bottomSectionHeightConstraint.constant = (ScorecardUI.landscapePhone() || ScorecardUI.smallPhoneSize() ? 0.0 : ((self.menuController?.isVisible ?? false) ? 75 : 58) + (self.view.safeAreaInsets.bottom == 0 ? 8.0 : 0.0))
            self.banner.setButton("override", isHidden: false)
            
            self.leftViewLeadingConstraint.constant = 0.0
            
            if (self.delegate?.gamePreviewHosting ?? false) {
                
                let canStartGame = self.controllerDelegate?.canProceed ?? true || Scorecard.game.isPlayingComputer
                
                if canStartGame {
                    // Ready to start (or suppressing message) - enable dealer buttons and no need for message
                    self.messageLabel.isHidden = true
                    self.continueButton.isEnabled = true
                    self.actionButtons.forEach{(button) in button.isHidden = false}
                    self.messageLabel.attributedText = NSAttributedString()
                    
                    if Config.autoStartHost && !autoStarting {
                        autoStarting = true
                        self.continuePressed()
                    }
                    
                } else  {
                    // Not ready
                    self.banner.setButton("continue", isHidden: true)
                    self.continueButton.isEnabled = false
                    self.messageLabel.isHidden = false
                    self.actionButtons.forEach{(button) in button.isHidden = true}
                    self.messageLabel.attributedText = self.delegate?.gamePreviewWaitMessage
                }
            } else if self.appController?.controllerType == .scoring {
                self.messageLabel.isHidden = true
            }
        }
        self.infoButton.isHidden = (self.menuController?.isVisible ?? false)
        self.banner.set(title: (self.smallScreen && !ScorecardUI.landscapePhone() ? smallFormTitle : self.formTitle))
    }
    
    private func setupScreenSize() {
        // Check if need to restrict bottom because of screen size
        self.smallScreen = (ScorecardUI.screenHeight < 800 || ScorecardUI.landscapePhone()) && ScorecardUI.phoneSize()
    }

    
    private func setupButtons() {
        var rightButtons: [BannerButton] = []
        var nonBannerButtonsAfter: [BannerButton] = []
                
        if self.readOnly {
            self.continueButton.isHidden = true
            self.cutForDealerButton.isEnabled = false
            self.cutForDealerButton.set(title: "")
            self.actionButtons.forEach{(button) in button.isHidden = true}
            self.selectedPlayersView.isEnabled = false
        } else {
            let hosting = (self.delegate?.gamePreviewHosting ?? false)
            self.actionButtons.forEach{(button) in button.isHidden = hosting}
            self.selectedPlayersView.isEnabled = !Scorecard.game.isPlayingComputer
            if (self.delegate?.gamePreviewHosting ?? false) {
                self.selectedPlayersView.setEnabled(slot: 0, enabled: false)
            }
            rightButtons.append(contentsOf: [BannerButton(title: "Continue", image: UIImage(named: "forward"), width: 100, action: self.continuePressed, menuHide: true, menuText: "Start Game", id: "continue")])
        }
        
        let leftButtons = [
            BannerButton(image: UIImage(named: (self.backText == nil ? "home" : "back")), width: 30, action: self.finishPressed, menuHide: true, menuText: self.backText ?? "Abandon Game", menuSpaceBefore: (self.backText == nil ? 20.0 : 0.0), id: "cancel")]
        
        let nonBannerButtonsBefore = [
            BannerButton(control: self.overrideSettingsButton, action: self.overrideSettingsPressed, menuHide: true, menuText: "Override settings", id: "override"),
        ]
        
        if self.backText != nil {
            // Add a home menu item as well
            nonBannerButtonsAfter.append(
                BannerButton(action: self.returnHomePressed, menuHide: true, menuText: "Abandon Game", menuSpaceBefore: 20.0, id: "home"))
        }
        
        self.banner.set(
            leftButtons: leftButtons,
            rightButtons: rightButtons,
            nonBannerButtonsBefore: nonBannerButtonsBefore,
            nonBannerButtonsAfter: nonBannerButtonsAfter)
        
        self.continueButton.toCircle()
        self.updateButtons()
    }
    
    public func refreshPlayers() {
        if !self.initialising {
            for slot in 0..<Scorecard.shared.maxPlayers {
                if slot < self.selectedPlayers.count {
                    self.selectedPlayersView.set(slot: slot, playerMO: self.selectedPlayers[slot]!)
                    if !(self.delegate?.gamePreview?(isConnected: self.selectedPlayers[slot]!) ?? true) {
                        self.selectedPlayersView.setAlpha(slot: slot, alpha: 0.3)
                    } else {
                        self.selectedPlayersView.setAlpha(slot: slot, alpha: 1.0)
                    }
                } else {
                    self.selectedPlayersView.clear(slot: slot)
                    self.selectedPlayersView.setAlpha(slot: slot, alpha: 0.0)
                }
            }
            self.selectedPlayersView.positionSelectedPlayers(players: self.selectedPlayers.count)
            self.showCurrentDealer()
            self.updateButtons()
        }
    }
    
    public func showStatus(status: String) {
        self.messageLabel?.text = status
    }
    
    func showCurrentDealer(clear: Bool = false) {
        if clear {
            for playerNumber in 1...Scorecard.game.currentPlayers {
                self.showDealer(playerNumber: playerNumber, forceHide: true)
            }
        }
        showDealer(playerNumber: Scorecard.game.dealerIs)
    }
    
    public func showDealer(playerNumber: Int, forceHide: Bool = false) {
        
        if self.selectedPlayersView != nil {
            if forceHide {
                self.selectedPlayersView.setHaloColor(slot: playerNumber - 1, color: Palette.halo.background)
                self.selectedPlayersView.setHaloWidth(slot: playerNumber - 1, haloWidth: haloWidth, allowHaloWidth: dealerHaloWidth)
            } else {
                self.selectedPlayersView.setHaloColor(slot: playerNumber - 1, color: Palette.haloDealer.background)
                self.selectedPlayersView.setHaloWidth(slot: playerNumber - 1, haloWidth: dealerHaloWidth)
            }
        }
    }
    
    // MARK: - Utility Routines ================================================================ -

    private func updateSelectedPlayers(_ selectedPlayers: [PlayerMO?]) {
        Scorecard.game.saveSelectedPlayers(selectedPlayers)
        self.selectedPlayersView.setAlpha(alpha: 0.3)
        self.selectedPlayersView.setAlpha(slot: 0, alpha: 1.0)

    }
    
    private func checkFaceTimeAvailable() {
        self.faceTimeAvailable = false
        if (self.delegate?.gamePreviewHosting ?? false) && Scorecard.shared.commsDelegate?.connectionProximity == .online && Utility.faceTimeAvailable() {
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
        let statusIsHidden = messageLabel.isHidden
        messageLabel.isHidden = true
        self.cutForDealerButton.isHidden = false
        
        // Remove current dealer halo
        self.showDealer(playerNumber: Scorecard.game.dealerIs, forceHide: true)
        
        // Carry out cut and broadcast
        cutCards = self.cutCards(preCutCards: preCutCards)
        if Scorecard.game.isHosting || Scorecard.game.isSharing {
            Scorecard.shared.sendCut(cutCards: cutCards, playerNames: self.selectedPlayers.map{ $0!.name! })
        }
        
       self.animateDealCards(cards: cutCards, afterDuration: 0.2, stepDuration: 0.3, completion: { [unowned self] in
            self.animateTurnCards(afterDuration: 0.3, stepDuration: 0.5, completion: { [unowned self] in
                self.animateHideOthers(afterDuration: 0.5, stepDuration: 0.5, completion: { [unowned self] in
                    self.animateOutcome(cards: cutCards, afterDuration: 0.0, stepDuration: 1.0, completion: { [unowned self] in
                        self.animateClear(afterDuration: 2.0, stepDuration: 0.5, completion: { [unowned self] in
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
        
        outcome.append(NSMutableAttributedString(string: self.selectedPlayers[Scorecard.game.dealerIs - 1]!.name!, attributes: outcomeTextColor))
        outcome.append(NSMutableAttributedString(string: " wins with ", attributes: outcomeTextColor))
        outcome.append(cutCards[Scorecard.game.dealerIs-1].toAttributedString())
        
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
        Scorecard.game.saveDealer(dealerIs)
        
        return cards
    }
    
    private func animateDealCards(cards: [Card], afterDuration: TimeInterval, stepDuration: TimeInterval, completion: @escaping ()->()) {
        
        if !self.readOnly {
            // Disable actions
            self.actionButtons.forEach{(button) in button.isEnabled = false}
        }
        
        // Hide thumbnails
        for slot in 0..<Scorecard.shared.maxPlayers {
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
        self.view.bringSubviewToFront(self.lowerMiddleSectionView)
        self.lowerMiddleSectionView.bringSubviewToFront(self.cutForDealerButton)
        if self.readOnly {
            self.cutForDealerButton.alpha = 1.0
        }
        
        // Animate cards
        slot = 1
        for sequence in 0..<self.selectedPlayers.count {
            
            let animation = UIViewPropertyAnimator(duration: stepDuration, curve: .easeIn) {
                // Move card to player
                let cardView = self.cutCardView[slot]
                let origin = self.selectedPlayersView.origin(slot: slot, in: self.view)
                cardView.frame = CGRect(origin: CGPoint(x: origin.x + ((self.thumbnailWidth - cardView.frame.width) / 2.0), y: origin.y), size: cardView.frame.size)
            }
            if slot == 0 {
                animation.addCompletion({ [unowned self] _ in
                    // Fade buttons
                    if !self.readOnly {
                        self.actionButtons.forEach{(button) in button.alpha = 0.7}
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
                self.cutForDealerButton.alpha = 0.7
            }
            // Hide card back (revealing front)
            self.cutCardView[slot].subviews.first!.alpha = 0.0
        }
        animation.addCompletion({ [unowned self] _ in
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
                if slot + 1 != Scorecard.game.dealerIs {
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
            let cutCard = self.cutCardView[Scorecard.game.dealerIs - 1]
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
                self.selectedPlayersView.messageAlpha = 0.0
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
        self.actionButtons.forEach{(button) in button.isEnabled = !self.readOnly}
        if !self.readOnly {
            self.actionButtons.forEach{(button) in button.alpha = 1.0}
        } else {
            self.cutForDealerButton.isHidden = true
        }
        self.selectedPlayersView.messageAlpha = 1.0
        self.messageLabel.isHidden = statusIsHidden
        self.cutting = false
    }
    
    private func createCutCards() {
        for _ in 0..<Scorecard.shared.maxPlayers {
            let cardView = UILabel(frame: CGRect(origin: CGPoint(), size: CGSize(width: cutCardWidth, height: cutCardHeight)))
            cardView.backgroundColor = Palette.cardFace.background
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
    
    // MARK: - Function to present and dismiss this view ==============================================================
    
    class func show(from viewController: ScorecardViewController, appController: ScorecardAppController? = nil, selectedPlayers: [PlayerMO], formTitle: String = "Preview", smallFormTitle: String? = nil, backText: String? = nil, readOnly: Bool = true, faceTimeAddress: [String] = [], animated: Bool = true, delegate: GamePreviewDelegate? = nil) -> GamePreviewViewController {
        let storyboard = UIStoryboard(name: "GamePreviewViewController", bundle: nil)
        let gamePreviewViewController = storyboard.instantiateViewController(withIdentifier: "GamePreviewViewController") as! GamePreviewViewController
        
        gamePreviewViewController.selectedPlayers = selectedPlayers
        gamePreviewViewController.formTitle = formTitle
        gamePreviewViewController.smallFormTitle = smallFormTitle ?? formTitle
        gamePreviewViewController.backText = backText
        gamePreviewViewController.readOnly = readOnly
        gamePreviewViewController.faceTimeAddress = faceTimeAddress
        gamePreviewViewController.delegate = delegate
        gamePreviewViewController.controllerDelegate = appController
                
        gamePreviewViewController.firstTime =  true
        
        viewController.present(gamePreviewViewController, appController: appController, animated: animated, container: .mainRight)
        return gamePreviewViewController
    }
}

extension GamePreviewViewController {

    /** _Note that this code was generated as part of the move to themed colors_ */

    private func defaultViewColors() {

        self.topSectionView.backgroundColor = ((self.menuController?.isVisible ?? false) ? Palette.normal.background : Palette.banner.background)
        self.selectedPlayersView.backgroundColor = Palette.tableTop.background
        self.messageLabel.textColor = Palette.normal.text
        self.continueButton.setTitleColor(Palette.continueButton.text, for: .normal)
        self.continueButton.setBackgroundColor(Palette.continueButton.background)
        self.continueButton.setTitleColor(Palette.continueButton.text, for: .normal)
        self.actionButtons.forEach{(button) in button.set(faceColor: Palette.buttonFace.background)}
        self.actionButtons.forEach{(button) in button.set(titleColor: Palette.buttonFace.text)}
        self.overrideSettingsButton.setBackgroundColor(Palette.buttonFace.background)
        self.overrideSettingsButton.setTitleColor(Palette.buttonFace.text, for: .normal)
        self.view.backgroundColor = Palette.normal.background
        self.infoButton.setBackgroundColor(Palette.bannerShadow.background)
        self.infoButton.tintColor = Palette.bannerShadow.text
    }

}

extension GamePreviewViewController {
    
    internal func setupHelpView() {
        
        self.helpView.reset()
        
        var text: String?
        
        if self.readOnly && !Scorecard.game.hasJoined {
            // Just watching someone else's game
            text = "This screen allows you to see what's happening when you are viewing a game which has not yet started."
        } else if self.appController?.controllerType == .scoring {
            text = "This screen allows you to review the players you have chosen for the game.\n\nYou can cut for dealer or manually select the dealer.\n\nYou can then start the game."
        } else if Scorecard.game.hasJoined {
            text = "This screen allows you to see what's happening when you have joined a game which has not yet started.\n\nYou can see the other players who have joined, and you can monitor the cut for dealer when it is initiated by the host."
        } else if Scorecard.game.isPlayingComputer {
            text = "This screen allows you to preview your game against the 3 robots.\n\nYou can cut for dealer or manually select the dealer.\n\nYou can then start the game."
        } else if (self.delegate?.gamePreviewHosting ?? false) {
            text = "This screen allows you to monitor who has connected to your game as you wait for the other players to join.\n\nOnce all players have joined you can cut for dealer or manually select the dealer.\n\nYou can then start the game."
        }
        
        if let text = text {
            self.helpView.add(text)
        }
        
        if !self.readOnly {
            var text = ""
            
            if Scorecard.game.isPlayingComputer {
                text = "The @*/room@*/ contains the players in the game. This is always you and 3 robots. You cannot cange them."
            } else if self.appController?.controllerType == .scoring {
                text = "The @*/room@*/ contains the players you have chosen. You can't change them, but you can drag the players to different positions in the room"
            } else if Scorecard.shared.commsDelegate?.connectionMode == .invite {
                text = "The @*/room@*/ contains  yourself (at the bottom) and the other players you have invited to join the game. They will be dim until they have accepted their invitation. You cannot change these players, but you can drag the other players to different positions in the room."
            } else {
                text = "The @*/room@*/ contains yourself (at the bottom) and the other players who have joined your game. You can tap on one of the other players to reject them or you can drag the other players to different positions in the room."
            }
            
            self.helpView.add(text, views: [self.selectedPlayersView], radius: 40)
            
            self.helpView.add("The {} allows you to change the settings for the current game only. You can change the number of cards in each hand and include/exclude the game in history and/or statistics.", descriptor: "@*/Override@*/ button", views: [self.overrideSettingsButton], bannerId: "override")
        }
        
        self.helpView.add("You will be kept informed of progress towards starting the game by this message", views: [self.messageLabel], horizontalBorder: -4)
        
        if !self.readOnly {
        
            self.helpView.add("The @*/Cut for Dealer@*/ button allows you to randomly select the dealer who will also be the person to start the bidding in the first round.", views: [self.cutForDealerButton])

            self.helpView.add("The @*/Next Dealer@*/ button allows you to move the dealer manually around the players (clockwise). You can also do this by using a rotate gesture with 2 fingers.", views: [self.nextDealerButton])
            
            let canStartGame = self.controllerDelegate?.canProceed ?? true || Scorecard.game.isPlayingComputer
            self.helpView.add("\(canStartGame ? "" : "When all the players have joined the {} will be enabled.") Click the @*/Continue@*/ button to start the game.", descriptor: "@*/Continue@*/ button", views: [self.continueButton], bannerId: "continue", radius: self.continueButton.frame.height / 2)

        }
        
        self.helpView.add("The {} takes you back to the selection screen and allows you to change the players in the game", bannerId: "cancel", horizontalBorder: 8, verticalBorder: 4)

        self.helpView.add("The {} abandons the game and takes you back to the home screen.", bannerId: "home", border: 4, horizontalBorder: 8, verticalBorder: 4)
        
    }
}
