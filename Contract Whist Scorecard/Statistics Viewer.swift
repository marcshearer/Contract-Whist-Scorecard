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

    public let viewTitle = "Statistics"
    public let allowSync = true
    public let nameField = "name"
    public let initialSortField = "name"
    public let headerRowHeight:CGFloat = 72.0
    public let headerTopSpacingHeight: CGFloat = 10.0
    public let bodyRowHeight:CGFloat = 52.0
        
    private var recordList: [PlayerDetail]
    private var sourceViewController: ScorecardViewController
    private var dataTableViewController: DataTableViewController!
    private var callerCompletion: (()->())?
    private var observer: NSObjectProtocol?
    public var backImage = "back"
    
    // Local class variables
    
    // fields displayed. Note that the sequence is used to show the order fields will be displayed in
    // but the priority of fields to show is the sequence in the array.
    public let availableFields: [DataTableField] = [
        DataTableField("",             "",                 sequence: 0,     width: 16,    type: .string),
        DataTableField("name",         "Player\nName",     sequence: 2,     width: 80,    type: .string,    align: .left,   pad: true),
        DataTableField(DataTableViewController.infoImageName, "", sequence: 14,    width: 40.0,  type: .button),
        DataTableField("=gamesWon%",   "Games Won %",      sequence: 5,     width: 75.0,  type: .double),
        DataTableField("=averageScore","Average Score",    sequence: 7,     width: 75.0,  type: .double),
        DataTableField("=handsMade%",  "Hands Made %",     sequence: 10,    width: 75.0,  type: .double),
        DataTableField("=twosMade%",   "Twos Made %",      sequence: 12,    width: 75.0,  type: .double),
        DataTableField("gamesPlayed",  "Games Played",     sequence: 3,     width: 75.0,  type: .int),
        DataTableField("gamesWon",     "Games Won",        sequence: 4,     width: 75.0,  type: .int),
        DataTableField("graph",        "",                 sequence: 13,    width: 50.0,  type: .button),
        DataTableField("thumbnail",    "",                 sequence: 1,     width: 60.0,  type: .thumbnail, combineHeading: "Player\nName"),
        DataTableField("totalScore",   "Total Score",      sequence: 6,     width: 75.0,  type: .int),
        DataTableField("handsMade",    "Hands Made",       sequence: 9,     width: 75.0,  type: .int),
        DataTableField("twosMade",     "Twos Made",        sequence: 11,    width: 75.0,  type: .int),
        DataTableField("handsPlayed",  "Hands Played",     sequence: 8,     width: 75.0,  type: .int),
    ]
    
    init(from viewController: ScorecardViewController, completion: (()->())? = nil) {
        self.sourceViewController = viewController
        self.recordList = Scorecard.shared.playerDetailList()
        self.callerCompletion = completion
        super.init()
        
        // Set nofification for image download
        observer = setImageDownloadNotification()
        
        // Call the data table viewer
        dataTableViewController = DataTableViewController.create(delegate: self, recordList: recordList)
        
        DataTableViewController.show(dataTableViewController, from: viewController)
    }
    
    internal func didSelect(record: DataTableViewerDataSource, field: String) {
        let record = record as! PlayerDetail
        switch field {
        case DataTableViewController.infoImageName:
            self.showDetail(playerDetail: record)
        default:
            self.drawGraph(playerDetail: record)
        }
        
    }
    
    internal func hideField(field: String) -> Bool {
        var result = false
        
        switch field {
        case "twosMade", "=twosMade%":
            result = !Scorecard.activeSettings.bonus2
        default:
            break
        }
        
        return result
    }
    
    internal func refreshData(recordList: [DataTableViewerDataSource])->[DataTableViewerDataSource] {
        Scorecard.shared.refreshPlayerDetailList(recordList as! [PlayerDetail])
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
    
    internal func addHelp(to helpView: HelpView, header: UITableView, body: UITableView) {
        
        helpView.add("The @*/\(self.viewTitle)@*/ screen allows you to review the key statistics for all players on this device.")
        
        helpView.add("The header row contains the column titles.\n\nTap on a column title to sort the data by that column's value.\n\nTap the same column again to reverse the order of the sort.\n\nThe up/down arrow shows the order of the sort.", views: [header])
        
        helpView.add("The body of the screen contains the data.\n\nTap on a row to show a graph of the player's recent game scores.", views: [body], item: 0, itemTo: 999, shrink: true, direction: .up)
        
        let image = NSMutableAttributedString(attachment: NSTextAttachment(image: UIImage(systemName: "info.circle.fill")!))
        image.addAttribute(NSAttributedString.Key.foregroundColor, value: Palette.otherButton.background, range: NSRange(0...image.length - 1))
        let text = NSAttributedString("Tap on the ") + image + NSAttributedString(" button in a row to show that player's details.")
        helpView.add(text, views: [body], callback: self.infoButton, item: 0)
    }
    
    private func infoButton(item: Int, view: UIView) -> CGRect? {
        var result: CGRect?
        if let tableCell = view as? DataTableCell {
            if let collectionView = tableCell.dataTableCollection {
                if let item = self.dataTableViewController.displayedFields.firstIndex(where: {$0.field == DataTableViewController.infoImageName}) {
                    if let collectionCell = collectionView.cellForItem(at: IndexPath(item: item, section: 0)) as? DataTableCollectionCell {
                        result = tableCell.convert(collectionCell.bodyButton.frame, from: collectionCell)
                    }
                }
            }
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
