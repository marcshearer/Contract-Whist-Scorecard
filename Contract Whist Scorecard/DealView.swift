//
//  DealView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 15/09/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class DealView : UIView, UITableViewDataSource, UITableViewDelegate {
    
    struct Content {
        let suit: Suit?
        let text: String
        
        init(suit: Suit? = nil, text: String) {
            self.suit = suit
            self.text = text
        }
    }
    
    // Properties passed
    private var round: Int!
    private var thisPlayer: Int!
    private var color: PaletteColor!
    
    // Other properties
    private var maxContentSize: [CGFloat] = []
    private var tableViewPlayer: [Int : Int] = [:]
    private var width: [CGFloat] = []
    private var height: [CGFloat] = []
    private var content: [Int : [Content]]!
    private var rowHeight: CGFloat!
    private let splitSuit = 6
    private var fontSize: CGFloat = 17.0
    private let suitWidth: CGFloat = 22.0
    private let titleExtra: CGFloat = 4.0
    
    // MARK: - IB Outlets ============================================================================== -
    
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private var tableView: [UITableView] = []
    @IBOutlet private weak var tableTopView: UIView!
    
    // MARK: - Constructors ============================================================================== -
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.loadDealView()
        self.frame = frame
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.loadDealView()
    }
    
    // MARK: - Show deal routine ======================================================================= -
    
    public func show(round: Int, thisPlayer: Int, color: PaletteColor = Palette.normal) {
        self.round = round
        self.thisPlayer = thisPlayer
        self.color = color
        
        self.setupPlayers()
        self.setupText()
        
        self.layoutSubviews()
    }
    
    
    // MARK: - View Overrides ========================================================================== -
    
    internal override func awakeFromNib() {
        super.awakeFromNib()
        
        // Setup default colors
        self.defaultViewColors()
        
        for _ in 1...Scorecard.shared.maxPlayers {
            maxContentSize.append(0.0)
            height.append(0)
            width.append(0)
        }
    }
    
    internal override func layoutSubviews() {
        super.layoutSubviews()
        if round != nil {
            self.setupWidth(totalWidth: self.frame.width)
            self.setupHeight(totalHeight: self.frame.height)
            self.setupPosition(frame: CGRect(origin: CGPoint(), size: self.frame.size))
            self.tableView.forEach { (tableView) in
                tableView.reloadData()
            }
        }
    }
    
    // MARK: - Load view  ============================================================================== -
    
    private func loadDealView() {
        Bundle.main.loadNibNamed("DealView", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Register table view cell
        let nib = UINib(nibName: "DealViewCell", bundle: nil)
        self.tableView.forEach { (tableView) in
            tableView.register(nib, forCellReuseIdentifier: "Table Cell")
        }
    }
    
    // MARK: - TableView Overrides ===================================================================== -
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let handNumber = tableViewPlayer[tableView.tag] {
            return self.content[handNumber]!.count
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.rowHeight + (indexPath.row == 0 ? self.titleExtra : 0)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Table Cell", for: indexPath) as! DealViewCell
        
        if let handNumber = tableViewPlayer[tableView.tag] {
            if indexPath.row == 0 {
                cell.suitWidthConstraint.constant = 0
                cell.label.textColor = color.strongText
                cell.label.font = UIFont.boldSystemFont(ofSize: self.fontSize)
            } else {
                cell.suitWidthConstraint.constant = self.suitWidth
                cell.label.textColor = color.text
                cell.label.font = UIFont.systemFont(ofSize: self.fontSize)
                cell.suitLabel.attributedText = self.content[handNumber]![indexPath.row].suit?.toAttributedString()
            }
            cell.label.text = self.content[handNumber]![indexPath.row].text
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
        
        for increment in 0..<Scorecard.game.currentPlayers {
            let playerNumber = ((thisPlayer + increment - 1) % Scorecard.game.currentPlayers) + 1
            var tag: Int
            if Scorecard.game.currentPlayers < 4 {
                tag = ((2 + increment - 1) % Scorecard.game.currentPlayers) + 2
            } else {
                tag = ((3 + increment - 1) % Scorecard.game.currentPlayers) + 1
            }
            tableViewPlayer[tag] = playerNumber
        }
    }
    
    private func setupText() {
        
        self.content = [:]
        for playerNumber in 1...Scorecard.game.currentPlayers {
            self.content[playerNumber] = []
            let player = Scorecard.game.player(enteredPlayerNumber: playerNumber)
            let playerScore = Scorecard.game.scores.get(round: self.round, playerNumber: playerNumber, sequence: .entered)
            
            // Add player name
            self.content[playerNumber]!.append(Content(text: "\(player.playerMO!.name!) \(playerScore.bid!)/\(playerScore.made!)"))
            
            if let hand: Hand = Scorecard.game?.dealHistory[self.round]?.hands[player.playerNumber - 1] {
                for rawSuit in (1...4).reversed() {
                    let suit = Suit(rawValue: rawSuit)
                    var suitText = ""
                    if let handSuit = hand.xrefSuit[suit] {
                        for cardNumber in 0..<min(splitSuit,handSuit.cards.count) {
                            if cardNumber != 0 {
                                suitText.append(" ")
                            }
                            suitText.append(handSuit.cards[cardNumber].toRankString())
                        }
                        self.content[playerNumber]!.append(Content(suit: suit, text: suitText))
                        if handSuit.cards.count > self.splitSuit {
                            suitText = ""
                            for cardNumber in self.splitSuit..<handSuit.cards.count {
                                if cardNumber != self.splitSuit {
                                    suitText.append(" ")
                                }
                                suitText.append(handSuit.cards[cardNumber].toRankString())
                            }
                            self.content[playerNumber]!.append(Content(text: suitText))
                        }
                    } else {
                        self.content[playerNumber]!.append(Content(suit: suit, text: "-"))
                    }
                }
            }
        }
    }
    
    private func setupHeight(totalHeight: CGFloat) {
        let totalRows = self.content[1]!.count + self.content[3]!.count
        rowHeight = min(20.0, (totalHeight - self.titleExtra)/CGFloat(totalRows))
        for (tableView, handNumber) in tableViewPlayer {
            let height = (CGFloat(self.content[handNumber]!.count) * rowHeight) + self.titleExtra
            self.height[tableView-1] = height
        }
    }
    
    private func setupWidth(totalWidth: CGFloat) {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 50, height: CGFloat.greatestFiniteMagnitude))
        fontSize = CGFloat(Int(totalWidth / 20.0))
        for (tableView, handNumber) in tableViewPlayer {
            var width: CGFloat = 0.0
            for row in 0..<content[handNumber]!.count {
                if row == 0 {
                    label.font = UIFont.boldSystemFont(ofSize: fontSize)
                } else {
                    label.font = UIFont.systemFont(ofSize: fontSize)
                }
                label.text = self.content[handNumber]![row].text
                width = max(width, label.intrinsicContentSize.width + self.suitWidth)
            }
            self.width[tableView-1] = width
        }
    }
    
    private func setupPosition(frame: CGRect) {
        var tableTopSpacing: CGFloat = 0.0
        let totalHeight = frame.height
        let totalWidth = frame.width
        let maxHeight = self.height.max()!
        let maxWidth = self.width.max()!
        var tableTopHeight = totalHeight - (2.0 * maxHeight) - 10.0
        var tableTopWidth = totalWidth - (2.0 * maxWidth) - 10.0
        var innerTableTopSize = min(tableTopHeight, tableTopWidth)
        var offset: CGFloat = 0
        if innerTableTopSize >= maxHeight && innerTableTopSize > maxWidth  {
            // Can fit all hands around this - no need to adjust
            tableTopHeight = innerTableTopSize
            tableTopWidth = innerTableTopSize
        } else if totalHeight > totalWidth {
            // Portrait - Move hands 1 and 3 away from centre to allow hands 2 and 4 to fit
            tableTopHeight = maxHeight + (totalHeight * 0.1)
            tableTopWidth = innerTableTopSize
        } else {
            // Landscape - Move hands 2 and 4 away from centre to allow hands 1 and 3 to fit
            tableTopHeight = innerTableTopSize
            tableTopWidth = maxWidth + (totalWidth * 0.2)
        }
        if Scorecard.game.currentPlayers < 4 {
            offset = -totalHeight / 8.0
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
            let minY = ((totalHeight - height) / 2.0) + 3.0
            self.tableTopView.frame = CGRect(x: frame.minX + minX,
                                             y: minY + offset,
                                             width: tableTopWidth,
                                             height: height)
            tableTopSpacing = 20.0
        } else {
            // Table top doesn't fit but is credibly sized
            tableTopView.isHidden = false
            innerTableTopSize -= 80.0
            self.tableTopView.frame = CGRect(x: frame.minX + (totalWidth - innerTableTopSize) / 2.0,
                                             y: frame.minY + offset + (totalHeight - innerTableTopSize) / 2.0,
                                             width: innerTableTopSize,
                                             height: innerTableTopSize)
        }
        self.tableTopView.roundCorners(cornerRadius: 10.0)
        
        // Setup top hand
        self.tableView[0].frame = CGRect(x: frame.minX + (totalWidth - maxMiddleWidth) / 2.0, y: frame.minY + offset + ((totalHeight - tableTopHeight) / 2.0) - height[0], width: width[0], height: height[0])
        
        // Setup right hand
        self.tableView[1].frame = CGRect(x: ((totalWidth + tableTopWidth) / 2.0) + tableTopSpacing, y: frame.minY + offset + ((totalHeight - maxSideHeight) / 2.0), width: width[1], height: height[1])
        
        // Setup bottom hand
        self.tableView[2].frame = CGRect(x: frame.minX + (totalWidth - maxMiddleWidth) / 2.0, y: frame.minY + offset + ((totalHeight + tableTopHeight) / 2.0), width: width[2], height: height[2])
        
        // Setup left hand
        self.tableView[3].frame = CGRect(x: frame.minX + ((totalWidth - tableTopWidth) / 2.0) - width[3] - tableTopSpacing, y: frame.minY + offset + ((totalHeight - maxSideHeight) / 2.0), width: width[3], height: height[3])
        
    }
    
    // MARK: - Default colors ===================================================================== -
    
    private func defaultViewColors() {
        
        self.tableTopView.backgroundColor = Palette.tableTop.background
        self.contentView.backgroundColor = UIColor.clear
    }
}

class DealViewCell: UITableViewCell {
    @IBOutlet fileprivate weak var label: UILabel!
    @IBOutlet fileprivate weak var suitLabel: UILabel!
    @IBOutlet fileprivate weak var suitWidthConstraint: NSLayoutConstraint!
}
