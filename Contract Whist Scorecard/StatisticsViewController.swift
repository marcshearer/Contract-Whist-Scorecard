//
//  StatisticsViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 12/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

protocol StatisticsDelegate : class {
    
    func deletePlayer(_ playerDetail: PlayerDetail)
    
    func updatePlayer(_ playerDetail: PlayerDetail)
    
}

class StatisticsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    // MARK: - Class Properties ======================================================================== -
    
    // Main state properties
    var scorecard: Scorecard!

    // Local class variables
    let availableFields = [
        Field("name",         "Player Name",      sequence: 1,     width: 80),
        Field("detail",       "",                 sequence: 13,    width: 40),
        Field("gamesPlayed",  "Games Played",     sequence: 2,     width: 75),
        Field("gamesWon%",    "Games Won %",      sequence: 4,     width: 75),
        Field("gamesWon",     "Games Won",        sequence: 3,     width: 75),
        Field("graph",        "",                 sequence: 12,    width: 50),
        Field("thumbnail",    "",                 sequence: 0,     width: 60),
        Field("averageScore", "Average Score",    sequence: 6,     width: 75),
        Field("handsMade%",   "Hands Made %",     sequence: 9,     width: 75),
        Field("twosMade%",    "Twos Made %",      sequence: 11,    width: 75 , hide: true),
        Field("totalScore",   "Total Score",      sequence: 5,     width: 75),
        Field("handsMade",    "Hands Made",       sequence: 8,     width: 75),
        Field("twosMade",     "Twos Made",        sequence: 10,    width: 75 , hide: true),
        Field("handsPlayed",  "Hands Played",     sequence: 7,     width: 75),
    ]


    var displayedFields: [Field] = []
    var buttonColumn = 0
    var thumbnailColumn = -1
    var firstTime = true
    var lastColumn = -1
    var nameColumn = 0
    var lastDescending = false
    private var observer: NSObjectProtocol?
    private let graphView = GraphView()
    
    // Cell sizes
    let paddingWidth: CGFloat = 20.0
    var carryWidth:CGFloat = 0.0
    
    // Properties to pass state to / from segues
    var playerDetail: PlayerDetail!
    var selectedPlayer: Int = 0
    var selectedList: [PlayerDetail]!
    weak var delegate: StatisticsDelegate?
    var returnSegue = ""
    var backText = "Back"
    var backImage = "back"
    
    // UI component pointers
    var headerCellImageView: [UIImageView?] = []
    var collectionView: [UICollectionView?] = []

    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet var headerView: UITableView!
    @IBOutlet var bodyView: UITableView!
    @IBOutlet var syncButton: RoundedButton!
    @IBOutlet var finishButton: UIButton!
       
    // MARK: - IB Unwind Segue Handlers ================================================================ -
    
    @IBAction func hideStatisticsPlayerDetail(segue:UIStoryboardSegue) {
    }
    
    @IBAction func hideStatisticsSync(segue:UIStoryboardSegue) {
        // Refresh screen
        scorecard.refreshPlayerDetailList(selectedList)
        bodyView.reloadData()
    }

    @IBAction func hideStatisticsGraph(segue:UIStoryboardSegue) {
    }

    // MARK: - IB Actions ============================================================================== -

    @IBAction func finishPressed(_ sender: UIButton) {
        self.performSegue(withIdentifier: returnSegue, sender: self )
        NotificationCenter.default.removeObserver(observer!)
    }
    
    @IBAction func syncPressed(_ sender: UIButton) {
        self.performSegue(withIdentifier: "showStatisticsSync", sender: self)
    }
    
    @IBAction func leftSwipe(recognizer:UISwipeGestureRecognizer) {
        if recognizer.state == .ended {
            finishPressed(finishButton)
        }
    }
    
    // MARK: - View Overrides ========================================================================== -

    override func viewDidLoad() {
        super.viewDidLoad()
        
        for _ in 1...selectedList.count {
            collectionView.append(nil)
        }
        
        // Check for network / iCloud login
        scorecard.checkNetworkConnection(button: syncButton, label: nil)
        
        // Set nofification for image download
        observer = setImageDownloadNotification()
        
        // Format finish button
        finishButton.setImage(UIImage(named: self.backImage), for: .normal)
        finishButton.setTitle(self.backText, for: .normal)
        
    }
    
    override func viewWillLayoutSubviews() {
        if firstTime {
            checkFieldDisplay(to: self.view.safeAreaLayoutGuide.layoutFrame.size)
            firstTime = true
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
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
            return selectedList.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell: StatisticsTableCell
        
        // Player names
    
        switch tableView.tag {
        case 1:
            // Header table view
            cell = tableView.dequeueReusableCell(withIdentifier: "Statistics Header Table Cell", for: indexPath) as! StatisticsTableCell
            ScorecardUI.sectionHeadingStyle(cell)
            cell.setCollectionViewDataSourceDelegate(self, forRow: 1000000+indexPath.row)
        default:
            // Body table view
            cell = tableView.dequeueReusableCell(withIdentifier: "Statistics Body Table Cell", for: indexPath) as! StatisticsTableCell
            ScorecardUI.normalStyle(cell)
            cell.setCollectionViewDataSourceDelegate(self, forRow: indexPath.row)
            collectionView[indexPath.row] = cell.statisticsCollection
        }

        return cell
    }
    
    // MARK: - Form Presentation / Handling Routines =================================================== -
    
    func checkFieldDisplay(to size: CGSize) {
        // Check how many fields we can display
        var skipping = false
        let availableWidth = size.width - paddingWidth // Allow for padding each end and detail button
        var widthRemaining = availableWidth
        var nameColumn = 0
        displayedFields.removeAll()
        
        for field in 0...availableFields.count-1 {
            if !availableFields[field].hide || scorecard.settingBonus2 {
                
                // Include if space and not already skipping
                if !skipping {
                    if availableFields[field].width <= widthRemaining {
                        widthRemaining -= availableFields[field].width
                        displayedFields.append(Field(availableFields[field].field,
                                                                   availableFields[field].title,
                                                                   sequence: availableFields[field].sequence,
                                                                   width: availableFields[field].width,
                                                                   align: availableFields[field].align))
                    } else {
                        skipping = true
                    }
                }
            }
        }
        
        // Sort selected columns by sequence
        displayedFields.sort(by: { $0.sequence < $1.sequence })
        
        // Look for special fields
        for field in 0...displayedFields.count-1 {
            switch displayedFields[field].field {
            case "name":
                nameColumn = field
            case "detail":
                buttonColumn = field
            case "thumbnail":
                thumbnailColumn = field
            default:
                break
            }
        }
        
        // Distribute any remaining width
        if widthRemaining > 0 && nameColumn != 0 {
            // Use up to 100 on name column
            displayedFields[nameColumn].width += min(100, widthRemaining)
            widthRemaining = max(0, widthRemaining - 100)
        }
        
        // Use up remainder on extra blank last column
        displayedFields.append(Field("padding",  "", width: paddingWidth + widthRemaining))
        
        // Set up array to point at sort arrow images
        for _ in 1...displayedFields.count {
            headerCellImageView.append(nil)
        }
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
    
    func updateImage(objectID: NSManagedObjectID) {
        // Find any cells containing an image which has just been downloaded asynchronously
        if self.thumbnailColumn >= 0 {
             Utility.mainThread {
                let index = self.selectedList.index(where: {($0.objectID == objectID)})
                if index != nil {
                    // Found it - update from managed object and reload the cell
                    self.selectedList[index!].fromManagedObject(playerMO: self.selectedList[index!].playerMO)
                    self.collectionView[index!]?.reloadItems(at: [IndexPath(row: self.thumbnailColumn, section: 0)])
                }
            }
        }
    }
    
    // MARK: - Draw graph ============================================================================== -
    
    func drawGraph(_ playerNumber: Int) {
        selectedPlayer = playerNumber
        self.performSegue(withIdentifier: "showGraph", sender: self)
    }
    
    // MARK: - Segue Prepare Handler =================================================================== -
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier! {
        case "showPlayerDetail":
            let destination = segue.destination as! PlayerDetailViewController

            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.isModalInPopover = true
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = self.view as UIView
            destination.preferredContentSize = CGSize(width: 400, height: 540)

            destination.playerDetail = selectedList[selectedPlayer - 1]
            destination.returnSegue = "hideStatisticsPlayerDetail"
            destination.mode = .display
            destination.scorecard = self.scorecard

        case "showStatisticsSync":
            let destination = segue.destination as! SyncViewController

            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.isModalInPopover = true
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = self.view
            destination.preferredContentSize = CGSize(width: 400, height: 523)

            destination.returnSegue = "hideStatisticsSync"
            destination.scorecard = self.scorecard

        case "showGraph":
            let destination = segue.destination as! GraphViewController
            let defaultRect = GraphView.defaultViewRect()

            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = self.view as UIView
            destination.preferredContentSize = CGSize(width: defaultRect.width, height: defaultRect.height)

            destination.playerDetail = selectedList[selectedPlayer - 1]
            destination.returnSegue = "hideStatisticsGraph"
            destination.scorecard = self.scorecard

        default:
            break
        }
    }
}

// MARK: - Extension Override Handlers ============================================================= -

extension StatisticsViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    // MARK: - CollectionView Overrides ================================================================ -
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return displayedFields.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let totalHeight: CGFloat = collectionView.bounds.size.height
        var width = displayedFields[indexPath.row].width
        
        // Put player name above thumbnail as well
        if collectionView.tag >= 1000000 {
            if displayedFields[indexPath.row].field == "thumbnail" {
                carryWidth = width
                width = 0
            } else {
                width += carryWidth
                carryWidth = 0
            }
        }
            
        return CGSize(width: width, height: totalHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var cell: StatisticsCollectionCell
        
        if collectionView.tag >= 1000000 {
            
            // Header
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Statistics Header Cell", for: indexPath) as! StatisticsCollectionCell
            cell.sortArrowImage.image = nil
            
            ScorecardUI.sectionHeadingStyle(cell.statisticsLabel)
            cell.statisticsLabel.text = displayedFields[indexPath.row].title
            cell.statisticsLabel.textAlignment = displayedFields[indexPath.row].align
            if displayedFields[indexPath.row].field == "name" {
                cell.sortArrowImage.image = UIImage(named: "up arrow")
                lastColumn = indexPath.row
            }
            headerCellImageView[indexPath.row] = cell.sortArrowImage
            
        } else {
            
            // Body
            switch displayedFields[indexPath.row].field {
            case "detail":
                cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Statistics Detail Body Cell", for: indexPath) as! StatisticsCollectionCell
                cell.statisticsButton.tag = collectionView.tag
                cell.statisticsButton.addTarget(self, action: #selector(StatisticsViewController.statisticsDetailButtonPressed(_:)), for: UIControl.Event.touchUpInside)
                cell.statisticsButton.isEnabled = true
            case "graph":
                cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Statistics Graph Body Cell", for: indexPath) as! StatisticsCollectionCell
                cell.statisticsButton.tag = collectionView.tag
                cell.statisticsButton.addTarget(self, action: #selector(StatisticsViewController.statisticsGraphButtonPressed(_:)), for: UIControl.Event.touchUpInside)
                cell.statisticsButton.isEnabled = (selectedList[collectionView.tag].handsPlayed > 0 && selectedList[collectionView.tag].datePlayed >= Utility.dateFromString("01/04/2017")!)
            case "thumbnail":
                cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Statistics Image Body Cell", for: indexPath) as! StatisticsCollectionCell
                Utility.setThumbnail(data: selectedList[collectionView.tag].thumbnail,
                                     imageView: cell.statisticsImage,
                                     initials: selectedList[collectionView.tag].name,
                                     label: cell.statisticsDisc)
            default:
                cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Statistics Body Cell", for: indexPath) as! StatisticsCollectionCell
                ScorecardUI.normalStyle(cell.statisticsLabel)
                switch displayedFields[indexPath.row].field {
                case "name":
                    cell.statisticsLabel.text = selectedList[collectionView.tag].name
                    nameColumn = indexPath.row
                case "gamesPlayed":
                    cell.statisticsLabel.text = "\(Int(selectedList[collectionView.tag].gamesPlayed))"
                case "gamesWon":
                    cell.statisticsLabel.text = "\(Int(selectedList[collectionView.tag].gamesWon))"
                case "gamesWon%":
                    cell.statisticsLabel.text = "\(Utility.roundPercent(selectedList[collectionView.tag].gamesWon, selectedList[collectionView.tag].gamesPlayed)) %"
                case "totalScore":
                    cell.statisticsLabel.text = "\(Int(selectedList[collectionView.tag].totalScore))"
                case "averageScore":
                    cell.statisticsLabel.text = "\(Utility.roundQuotient(selectedList[collectionView.tag].totalScore,selectedList[collectionView.tag].gamesPlayed))"
                case "handsPlayed":
                    cell.statisticsLabel.text = "\(Int(selectedList[collectionView.tag].handsPlayed))"
                case "handsMade":
                    cell.statisticsLabel.text = "\(Int(selectedList[collectionView.tag].handsMade))"
                case "handsMade%":
                    cell.statisticsLabel.text = "\(Utility.roundPercent(selectedList[collectionView.tag].handsMade, selectedList[collectionView.tag].handsPlayed)) %"
                case "twosMade":
                    cell.statisticsLabel.text = "\(Int(selectedList[collectionView.tag].twosMade))"
                case "twosMade%":
                    cell.statisticsLabel.text = "\(Utility.roundPercent(selectedList[collectionView.tag].twosMade,    selectedList[collectionView.tag].handsPlayed)) %"
                default:
                    cell.statisticsLabel.text = ""
                }
                cell.statisticsLabel.textAlignment = displayedFields[indexPath.row].align
            }
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        
        let field = displayedFields[indexPath.row].field
        
        return (field != "detail" && field != "graph")
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        var defaultDescending: Bool
        var column: Int
        
        if collectionView.tag >= 1000000 {
            // Header row - sort
            
            if lastColumn != -1 {
                headerCellImageView[lastColumn]!.image = nil
            }
            
            let field = displayedFields[indexPath.row].field
            if field == "name" || field == "thumbnail" || field == "detail" {
                // Treat all the same and default to ascending
                column = nameColumn
                defaultDescending = false
            } else {
                // Data column - default to descending
                column = indexPath.row
                defaultDescending = true
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
            // Body entry pressed - amend player
            showDetail(collectionView.tag+1)
        }
    }
    
    // MARK: - Collection View Action Handlers ========================================================== -
    
    @objc func statisticsDetailButtonPressed(_ button: UIButton) {
        showDetail(button.tag + 1)
    }
    
    @objc func statisticsGraphButtonPressed(_ button: UIButton) {
        drawGraph(button.tag + 1)
    }
    
    // MARK: - Collecton View Utility Routines ========================================================== -

    func showDetail(_ playerNumber: Int) {
        selectedPlayer = playerNumber
        self.performSegue(withIdentifier: "showPlayerDetail", sender: self)
    }
    
    func updateTags() {
        // Assume anything could have disappeared so check if not nil
        // Presumably it will be recreated correctly when the cells are dequeued
        let tableRows = bodyView.numberOfRows(inSection: 0)
        for playerDetailLoop in 1...tableRows{
            let tableCell = bodyView.cellForRow(at: IndexPath(row: playerDetailLoop-1, section: 0)) as! StatisticsTableCell?
            if tableCell != nil {
                let collectionView:UICollectionView? = tableCell!.statisticsCollection
                if collectionView != nil {
                    collectionView!.tag = playerDetailLoop-1
                    let collectionCell = collectionView!.cellForItem(at: IndexPath(row: buttonColumn, section: 0)) as! StatisticsCollectionCell?
                    if collectionCell != nil {
                        collectionCell!.statisticsButton.tag = playerDetailLoop-1
                    }
                }
            }
        }
    }
    
    func sortList(column: Int, descending: Bool = true) {
        
        func sortCriteria(sort1: PlayerDetail, sort2: PlayerDetail) -> Bool {
            var result: Bool
            
            switch displayedFields[column].field {
            case "gamesPlayed":
                result = sort1.gamesPlayed > sort2.gamesPlayed
            case "gamesWon":
                result =  sort1.gamesWon > sort2.gamesWon
            case "gamesWon%":
                result = Utility.roundPercent(sort1.gamesWon, sort1.gamesPlayed) > Utility.roundPercent(sort2.gamesWon, sort2.gamesPlayed)
            case "totalScore":
                result = sort1.totalScore > sort2.totalScore
            case "averageScore":
                result = Utility.roundPercent(sort1.totalScore, sort1.gamesPlayed) > Utility.roundPercent(sort2.totalScore, sort2.gamesPlayed)
            case "handsPlayed":
                result = sort1.handsPlayed > sort2.handsPlayed
            case "handsMade":
                result = sort1.handsMade > sort2.handsMade
            case "handsMade%":
                result = Utility.roundPercent(sort1.handsMade, sort1.handsPlayed) > Utility.roundPercent(sort2.handsMade, sort2.handsPlayed)
            case "twosMade":
                result = sort1.twosMade > sort2.twosMade
            case "twosMade%":
                result = Utility.roundPercent(sort1.twosMade, sort1.handsPlayed) > Utility.roundPercent(sort2.twosMade, sort2.handsPlayed)
            default:
                result = sort1.name > sort2.name
            }
            
            if !descending {
                result = !result
            }
            
            return result
        }
        
        selectedList.sort(by: sortCriteria)
        
    }
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -


class StatisticsTableCell: UITableViewCell {
    
    @IBOutlet weak var statisticsCollection: UICollectionView!
    
    func setCollectionViewDataSourceDelegate
        <D: UICollectionViewDataSource & UICollectionViewDelegate>
        (_ dataSourceDelegate: D, forRow row: Int) {
        
        statisticsCollection.delegate = dataSourceDelegate
        statisticsCollection.dataSource = dataSourceDelegate
        statisticsCollection.tag = row
        statisticsCollection.reloadData()
    }
}

class StatisticsCollectionCell: UICollectionViewCell {
    @IBOutlet weak var statisticsLabel: UILabel!
    @IBOutlet weak var statisticsButton: UIButton!
    @IBOutlet weak var statisticsImage: UIImageView!
    @IBOutlet weak var statisticsDisc: UILabel!
    @IBOutlet weak var sortArrowImage: UIImageView!
}

