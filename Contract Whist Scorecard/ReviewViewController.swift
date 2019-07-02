//
//  ReviewViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 06/08/2018.
//  Copyright © 2018 Marc Shearer. All rights reserved.
//

import UIKit

class ReviewViewController: CustomViewController, UITableViewDataSource, UITableViewDelegate {

    // Properties passed to/from segues
    public var scorecard: Scorecard!
    public var round: Int!
    public var thisPlayer: Int!
    
    // Other properties
    private var maxContentSize: [CGFloat] = []
    private var tableViewPlayer: [Int : Int] = [:]
    private var tableView: [UITableView] = []
    private var width: [CGFloat] = []
    private var height: [CGFloat] = []
    private var text: [[String]]!
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
    @IBOutlet private weak var roundTitleLabel: UILabel!
    @IBOutlet private weak var overUnderLabel: UILabel!
    @IBOutlet private weak var titleView: UIView!
    @IBOutlet private weak var titleViewHeight: NSLayoutConstraint!
    
    @IBAction func finishPressed(_ sender: UIButton) {
        self.performSegue(withIdentifier: "hideReview", sender: self)
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
        return rowHeight
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Hand Cell \(tableView.tag)", for: indexPath) as! ReviewTableViewCell
        if let handNumber = tableViewPlayer[tableView.tag] {
            if indexPath.row == 0 {
                cell.label.font = UIFont.boldSystemFont(ofSize: 17.0)
                cell.label.textColor = UIColor.black
            } else {
                cell.label.font = UIFont.systemFont(ofSize: 17.0)
                cell.label.textColor = UIColor.white
            }
            cell.label.text = self.text[handNumber-1][indexPath.row]
        }
        
        return cell
    }
    
   func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.separatorInset = UIEdgeInsets.zero
        cell.preservesSuperviewLayoutMargins = false
        cell.layoutMargins = UIEdgeInsets.zero
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
        self.roundTitleLabel.attributedText = scorecard.roundTitle(round, rankColor: UIColor.white)
        let totalRemaining = self.scorecard.remaining(playerNumber: 0, round: self.round, mode: Mode.bid, rounds: self.scorecard.rounds, cards: self.scorecard.handState.cards, bounce: self.scorecard.handState.bounce)
        self.overUnderLabel.text = "\(abs(Int64(totalRemaining))) \(totalRemaining >= 0 ? "under" : "over")"
        self.overUnderLabel.textColor = (totalRemaining == 0 ? ScorecardUI.contractEqualColor : (totalRemaining > 0 ? ScorecardUI.contractUnderColor : ScorecardUI.contractOverColor))
    }
    
    private func setupText() {
        
        self.text = []
        for playerNumber in 1...self.scorecard.currentPlayers {
            self.text.append([])
            let player = self.scorecard.enteredPlayer(playerNumber)
            self.text[playerNumber-1].append("\(player.playerMO!.name!) \(player.bid(self.round)!)/\(player.made(self.round)!)")
            if let hand: Hand = self.scorecard.dealHistory[self.round]?.hands[player.playerNumber - 1] {
                for handSuit in hand.handSuits {
                    var suitText = handSuit.cards.first!.suit.toString()
                    for cardNumber in 0..<min(splitSuit,handSuit.cards.count) {
                        suitText = suitText + " " + handSuit.cards[cardNumber].toRankString()
                    }
                    self.text[playerNumber-1].append(suitText)
                    if handSuit.cards.count > self.splitSuit {
                        var suitText = "  "
                        for cardNumber in self.splitSuit..<handSuit.cards.count {
                            suitText = suitText + "  " + handSuit.cards[cardNumber].toRankString()
                        }
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
            self.titleView.backgroundColor = UIColor.darkGray
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
                self.dummyLabel.text = self.text[handNumber-1][row]
                width = max(width, self.dummyLabel.intrinsicContentSize.width)
            }
            self.width[tableView-1] = width
        }
        dummyLabel.isHidden = true
    }
    
    private func setupPosition(frame: CGRect) {
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
            innerTableTopSize -= 80
        } else if totalHeight > totalWidth {
            // Portrait - Move hands 1 and 3 away from centre to allow hands 2 and 4 to fit
            tableTopHeight = maxHeight + (useableHeight * 0.1)
            tableTopWidth = innerTableTopSize
            innerTableTopSize -= 20
        } else {
            // Landscape - Move hands 2 and 4 away from centre to allow hands 1 and 3 to fit
            tableTopHeight = innerTableTopSize
            tableTopWidth = maxWidth + (totalWidth * 0.2)
            innerTableTopSize -= 20
        }
        if self.scorecard.currentPlayers < 4 {
            offset = -useableHeight / 8.0
        }
        
        // Setup displayed table top
        if innerTableTopSize <= 50.0 {
            tableTopView.isHidden = true
        } else {
            tableTopView.isHidden = false
            self.tableTopView.frame = CGRect(x: frame.minX + (totalWidth - innerTableTopSize) / 2.0, y: frame.minY + offset + (useableHeight - innerTableTopSize) / 2.0, width: innerTableTopSize, height: innerTableTopSize)
        }
        
        // Setup hand 1
        self.hand1TableView.frame = CGRect(x: frame.minX + (totalWidth - width[0]) / 2.0, y: frame.minY + offset + ((useableHeight - tableTopHeight) / 2.0) - height[0], width: width[0], height: height[0])
        
        // Setup hand 2
        self.hand2TableView.frame = CGRect(x: (totalWidth + tableTopWidth) / 2.0, y: frame.minY + offset + ((useableHeight - height[1]) / 2.0), width: width[1], height: height[1])
        
        // Setup hand 3
        self.hand3TableView.frame = CGRect(x: frame.minX + (totalWidth - width[2]) / 2.0, y: frame.minY + offset + ((useableHeight + tableTopHeight) / 2.0), width: width[2], height: height[2])
        
        // Setup hand 4
        self.hand4TableView.frame = CGRect(x: frame.minX + ((totalWidth - tableTopWidth) / 2.0) - width[3], y: frame.minY + offset + ((useableHeight - height[3]) / 2.0), width: width[3], height: height[3])
        
    }
    
    func setupOutlets() {
        
        self.tableView.append(self.hand1TableView)
        self.tableView.append(self.hand2TableView)
        self.tableView.append(self.hand3TableView)
        self.tableView.append(self.hand4TableView)
        
    }
}

class ReviewTableViewCell: UITableViewCell {
    
    @IBOutlet public weak var label: UILabel!

}
