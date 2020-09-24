//
//  DataTableTilePersonalStatsDataSource.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 03/07/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import CoreGraphics

class DataTableTilePersonalStatsDataSource : DataTableTileViewDataSource {
    
    let availableFields: [DataTableField] = [
        DataTableField("",              "",          sequence: 1,   width: 7,   type: .string),
        DataTableField("",              "",          sequence: 4,   width: 7,   type: .string),
        DataTableField("name",          "Stat",      sequence: 2,   width: 60,  type: .string,  align: .left, pad: true),
        DataTableField("value",         "Value",     sequence: 3,   width: 50,  type: .string,  align: .left)
    ]

    let minColumns = 4
    
    internal func getData(personal: Bool, count: Int) -> [DataTableViewerDataSource] {
        var result: [DataTableViewerDataSource] = []
        
        if let playerMO = Scorecard.shared.findPlayerByPlayerUUID(Scorecard.settings.thisPlayerUUID) {
            result.append(DataTablePersonalStats(name: "Games won", value: "\(Utility.roundPercent(playerMO.gamesWon,playerMO.gamesPlayed)) %"))
            result.append(DataTablePersonalStats(name: "Av. score", value: "\(Utility.roundQuotient(playerMO.totalScore, playerMO.gamesPlayed))"))
            result.append(DataTablePersonalStats(name: "Bids made", value: "\(Utility.roundPercent(playerMO.handsMade, playerMO.handsPlayed)) %"))
            result.append(DataTablePersonalStats(name: "Twos made", value: "\(Utility.roundPercent(playerMO.twosMade, playerMO.handsPlayed)) %"))
        }
        
        return result
    }
}

class DataTablePersonalStats : DataTableViewerDataSource {
    
    let name: String
    let value: String
    
    init(name: String, value: String) {
        self.name = name
        self.value = value
    }
    
    func value(forKey key: String) -> Any? {
        switch key {
        case "name":
            return self.name
        case "value":
            return self.value
        default:
            return nil
        }
    }
}
