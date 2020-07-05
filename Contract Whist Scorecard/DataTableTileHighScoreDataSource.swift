//
//  DataTableTileHighScoreDataSource.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 03/07/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class DataTableTileHighScoreDataSource : DataTableTileViewDataSource {

    let type: HighScoreType
    let parentDashboardView: DashboardView?
    
    init(type: HighScoreType, parentDashboardView: DashboardView?) {
        self.type = type
        self.parentDashboardView = parentDashboardView
    }
    
    var availableFields: [DataTableField] {
        get {
            var result = [ DataTableField("",             "",                 sequence: 1,     width: 7,     type: .string),
                           DataTableField("",             "",                 sequence: 9,     width: 7,     type: .string),
                           DataTableField("name",         "Name",             sequence: 4,     width: 70,   type: .string,    align: .left,   pad: true),
                           DataTableField("value",        "Value",            sequence: 5,     width: 60.0,  type: .int),
                           DataTableField("thumbnail",    "",                 sequence: 2,     width: 34.0,  type: .thumbnail),
                           DataTableField("",             "",                 sequence: 3,     width: 5,     type: .string)]
            if self.type == .winStreak {
                result.append(
                           DataTableField("value",        "",                 sequence: 8,     width: 120.0,  type: .collection))
            }
            
            return result
        }
    }
    
    var minColumns: Int {
        get {
            return (self.type == .winStreak ? 7 : 6)
        }
    }
    
    internal func getData(personal: Bool, count: Int) -> [DataTableViewerDataSource] {
        var data: [DataTableHighScore] = []

        if let highScores = self.parentDashboardView?.getHighScores(type: self.type, count: count) {
            for highScore in highScores {
                if let playerMO = Scorecard.shared.findPlayerByPlayerUUID(highScore.playerUUID) {
                    data.append(DataTableHighScore(name: playerMO.name!, value: highScore.score, playerUUID: highScore.playerUUID, thumbnail: playerMO.thumbnail, participantMO: highScore.participantMO))
                }
            }
        }
        return Array(data.prefix(count))
    }
    
    private func gamesWon(_ playerDetail: PlayerDetail) -> Double {
        if playerDetail.gamesPlayed == 0 {
            return 0
        } else {
            return Double(playerDetail.gamesWon) / Double(playerDetail.gamesPlayed)
        }
    }
}

class DataTableHighScore : DataTableViewerDataSource {
    
    let name: String
    let value: Int
    let playerUUID: String
    let thumbnail: Data?
    let participantMO: ParticipantMO?

    init(name: String, value: Int, playerUUID: String, thumbnail: Data?, participantMO: ParticipantMO?) {
        self.name = name
        self.value = value
        self.playerUUID = playerUUID
        self.thumbnail = thumbnail
        self.participantMO = participantMO
    }
    
    func value(forKey key: String) -> Any? {
        switch key {
        case "name":
            return self.name
        case "value":
            return self.value
        case "thumbnail":
            return self.thumbnail
        case "playerUUID":
            return self.playerUUID
        case "participantMO":
            return self.participantMO
        default:
            return nil
        }
    }
}
