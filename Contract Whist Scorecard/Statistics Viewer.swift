//
//  Statistics Viewer.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 29/06/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

class StatisticsViewer : NSObject, DataTableViewerDelegate {

    private let scorecard = Scorecard.shared
        
    public let viewTitle = "Statistics"
    public let allowSync = true
    public let nameField = "name"
    public let initialSortField = "name"
    public let headerRowHeight:CGFloat = 72.0
    public let headerTopSpacingHeight: CGFloat = 10.0
    public let bodyRowHeight:CGFloat = 52.0
        
    private var recordList: [PlayerDetail]
    private var sourceViewController: UIViewController
    private var dataTableViewController: DataTableViewController!
    private var callerCompletion: (()->())?
    private var observer: NSObjectProtocol?
    
    // Local class variables
    public let availableFields: [DataTableField] = [
        DataTableField("",             "",                 sequence: 0,     width: 16,    type: .string),
        DataTableField("name",         "Player\nName",     sequence: 2,     width: 80,    type: .string,    align: .left,   pad: true),
        DataTableField("info",         "",                 sequence: 14,    width: 40.0,  type: .button),
        DataTableField("gamesPlayed",  "Games Played",     sequence: 3,     width: 75.0,  type: .int),
        DataTableField("=gamesWon%",   "Games Won %",      sequence: 5,     width: 75.0,  type: .double),
        DataTableField("gamesWon",     "Games Won",        sequence: 4,     width: 75.0,  type: .int),
        DataTableField("graph",        "",                 sequence: 13,    width: 50.0,  type: .button),
        DataTableField("thumbnail",    "",                 sequence: 1,     width: 60.0,  type: .thumbnail, combineHeading: "Player\nName"),
        DataTableField("=averageScore","Average Score",    sequence: 7,     width: 75.0,  type: .double),
        DataTableField("=handsMade%",  "Hands Made %",     sequence: 10,    width: 75.0,  type: .double),
        DataTableField("=twosMade%",   "Twos Made %",      sequence: 12,    width: 75.0,  type: .double),
        DataTableField("totalScore",   "Total Score",      sequence: 6,     width: 75.0,  type: .int),
        DataTableField("handsMade",    "Hands Made",       sequence: 9,     width: 75.0,  type: .int),
        DataTableField("twosMade",     "Twos Made",        sequence: 11,    width: 75.0,  type: .int),
        DataTableField("handsPlayed",  "Hands Played",     sequence: 8,     width: 75.0,  type: .int),
    ]
    
    init(from viewController: UIViewController, completion: (()->())? = nil) {
        self.sourceViewController = viewController
        self.recordList = self.scorecard.playerDetailList()
        self.callerCompletion = completion
        super.init()
        
        // Set nofification for image download
        observer = setImageDownloadNotification()
        
        // Call the data table viewer
        dataTableViewController = DataTableViewController.show(from: viewController, delegate: self, recordList: recordList)
    }
    
    internal func didSelect(record: DataTableViewerDataSource, field: String) {
        let record = record as! PlayerDetail
        switch field {
        case "info":
            self.showDetail(playerDetail: record)
        default:
            self.drawGraph(playerDetail: record)
        }
        
    }
    
    internal func hideField(field: String) -> Bool {
        var result = false
        
        switch field {
        case "twosMade", "=twosMade%":
            result = !self.scorecard.settingBonus2
        default:
            break
        }
        
        return result
    }
    
    internal func derivedField(field: String, record: DataTableViewerDataSource, sortValue: Bool) -> String {
        var numericResult: Double?
        var result: String
        let format = (ScorecardUI.landscapePhone() ? "%.1f" : "%.0f")
        
        let record = record as! PlayerDetail
        if record.gamesPlayed == 0 {
            numericResult = 0.0
            result = ""
        } else {
            switch field  {
            case "gamesWon%":
                numericResult = Double(record.gamesWon) / Double(record.gamesPlayed) * 100.0
                result = "\(String(format: format, numericResult!)) %"
            case "averageScore":
                numericResult = Double(record.totalScore) / Double(record.gamesPlayed)
                result = String(format: format, numericResult!)
            case "handsMade%":
                numericResult = Double(record.handsMade) / Double(record.handsPlayed) * 100.0
                result = "\(Int(numericResult!.rounded())) %"
            case "twosMade%":
                numericResult = Double(record.twosMade) / Double(record.handsPlayed) * 100.0
                result = "\(Int(numericResult!.rounded())) %"
            default:
                result = ""
            }
        }
        
        if numericResult != nil && sortValue {
            let valueString = String(format: "%.4f", Double(numericResult!) + 1e14)
            result = String(repeating: " ", count: 20 - valueString.count) + valueString
        }
        
        return result
    }
    
    internal func refreshData(recordList: [DataTableViewerDataSource])->[DataTableViewerDataSource] {
        scorecard.refreshPlayerDetailList(recordList as! [PlayerDetail])
        return recordList
    }
    
    
    internal func isEnabled(button: String, record: DataTableViewerDataSource) -> Bool {
        var result: Bool
        
        let record = record as! PlayerDetail
        switch button {
        case "graph":
            result = (record.handsPlayed > 0 && record.datePlayed >= Utility.dateFromString("01/04/2017")!)
        default:
            result = true
        }
        return result
    }
    
    internal func completion() {
        NotificationCenter.default.removeObserver(observer!)
        self.callerCompletion?()
    }
    
    // MARK: - Drill routines============================================================= -
    
    func drawGraph(playerDetail: PlayerDetail) {
        GraphViewController.show(from: self.dataTableViewController, playerDetail: playerDetail)
    }
    
    func showDetail(playerDetail: PlayerDetail) {
        PlayerDetailViewController.show(from: self.dataTableViewController, playerDetail: playerDetail, mode: .display, sourceView: self.dataTableViewController.view)
    }
    
    // MARK: - Image download handlers =================================================== -
    
    func setImageDownloadNotification() -> NSObjectProtocol? {
        // Set a notification for images downloaded
        let observer = NotificationCenter.default.addObserver(forName: .playerImageDownloaded, object: nil, queue: nil) {
            (notification) in
            self.updateImage(objectID: notification.userInfo?["playerObjectID"] as! NSManagedObjectID)
        }
        return observer
    }
    
    private func updateImage(objectID: NSManagedObjectID) {
        // Find any cells containing an image which has just been downloaded asynchronously
        Utility.mainThread {
            let index = self.recordList.firstIndex(where: {($0.objectID == objectID)})
            if let index = index {
                // Found it - update from managed object and reload the cell
                self.recordList[index].fromManagedObject(playerMO: self.recordList[index].playerMO)
                self.dataTableViewController.refreshRows(at: [IndexPath(row: index, section: 0)])
            }
        }
    }
}
