//
//  ReviewViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 06/08/2018.
//  Copyright © 2018 Marc Shearer. All rights reserved.
//

import UIKit

class ReviewViewController: CustomViewController, UITableViewDataSource, UITableViewDelegate, ScorecardAlertDelegate {

    // Properties passed
    private let scorecard = Scorecard.shared
    public var round: Int!
    public var thisPlayer: Int!
    
    // Other properties
    private var maxContentSize: [CGFloat] = []
    private var tableViewPlayer: [Int : Int] = [:]
    private var tableView: [UITableView] = []
    private var width: [CGFloat] = []
    private var height: [CGFloat] = []
    private var text: [[NSMutableAttributedString]]!
    private var rowHeight: CGFloat!
    private var titleHeight: CGFloat!
    private let splitSuit = 6
    private var fontSize: CGFloat = 17.0
    
    @IBOutlet private weak var dummyLabel: UILabel!
    @IBOutlet private weak var finishButton: UIButton!
    @IBOutlet private weak var hand1TableView: UITableView!
    @IBOutlet private weak var hand2TableView: UITableView!
    @IBOutlet private weak var hand3TableView: UITableView!
    @IBOutlet private weak var hand4TableView: UITableView!
    @IBOutlet private weak var tableTopView: UIView!
    @IBOutlet private weak var tableTopTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var tableTopLeadingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var tableTopWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var tableTopHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var roundTitleLabel: UILabel!
    @IBOutlet private weak var overUnderLabel: UILabel!
    @IBOutlet private weak var titleView: UIView!
    @IBOutlet private weak var titleViewHeight: NSLayoutConstraint!
    
    @IBAction func finishPressed(_ sender: UIButton) {
        self.dismiss()
    }
   
    @IBAction func tapGesture(recognizer:UITapGestureRecognizer) {
        self.finishPressed(self.finishButton)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        for _ in 1...self.scorecard.numberPlayers {
            maxContentSize.append(0.0)
            height.append(0)
            width.append(0)
        }
        
        self.setupPlayers()
        self.setupOutlets()
        self.setupTitle()
        self.setupText()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.scorecard.alertDelegate = self
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        scorecard.reCenterPopup(self)
        view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.setupWidth(totalWidth: self.view.safeAreaLayoutGuide.layoutFrame.width)
        self.setupHeight(totalHeight: self.view.safeAreaLayoutGuide.layoutFrame.height)
        self.setupPosition(frame: self.view.safeAreaLayoutGuide.layoutFrame)
        for tableView in self.tableView {
            tableView.reloadData()
        }
        self.view.setNeedsLayout()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.scorecard.alertDelegate = nil
    }
    
    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        self.scorecard.motionBegan(motion, with: event)
    }
    
    // MARK: - TableView Overrides ===================================================================== -
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let handNumber = tableViewPlayer[tableView.tag] {
            return self.text[handNumber-1].count
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.rowHeight
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Hand Cell \(tableView.tag)", for: indexPath) as! ReviewTableViewCell
        if let handNumber = tableViewPlayer[tableView.tag] {
            if indexPath.row == 0 {
                cell.label.font = UIFont.boldSystemFont(ofSize: 17.0)
                cell.label.textColor = UIColor.black
            } else {
                cell.label.font = UIFont.systemFont(ofSize: 17.0)
                cell.label.textColor = Palette.text
            }
            cell.label.attributedText = self.text[handNumber-1][indexPath.row]
        }
        
        return cell
    }
    
   func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.separatorInset = UIEdgeInsets.zero
        cell.preservesSuperviewLayoutMargins = false
        cell.layoutMargins = UIEdgeInsets.zero
    }
    
    // MARK: - Alert delegate handlers =================================================== -
    
    internal func alertUser(reminder: Bool) {
        self.finishButton.alertFlash(duration: 0.3, repeatCount: 3)
    }
    
    // MARK: - Utility Routines ======================================================================== -
    
    private func setupPlayers() {
        
        for increment in 0..<self.scorecard.currentPlayers {
            let playerNumber = ((thisPlayer + increment - 1) % self.scorecard.currentPlayers) + 1
            var tag: Int
            if self.scorecard.currentPlayers < 4 {
                tag = ((2 + increment - 1) % self.scorecard.currentPlayers) + 2
            } else {
                tag = ((3 + increment - 1) % self.scorecard.currentPlayers) + 1
            }
            tableViewPlayer[tag] = playerNumber
        }
    }
    
    private func setupTitle() {
        self.roundTitleLabel.textColor = UIColor.white
        self.roundTitleLabel.attributedText = scorecard.roundTitle(round, rankColor: Palette.roomInteriorText)
        let totalRemaining = self.scorecard.remaining(playerNumber: 0, round: self.round, mode: Mode.bid, rounds: self.scorecard.rounds, cards: self.scorecard.handState.cards, bounce: self.scorecard.handState.bounce)
        self.overUnderLabel.text = "\(abs(Int64(totalRemaining))) \(totalRemaining >= 0 ? "under" : "over")"
        self.overUnderLabel.textColor = (totalRemaining == 0 ? Palette.contractEqual : (totalRemaining > 0 ? Palette.contractUnder : Palette.contractOver))
    }
    
    private func setupText() {
        
        self.text = []
        for playerNumber in 1...self.scorecard.currentPlayers {
            self.text.append([])
            let player = self.scorecard.enteredPlayer(playerNumber)
            self.text[playerNumber-1].append(NSMutableAttributedString(string: "\(player.playerMO!.name!) \(player.bid(self.round)!)/\(player.made(self.round)!)"))
            if let hand: Hand = self.scorecard.dealHistory[self.round]?.hands[player.playerNumber - 1] {
                for rawSuit in (1...4).reversed() {
                    let suit = Suit(rawValue: rawSuit)
                    var suitText: NSMutableAttributedString = NSMutableAttributedString(attributedString: suit.toAttributedString())
                    if let handSuit = hand.xrefSuit[suit] {
                        for cardNumber in 0..<min(splitSuit,handSuit.cards.count) {
                            suitText.append(NSAttributedString(string: " " + handSuit.cards[cardNumber].toRankString()))
                        }
                        self.text[playerNumber-1].append(suitText)
                        if handSuit.cards.count > self.splitSuit {
                            suitText = NSMutableAttributedString(string: "  ")
                            for cardNumber in self.splitSuit..<handSuit.cards.count {
                                suitText.append(NSMutableAttributedString(string: handSuit.cards[cardNumber].toRankString()))
                            }
                            self.text[playerNumber-1].append(suitText)
                        }
                    } else {
                        suitText.append(NSMutableAttributedString(string: " -"))
                        self.text[playerNumber-1].append(suitText)
                    }
                }
            }
        }
    }
    
    private func setupHeight(totalHeight: CGFloat) {
        if totalHeight <= 320.0 {
            self.titleHeight = 0.0
            self.roundTitleLabel.isHidden = true
            self.overUnderLabel.isHidden = true
            self.titleView.backgroundColor = UIColor.clear
        } else {
            self.titleHeight = (ScorecardUI.landscapePhone() ? 35.0 : 44.0)
            self.roundTitleLabel.isHidden = false
            self.overUnderLabel.isHidden = false
            self.titleView.backgroundColor = Palette.roomInterior
        }
        self.titleViewHeight.constant = self.titleHeight
        let useableHeight = totalHeight - 30.0 - titleHeight
        let totalRows = self.text[0].count + self.text[2].count
        rowHeight = min(30.0, useableHeight/CGFloat(totalRows))
        for (tableView, handNumber) in tableViewPlayer {
            let height = CGFloat(self.text[handNumber-1].count) * rowHeight
            self.height[tableView-1] = height
        }
    }
    
    private func setupWidth(totalWidth: CGFloat) {
        if totalWidth < 320.0 {
            fontSize = 17.0
        } else {
            fontSize = 20.0
        }
        for (tableView, handNumber) in tableViewPlayer {
            var width: CGFloat = 0.0
            for row in 0..<text[handNumber-1].count {
                if row == 0 {
                    self.dummyLabel.font = UIFont.boldSystemFont(ofSize: 17.0)
                } else {
                    self.dummyLabel.font = UIFont.systemFont(ofSize: 17.0)
                }
                self.dummyLabel.attributedText = self.text[handNumber-1][row]
                width = max(width, self.dummyLabel.intrinsicContentSize.width)
            }
            self.width[tableView-1] = width
        }
        dummyLabel.isHidden = true
    }
    
    private func setupPosition(frame: CGRect) {
        var tableTopSpacing: CGFloat = 0.0
        let totalHeight = frame.height
        let totalWidth = frame.width
        let useableHeight = totalHeight - self.titleHeight
        let maxHeight = self.height.max()!
        let maxWidth = self.width.max()!
        var tableTopHeight = useableHeight - (2.0 * maxHeight) - 10.0
        var tableTopWidth = totalWidth - (2.0 * maxWidth) - 10.0
        var innerTableTopSize = min(tableTopHeight, tableTopWidth)
        var offset: CGFloat = titleHeight
        if innerTableTopSize >= maxHeight && innerTableTopSize > maxWidth  {
            // Can fit all hands around this - no need to adjust
            tableTopHeight = innerTableTopSize
            tableTopWidth = innerTableTopSize
        } else if totalHeight > totalWidth {
            // Portrait - Move hands 1 and 3 away from centre to allow hands 2 and 4 to fit
            tableTopHeight = maxHeight + (useableHeight * 0.1)
            tableTopWidth = innerTableTopSize
        } else {
            // Landscape - Move hands 2 and 4 away from centre to allow hands 1 and 3 to fit
            tableTopHeight = innerTableTopSize
            tableTopWidth = maxWidth + (totalWidth * 0.2)
        }
        if self.scorecard.currentPlayers < 4 {
            offset = -useableHeight / 8.0
        }
        
        // Setup displayed table top
        let maxSideHeight = max(height[1], height[3])
        let maxMiddleWidth = max(width[0], width[2])
        if innerTableTopSize <= 130.0 {
            // Table top too small - forget it
            tableTopView.isHidden = true
        } else if innerTableTopSize >= maxHeight && innerTableTopSize > maxWidth {
            // Table top fits sized to height and width
            tableTopView.isHidden = false
            let height = maxSideHeight - self.rowHeight - 15.0
            tableTopWidth = min(height, maxWidth)
            let minX = frame.midX - (tableTopWidth / 2.0)
            let minY = ((useableHeight - height) / 2.0) + 3.0
            self.tableTopLeadingConstraint.constant = frame.minX + minX
            self.tableTopTopConstraint.constant = minY + offset - self.titleHeight
            self.tableTopWidthConstraint.constant = tableTopWidth
            self.tableTopHeightConstraint.constant = height
            tableTopSpacing = 20.0
        } else {
            // Table top doesn't fit but is credibly sized
            tableTopView.isHidden = false
            innerTableTopSize -= 80.0
            self.tableTopLeadingConstraint.constant = frame.minX + (totalWidth - innerTableTopSize) / 2.0
            self.tableTopTopConstraint.constant = frame.minY + offset - self.titleHeight + (useableHeight - innerTableTopSize) / 2.0
            self.tableTopWidthConstraint.constant = innerTableTopSize
            self.tableTopHeightConstraint.constant = innerTableTopSize
        }
        
        // Setup top hand
        self.hand1TableView.frame = CGRect(x: frame.minX + (totalWidth - maxMiddleWidth) / 2.0, y: frame.minY + offset + ((useableHeight - tableTopHeight) / 2.0) - height[0], width: width[0], height: height[0])
        
        // Setup right hand
        self.hand2TableView.frame = CGRect(x: ((totalWidth + tableTopWidth) / 2.0) + tableTopSpacing, y: frame.minY + offset + ((useableHeight - maxSideHeight) / 2.0), width: width[1], height: height[1])
        
        // Setup bottom hand
        self.hand3TableView.frame = CGRect(x: frame.minX + (totalWidth - maxMiddleWidth) / 2.0, y: frame.minY + offset + ((useableHeight + tableTopHeight) / 2.0), width: width[2], height: height[2])
        
        // Setup left hand
        self.hand4TableView.frame = CGRect(x: frame.minX + ((totalWidth - tableTopWidth) / 2.0) - width[3] - tableTopSpacing, y: frame.minY + offset + ((useableHeight - maxSideHeight) / 2.0), width: width[3], height: height[3])
        
    }
    
    func setupOutlets() {
        
        self.tableView.append(self.hand1TableView)
        self.tableView.append(self.hand2TableView)
        self.tableView.append(self.hand3TableView)
        self.tableView.append(self.hand4TableView)
        
    }
    
    // MARK: - Function to present and dismiss this view ==============================================================
    
    class public func show(from viewController: CustomViewController, round: Int, thisPlayer: Int) {
        
        let storyboard = UIStoryboard(name: "ReviewViewController", bundle: nil)
        let reviewViewController = storyboard.instantiateViewController(withIdentifier: "ReviewViewController") as! ReviewViewController
        
        reviewViewController.preferredContentSize = CGSize(width: 400, height: Scorecard.shared.scorepadBodyHeight)
        
        reviewViewController.round = round
        reviewViewController.thisPlayer = thisPlayer
        
        viewController.present(reviewViewController, sourceView: viewController.popoverPresentationController?.sourceView ?? viewController.view, animated: true, completion: nil)
        
    }
    
    private func dismiss(linkToGameSummary: Bool = false) {
        self.dismiss(animated: true, completion: nil)
    }
}

class ReviewTableViewCell: UITableViewCell {
    
    @IBOutlet public weak var label: UILabel!

}
