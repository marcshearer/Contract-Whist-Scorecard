//
//  History Viewer.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 29/06/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

class HistoryViewer : NSObject, DataTableViewerDelegate {

    private let scorecard = Scorecard.shared
    
    public let viewTitle = "History"
    public let allowSync = true
    public let initialSortField = "datePlayed"
    public let initialSortDescending = true
    public let bodyRowHeight: CGFloat = 36.0 
    public let separatorHeight: CGFloat = 0.5
    
    private var history: History!
    private var sourceViewController: UIViewController
    private var dataTableViewController: DataTableViewController!
    private var callerCompletion: (()->())?
    
    // Local class variables
    let availableFields: [DataTableField] = [
        DataTableField("",              "",          sequence: 0,   width: 10,  type: .string),
        DataTableField("=count",        "Count",     sequence: 1,   width: 60,  type: .int),
        DataTableField("=location",     "Location",  sequence: 2,   width: 100, type: .string,      align: NSTextAlignment.left, pad: true),
        DataTableField("info",          "",          sequence: 14,  width: 40,  type: .button),
        DataTableField("cross black",   "",          sequence: 13,  width: 40,  type: .button),
        DataTableField("datePlayed",    "Date",      sequence: 3,   width: 100, type: .date),
        DataTableField("=player1",      "Winner",    sequence: 5,   width: 80,  type: .string),
        DataTableField("=score1",       "Score",     sequence: 6,   width: 50,  type: .int),
        DataTableField("=player2",      "Second",    sequence: 7,   width: 80,  type: .string),
        DataTableField("=score2",       "Score",     sequence: 8,   width: 50,  type: .int),
        DataTableField("=player3",      "Third",     sequence: 9,   width: 80,  type: .string),
        DataTableField("=score3",       "Score",     sequence: 10,  width: 50,  type: .int),
        DataTableField("=player4",      "Fourth",    sequence: 11,  width: 80,  type: .string),
        DataTableField("=score4",       "Score",     sequence: 12,  width: 50,  type: .int),
        DataTableField("datePlayed",    "",          sequence: 4,   width: 60,  type: .time,        combineHeading: "Date")
    ]
    
    init(from viewController: UIViewController, completion: (()->())? = nil) {
        self.sourceViewController = viewController
        super.init()
        self.getHistory()
        self.callerCompletion = completion
        
        // Call the data table viewer
        dataTableViewController = DataTableViewController.show(from: viewController, delegate: self, recordList: history.games)
    }
    
    internal func didSelect(record: DataTableViewerDataSource, field: String) {
        let historyGame = record as! HistoryGame
        switch field {
        case "cross black":
            self.deleteHistory(historyGame: historyGame)
        default:
            self.showDetail(historyGame: historyGame)
        }
        
    }
    
    internal func hideField(field: String) -> Bool {
        var result = false
        
        switch field {
        case "=count", "cross black":
            result = !Scorecard.adminMode
        case "=location":
            result = !self.scorecard.settingSaveLocation
        default:
            break
        }
        
        return result
    }
    
    internal func derivedField(field: String, record: DataTableViewerDataSource, sortValue: Bool) -> String {
        var numericResult: Int?
        var result = ""
        
        let historyGame = record as! HistoryGame
        
        if historyGame.participant == nil {
            if let index = self.history.games.firstIndex(where: { $0.gameUUID == historyGame.gameUUID } ) {
                history.getParticipants(index: index)
            }
        }
        
        switch field  {
        case "count":
            if let index = self.history.games.firstIndex(where: { $0.gameUUID == historyGame.gameUUID }) {
                numericResult = index + 1
            } else {
                result = ""
            }
            
        case "location":
            if let location = historyGame.gameLocation.description {
                result = location
            } else {
                result = ""
            }
            
        case "player1", "player2", "player3", "player4":
            let player = Int(String(field.suffix(1)))!
            if player <= historyGame.participant.count {
                if let participant = historyGame.participant?[player-1] {
                    result = participant.name
                } else {
                    result = ""
                }
            } else {
                result = ""
            }

        case "score1", "score2", "score3", "score4":
            let player = Int(String(field.suffix(1)))!
            if player <= historyGame.participant.count {
                if let participant = historyGame.participant?[player-1] {
                    numericResult = Int(participant.totalScore)
                } else {
                    result = ""
                }
            } else {
                result = ""
            }

        default:
            result = ""
        }
        
        if numericResult != nil {
            if sortValue {
                let valueString = String(format: "%.4f", Double(numericResult!) + 1e14)
                result = String(repeating: " ", count: 20 - valueString.count) + valueString
            } else {
                result = "\(numericResult!)"
            }
        }
        
        return result
    }
    
    internal func refreshData(recordList: [DataTableViewerDataSource]) {
        self.getHistory()
    }
    
    internal func completion() {
        self.callerCompletion?()
    }
    
    // MARK: - Load data ================================================================= -
    
    func getHistory() {
        // Load list of games from core data
        if self.history == nil {
            self.history = History(getParticipants: false, includeBF: Scorecard.adminMode)
        } else {
            self.history.loadGames(getParticipants: false, includeBF: Scorecard.adminMode)
        }
    }
    
    // MARK: - Drill routines============================================================= -
    
    func showDetail(historyGame: HistoryGame) {
        HistoryDetailViewController.show(from: self.dataTableViewController, gameDetail: historyGame, sourceView: self.dataTableViewController.view, completion: { (historyGame) in
            if let historyGame = historyGame {
                if let row = self.history.games.firstIndex(where: { $0.gameUUID == historyGame.gameUUID }) {
                    self.dataTableViewController.refreshRows(at: [IndexPath(row: row, section: 0)])
                }
            }
        })
    }
    
    func deleteHistory(historyGame: HistoryGame) {
        if let row = self.history.games.firstIndex(where: { $0.gameUUID == historyGame.gameUUID }) {
            var locationDescription = historyGame.gameLocation.description
            if locationDescription == nil {
                locationDescription = "game at unknown location"
            } else if locationDescription == "Online" {
                locationDescription = "online game"
            } else {
                locationDescription = "game at \(locationDescription!)"
            }
            let gameDate = Utility.dateString(historyGame.datePlayed)
            self.dataTableViewController.alertDecision("Are you sure you want to delete this \(locationDescription!) on \(gameDate)", title: "Warning", okButtonText: "Delete", okHandler: {
                if !CoreData.update(updateLogic: {
                    // First delete participants
                    for historyParticipant in historyGame.participant {
                        CoreData.delete(record: historyParticipant.participantMO)
                    }
                    // Now delete game
                    CoreData.delete(record: historyGame.gameMO)
                }) {
                    self.dataTableViewController.alertMessage("Error deleting game")
                    return
                }
                self.dataTableViewController.deleteRows(at: [IndexPath(row: row, section: 0)])
            })
        }
    }
}
