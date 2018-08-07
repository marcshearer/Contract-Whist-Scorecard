//
//  ReviewViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 06/08/2018.
//  Copyright © 2018 Marc Shearer. All rights reserved.
//

import UIKit

class ReviewViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    public var scorecard: Scorecard!
    public var round: Int!
    private var maxContentSize: [CGFloat] = []
    private var tagXref: [Int : Int] = [:]
    private var tableView: [UITableView] = []
    private var tableViewWidth: [NSLayoutConstraint] = []
    private var tableViewHeight: [NSLayoutConstraint] = []
    private var text: [[String]]!
    private var rowHeight: CGFloat!
    private let splitSuit = 6
    
    @IBOutlet private weak var dummyLabel: UILabel!
    @IBOutlet private weak var finishButton: UIButton!
    @IBOutlet private weak var hand1TableView: UITableView!
    @IBOutlet private weak var hand2TableView: UITableView!
    @IBOutlet private weak var hand3TableView: UITableView!
    @IBOutlet private weak var hand4TableView: UITableView!
    @IBOutlet private weak var hand1Width: NSLayoutConstraint!
    @IBOutlet private weak var hand2Width: NSLayoutConstraint!
    @IBOutlet private weak var hand3Width: NSLayoutConstraint!
    @IBOutlet private weak var hand4Width: NSLayoutConstraint!
    @IBOutlet private weak var hand1Height: NSLayoutConstraint!
    @IBOutlet private weak var hand2Height: NSLayoutConstraint!
    @IBOutlet private weak var hand3Height: NSLayoutConstraint!
    @IBOutlet private weak var hand4Height: NSLayoutConstraint!
    
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
            tagXref[handNumber] = handNumber
        }
        
        if self.scorecard.currentPlayers < 4 {
            hand3TableView.isHidden = true
            tagXref[4] = 3
            tagXref[3] = nil
        }
        
        self.setupOutlets()
        self.setupText()
        self.setupWidth()
        self.setupHeight(totalHeight: self.view.frame.height)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        scorecard.reCenterPopup(self)
        self.setupHeight(totalHeight: size.height)
        view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        for tableView in self.tableView {
            tableView.reloadData()
        }
        self.view.setNeedsLayout()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let handNumber = tagXref[tableView.tag] {
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
        if let handNumber = tagXref[tableView.tag] {
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
    
    private func setupText() {
        
        self.text = []
        for handNumber in 1...self.scorecard.currentPlayers {
            self.text.append([])
            let player = self.scorecard.roundPlayer(playerNumber: handNumber, round: self.round)
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
        for (index, tableViewHeight) in self.tableViewHeight.enumerated() {
            tableViewHeight.constant = CGFloat(self.text[index].count) * rowHeight
        }
    }
    
    private func setupWidth() {
        
        
        for tag in 1...self.scorecard.currentPlayers {
            if let handNumber = tagXref[tag] {
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
                tableViewWidth[tag-1].constant = width
            }
        }
        dummyLabel.isHidden = true
    }
    
    func setupOutlets() {
        
        self.tableView.append(self.hand1TableView)
        self.tableView.append(self.hand2TableView)
        self.tableView.append(self.hand3TableView)
        self.tableView.append(self.hand4TableView)
        
        self.tableViewWidth.append(self.hand1Width)
        self.tableViewWidth.append(self.hand2Width)
        self.tableViewWidth.append(self.hand3Width)
        self.tableViewWidth.append(self.hand4Width)
        
        self.tableViewHeight.append(self.hand1Height)
        self.tableViewHeight.append(self.hand2Height)
        self.tableViewHeight.append(self.hand3Height)
        self.tableViewHeight.append(self.hand4Height)
    }
}

class ReviewTableViewCell: UITableViewCell {
    
    @IBOutlet public weak var label: UILabel!

}
