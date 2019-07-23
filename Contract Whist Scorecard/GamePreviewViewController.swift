//
//  GamePreviewViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 27/11/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

protocol GamePreviewDelegate {
    func gamePreviewComplete()
}

class GamePreviewViewController: CustomViewController, CutDelegate, ImageButtonDelegate {
    
    // MARK: - Class Properties ================================================================ -
    
    // Main state properties
    private let scorecard = Scorecard.shared
    private var recovery: Recovery!

    // Delegate
    public var delegate: GamePreviewDelegate!
    
    // Properties to pass state to / from segues
    public var selectedPlayers = [PlayerMO?]()          // Selected players passed in from player selection
    public var faceTimeAddress: [String] = []           // FaceTime addresses for the above
    public var returnSegue: String!                     // View to return to
    public var rabbitMQService: RabbitMQService!
    public var computerPlayerDelegate: [Int: ComputerPlayerDelegate?]?
    public var cutDelegate: CutDelegate?
    public var readOnly = false
    
    // Local class variables
    private var buttonMode = "Triangle"
    private var buttonRowHeight:CGFloat = 0.0
    private var playerRowHeight:CGFloat = 0.0
    private var thumbnailWidth: CGFloat = 75.0
    private var thumbnailHeight: CGFloat = 100.0
    private var haloWidth: CGFloat = 3.0
    private var observer: NSObjectProtocol?
    private var faceTimeAvailable = false
    private var firstTime = true
    private var cutCardView: [UILabel] = []
    
    // MARK: - IB Outlets ================================================================ -
    
    @IBOutlet private weak var continueButton: UIButton!
    @IBOutlet private weak var selectedPlayersView: SelectedPlayersView!
    @IBOutlet private weak var overrideButton: UIButton!
    @IBOutlet private weak var toolbar: UIToolbar!
    @IBOutlet private weak var toolbarBottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var actionButtonView: UIView!
    @IBOutlet private weak var cutForDealerButton: ImageButton!
    @IBOutlet private weak var nextDealerButton: ImageButton!

    // MARK: - IB Unwind Segue Handlers ================================================================ -

    @IBAction func hideScorepad(segue:UIStoryboardSegue) {
        self.scorecard.setGameInProgress(false)
    }

    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func finishGamePressed(_ sender: Any) {
        // Link back to selection
        if self.readOnly {
            self.delegate?.gamePreviewComplete()
            self.dismiss(animated: true, completion: nil)
        } else {
            NotificationCenter.default.removeObserver(observer!)
            self.scorecard.resetOverrideSettings()
            self.performSegue(withIdentifier: returnSegue, sender: self)
        }
    }
    
    @IBAction func continuePressed(_ sender: Any) {
        self.goToScorepad()
    }
    
    @IBAction func overrideSettingsPressed(_ sender: UIButton) {
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
    
    @IBAction func leftSwipe(recognizer:UISwipeGestureRecognizer) {
        if recognizer.state == .ended {
            showScorepad()
        }
    }
    
    @IBAction func rightSwipe(recognizer:UISwipeGestureRecognizer) {
        if recognizer.state == .ended {
            self.finishGamePressed(self)
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

       // Make sure dealer not too high
        if self.scorecard.dealerIs > self.scorecard.currentPlayers {
            self.scorecard.saveDealer(1)
        }
        
        updateSelectedPlayers(selectedPlayers)
        setupScreen(size: self.view.frame.size)
        scorecard.saveMaxScores()
        
        // Set nofification for image download
        observer = setImageDownloadNotification()

        // Set readonly
        if self.readOnly {
            self.selectedPlayersView.isEnabled = false
            self.continueButton.isHidden = true
        }
        
        if !self.readOnly {
            self.checkFaceTimeAvailable()
        }
        
        self.createCutCards()
        
        // Set toolbar clear
        ScorecardUI.setToolbarClear(toolbar: toolbar)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Check if in recovery mode and if so go straight to scorecard
        if firstTime && scorecard.recoveryMode {
            firstTime = false
            self.recoveryScorepad()
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.view.setNeedsLayout()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        setupScreen(size: UIScreen.main.bounds.size)
        self.selectedPlayersView.setHaloWidth(haloWidth: self.haloWidth)
        self.selectedPlayersView.setHaloColor(color: Palette.halo)
        self.selectedPlayersView.drawRoom(thumbnailWidth: thumbnailWidth, thumbnailHeight: thumbnailHeight, directions: .up, .down)
        for slot in 0..<self.scorecard.currentPlayers {
            self.selectedPlayersView.set(slot: slot, playerMO: self.selectedPlayers[slot]!)
        }
        self.showCurrentDealer()
    }
    
    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        self.scorecard.motionBegan(motion, with: event)
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
        // Find any cells containing an image which has just been downloaded asynchronously
        Utility.mainThread {
            let index = self.scorecard.enteredIndex(objectID)
            if index != nil {	
                // Found it - reload the cell
                //TODO Update selected image
            }
        }
    }
    
    // MARK: - Cut for dealer delegate routines ===================================================================== -
    
    public func cutComplete() {
        for playerNumber in 1...self.scorecard.currentPlayers {
            self.showDealer(playerNumber: playerNumber)
        }
        self.cutDelegate?.cutComplete()
    }
    
    // MARK: - Form Presentation / Handling Routines ================================================================ -
    
    func setupScreen(size: CGSize) {
        if size.width >= 530 {
            buttonMode = "Row"
            buttonRowHeight = 160
        } else {
            buttonMode = "Row"
            buttonRowHeight = 160
        }
        
        playerRowHeight = max(48, min(80, (size.height - buttonRowHeight - 100) / CGFloat(scorecard.currentPlayers)))
        
        self.slideOutToolbar()

    }
    
    private func slideOutToolbar(animated: Bool = false) {
        // Note the selected view extends 44 below the bottom of the screen. Setting the bottom constraint to zero makes the toolbar disappear
        let toolbarBottomOffset: CGFloat = -44 + (self.view.safeAreaInsets.bottom * 0.40)
        if toolbarBottomOffset != self.toolbarBottomConstraint.constant {
            if animated {
                Utility.animate(duration: 0.3) {
                    self.toolbarBottomConstraint.constant = toolbarBottomOffset
                }
            } else {
                self.toolbarBottomConstraint.constant = toolbarBottomOffset
            }
        }
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
        self.alertMessage(if: self.scorecard.overrideSelected, "This game was being played with Override Settings", title: "Reminder", okHandler: {
            self.performSegue(withIdentifier: "showScorepad", sender: self )
        })
    }
    
    func showScorepad() {
        recovery.saveInitialValues()
        self.scorecard.setGameInProgress(true)
        self.performSegue(withIdentifier: "showScorepad", sender: self )
    }
    
    func showCurrentDealer() {
        showDealer(playerNumber: scorecard.dealerIs)
    }
    
    public func showDealer(playerNumber: Int, forceHide: Bool = false) {
        
        if forceHide {
            self.selectedPlayersView.setHaloColor(slot: playerNumber - 1, color: Palette.halo)
            self.selectedPlayersView.setHaloWidth(slot: playerNumber - 1, haloWidth: 3.0)
        } else {
            self.selectedPlayersView.setHaloColor(slot: playerNumber - 1, color: Palette.haloDealer)
            self.selectedPlayersView.setHaloWidth(slot: playerNumber - 1, haloWidth: 5.0)
        }
    }
    
    // MARK: - Utility Routines ================================================================ -

    func updateSelectedPlayers(_ selectedPlayers: [PlayerMO?]) {
        scorecard.updateSelectedPlayers(selectedPlayers)
        scorecard.checkReady()

    }
    
    private func checkFaceTimeAvailable() {
        self.faceTimeAvailable = false
        if self.scorecard.isHosting && self.scorecard.commsDelegate?.connectionProximity == .online && Utility.faceTimeAvailable() {
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
    
    private func executeCut(preCutCards: [Card]? = nil) {
        var cutCards: [Card]
        
        // Remove current dealer halo
        self.showDealer(playerNumber: self.scorecard.dealerIs, forceHide: true)
        
        // Carry out cut and broadcast
        cutCards = self.cutCards(preCutCards: preCutCards)
        if self.scorecard.isHosting {
            self.scorecard.sendCut(cutCards: cutCards)
        }
        
        animateDealCards(cards: cutCards, afterDuration: 0.2, stepDuration: 0.3, completion: {
            self.animateTurnCards(afterDuration: 0.3, stepDuration: 0.5, completion: {
                self.animateHideOthers(afterDuration: 0.5, stepDuration: 0.5, completion: {
                    self.animateOutcome(cards: cutCards, afterDuration: 0.0, stepDuration: 1.0, completion: {
                        self.animateClear(afterDuration: 2.0, stepDuration: 0.5, completion: {
                            self.animateResume()
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
        
        // Disable actions
        self.cutForDealerButton.isEnabled = false
        self.nextDealerButton.isEnabled = false
        
        // Hide thumbnails
        for slot in 0..<self.scorecard.currentPlayers {
            self.selectedPlayersView.setThumbnailAlpha(slot: slot, alpha: 0.0)
        }
        
        // Animate cards
        var slot = 1
        for sequence in 0..<self.scorecard.currentPlayers {
            
            // Position a card on the deck and show back (only subview)
            let cardView = self.cutCardView[slot]
            let button = self.cutForDealerButton!
            cardView.frame = CGRect(origin: button.convert(CGPoint(x: (button.frame.width - cardView.frame.width) / 2.0,
                                                                   y: (button.frame.height - cardView.frame.height) * 0.25),
                                                           to: self.view),
                                    size: cardView.frame.size)
            cardView.alpha = 1.0
            let cardImageView = self.cutCardView[slot].subviews.first!
            cardImageView.alpha = 1.0
            cardView.bringSubviewToFront(cardImageView)
            self.view.bringSubviewToFront(self.actionButtonView)
            self.actionButtonView.bringSubviewToFront(self.cutForDealerButton)
            cardView.attributedText = cards[slot].toAttributedString()
    
            let animation = UIViewPropertyAnimator(duration: stepDuration, curve: .easeIn) {
                // Move card to player
                let origin = self.selectedPlayersView.origin(slot: slot, in: self.view)
                cardView.frame = CGRect(origin: CGPoint(x: origin.x + ((self.thumbnailWidth - cardView.frame.width) / 2.0),
                                                        y: origin.y),
                                        size: cardView.frame.size)
            }
            if slot == 0 {
                animation.addCompletion({ _ in
                    // Fade buttons
                    self.cutForDealerButton.alpha = 0.5
                    self.nextDealerButton.alpha = 0.5
                    completion()
                })
            }
            animation.startAnimation(afterDelay: Double(sequence) * afterDuration)
            
            slot = (slot + 1) % self.scorecard.currentPlayers
            
        }
    }
    
    private func animateTurnCards(afterDuration: TimeInterval = 0.0, stepDuration: TimeInterval, slot: Int = 1, completion: @escaping ()->()) {
        
        // Animate card turn
        let animation = UIViewPropertyAnimator(duration: stepDuration, curve: .easeIn) {
            // Fade out the back
            self.cutCardView[slot].subviews.first!.alpha = 0.0
        }
        animation.addCompletion({ _ in
            if slot == 0 {
                completion()
            } else {
                self.animateTurnCards(afterDuration: afterDuration, stepDuration: stepDuration, slot: (slot + 1) % self.scorecard.currentPlayers, completion: completion)
            }
        })
        animation.startAnimation(afterDelay: afterDuration)
    }
    
    private func animateHideOthers(afterDuration: TimeInterval, stepDuration: TimeInterval, completion: @escaping ()->()) {
        let animation = UIViewPropertyAnimator(duration: stepDuration, curve: .easeIn) {
            for slot in 0..<self.scorecard.currentPlayers {
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
            for slot in 0..<self.scorecard.currentPlayers {
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
    
    private func animateResume() {
        self.selectedPlayersView.message = NSAttributedString()
        self.showCurrentDealer()
        self.cutForDealerButton.isEnabled = true
        self.nextDealerButton.isEnabled = true
        self.cutForDealerButton.alpha = 1.0
        self.nextDealerButton.alpha = 1.0
        self.selectedPlayersView.messageAlpha = 1.0
    }
    
    private func createCutCards() {
        for _ in 0..<self.scorecard.currentPlayers {
            let cardView = UILabel(frame: CGRect(origin: CGPoint(), size: CGSize(width: 50.0, height: 75.0)))
            cardView.backgroundColor = Palette.cardFace
            ScorecardUI.roundCorners(cardView)
            cardView.textAlignment = .center
            cardView.font = UIFont.systemFont(ofSize: 24.0)
            let cardImageView = UIImageView(frame: cardView.frame)
            cardImageView.image = UIImage(named: "card back")
            cardView.addSubview(cardImageView)
            self.view.addSubview(cardView)
            cardView.alpha = 0.0
            cardImageView.alpha = 0.0
            self.cutCardView.append(cardView)
        }
    }
    
    
    // MARK: - Segue Prepare Handler ================================================================ -

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier! {
        case "showScorepad":
            let destination = segue.destination as! ScorepadViewController
            destination.scorepadMode = (self.scorecard.isHosting || self.scorecard.hasJoined ? .display : .amend)
            if self.scorecard.checkOverride() {
                destination.cards = scorecard.overrideCards
                destination.bounce = scorecard.overrideBounceNumberCards
                destination.rounds = scorecard.calculateRounds(cards: destination.cards,
                                                               bounce: destination.bounce)
            } else {
                destination.cards = scorecard.settingCards
                destination.bounce = scorecard.settingBounceNumberCards
                destination.rounds = scorecard.rounds
            }
            destination.bonus2 = scorecard.settingBonus2
            destination.suits = scorecard.suits
            destination.returnSegue = "hideScorepad"
            destination.rabbitMQService = self.rabbitMQService
            destination.recoveryMode = self.scorecard.recoveryMode
            destination.computerPlayerDelegate = self.computerPlayerDelegate
            self.scorecard.recoveryMode = false
            
        default:
            break
        }
    }
    
    // MARK: - Function to present this view ==============================================================
    
    class func showGamePreview(viewController: UIViewController, selectedPlayers: [PlayerMO]) -> GamePreviewViewController {
        let storyboard = UIStoryboard(name: "GamePreviewViewController", bundle: nil)
        let gamePreviewViewController = storyboard.instantiateViewController(withIdentifier: "GamePreviewViewController") as! GamePreviewViewController
        gamePreviewViewController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        
        gamePreviewViewController.selectedPlayers = selectedPlayers
        gamePreviewViewController.readOnly = true
        
        viewController.present(gamePreviewViewController, animated: true, completion: nil)
        return gamePreviewViewController
    }
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class GamePreviewNameCell: UITableViewCell {
    @IBOutlet var playerName: UILabel!
    @IBOutlet var playerButton: UIButton!
    @IBOutlet weak var playerImage: UIImageView!
    @IBOutlet weak var playerDisc: UILabel!
    @IBOutlet weak var faceTimeButton: UIButton!
    @IBOutlet weak var faceTimeButtonWidth: NSLayoutConstraint!
    @IBOutlet weak var faceTimeButtonTrailing: NSLayoutConstraint!
}

class GamePreviewActionCell: UITableViewCell {
    @IBOutlet weak var cutForDealerButton: ImageButton!
    @IBOutlet weak var nextDealerButton: ImageButton!
    @IBOutlet weak var overrideSettingsButton: ImageButton!
}

// MARK: - Utility Classes ================================================================ -

class UIStoryboardSegueWithCompletion: UIStoryboardSegue {
    // This is an affectation to allow a segue to wait for its completion before doing something else - e.g. fire another segue
    // For it to work the exit segue has to have this class filled in in the Storyboard
    var completion: (() -> Void)?
    
    override func perform() {
        super.perform()
        if let completion = completion {
            completion()
        }
    }
}
