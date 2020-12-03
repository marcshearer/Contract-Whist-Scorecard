//
//  DataTableTileStatsDataSource.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 03/07/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import CoreGraphics

class DataTableTileStatsDataSource : DataTableTileViewDataSource {

    var availableFields: [DataTableField]
        
    init() {
        
        self.availableFields = [
                DataTableField("",             "",                 sequence: 1,     width: 7,     type: .string),
                DataTableField("",             "",                 sequence: 9,     width: 7,     type: .string),
                DataTableField("name",         "",                 sequence: 2,     width: 140,    type: .string,    align: .left,   pad: true),
                DataTableField("=gamesWon%",   "Games Won",        sequence: 5,     width: 60.0,  type: .double),
                DataTableField("=averageScore","Av. Score",        sequence: 6,     width: 60.0,  type: .double),
                DataTableField("=handsMade%",  "Hands Made",       sequence: 7,     width: 60.0,  type: .double)]
        if Scorecard.settings.bonus2 {
            self.availableFields.append(
                DataTableField("=twosMade%",   "Twos Made",        sequence: 8,     width: 60.0,  type: .double))
        }
        self.availableFields.append(contentsOf: [
                DataTableField("gamesPlayed",  "Games Played",     sequence: 3,     width: 60.0,  type: .int),
                DataTableField("gamesWon",     "Games Won",        sequence: 4,     width: 60.0,  type: .int)]
        )
    }
    
    let minColumns = 4
    
    internal func getData(personal: Bool, count: Int) -> [DataTableViewerDataSource] {
        Scorecard.shared.playerDetailList().sorted(by: {self.gamesWon($0) > self.gamesWon($1)})
    }
    
    private func gamesWon(_ playerDetail: PlayerDetail) -> Double {
        if playerDetail.gamesPlayed == 0 {
            return 0
        } else {
            return Double(playerDetail.gamesWon) / Double(playerDetail.gamesPlayed)
        }
    }
}
