//
//  PersonalDashboard.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 22/06/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class DashboardView : UIView, DashboardActionDelegate {
    
    private var historyViewer: HistoryViewer!
    private var statisticsViewer: StatisticsViewer!

    @IBOutlet public weak var delegate: DashboardActionDelegate?
    @IBOutlet public weak var parentViewController: ScorecardViewController?
    @IBOutlet private weak var contentView: UIView!

    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    convenience init(withNibName nibName: String, frame: CGRect) {
        self.init(frame: frame)
        self.loadDashboardView(withNibName: nibName)
    }
            
    private func loadDashboardView(withNibName nibName: String) {
        Bundle.main.loadNibNamed(nibName, owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    
    // MARK: - Dashboard Action Delegate =============================================================== -
    
    func action(view: DashboardDetailType) {
        switch view {
        case .history:
            self.historyViewer = HistoryViewer(from: self.parentViewController!) {
                self.historyViewer = nil
                self.delegate?.reloadData?()
            }
        case .statistics:
            self.statisticsViewer = StatisticsViewer(from: self.parentViewController!) {
                self.statisticsViewer = nil
                self.delegate?.reloadData?()
            }
        case .highScores:
            self.showHighScores()
        }
        delegate?.action(view: view)
    }
    
    // MARK: - High score utilities ====================================================================== -
    
    public func drillHighScore(from viewController: ScorecardViewController, sourceView: UIView, type: HighScoreType, occurrence: Int, detailParticipantMO: ParticipantMO?, playerUUID: String) {
        if type == .winStreak {
            // Win streak - special case
            self.historyViewer = HistoryViewer(from: viewController, winStreakPlayer: playerUUID) {
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
            return Array(Scorecard.shared.playerList.map{(name: $0.name!, score: $0.value(forKey: type.playerKey) as! Int, playerUUID: $0.playerUUID!, participantMO: nil)}.sorted(by: {$0.score > $1.score}).prefix(1))
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
    
    // MARK: - Functions to present other views ========================================================== -
    
    private func showHighScores() {
        DashboardViewController.show(from: self.parentViewController!,
                                     dashboardNames: [(title: "High Scores",  fileName: "HighScoresDashboard",  imageName: "person.fill")], backImage: "back", bannerColor: Palette.highScores, bannerShadowColor: Palette.highScores, backgroundColor: Palette.highScores) {
            self.delegate?.reloadData?()
        }
    }

}
