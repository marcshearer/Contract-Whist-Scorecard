//
//  DataTableTileHistoryDataSource.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 03/07/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import CoreGraphics

class DataTableTileHistoryDataSource : DataTableTileViewDataSource {
    
    private var history = History()
    
    let availableFields: [DataTableField] = [
        DataTableField("        ",      "",          sequence: 1,   width: 7,   type: .string),
        DataTableField("        ",      "",          sequence: 6,   width: 2,   type: .string),
        DataTableField("=shortDate",    "Date",      sequence: 2,   width: 50,  type: .date,    align: .left, pad: true),
        DataTableField("=player1",      "Winner",    sequence: 3,   width: 60,  type: .string,  pad: true),
        DataTableField("=score1",       "Score",     sequence: 4,   width: 50,  type: .int),
        DataTableField("=location",     "Location",  sequence: 5,   width: 60,  type: .string,  pad: true),
    ]
    
    let minColumns = 4
    
    internal func getData(personal: Bool, count: Int) -> [DataTableViewerDataSource] {
        self.history = History(playerUUID: (personal ? Scorecard.settings.thisPlayerUUID : nil), limit: count)
        return self.history.games
    }
    
}
