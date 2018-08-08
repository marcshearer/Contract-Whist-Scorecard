//
//  ReviewViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 06/08/2018.
//  Copyright © 2018 Marc Shearer. All rights reserved.
//

import UIKit

class ReviewViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

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
    private let splitSuit = 6
    private var fontSize: CGFloat = 17.0
    
    @IBOutlet private weak var dummyLabel: UILabel!
    @IBOutlet private weak var finishButton: UIButton!
    @IBOutlet private weak var hand1TableView: UITableView!
    @IBOutlet private weak var hand2TableView: UITableView!
    @IBOutlet private weak var hand3TableView: UITableView!
    @IBOutlet private weak var hand4TableView: UITableView!
    @IBOutlet private weak var tableTopView: UIView!
    
    @IBAction func finishPressed(_ sender: UIButton) {
        self.performSegue(withIdentifier: "hideReview", sender: self)
    }
   
    @IBAction func tapGesture(recognizer:UITapGestureRecognizer) {
        self.finishPressed(self.finishButton)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        for handNumber in 1...self.scorecard.numberPlayers {
            maxContentSize.append(0.0)
            height.append(0)
            width.append(0)
        }
        
        self.setupPlayers()
        self.setupOutlets()
        self.setupText()
        
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        scorecard.reCenterPopup(self)
        view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.setupWidth(totalWidth: self.view.frame.width)
        self.setupHeight(totalHeight: self.view.frame.height)
        self.setupPosition(totalHeight: self.view.frame.height, totalWidth: self.view.frame.width)
        for tableView in self.tableView {
            tableView.reloadData()
        }
        self.view.setNeedsLayout()
    }
    
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
    
    private func setupPlayers() {
        
        tableViewPlayer[3] = thisPlayer
        
        for increment in 1..<self.scorecard.currentPlayers {
            let playerNumber = ((thisPlayer + increment - 1) % self.scorecard.currentPlayers) + 1
            let tag = ((3 + increment - 1) % self.scorecard.currentPlayers) + 1
            tableViewPlayer[tag] = playerNumber
        }
    }
    
    private func setupText() {
        
        self.text = []
        for handNumber in 1...self.scorecard.currentPlayers {
            self.text.append([])
            let player = self.scorecard.enteredPlayer(playerNumber: handNumber)
            self.text[handNumber-1].append("\(player.playerMO!.name!) \(player.bid(self.round)!)/\(player.made(self.round)!)")
            if let hand: Hand = self.scorecard.dealHistory[self.round]?.hands[player.playerNumber - 1] {
                for handSuit in hand.handSuits {
                    var suitText = handSuit.cards.first!.suit.toString()
                    for cardNumber in 0..<min(splitSuit,handSuit.cards.count) {
                        suitText = suitText + " " + handSuit.cards[cardNumber].toRankString()
                    }
                    self.text[handNumber-1].append(suitText)
                    if handSuit.cards.count > self.splitSuit {
                        var suitText = "  "
                        for cardNumber in self.splitSuit..<handSuit.cards.count {
                            suitText = suitText + "  " + handSuit.cards[cardNumber].toRankString()
                        }
                        self.text[handNumber-1].append(suitText)
                    }
                }
            }
        }
    }
    
    private func setupHeight(totalHeight: CGFloat) {
        let totalRows = self.text[0].count + self.text[2].count
        let useableHeight = totalHeight - 30
        rowHeight = min(30, useableHeight/CGFloat(totalRows))
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
    
    private func setupPosition(totalHeight: CGFloat, totalWidth: CGFloat) {
        let maxHeight = self.height.max()!
        let maxWidth = self.width.max()!
        var tableTopHeight = totalHeight - (2.0 * maxHeight) - 10.0
        var tableTopWidth = totalWidth - (2.0 * maxWidth) - 10.0
        var innerTableTopSize = min(tableTopHeight, tableTopWidth)
        if innerTableTopSize >= maxHeight && innerTableTopSize > maxWidth  {
            // Can fit all hands around this - no need to adjust
            tableTopHeight = innerTableTopSize
            tableTopWidth = innerTableTopSize
            innerTableTopSize -= 80
        } else if totalHeight > totalWidth {
            // Portrait - Move hands 1 and 3 away from centre to allow hands 2 and 4 to fit
            tableTopHeight = maxHeight + (totalHeight * 0.2)
            tableTopWidth = innerTableTopSize
            innerTableTopSize -= 20
        } else {
            // Landscape - Move hands 2 and 4 away from centre to allow hands 1 and 3 to fit
            tableTopHeight = innerTableTopSize
            tableTopWidth = maxWidth + (totalWidth * 0.2)
            innerTableTopSize -= 20
        }
        
        // Setup displayed table top
        if innerTableTopSize <= 50.0 {
            tableTopView.isHidden = true
        } else {
            tableTopView.isHidden = false
            self.tableTopView.frame = CGRect(x: (totalWidth - innerTableTopSize) / 2.0, y: (totalHeight - innerTableTopSize) / 2.0, width: innerTableTopSize, height: innerTableTopSize)
        }
        
        // Setup hand 1
        self.hand1TableView.frame = CGRect(x: (totalWidth - width[0]) / 2.0, y: ((totalHeight - tableTopHeight) / 2.0) - height[0], width: width[0], height: height[0])
        
        // Setup hand 2
        self.hand2TableView.frame = CGRect(x: (totalWidth + tableTopWidth) / 2.0, y: (totalHeight - height[1]) / 2.0, width: width[1], height: height[1])
        
        // Setup hand 3
        self.hand3TableView.frame = CGRect(x: (totalWidth - width[2]) / 2.0, y: ((totalHeight + tableTopHeight) / 2.0), width: width[2], height: height[2])
        
        // Setup hand 4
        self.hand4TableView.frame = CGRect(x: ((totalWidth - tableTopWidth) / 2.0) - width[3], y: (totalHeight - height[3]) / 2.0, width: width[3], height: height[3])
        
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
