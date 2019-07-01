//
//  DataTableViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 12/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

@objc public protocol DataTableViewerDataSource {
    func value(forKey: String) -> Any?
}

@objc public protocol DataTableViewerDelegate : class {
    
    var availableFields: [DataTableField] { get }
    @objc optional var allowSync: Bool { get }
    @objc optional var viewTitle: String { get }
    @objc optional var nameField: String { get }
    @objc optional var initialSortField: String { get }
    @objc optional var initialSortDescending: Bool {get}
    @objc optional var headerRowHeight: CGFloat { get }
    @objc optional var bodyRowHeight: CGFloat { get }
    @objc optional var separatorHeight: CGFloat { get }
    
    @objc optional func didSelect(record: DataTableViewerDataSource, field: String)
    
    @objc optional func derivedField(field: String, record: DataTableViewerDataSource, sortValue: Bool) -> String
    
    @objc optional func refreshData(recordList: [DataTableViewerDataSource])
    
    @objc optional func isEnabled(button: String, record: DataTableViewerDataSource) -> Bool
    
    @objc optional func hideField(field: String) -> Bool
    
    @objc optional func completion()
    
}

class DataTableViewController: CustomViewController, UITableViewDataSource, UITableViewDelegate {
    
    // MARK: - Class Properties ======================================================================== -
    
    // Main state properties
    var scorecard: Scorecard!

    var displayedFields: [DataTableField] = []
    var firstTime = true
    var lastSortColumn = -1
    var lastSortField = ""
    var lastSortDescending = false
    private let graphView = GraphView()
    private var padColumn = -1
    
    // Cell sizes
    let paddingWidth: CGFloat = 20.0
    
    // Properties to control how viewer works
    private var recordList: [DataTableViewerDataSource]!
    private var delegate: DataTableViewerDelegate?
    private var backText = "Back"
    private var backImage = "back"
    
    // UI component pointers
    var headerCollectionView: UICollectionView!
    var collectionView: [UICollectionView?] = []

    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet var headerView: UITableView!
    @IBOutlet var bodyView: UITableView!
    @IBOutlet var syncButton: RoundedButton!
    @IBOutlet var finishButton: UIButton!
    @IBOutlet var navigationHeaderItem: UINavigationItem!
    @IBOutlet var headerHeightConstraint: NSLayoutConstraint!
    @IBOutlet var leftPaddingHeightConstraint: NSLayoutConstraint!
    @IBOutlet var rightPaddingHeightConstraint: NSLayoutConstraint!

    // MARK: - IB Unwind Segue Handlers ================================================================ -
    
    @IBAction func hideDataTableSync(segue:UIStoryboardSegue) {
        // Refresh screen
        self.delegate?.refreshData?(recordList: self.recordList)
        bodyView.reloadData()
    }

    // MARK: - IB Actions ============================================================================== -

    @IBAction func finishPressed(_ sender: UIButton) {
        self.dismiss(animated: true, completion: self.delegate?.completion)
    }
    
    @IBAction func syncPressed(_ sender: UIButton) {
        self.performSegue(withIdentifier: "showDataTableSync", sender: self)
    }
    
    @IBAction func rightSwipe(recognizer:UISwipeGestureRecognizer) {
        if recognizer.state == .ended {
            finishPressed(finishButton)
        }
    }
    
    // MARK: - method to show this view controller ============================================================================== -
    
    static public func show(from sourceViewController: UIViewController, delegate: DataTableViewerDelegate, scorecard: Scorecard, recordList: [DataTableViewerDataSource]) -> DataTableViewController {
        let storyboard = UIStoryboard(name: "DataTableViewController", bundle: nil)
        let dataTableviewController = storyboard.instantiateViewController(withIdentifier: "DataTableViewController") as! DataTableViewController
        dataTableviewController.recordList = recordList
        dataTableviewController.delegate = delegate
        dataTableviewController.scorecard = scorecard
        sourceViewController.present(dataTableviewController, animated: true, completion: nil)
        
        return dataTableviewController
    }
    
    // MARK: - View Overrides ========================================================================== -

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if recordList.count > 0 {
            for _ in 1...recordList.count {
                collectionView.append(nil)
            }
        }
        
        // Check for network / iCloud login
        if self.delegate?.allowSync ?? true {
            scorecard.checkNetworkConnection(button: syncButton, label: nil)
        } else {
            syncButton.isHidden = true
        }
        
        // Format finish button
        finishButton.setImage(UIImage(named: self.backImage), for: .normal)
        finishButton.setTitle(self.backText, for: .normal)
        
        // Set initial sort (if any)
        self.lastSortField = self.delegate?.initialSortField ?? ""
        self.lastSortDescending = self.delegate?.initialSortDescending ?? false
        
        // Set title
        self.navigationHeaderItem.title = self.delegate?.viewTitle ?? ""
        
        // Set header / padding heights
        self.headerHeightConstraint.constant = self.delegate?.headerRowHeight ?? 44.0
        self.leftPaddingHeightConstraint.constant = self.headerHeightConstraint.constant - 10.0
        self.rightPaddingHeightConstraint.constant = self.headerHeightConstraint.constant - 10.0
        
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        print("Sort \(lastSortColumn) \(lastSortField)")
        self.clearSortArrows()
        super.viewWillTransition(to: size, with: coordinator)
        self.view.setNeedsLayout()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        checkFieldDisplay(to: self.view.safeAreaLayoutGuide.layoutFrame.size)
        headerView.reloadData()
        bodyView.reloadData()
        headerView.layoutIfNeeded()
        firstTime = true
    }
    
    // MARK: - Method to refresh a specific row in the table view====================================== -
    
    public func refreshRows(at indexPaths: [IndexPath]) {
        self.bodyView.reloadRows(at: indexPaths, with: .fade)
    }
    
    public func deleteRows(at indexPaths: [IndexPath]) {
        self.bodyView.beginUpdates()
        for indexPath in indexPaths {
            self.recordList.remove(at: indexPath.row)
        }
        self.bodyView.deleteRows(at: indexPaths, with: .fade)
        self.bodyView.endUpdates()
    }

    // MARK: - TableView Overrides ===================================================================== -

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch tableView.tag {
        case 1:
            return 1
        default:
            return recordList.count
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch tableView.tag {
        case 1:
            // Header table view
            return self.delegate?.headerRowHeight ?? 44.0
        default:
            // Body table view
            return self.delegate?.bodyRowHeight ?? 44.0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell: DataTableCell
    
        switch tableView.tag {
        case 1:
            // Header table view
            cell = tableView.dequeueReusableCell(withIdentifier: "Data Table Header Cell", for: indexPath) as! DataTableCell
            cell.setCollectionViewDataSourceDelegate(self, forRow: 1000000+indexPath.row)
            self.headerCollectionView = cell.dataTableCollection
        default:
            // Body table view
            cell = tableView.dequeueReusableCell(withIdentifier: "Data Table Body Cell", for: indexPath) as! DataTableCell
            ScorecardUI.normalStyle(cell)
            cell.setCollectionViewDataSourceDelegate(self, forRow: indexPath.row)
            cell.separatorHeightConstraint.constant = self.delegate?.separatorHeight ?? 1.0
            collectionView[indexPath.row] = cell.dataTableCollection
        }

        return cell
    }
    
    // MARK: - Form Presentation / Handling Routines =================================================== -
    
    func checkFieldDisplay(to size: CGSize) {
        // Check how many fields we can display
        var skipping = false
        let availableWidth = size.width - paddingWidth // Allow for padding each end and detail button
        var widthRemaining = availableWidth
        displayedFields.removeAll()
        
        if let columns = self.delegate?.availableFields {
            for column in columns {
                if !(self.delegate?.hideField?(field: column.field) ?? false) {
                    
                    // Include if space and not already skipping
                    if !skipping {
                        if column.width <= widthRemaining {
                            widthRemaining -= column.width
                            displayedFields.append(DataTableField(column.field,
                                                                       column.title,
                                                                       sequence: column.sequence,
                                                                       width: column.width,
                                                                       type: column.type,
                                                                       align: column.align,
                                                                       pad: column.pad,
                                                                       combineHeading: column.combineHeading))
                        } else {
                            skipping = true
                        }
                    }
                }
            }
        }
        // Sort selected columns by sequence
        displayedFields.sort(by: { $0.sequence < $1.sequence })
        
        // Find and expand pad column
        if widthRemaining > 0 {
            if let index = displayedFields.firstIndex(where: { $0.pad }) {
                displayedFields[index].width += min(100, widthRemaining)
                widthRemaining = max(0, widthRemaining - 100)
            }
        }
        
        // Use up remainder on extra blank last column
        displayedFields.append(DataTableField("",  "", width: paddingWidth + widthRemaining, type: .string))
    }
    
    // MARK: - Segue Prepare Handler =================================================================== -
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier! {
        
        case "showDataTableSync":
            let destination = segue.destination as! SyncViewController

            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.isModalInPopover = true
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = self.view
            destination.preferredContentSize = CGSize(width: 400, height: 523)

            destination.returnSegue = "hideDataTableSync"
            destination.scorecard = self.scorecard

        default:
            break
        }
    }
}

// MARK: - Extension Override Handlers ============================================================= -

extension DataTableViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    // MARK: - CollectionView Overrides ================================================================ -
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return displayedFields.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let totalHeight: CGFloat = collectionView.bounds.size.height
        let column = displayedFields[indexPath.row]
        var width = column.width
        
        // Combine any headings as requested
        if collectionView.tag >= 1000000 {
            if let index = displayedFields.firstIndex(where: { $0.combineHeading == column.title }) {
                if abs(index - indexPath.row) == 1 {
                    // Is adjacent - combine
                    width += displayedFields[index].width
                }
            }
            if column.combineHeading != "" {
                if let index = displayedFields.firstIndex(where: { $0.title == column.combineHeading } ) {
                    if abs(index - indexPath.row) == 1 {
                        // Is adjacent - combine
                        width = 0
                    }
                }
            }
        }
        
        return CGSize(width: width, height: totalHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var cell: DataTableCollectionCell
        
        let column = displayedFields[indexPath.row]
        
        if collectionView.tag >= 1000000 {
            
            // Header
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Data Table Header Cell", for: indexPath) as! DataTableCollectionCell
            cell.tag = indexPath.row

            ScorecardUI.sectionHeadingStyle(cell.textLabel)
            cell.headerUpArrowView.backgroundColor = ScorecardUI.sectionHeadingColor
            cell.textLabel.text = column.title
            cell.textLabel.textAlignment = column.align
            
            // Sort arrow
            cell.setupArrows()
            if column.field == lastSortField {
                lastSortColumn = indexPath.row
                self.showSortArrow(cell)
            }
            
        } else {
            
            // Body
            
            let record = recordList[collectionView.tag]
            
            switch displayedFields[indexPath.row].type {
            case .button:
                cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Data Table Body Button Cell", for: indexPath) as! DataTableCollectionCell
                cell.bodyButton.tag = (collectionView.tag * 1000) + indexPath.row
                cell.bodyButton.addTarget(self, action: #selector(DataTableViewController.buttonPressed(_:)), for: UIControl.Event.touchUpInside)
                cell.bodyButton.setImage(UIImage(named: column.field), for: .normal)
                cell.bodyButton.setTitle(column.field, for: .normal)
                cell.bodyButton.contentMode = .scaleAspectFill
                cell.bodyButton.isEnabled = self.delegate?.isEnabled?(button: column.field, record: recordList[collectionView.tag]) ?? true
            case .thumbnail:
                cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Data Table Body Thumbnail Cell", for: indexPath) as! DataTableCollectionCell
                
                var data: Data?
                if let content = record.value(forKey: column.field) {
                    if !(content is NSNull) {
                        data = content as? Data
                    }
                }
                
                var name = ""
                if let nameField = self.delegate?.nameField {
                    name = record.value(forKey: nameField) as! String
                }
                Utility.setThumbnail(data: data,
                                     imageView: cell.bodyThumbnailImage,
                                     initials: name,
                                     label: cell.bodyThumbnailDisc)
            default:
                cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Data Table Body Normal Cell", for: indexPath) as! DataTableCollectionCell
                ScorecardUI.normalStyle(cell.textLabel)
                cell.textLabel.text = self.getValue(record: record, column: column)
                cell.textLabel.textAlignment = displayedFields[indexPath.row].align
            }
            cell.resetArrows()
        }
        
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        
        let column = displayedFields[indexPath.row]
        
        return (column.type != .button)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        var defaultDescending: Bool
        var sortColumn: Int
        
        if collectionView.tag >= 1000000 {
            // Header row - sort

            self.clearSortArrows()

            let cell = collectionView.cellForItem(at: indexPath) as! DataTableCollectionCell
            
            let column = displayedFields[indexPath.row]
            
            sortColumn = indexPath.row
            
            if column.type == .string {
                defaultDescending = false
            } else {
                defaultDescending = true
            }
            
            if lastSortColumn == sortColumn {
                // Same column as last time - reverse the sort
                lastSortDescending = !lastSortDescending
            } else {
                // New column - revert to default
                lastSortDescending = defaultDescending
            }
            
            lastSortColumn = sortColumn
            lastSortField = column.field
            
            self.showSortArrow(cell)

            sortList(column: indexPath.row, descending: lastSortDescending)
            bodyView.reloadData()
            
        } else {
            // Body entry pressed - show detail
            showDetail(collectionView.tag)
        }
    }
    
    // MARK: - Collecton View Utility Routines ========================================================== -

    @objc internal func buttonPressed(_ button: UIButton) {
        let column = button.tag % 1000
        let row = button.tag / 1000
        self.delegate?.didSelect?(record: recordList[row], field: displayedFields[column].field)
    }
    
    func showDetail(_ row: Int) {
        self.delegate?.didSelect?(record: self.recordList[row], field: "")
    }
    
    func updateTags() {
        // Assume anything could have disappeared so check if not nil
        // Presumably it will be recreated correctly when the cells are dequeued
        let tableRows = bodyView.numberOfRows(inSection: 0)
        for recordNumber in 0..<tableRows {
            let tableCell = bodyView.cellForRow(at: IndexPath(row: recordNumber, section: 0)) as! DataTableCell?
            if tableCell != nil {
                let collectionView:UICollectionView? = tableCell!.dataTableCollection
                if collectionView != nil {
                    collectionView!.tag = recordNumber
                    for (columnNumber, column) in self.displayedFields.enumerated() {
                        if column.type == .button {
                            if let collectionCell = collectionView!.cellForItem(at: IndexPath(row: columnNumber, section: 0)) as! DataTableCollectionCell? {
                                collectionCell.bodyButton.tag = recordNumber * 1000 + columnNumber
                            }
                        }
                    }
                }
            }
        }
    }
    
    func sortList(column: Int, descending: Bool = true) {
        
        func sortCriteria(sort1: DataTableViewerDataSource, sort2: DataTableViewerDataSource) -> Bool {
            var result: Bool
            
            let column = displayedFields[column]
            let value1 = self.getValue(record: sort1, column: column, sortValue: true)
            let value2 = self.getValue(record: sort2, column: column, sortValue: true)

            result = value1 > value2
            
            if !descending {
                result = !result
            }
            
            return result
        }
        
        recordList.sort(by: sortCriteria)
        
    }
    
    private func showSortArrow(_ sortCell: DataTableCollectionCell) {
        if lastSortColumn != -1 {
            if lastSortDescending {
                sortCell.headerDownArrowShape.isHidden = false
            } else {
                sortCell.headerUpArrowShape.isHidden = false
            }
        }
    }
    
    private func clearSortArrows() {
        if lastSortColumn != -1 {
            let sortCell = headerCollectionView.cellForItem(at: IndexPath(item: lastSortColumn, section: 0)) as! DataTableCollectionCell
            sortCell.headerDownArrowShape.isHidden = true
            sortCell.headerUpArrowShape.isHidden = true
        }
    }
    
    // MARK: - Utility routines to get values ===================================================== -
    
    private func getValue(record: DataTableViewerDataSource, column: DataTableField, sortValue: Bool = false) -> String {
        let derived = (column.field.left(1) == "=")
        if derived {
            return self.delegate?.derivedField?(field: column.field.right(column.field.length - 1), record: record, sortValue: sortValue) ?? ""
        } else {
            if let object = record.value(forKey: column.field) {
                switch column.type {
                case .string:
                    return object as! String
                case .date:
                    if sortValue {
                        let valueString = "\(Int((object as! Date).timeIntervalSinceReferenceDate))"
                        return String(repeating: " ", count: 20 - valueString.count) + valueString
                    } else {
                        return Utility.dateString(object as! Date)
                    }
                case .dateTime:
                    if sortValue {
                        let valueString = "\(Int((object as! Date).timeIntervalSinceReferenceDate))"
                        return String(repeating: " ", count: 20 - valueString.count) + valueString
                    } else {
                        return Utility.dateString(object as! Date, format: "dd/MM/yyyy HH:mm")
                    }
                case .time:
                    if sortValue {
                         let valueString = "\(Int((object as! Date).timeIntervalSinceReferenceDate))"
                        return String(repeating: " ", count: 20 - valueString.count) + valueString
                    } else {
                        return Utility.dateString(object as! Date, format: "HH:mm")
                    }
                case .int, .double:
                    if sortValue {
                        let valueString = String(format: "%.4f", (object as! Double) + 1e14)
                        return String(repeating: " ", count: 20 - valueString.count) + valueString
                    } else {
                        if column.type == .int {
                            return "\(object as! Int)"
                        } else {
                            var number = object as! Double
                            number.round()
                            return "\(Int(number))"
                        }
                    }
                case .bool:
                    return (object as! Bool == true ? "X" : "")
                default:
                    return ""
                }
            } else {
                return ""
            }
        }
    }
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -


class DataTableCell: UITableViewCell {
    
    @IBOutlet weak var dataTableCollection: UICollectionView!
    @IBOutlet weak var separatorHeightConstraint: NSLayoutConstraint!
    
    func setCollectionViewDataSourceDelegate
        <D: UICollectionViewDataSource & UICollectionViewDelegate>
        (_ dataSourceDelegate: D, forRow row: Int) {
        
        dataTableCollection.delegate = dataSourceDelegate
        dataTableCollection.dataSource = dataSourceDelegate
        dataTableCollection.tag = row
        dataTableCollection.reloadData()
    }
}

@objc class DataTableCollectionCell: UICollectionViewCell {
    public var headerUpArrowShape: UIView!
    public var headerDownArrowShape: UIView!

    @IBOutlet weak var textLabel: UILabel!
    @IBOutlet weak var headerUpArrowView: UIView!
    @IBOutlet weak var headerDownArrowView: UIView!
    @IBOutlet weak var bodyButton: UIButton!
    @IBOutlet weak var bodyThumbnailImage: UIImageView!
    @IBOutlet weak var bodyThumbnailDisc: UILabel!
    
    public func resetArrows() {
        if self.headerUpArrowShape != nil {
            self.headerUpArrowShape.removeFromSuperview()
            self.headerUpArrowShape = nil
        }
        if self.headerDownArrowShape != nil {
            self.headerDownArrowShape.removeFromSuperview()
            self.headerDownArrowShape = nil
        }
    }
    
    public func setupArrows() {
        self.resetArrows()
        self.headerUpArrowShape = self.centralArrow(container: self.headerUpArrowView, up: true, color: ScorecardUI.backgroundColor)
        self.headerDownArrowShape = self.centralArrow(container: self.headerDownArrowView, up: false, color: ScorecardUI.sectionHeadingColor)
    }
    
    private func centralArrow(container: UIView, up: Bool, color: UIColor) -> UIView {
        
        var points: [PolygonPoint] = []
        let cellSize = self.frame.size
        let size: CGFloat = container.frame.height
        
        let view = UIView(frame: CGRect(x: (cellSize.width / 2.0) - size, y: 0.0, width: size * 2.0, height: size))
        self.addSubview(view)
        view.isHidden = true

       if up == true {
        points.append(PolygonPoint(x: 0.0, y: container.frame.minY + size))
        points.append(PolygonPoint(x: (size * 2.0), y: container.frame.minY + size))
        points.append(PolygonPoint(x: size, y: container.frame.minY))
        } else {
        points.append(PolygonPoint(x: 0.0, y: container.frame.minY))
        points.append(PolygonPoint(x: (size * 2.0), y: container.frame.minY))
        points.append(PolygonPoint(x: size, y: container.frame.minY + size))
        }
        
        Polygon.roundedShape(in: view, definedBy: points, strokeColor: color, fillColor: color, lineWidth: 1.0, roundingFraction: 0.01)
        
        return view
    }
}

// MARK: - Utility Class for Field Output ==================================================== -

public enum DataTableVariableType {
    case string
    case date
    case dateTime
    case time
    case int
    case double
    case bool
    case button
    case thumbnail
}

@objc public class DataTableField: NSObject {
    var field: String
    var title: String
    var sequence: Int
    var width: CGFloat
    var align: NSTextAlignment
    var type: DataTableVariableType
    var pad: Bool
    var combineHeading: String
    
    init(_ field: String,_ title: String, sequence: Int = 0, width: CGFloat, type: DataTableVariableType, align: NSTextAlignment = .center, pad: Bool = false, combineHeading: String = "") {
        self.field = field
        self.title = title
        self.sequence = sequence
        self.width = width
        self.align = align
        self.type = type
        self.pad = pad
        self.combineHeading = combineHeading
    }
}
