//
//  CutViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 17/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit

protocol CutDelegate {
    func cutComplete()
}

class CutViewController: CustomViewController {

    // MARK: - Class Properties ======================================================================== -
    // Main state properties
    private let scorecard = Scorecard.shared
    
    // Values passed to/from segues
    public var preCutCards: [Card]!
    public var playerName: [String]!
    
    // Delegates
    public var delegate: CutDelegate!

    // Timings
    private let delay = 0.5
    private let stepDuration = 0.7
    private let outcomeDuration = 1.0
    private let waitForExit = 3.0
    
    // Positions / sizes
    private var height:CGFloat = 0.0
    private var width:CGFloat = 0.0
    private var cardHeight:CGFloat = 0.0
    private var cardWidth:CGFloat = 0.0
    private var horizontalCenter:CGFloat = 0.0
    private var verticalCenter:CGFloat = 0.0
    private var nameHeight:CGFloat = 0.0
    private var nameSpace:CGFloat = 0.0
    private var edgeSpace:CGFloat = 0.0
    private var minDimension:CGFloat = 0.0
    
    // UI component pointers
    private var playerCardView = [UIView?]()
    private var playerBackView = [UIView?]()
    private var playerCardLabel = [UILabel?]()
    private var playerNameLabel = [UILabel?]()
    
    // Other
    private var firstTime = true

    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet weak private var cutToDealView: UIView!
    @IBOutlet weak private var tableTopView: UIView!
    @IBOutlet weak private var outcomeLabel: UILabel!
    @IBOutlet weak private var player1CardView: UIView!
    @IBOutlet weak private var player2CardView: UIView!
    @IBOutlet weak private var player3CardView: UIView!
    @IBOutlet weak private var player4CardView: UIView!
    @IBOutlet weak private var player1BackView: UIView!
    @IBOutlet weak private var player2BackView: UIView!
    @IBOutlet weak private var player3BackView: UIView!
    @IBOutlet weak private var player4BackView: UIView!
    @IBOutlet weak private var player1CardLabel: UILabel!
    @IBOutlet weak private var player2CardLabel: UILabel!
    @IBOutlet weak private var player3CardLabel: UILabel!
    @IBOutlet weak private var player4CardLabel: UILabel!
    @IBOutlet weak private var player1NameLabel: UILabel!
    @IBOutlet weak private var player2NameLabel: UILabel!
    @IBOutlet weak private var player3NameLabel: UILabel!
    @IBOutlet weak private var player4NameLabel: UILabel!
    
    // MARK: - View Overrides ========================================================================== -

    override func viewDidLoad() {
        super.viewDidLoad()
                
        setupArrays()
        for playerNumber in 1...playerName.count {
            ScorecardUI.roundCorners(playerCardView[playerNumber-1]!, percent:10)
            playerNameLabel[playerNumber-1]?.text = playerName[playerNumber - 1]
            if self.playerName.count == 4  && (playerNumber == 2 || playerNumber == 4) {
                playerNameLabel[playerNumber-1]?.transform =
                    CGAffineTransform(rotationAngle: CGFloat.pi * (CGFloat(playerNumber) - 1.0) / 2.0)
            }
        }
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(finishPressed))
        tapGestureRecognizer.cancelsTouchesInView = false
        cutToDealView.addGestureRecognizer(tapGestureRecognizer)
        executeCut(preCutCards: self.preCutCards)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        scorecard.reCenterPopup(self)
        self.view.setNeedsLayout()
    }
    
    override func viewWillLayoutSubviews() {
        setupSize(to: cutToDealView.safeAreaLayoutGuide.layoutFrame)
        if firstTime {
            animateCut()
            firstTime = false
        }
    }
    
    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        self.scorecard.motionBegan(motion, with: event)
    }
    
    // MARK: - Action Handlers  - Gestures ============================================================= -

    @objc private func finishPressed() {
        self.delegate?.cutComplete()
        self.delegate = nil
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Form Presentation / Handling Routines =================================================== -
    
    private func animateCut() {
        
        // Hide the outcome
        outcomeLabel.alpha = 0.0
        
        // Animate card 1
        let animation = UIViewPropertyAnimator(duration: self.stepDuration, curve: .easeIn) {
            self.playerBackView[0]?.alpha = 0.0
        }
        animation.addCompletion( {_ in 
            
            // When complete animate card 2
            let animation = UIViewPropertyAnimator(duration: self.stepDuration, curve: .easeIn) {
                self.playerBackView[1]?.alpha = 0.0
            }
            animation.addCompletion( {_ in 
                
                // When complete animate card 3
                let animation = UIViewPropertyAnimator(duration: self.stepDuration, curve: .easeIn) {
                    self.playerBackView[2]?.alpha = 0.0
                }
                animation.addCompletion( {_ in 
                    
                    // When complete animate card 4 (if 4 player game)
                    if self.playerName.count >= 4 {
                        
                        let animation = UIViewPropertyAnimator(duration: self.stepDuration, curve: .easeIn) {
                            self.playerBackView[3]?.alpha = 0.0
                        }
                        animation.addCompletion( {_ in 
                            
                           self.animateOutcome()
                        })
                        animation.startAnimation()
                    } else {
                        self.animateOutcome()
                    }
                })
                animation.startAnimation()
            })
            animation.startAnimation()
        })
        animation.startAnimation(afterDelay: delay)
    }
    
    private func animateOutcome() {
        // Animate outcome message (4-player game)
        let animation = UIViewPropertyAnimator(duration: self.outcomeDuration, curve: .easeIn) {
            for playerNumber in 1...self.playerName.count {
                if playerNumber != self.scorecard.dealerIs {
                    self.playerCardView[playerNumber-1]!.alpha = 0.0
                    self.playerNameLabel[playerNumber-1]!.alpha = 0.0
                }
            }
            if self.playerName.count == 4  && (self.scorecard.dealerIs == 2 || self.scorecard.dealerIs == 4) {
                // Rotate back to horizontal
                self.playerNameLabel[self.scorecard.dealerIs-1]!.transform =
                    CGAffineTransform(rotationAngle: CGFloat.pi * 2)
            }
            self.playerCardView[self.scorecard.dealerIs-1]!.frame = CGRect(x: self.horizontalCenter - (self.cardWidth/2),
                                                                          y: self.verticalCenter - (self.cardHeight/2),
                                                                          width: self.cardWidth,
                                                                          height: self.cardHeight)
            
            let currentWidth = self.playerNameLabel[self.scorecard.dealerIs-1]!.frame.width
            self.playerNameLabel[self.scorecard.dealerIs-1]!.frame =
                    CGRect(x: (self.minDimension - currentWidth)/2,
                           y: self.verticalCenter + (self.scorecard.dealerIs == 1 ?
                                    (self.cardHeight/2) + self.nameSpace :
                                    -(self.cardHeight/2) - self.nameHeight - self.nameSpace),
                        width: currentWidth,
                        height: self.nameHeight)
            
            self.outcomeLabel.frame =
                    CGRect(x: self.horizontalCenter - (self.outcomeLabel.frame.width / 2),
                           y: self.verticalCenter + (self.scorecard.dealerIs == 1 ?
                                    -(self.cardHeight/2) - self.outcomeLabel.frame.height - self.nameSpace :
                                    (self.cardHeight/2) + self.nameSpace),
                           width: self.outcomeLabel.frame.width,
                           height: self.outcomeLabel.frame.height)}
        animation.addCompletion( {_ in
            let animation = UIViewPropertyAnimator(duration: self.stepDuration, curve: .easeIn) {
                // Show the outcome
                self.outcomeLabel.alpha = 0.99
            }
            animation.addCompletion( {_ in
                let animation = UIViewPropertyAnimator(duration: self.waitForExit, curve: .easeIn) {
                    // Give them time to see it
                    self.outcomeLabel.alpha = 1.0
                }
                animation.addCompletion( {_ in
                    self.finishPressed()
                })
                animation.startAnimation()
            })
            animation.startAnimation()
        })
        animation.startAnimation()
    }
    
    private func setupSize(to: CGRect) {
        height = to.height
        width = to.width
        minDimension = min(height, width)
        let left = (width - minDimension) / 2
        let top = (height - minDimension) / 2

        let right = minDimension
        let bottom = minDimension
        cardHeight = minDimension * (1/4)
        cardWidth = cardHeight * (2/3)
        horizontalCenter = minDimension / 2
        verticalCenter = minDimension / 2
        edgeSpace = minDimension * (1/8)
        
        nameSpace = minDimension * (1/160)
        nameHeight = edgeSpace - (CGFloat(2) * nameSpace)
        
        let cardLabelSpace = minDimension * 1/64
        let outcomeSpace = minDimension * 1/32
        
        let cardFontSize = minDimension * (1/16)
        let outcomeFontSize = minDimension * (1/20)
        let nameFontSize = minDimension * (1/20)
        
        
        // Table Top
        tableTopView.frame = CGRect(x: to.minX + left,
                                    y: to.minY + top,
                                    width: minDimension,
                                    height: minDimension)
        
        // Card Views
        
        if self.playerName.count == 3 {
            
            playerCardView[0]!.frame = CGRect(x: horizontalCenter - (cardWidth / 2),
                                             y: bottom - edgeSpace - cardHeight,
                                             width: cardWidth,
                                             height: cardHeight)
            playerCardView[1]!.frame = CGRect(x: edgeSpace,
                                              y: edgeSpace,
                                              width: cardWidth,
                                              height: cardHeight)
            playerCardView[2]!.frame = CGRect(x: right - edgeSpace - cardWidth,
                                              y: edgeSpace,
                                              width: cardWidth,
                                              height: cardHeight)
            playerCardView[3]!.isHidden = true
            playerBackView[3]!.isHidden = true
            
        } else {
            
            playerCardView[0]!.frame = CGRect(x: horizontalCenter - (cardWidth / 2),
                                             y: bottom - edgeSpace - cardHeight,
                                             width: cardWidth,
                                             height: cardHeight)
            playerCardView[1]!.frame = CGRect(x: edgeSpace,
                                                y: verticalCenter - (cardHeight / 2),
                                                width: cardWidth,
                                                height: cardHeight)
            playerCardView[2]!.frame = CGRect(x: horizontalCenter - (cardWidth / 2),
                                                y: edgeSpace,
                                                width: cardWidth,
                                                height: cardHeight)            
            playerCardView[3]!.frame = CGRect(x: right - edgeSpace - cardWidth,
                                                y: verticalCenter - (cardHeight / 2),
                                                width: cardWidth,
                                                height: cardHeight)
        
        }
        
        // Card backs
        
        for playerNumber in 1...self.playerName.count {
            
            playerBackView[playerNumber - 1]!.frame = CGRect(x: playerCardView[playerNumber-1]!.frame.minX + 8,
                                                            y: playerCardView[playerNumber-1]!.frame.minY + 8,
                                                            width: playerCardView[playerNumber-1]!.frame.width - 16,
                                                            height: playerCardView[playerNumber-1]!.frame.height - 16)
            
        }
        
        // Name labels
        
        if self.playerName.count == 3 {
            
            playerNameLabel[0]!.frame = CGRect(x: 0,
                                               y: bottom - edgeSpace + nameSpace,
                                               width: minDimension,
                                               height: nameHeight)
            playerNameLabel[1]!.frame = CGRect(x: 0,
                                             y: edgeSpace - nameSpace - nameHeight,
                                             width: cardWidth + (edgeSpace*2),
                                             height: nameHeight)
            playerNameLabel[2]!.frame = CGRect(x: minDimension - cardWidth - (edgeSpace*2),
                                             y: edgeSpace - nameSpace - nameHeight,
                                             width: cardWidth + (edgeSpace*2),
                                             height: nameHeight)
            playerNameLabel[3]!.isHidden = true
            
        } else {
            
            playerNameLabel[0]!.frame = CGRect(x: 0,
                                               y: bottom - edgeSpace + nameSpace,
                                               width: minDimension,
                                               height: nameHeight)
            playerNameLabel[1]!.frame = CGRect(x: edgeSpace - nameSpace - nameHeight,
                                                 y: 0,
                                                 width: nameHeight,
                                                 height: minDimension)
            playerNameLabel[2]!.frame = CGRect(x: 0,
                                                 y: edgeSpace - nameSpace - nameHeight,
                                                 width: minDimension,
                                                 height: nameHeight)
            playerNameLabel[3]!.frame = CGRect(x: right - edgeSpace + nameSpace,
                                                 y: 0,
                                                 width: nameHeight,
                                                 height: minDimension)
        }
        
        for playerNumber in 1...self.playerName.count {
            
            // Name label fonts
            playerNameLabel[playerNumber - 1]!.font = UIFont.systemFont(ofSize: nameFontSize)
            
            // Card labels
            playerCardLabel[playerNumber - 1]!.frame = CGRect(x: cardLabelSpace,
                                              y: cardLabelSpace,
                                              width: cardWidth - (2*cardLabelSpace),
                                              height: cardHeight - (2*cardLabelSpace))
        
            // Card label font
            playerCardLabel[playerNumber - 1]!.font = UIFont.systemFont(ofSize: cardFontSize)
        }
        
        
        // Outcome label
        outcomeLabel.frame = CGRect(x: edgeSpace + cardWidth + outcomeSpace,
                                    y: edgeSpace + cardHeight + outcomeSpace,
                                    width: minDimension - (2 * (edgeSpace + cardWidth + outcomeSpace)),
                                    height: minDimension - (2 * (edgeSpace + cardHeight + outcomeSpace)))
        outcomeLabel.font = UIFont.systemFont(ofSize: outcomeFontSize)
    }
    
    private func executeCut(preCutCards: [Card]? = nil) {
        var cut: [Card]
        cut = self.cutCards(preCutCards: preCutCards)
        if self.scorecard.isHosting {
            self.scorecard.sendCut(cutCards: cut)
        }
        for playerNumber in 1...self.playerName.count {
            playerCardLabel[playerNumber-1]!.attributedText = cut[playerNumber-1].toAttributedString()
        }
    
        let outcome = NSMutableAttributedString()
        let outcomeTextColor = [NSAttributedString.Key.foregroundColor: UIColor.white]
        
        outcome.append(NSMutableAttributedString(string: self.playerName[self.scorecard.dealerIs - 1], attributes: outcomeTextColor))
        outcome.append(NSMutableAttributedString(string: " wins with ", attributes: outcomeTextColor))
        outcome.append(cut[scorecard.dealerIs-1].toAttributedString())
            
        outcomeLabel.attributedText = outcome
    }
    
    private func setupArrays() {
        playerCardView.append(player1CardView)
        playerCardView.append(player2CardView)
        playerCardView.append(player3CardView)
        playerCardView.append(player4CardView)
        playerBackView.append(player1BackView)
        playerBackView.append(player2BackView)
        playerBackView.append(player3BackView)
        playerBackView.append(player4BackView)
        playerCardLabel.append(player1CardLabel)
        playerCardLabel.append(player2CardLabel)
        playerCardLabel.append(player3CardLabel)
        playerCardLabel.append(player4CardLabel)
        playerNameLabel.append(player1NameLabel)
        playerNameLabel.append(player2NameLabel)
        playerNameLabel.append(player3NameLabel)
        playerNameLabel.append(player4NameLabel)
    }
    
    // MARK: - Utility Routines ======================================================================== -
    
    private func cutCards(preCutCards: [Card]?) -> [Card] {
        var cards: [Card] = []
        
        if preCutCards != nil {
            cards = preCutCards!
        } else {
            let deal = Pack.deal(numberCards: 1, numberPlayers: self.playerName.count)
            for playerLoop in 1...self.playerName.count {
                cards.append(deal.hands[playerLoop-1].cards[0])
            }
        }
        
        // Determine who won
        var dealerIs = 1
        for playerLoop in 1...self.playerName.count {
            if cards[playerLoop-1].toNumber() > cards[dealerIs-1].toNumber() {
                dealerIs = playerLoop
            }
        }
        
        // Save it
        self.scorecard.saveDealer(dealerIs)
        
        return cards
    }
    
    // MARK: - Function to present this view ==============================================================
    
    class func cutForDealer(viewController: UIViewController, view: UIView, cutDelegate: CutDelegate! = nil, popoverDelegate: UIPopoverPresentationControllerDelegate? = nil, preCutCards: [Card]? = nil, playerName: [String]? = nil) -> CutViewController {
        var playerName = playerName
        if playerName == nil {
            // Derive from current game
            playerName = []
            for playerNumber in 1...Scorecard.shared.currentPlayers {
                playerName!.append(Scorecard.shared.enteredPlayer(playerNumber).playerMO!.name!)
            }
        }
        let storyboard = UIStoryboard(name: "CutViewController", bundle: nil)
        let cutViewController = storyboard.instantiateViewController(withIdentifier: "CutViewController") as! CutViewController
        
        let preferredSize:CGFloat = 640.0
        if min(UIScreen.main.bounds.size.height,UIScreen.main.bounds.size.width) < preferredSize {
            cutViewController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        } else {
            cutViewController.modalPresentationStyle = UIModalPresentationStyle.popover
            cutViewController.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            cutViewController.popoverPresentationController?.sourceView = view as UIView
            cutViewController.preferredContentSize = CGSize(width: preferredSize, height: preferredSize)
        }
        
        cutViewController.preCutCards = preCutCards
        cutViewController.playerName = playerName
        cutViewController.delegate = cutDelegate
        cutViewController.popoverPresentationController?.delegate = popoverDelegate
        
        viewController.present(cutViewController, animated: true, completion: nil)
        return cutViewController
    }
}
