//
//  HistoryViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 12/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData
import CoreLocation

class HistoryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    // MARK: - Class Properties ======================================================================== -
    
    // Main state properties
    var scorecard: Scorecard!
        
    // Local class variables
    let availableFields = [
        Field("count",        "Count",            width: 60),
        Field("location",     "Location",         width: 80 ,hide: true, align: NSTextAlignment.left),
        Field("date",         "Date",             width: 100),
        Field("player1",      "Winner",           width: 80),
        Field("score1",       "Score",            width: 60),
        Field("player2",      "Second",           width: 80),
        Field("score2",       "Score",            width: 60),
        Field("player3",      "Third",            width: 80),
        Field("score3",       "Score",            width: 60),
        Field("player4",      "Fourth",           width: 80),
        Field("score4",       "Score",            width: 60),
        Field("detail",       "",                 width: 0) ,
        Field("delete",       "",                 width: 0) ,
        Field("padding",      "",                 width: 0)
    ]
    
    var history: History!
    var displayedFields = [Field?]()
    var displayFieldCount = 0
    var buttonColumn = 0
    var deleteColumn = -1
    var lastColumn = -1
    var locationColumn = -1
    var lastDescending = true
    var firstTime = true
    var selectedGame = 0
    
    // Cell sizes
    let detailWidth: CGFloat = 40.0
    let paddingWidth: CGFloat = 10.0
    var carryWidth:CGFloat = 0.0
    
    // UI component pointers
    var headerCellImageView: [UIImageView?] = []
    var locationLabel: [UILabel?] = []

    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet var headerView: UITableView!
    @IBOutlet var bodyView: UITableView!
    @IBOutlet var historyView: UIView!
    @IBOutlet var syncButton: RoundedButton!
    @IBOutlet var syncMessage: UILabel!

    
    // MARK: - IB Unwind Segue Handlers ================================================================ -
    
    @IBAction func hideHistoryDetail(segue:UIStoryboardSegue) {
    }
    
    @IBAction func hideHistorySync(segue:UIStoryboardSegue) {
        // Reload history
        getHistory()
        // Refresh screen
        bodyView.reloadData()
    }
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func finishPressed(_ sender: UIButton) {
        self.navigationController?.isNavigationBarHidden = false
        self.performSegue(withIdentifier: "hideHistory", sender: self )
    }
    
    @IBAction func leftSwipe(recognizer:UISwipeGestureRecognizer) {
        if recognizer.state == .ended {
            self.navigationController?.isNavigationBarHidden = false
            self.performSegue(withIdentifier: "hideHistory", sender: self )
        }
    }
    
    @IBAction func syncPressed(_ sender: UIButton) {
        self.performSegue(withIdentifier: "showHistorySync", sender: self)
    }
    
    // MARK: - View Overrides ========================================================================== -
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for _ in 1...availableFields.count {
            displayedFields.append(nil)
        }
        
        // Hide navigation bar - using custom one
        self.navigationController?.isNavigationBarHidden = true
        
        // Check for network / iCloud login
        scorecard.checkNetworkConnection(button: syncButton, label: syncMessage)
       
        // Get history
       getHistory()
    }
        
    override func viewWillLayoutSubviews() {
        if firstTime {
            checkFieldDisplay(to: historyView.frame.size)
            firstTime = true
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        checkFieldDisplay(to: size)
        headerView.reloadData()
        bodyView.reloadData()
    }
    
    // MARK: - TableView Overrides ===================================================================== -
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch tableView.tag {
        case 1:
            return 1
        default:
            return history.games.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell: HistoryTableCell
        
        // Player names
        
        switch tableView.tag {
        case 1:
            // Header table view
            cell = tableView.dequeueReusableCell(withIdentifier: "History Header Table Cell", for: indexPath) as! HistoryTableCell
            ScorecardUI.sectionHeadingStyle(cell)
            cell.setCollectionViewDataSourceDelegate(self, forRow: 1000000+indexPath.row)
        default:
            // Body table view
            cell = tableView.dequeueReusableCell(withIdentifier: "History Body Table Cell", for: indexPath) as! HistoryTableCell
            ScorecardUI.normalStyle(cell)
            cell.setCollectionViewDataSourceDelegate(self, forRow: indexPath.row)
            if history.games[indexPath.row].participant == nil {
                history.getParticipants(index: indexPath.row)
            }
            if history.games[indexPath.row].duplicate {
                cell.backgroundColor = UIColor.lightGray
            } else {
                cell.backgroundColor = UIColor.white
            }
        }
        
        return cell
    }
    
    // MARK: - Form Presentation / Handling Routines =================================================== -
    
    func checkFieldDisplay(to size: CGSize) {
        // Check how many fields we can display
        var dateColumn = -1
        let availableWidth = size.width - (paddingWidth * 2) - (detailWidth * (Scorecard.adminMode ? 2 : 1)) // Allow for padding each end and detail button
        var widthRemaining = availableWidth
        displayFieldCount = 0
        
        for field in 0...availableFields.count-1 {
             if !availableFields[field].hide || scorecard.settingSaveLocation {
                switch availableFields[field].field {
                case "detail":
                    // Detail always make it in
                    displayedFields[displayFieldCount] = Field(availableFields[field].field,
                                                               availableFields[field].title,
                                                               width: detailWidth)
                    buttonColumn = displayFieldCount
                    displayFieldCount += 1
                case "delete":
                    // Always include in admin mode - otherwise omit
                    if Scorecard.adminMode {
                        displayedFields[displayFieldCount] = Field(availableFields[field].field,
                                                                   availableFields[field].title,
                                                                   width: detailWidth)
                        deleteColumn = displayFieldCount
                        displayFieldCount += 1
                    }
                case "count":
                    // Only include in admin mode - otherwise omit
                    if Scorecard.adminMode {
                        widthRemaining -= availableFields[field].width
                        displayedFields[displayFieldCount] = Field(availableFields[field].field,
                                                                   availableFields[field].title,
                                                                   width: availableFields[field].width)
                        displayFieldCount += 1
                    }
                case "padding":
                    // When get to padding distribute remaining width
                    if widthRemaining > 0 && locationColumn >= 0 {
                        // Use up to 200 on location column
                        displayedFields[locationColumn]!.width += min(200, widthRemaining)
                        widthRemaining = max(0, widthRemaining - 200)
                    }
                    if widthRemaining > 0 && dateColumn >= 0 {
                        // Use up to 50 on date column (or 100 if not showing location)
                        let extra:CGFloat = (scorecard.settingSaveLocation ? 50 : 100)
                        displayedFields[dateColumn]!.width += min(extra, widthRemaining)
                        widthRemaining = max(0, widthRemaining - extra)
                    }
                    if widthRemaining > 0 {
                        // Spread it around all other columns
                        let addWidth = widthRemaining / CGFloat(displayFieldCount)
                        for addColumn in 1...displayFieldCount {
                            displayedFields[addColumn-1]!.width += addWidth
                            widthRemaining -= addWidth
                        }
                    }
                    // Use up remainder on blank last column
                    displayedFields[displayFieldCount] = Field(availableFields[field].field,
                                                               availableFields[field].title,
                                                               width: paddingWidth + widthRemaining)
                    displayFieldCount += 1
                default:
                    // Normal fields - include if space
                    switch availableFields[field].field {
                    case "location":
                        locationColumn = displayFieldCount
                    case "date":
                        dateColumn = displayFieldCount
                    default:
                        break
                    }
                    if availableFields[field].width <= widthRemaining {
                        widthRemaining -= availableFields[field].width
                        displayedFields[displayFieldCount] = Field(availableFields[field].field,
                                                                   availableFields[field].title,
                                                                   width: availableFields[field].width,
                                                                   align: availableFields[field].align)
                        displayFieldCount += 1
                    }
                }
            }
        }
        for _ in 1...displayFieldCount {
            headerCellImageView.append(nil)
        }
    }
    
    // MARK: - Utility Routines ======================================================================== -
    
    func getHistory() {
        // Load list of games from core data
        history=nil
        history = History(getParticipants: false, includeBF: Scorecard.adminMode)
        
        // Setup label pointer array
        locationLabel.removeAll()
        if history.games.count > 0 {
            for _ in 1...history.games.count {
                locationLabel.append(nil)
            }
        }

    }
    
    // MARK: - Segue Prepare Handler =================================================================== -
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier! {
        case "showHistoryDetail":
            let destination = segue.destination as! HistoryDetailViewController
            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = historyView
            destination.preferredContentSize = CGSize(width: 400, height: (scorecard.settingSaveLocation ? 530 :
                262) - (44 * (scorecard.numberPlayers - history.games[selectedGame-1].participant.count)))
            destination.gameDetail = history.games[selectedGame - 1]
            destination.locationLabel = locationLabel[selectedGame-1]
            destination.scorecard = self.scorecard
            destination.returnSegue = "hideHistoryDetail"
            
        case "showHistorySync":
            let destination = segue.destination as! SyncViewController
            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.isModalInPopover = true
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = historyView
            destination.preferredContentSize = CGSize(width: 400, height: 523)
            destination.returnSegue = "hideHistorySync"
            destination.scorecard = self.scorecard
        
        default:
            break
        }
    }
}

// MARK: - Extension Override Handlers ============================================================= -

extension HistoryViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    // MARK: - CollectionView Overrides ================================================================ -
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return displayFieldCount
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let totalHeight: CGFloat = collectionView.bounds.size.height
        let width = displayedFields[indexPath.row]!.width
        
        return CGSize(width: width, height: totalHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var cell: HistoryCollectionCell
        let column = indexPath.row
        
        
        if collectionView.tag >= 1000000 {
            
            // Header
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "History Header Cell", for: indexPath) as! HistoryCollectionCell
            cell.sortArrowImage.image = nil
            
            ScorecardUI.sectionHeadingStyle(cell.historyLabel)
            cell.historyLabel.text = displayedFields[column]!.title
            cell.historyLabel.textAlignment = displayedFields[column]!.align
            switch displayedFields[column]!.field {
            case "date":
                cell.sortArrowImage.image = UIImage(named: "down arrow")
                lastColumn = column
            default:
                break
            }
            headerCellImageView[column] = cell.sortArrowImage
            
        } else {
            
            // Body
            let row = collectionView.tag
            switch displayedFields[column]!.field {
            case "detail":
                cell = collectionView.dequeueReusableCell(withReuseIdentifier: "History Detail Body Cell", for: indexPath) as! HistoryCollectionCell
                cell.historyButton.tag = row
                cell.historyButton.addTarget(self, action: #selector(HistoryViewController.historyButtonPressed(_:)), for: UIControlEvents.touchUpInside)
            case "delete":
                cell = collectionView.dequeueReusableCell(withReuseIdentifier: "History Delete Body Cell", for: indexPath) as! HistoryCollectionCell
                cell.historyButton.tag = row
                cell.historyButton.addTarget(self, action: #selector(HistoryViewController.historyDeletePressed(_:)), for: UIControlEvents.touchUpInside)
                
            default:
                cell = collectionView.dequeueReusableCell(withReuseIdentifier: "History Body Cell", for: indexPath) as! HistoryCollectionCell
                
                ScorecardUI.normalStyle(cell.historyLabel)
                switch displayedFields[column]!.field {
                case "location":
                    cell.historyLabel.text = history.games[row].gameLocation.description
                    locationLabel[row] = cell.historyLabel
                case "date":
                    if scorecard.settingSaveLocation {
                        cell.historyLabel.text = DateFormatter.localizedString(from: history.games[row].datePlayed, dateStyle: .short, timeStyle: .none)
                    } else {
                        let dateString = DateFormatter.localizedString(from: history.games[row].datePlayed, dateStyle: .medium, timeStyle: .none)
                        if ScorecardUI.phoneSize() || !ScorecardUI.landscape() {
                            cell.historyLabel.text = dateString
                        } else {
                            let timeString = DateFormatter.localizedString(from: history.games[row].datePlayed, dateStyle: .none, timeStyle: .short)
                            cell.historyLabel.text = "\(dateString) - \(timeString)"
                        }
                    }
                case "player1", "player2", "player3", "player4":
                    let playerNumber = occurs(displayedFields[column]!.field)
                    if history.games[row].participant.count >= playerNumber {
                        if let email = history.games[row].participant[playerNumber-1].participantMO.email {
                            let name = scorecard.playerName(email)
                            if name == "" {
                                cell.historyLabel.text = history.games[row].participant[playerNumber-1].name
                                cell.historyLabel.textColor = UIColor.lightGray
                            } else {
                                cell.historyLabel.text = name
                            }
                            // Change colour if excluded from stats
                            if history.games[row].participant[playerNumber-1].participantMO.excludeStats {
                                cell.historyLabel.textColor = UIColor.blue
                            }
                        } else {
                            cell.historyLabel.text = ""
                        }
                    } else {
                        cell.historyLabel.text = ""
                    }
                case "score1", "score2", "score3", "score4":
                    let playerNumber = occurs(displayedFields[column]!.field)
                    if history.games[row].participant.count >= playerNumber {
                        cell.historyLabel.text = "\(history.games[row].participant[playerNumber-1].totalScore)"
                        if let email = history.games[row].participant[playerNumber-1].participantMO.email {
                            if scorecard.findPlayerByEmail(email) == nil {
                                cell.historyLabel.textColor = UIColor.lightGray
                            }
                        } else {
                            cell.historyLabel.textColor = UIColor.lightGray
                        }
                    } else {
                        cell.historyLabel.text = ""
                    }
                case "count":
                    cell.historyLabel.text = "\(row+1)/\(history.games[row].participant.count)"
                default:
                    cell.historyLabel.text = ""
                }
                cell.historyLabel.textAlignment = displayedFields[column]!.align
            }
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        var defaultDescending: Bool
        var column: Int
        
        if collectionView.tag >= 1000000 {
            // Header row - sort
            
            if lastColumn != -1 {
                headerCellImageView[lastColumn]!.image = nil
            }
            
            switch displayedFields[indexPath.row]!.field {
            case "date", "score1", "score2", "score3", "score4":
                column = indexPath.row
                defaultDescending = true
            case "player1", "player2", "player3", "player4":
                column = indexPath.row
                defaultDescending = false
            default:
                column = locationColumn
                defaultDescending = false
            }
            
            if lastColumn == column {
                // Same column as last time - reverse the sort
                lastDescending = !lastDescending
            } else {
                // New column - revert to default
                lastDescending = defaultDescending
            }
            lastColumn = column
            headerCellImageView[lastColumn]!.image = UIImage(named: lastDescending ? "down arrow" : "up arrow")
            
            sortList(column: indexPath.row, descending: lastDescending)
            bodyView.reloadData()
            
        } else {
            // Body entry pressed - show detail
            showDetail(collectionView.tag+1)
        }
    }
    
    // MARK: - Collection View Action Handlers ========================================================== -
    
    
    @objc func historyButtonPressed(_ button: UIButton) {
        showDetail(button.tag+1)
    }

    @objc func historyDeletePressed(_ button: UIButton) {
        deleteHistory(button.tag+1)
    }

    // MARK: - Collecton View Utility Routines ========================================================== -
    
    func occurs(_ fieldName: String) -> Int {
        return Int(fieldName.right(1))!
    }
    
    func showDetail(_ gameNumber: Int) {
        selectedGame = gameNumber
        self.performSegue(withIdentifier: "showHistoryDetail", sender: self)
    }
    
    func deleteHistory(_ gameNumber: Int) {
        let historyGame = history.games[gameNumber - 1]
        var locationDescription = historyGame.gameLocation.description
        if locationDescription == nil {
            locationDescription = "unknown location"
        }
        let gameDate = Utility.dateString(historyGame.datePlayed)
        self.alertDecision("Are you sure you want to delete this game at \(locationDescription!) on \(gameDate)", title: "Warning", okButtonText: "Delete", okHandler: {
        })
        if !CoreData.update(updateLogic: {
            // First delete participants
            for historyParticipant in historyGame.participant {
                CoreData.delete(record: historyParticipant.participantMO)
            }
            // Now delete game
            CoreData.delete(record: historyGame.gameMO)
        }) {
            self.alertMessage("Error deleting game")
            return
        }
        history.games.remove(at: gameNumber - 1)
        bodyView.reloadData()
    }
    
    func sortList(column: Int, descending: Bool = true) {
        
        func sortCriteria(sort1: HistoryGame, sort2: HistoryGame) -> Bool {
            var result: Bool
            
            switch displayedFields[column]!.field {
            case "date":
                result =  sort1.datePlayed > sort2.datePlayed
            case "player1", "player2", "player3", "player4":
                let playerNumber = occurs(displayedFields[column]!.field)
                if sort1.participant == nil || playerNumber > sort1.participant.count {
                    result = false
                } else if sort2.participant == nil || playerNumber > sort2.participant.count {
                    result = true
                } else {
                    result = sort1.participant[playerNumber-1].name > sort2.participant[playerNumber-1].name
                }
            case "score1", "score2", "score3", "score4":
                let playerNumber = occurs(displayedFields[column]!.field)
                if sort1.participant == nil || playerNumber > sort1.participant.count {
                    result = false
                } else if sort2.participant == nil || playerNumber > sort2.participant.count {
                    result = true
                } else {
                    result = sort1.participant[playerNumber-1].totalScore > sort2.participant[playerNumber-1].totalScore
                }
            default:
                result = sort1.gameLocation.description > sort2.gameLocation.description
            }
            
            if !descending {
                result = !result
            }
            
            return result
        }
        
        history.loadAllParticipants()
        history.games.sort(by: sortCriteria)
        
    }
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -


class HistoryTableCell: UITableViewCell {
    
    @IBOutlet weak var historyCollection: UICollectionView!
    
    func setCollectionViewDataSourceDelegate
        <D: UICollectionViewDataSource & UICollectionViewDelegate>
        (_ dataSourceDelegate: D, forRow row: Int) {
        
        historyCollection.delegate = dataSourceDelegate
        historyCollection.dataSource = dataSourceDelegate
        historyCollection.tag = row
        historyCollection.reloadData()
    }
}

class HistoryCollectionCell: UICollectionViewCell {
    @IBOutlet weak var historyLabel: UILabel!
    @IBOutlet weak var historyButton: UIButton!
    @IBOutlet weak var sortArrowImage: UIImageView!
}


