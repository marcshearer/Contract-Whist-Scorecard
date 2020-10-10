//
//  LeaderboardViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 25/09/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

fileprivate struct LeaderboardEntry {
    let position: Int
    let participantMO: ParticipantMO
    var currentGame: Bool = false
}

class LeaderboardView: UIView, UITableViewDataSource, UITableViewDelegate {
    
    private var entries: [LeaderboardEntry]!
    private let topToInclude = 10
    private var sectionCount: [Int:Int] = [:]
    private var sectionXref: [Int:Int] = [:]
    
    // MARK: - IB Outlets ============================================================================== -

    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var parentViewController: ScorecardViewController!
 
    // MARK: - View Overrides ========================================================================== -

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.loadLeaderboardView()
    }
    
    override init(frame: CGRect) {
        super.init(frame:frame)
        self.loadLeaderboardView()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        LeaderboardViewCell.register(self.tableView)
        LeaderboardViewHeaderFooterView.register(self.tableView)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    public func reloadData() {
        self.loadData()
        self.tableView.reloadData()
    }
       
    // MARK: - TableView Overrides ===================================================================== -

    func numberOfSections(in tableView: UITableView) -> Int {
        return self.sectionXref.count
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch sectionXref[section] {
        case 0:
            return 0
        default:
            return 36
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = LeaderboardViewHeaderFooterView.dequeue(tableView)
        view.backgroundView = UIView()
        view.backgroundView?.backgroundColor = UIColor.clear
        view.bind(section: sectionXref[section]!)
        return view
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sectionCount[sectionXref[section]!] ?? 0
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 40
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = LeaderboardViewCell.dequeue(tableView, for: indexPath)
        var row = indexPath.row
        var previousScore: Int16 = 0
        if row > 0 {
            previousScore = entries[row - 1].participantMO.totalScore
        }
        for (section, count) in sectionCount {
            if section < sectionXref[indexPath.section]! {
                row += count
            }
        }
        cell.bind(entry: entries[row], previousScore: previousScore)
        return cell
    }
    
    // MARK: - Data Source Routines ======================================================================== -
    
    private func loadData() {
        self.entries = []
        self.sectionCount = [:]
        self.sectionXref = [:]
        
        // Add top N
        let topN = History.getHighScores(type: .totalScore, limit: topToInclude, playerUUIDList: Scorecard.shared.playerUUIDList(getPlayerMode: .getAll))
        self.sectionCount[0] = topN.count
        for (index, participantMO) in topN.enumerated() {
            entries.append(LeaderboardEntry(position: index + 1, participantMO: participantMO))
        }
        
        // Check if any players in game not in top N
        var others: [ParticipantMO] = []
        for playerNumber in 1...Scorecard.game.currentPlayers {
            if let participantMO = Scorecard.game.player(enteredPlayerNumber: playerNumber).participantMO {
                if let index = entries.firstIndex(where: {$0.participantMO ~ participantMO}) {
                    entries[index].currentGame = true
                } else {
                    // Not in top N - find true position
                    others.append(participantMO)
                }
            }
        }
        
        if !others.isEmpty {
            // Get scores for non top 3
            let minScore = others.map{$0.totalScore}.reduce(999, {min($0, $1)})
            let highScores = History.getHighScores(type: .totalScore, limit: 100, minScore: minScore)
            for participantMO in others {
                let index = highScores.firstIndex(where: {$0 ~ participantMO}) ?? 10000 - Int(participantMO.totalScore)
                self.entries.append(LeaderboardEntry(position: index + 1, participantMO: participantMO, currentGame: true))
                let section = (index < 100 ? 1 : 2)
                sectionCount[section] = (sectionCount[section] ?? 0) + 1
            }
            entries.sort(by: {$0.position < $1.position})
        }
        
        var xref = 0
        for section in 0...2 {
            if sectionCount[section] ?? 0 != 0 {
                sectionXref[xref] = section
                xref += 1
            }
        }
    }
    
    
    // MARK: - Utility Routines ======================================================================== -
    
    func loadLeaderboardView() {
        Bundle.main.loadNibNamed("LeaderboardView", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
}

class LeaderboardViewCell: UITableViewCell {
    
    @IBOutlet private weak var shadowView: UIView!
    @IBOutlet private weak var positionLabel: UILabel!
    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var scoreLabel: UILabel!
    @IBOutlet private var textLabels: [UILabel]!
    @IBOutlet private var smallTextLabels: [UILabel]!
    
    fileprivate func bind(entry: LeaderboardEntry, previousScore: Int16 = 0) {
        
        if entry.position <= 100 && entry.participantMO.totalScore != previousScore {
            self.positionLabel.text = NumberFormatter.localizedString(from: NSNumber(value: entry.position), number: .ordinal)
        } else {
            self.positionLabel.text = ""
        }
        self.nameLabel.text = entry.participantMO.name
        self.scoreLabel.text = "\(entry.participantMO.totalScore)"
        let background = Palette.rightGameDetailPanel
        let color = background.text
        self.textLabels.forEach{ (label) in label.textColor = color ; label.font = UIFont.systemFont(ofSize: 28, weight: .light)}
        self.smallTextLabels.forEach{ (label) in label.textColor = color ; label.font = UIFont.systemFont(ofSize: 20, weight: .light)}
        self.backgroundView = UIView()
        self.backgroundView?.backgroundColor = UIColor.clear
        self.shadowView.backgroundColor = (entry.currentGame ? Palette.rightGameDetailPanelShadow.background : UIColor.clear)
        self.shadowView.layoutIfNeeded()
        self.shadowView.roundCorners(cornerRadius: self.shadowView.frame.height / 2, corners: [.topLeft, .bottomLeft])
    }
    
    public static func register(_ tableView: UITableView) {
        let nib = UINib(nibName: "LeaderboardViewCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "Leaderboard Cell")
    }
    
    fileprivate static func dequeue(_ tableView: UITableView, for indexPath: IndexPath) -> LeaderboardViewCell {
        return tableView.dequeueReusableCell(withIdentifier: "Leaderboard Cell", for: indexPath) as! LeaderboardViewCell
    }
}

class LeaderboardViewHeaderFooterView : UITableViewHeaderFooterView {
    
    @IBOutlet private weak var label: UILabel!
    @IBOutlet private weak var separator: UIView!
    
    fileprivate func bind(section: Int) {
        switch section {
        case 1:
            self.label.isHidden = true
            self.separator.isHidden = false
            self.separator.backgroundColor = Palette.rightGameDetailPanelShadow.background
            
        case 2:
            self.separator.isHidden = true
            self.label.text = "Below Top 100"
            self.label.textColor = Palette.rightGameDetailPanel.text
            
        default:
            break
        }
    }
    
    public class func register(_ tableView: UITableView) {
        let nib = UINib(nibName: "LeaderboardViewHeaderFooterView", bundle: nil)
        tableView.register(nib, forHeaderFooterViewReuseIdentifier: "Leaderboard Header")
    }
    
    public class func dequeue(_ tableView: UITableView) -> LeaderboardViewHeaderFooterView {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: "Leaderboard Header") as! LeaderboardViewHeaderFooterView
        return view
    }
}

infix operator ~: ComparisonPrecedence

extension ParticipantMO {
    
    static func ~ (left: ParticipantMO, right: ParticipantMO) -> Bool {
        return left.gameUUID == right.gameUUID && left.playerUUID == right.playerUUID
    }
}
