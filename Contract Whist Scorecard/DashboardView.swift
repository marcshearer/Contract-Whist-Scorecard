//
//  PersonalDashboard.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 22/06/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

enum HighScoreType: Int {
    case totalScore = 1
    case handsMade = 2
    case twosMade = 3
    case winStreak = 4
    
    var playerKey: String {
        switch self {
        case .totalScore: return "maxScore"
        case .handsMade: return "maxMade"
        case .twosMade: return "maxTwos"
        case .winStreak: return "maxWinStreak"
        }
    }
    
    var description: String {
        switch self {
        case .totalScore:
            return "highest points score in a game"
        case .twosMade:
            return "most tricks won with a two in a game"
        case .handsMade:
            return "most bids achieved in a game"
        case .winStreak:
            return "most games won in a row"
        }
    }
    
    var playerSort: [(String, SortDirection)] {
        switch self {
        case .totalScore:
            return [("maxScore", .descending), ("maxScoreSplit", .descending), ("maxScoreDate", .ascending)]
        case .handsMade:
            return [("maxMade", .descending), ("maxMadeSplit", .descending), ("maxMadeDate", .ascending)]
        case .twosMade:
            return [("maxTwos", .descending), ("maxTwosSplit", .descending), ("maxTwosDate", .ascending)]
        case .winStreak:
            return [("maxWinStreak", .descending), ("maxWinStreakDate", .ascending)]
        }
    }
    
    var participantKey: String {
        switch self {
        case .totalScore: return "totalScore"
        case .handsMade: return "handsMade"
        case .twosMade: return "twosMade"
        case .winStreak: return ""
        }
    }
    
    var participantSort: [(String, SortDirection)] {
        switch self {
        case .totalScore:
            return [("totalScore", .descending), ("handsMade", .descending), ("datePlayed", .ascending)]
        case .handsMade:
            return [("handsMade", .descending), ("totalScore", .descending), ("datePlayed", .ascending)]
        case .twosMade:
            return [("twosMade", .descending), ("totalScore", .descending), ("datePlayed", .ascending)]
        default:
            return []
        }
    }
}

class DashboardView : UIView, DashboardActionDelegate {
    
    private var historyViewer: HistoryViewer!
    private var title: String?
    private var returnTo: String?
    private(set) var id: String!

    @IBOutlet public weak var delegate: DashboardActionDelegate?
    @IBOutlet public weak var parentViewController: DashboardViewController?
    @IBOutlet private weak var contentView: UIView!

    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    convenience init(withNibName nibName: String, frame: CGRect, parent: DashboardViewController?, title: String? = nil, returnTo: String? = nil, delegate: DashboardActionDelegate?) {
        self.init(frame: frame)
        self.id = nibName
        self.parentViewController = parent
        self.delegate = delegate
        self.title = title
        self.returnTo = returnTo ?? title
        self.loadDashboardView(withNibName: nibName)
    }
            
    private func loadDashboardView(withNibName nibName: String) {
        Bundle.main.loadNibNamed(nibName, owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    
    // MARK: - Dashboard Action Delegate =============================================================== -
    
    func action(view: DashboardDetailType, personal: Bool) {
        delegate?.action(view: view, personal: personal)
    }
    
    // MARK: - High score utilities ====================================================================== -
    
    public func drillHighScore(from viewController: ScorecardViewController, sourceView: UIView, type: HighScoreType, occurrence: Int, detailParticipantMO: ParticipantMO?, playerUUID: String) {
        if type == .winStreak {
            // Win streak - special case
            self.historyViewer = HistoryViewer(from: viewController, playerUUID: playerUUID, winStreak: true) {
                self.historyViewer = nil
            }
        } else {
            // Use participant we loaded on entry if available
            var detailParticipantMO = detailParticipantMO
            if detailParticipantMO == nil {
                // Presumably got the data from player so don't have participant
                let highScores = self.getHighScores(type: type, forceParticipant: true, count: occurrence + 1)
                if occurrence < highScores.count {
                    detailParticipantMO = highScores[occurrence].participantMO
                }
            }
            
            if let detailParticipantMO = detailParticipantMO {
                // Got a participant MO - load the game and show it
                let history = History(gameUUID: detailParticipantMO.gameUUID)
                if history.games.count > 0 {
                    HistoryDetailViewController.show(from: viewController, gameDetail: history.games[0], sourceView: sourceView)
                }
            }
        }
    }
    
    public func getHighScores(type: HighScoreType, forceParticipant: Bool = false, count: Int) -> [(name: String, score: Int, playerUUID: String, participantMO: ParticipantMO?)] {
        if count == 1 && !forceParticipant {
            // Can get them much more efficiently from the player record
            let sortedPlayers = self.sorted(Scorecard.shared.playerList, by: type)
            return Array(sortedPlayers.map{(name: $0.name!, score: $0.value(forKey: type.playerKey) as! Int, playerUUID: $0.playerUUID!, participantMO: nil)}.prefix(1))
        } else {
            // Have to search the participants as same player might appear more than once in list
            var highScores: [(playerUUID: String, value: Int, participantMO: ParticipantMO?)]
            let playerUUIDList = Scorecard.shared.playerUUIDList()
            if type == .winStreak {
                let winStreaks = History.getWinStreaks(playerUUIDList: playerUUIDList, limit: count)
                highScores = winStreaks.map{($0.playerUUID, $0.longestStreak, nil)}
            } else {
                let highScoreParticipantMOs = History.getHighScores(type: type, limit: count, playerUUIDList: playerUUIDList)
                highScores = highScoreParticipantMOs.map{($0.playerUUID!, $0.value(forKey: type.participantKey) as! Int, $0)}
            }
            var data: [(name: String, score: Int, playerUUID: String, participantMO: ParticipantMO?)] = []
            for highScore in highScores {
                if let playerMO = Scorecard.shared.findPlayerByPlayerUUID(highScore.playerUUID) {
                    data.append((name: playerMO.name!, score: highScore.value, playerUUID: playerMO.playerUUID!, participantMO: highScore.participantMO))
                }
            }
            return Array(data.prefix(count))
        }
    }
    
    private func sorted(_ unsorted: [PlayerMO], by type: HighScoreType) -> [PlayerMO] {
        let sortKeys = type.playerSort
        return unsorted.sorted(by: {self.sort($0, $1, sortKeys)})
    }
       
    private func sort(_ first: PlayerMO, _ second: PlayerMO, _ sortKeys: [(value: String, direction: SortDirection)]) -> Bool {
        // Assumes values are either Int64 or Date
        var result = false
        for key in sortKeys {
            var equal = true
            var lessThan = false
            if let firstValue = first.value(forKey: key.value) as? Int64,
               let secondValue = second.value(forKey: key.value) as? Int64 {
                equal = (firstValue == secondValue)
                lessThan = (firstValue < secondValue)
            } else if let firstValue = first.value(forKey: key.value) as? Date,
                      let secondValue = second.value(forKey: key.value) as? Date {
                equal = (firstValue == secondValue)
                lessThan = (firstValue < secondValue)
            }
            if !equal {
                result = lessThan
                if key.direction == .descending {
                    result.toggle()
                }
                break
            }
        }
        return result
    }
}
