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
    
    @objc optional func derivedField(field: String, record: DataTableViewerDataSource, sortValue: Bool, width: CGFloat) -> String

}

@objc internal protocol DataTableViewerDelegate : AnyObject {
    
    var availableFields: [DataTableField] { get }
    @objc optional var allowSync: Bool { get }
    @objc optional var viewTitle: String { get }
    @objc optional var nameField: String { get }
    @objc optional var initialSortField: String { get }
    @objc optional var initialSortDescending: Bool {get}
    @objc optional var headerRowHeight: CGFloat { get }
    @objc optional var headerTopSpacingHeight: CGFloat { get }
    @objc optional var bodyRowHeight: CGFloat { get }
    @objc optional var separatorHeight: CGFloat { get }
    @objc optional var backImage: String { get }
    @objc optional var backText: String { get }

    @objc optional func setupCustomButton(id: AnyHashable?) -> BannerButton?
    
    @objc optional func setupCustomControls(completion: ()->())
    
    @objc optional func didSelect(record: DataTableViewerDataSource, field: String)
        
    @objc optional func refreshData(recordList: [DataTableViewerDataSource]) -> [DataTableViewerDataSource]
    
    @objc optional func isEnabled(button: String, record: DataTableViewerDataSource) -> Bool
    
    @objc optional func hideField(field: String) -> Bool
    
    @objc optional func completion()
    
    @objc optional func layoutSubviews()
    
    @objc optional func syncButtons(enabled: Bool)
    
    @objc optional func addHelp(to helpView: HelpView, header: UITableView, body: UITableView)

}

class DataTableViewController: ScorecardViewController, UITableViewDataSource, UITableViewDelegate {
    
    // MARK: - Class Properties ======================================================================== -
    
    internal var displayedFields: [DataTableField] = []
    private var firstTime = true
    private var lastSortColumn = -1
    private var lastSortField = ""
    private var lastSortDescending = false
    private let graphView = GraphView()
    private var padColumn = -1
    private var observer: NSObjectProtocol?
    private var finishButton = Banner.finishButton
    private var syncButton = 1
    private var customButton = 2
    internal static var infoImageName = "system.info.circle.fill"
    
    // Cell sizes
    let paddingWidth: CGFloat = 6.0
    
    // Properties to control how viewer works
    private var recordList: [DataTableViewerDataSource]!
    private weak var delegate: DataTableViewerDelegate?
    
    // UI component pointers
    private var headerCollectionView: UICollectionView!
 
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var banner: Banner!
    @IBOutlet private weak var headerView: UITableView!
    @IBOutlet private weak var bodyView: UITableView!
    @IBOutlet private weak var leftPaddingView: UIView!
    @IBOutlet private weak var rightPaddingView: UIView!
    @IBOutlet private weak var headerHeightConstraint: NSLayoutConstraint!
    @IBOutlet public weak var customHeaderView: UIView!
    @IBOutlet public weak var customHeaderViewHeightConstraint: NSLayoutConstraint!
    
    // MARK: - IB Actions ============================================================================== -

    internal func finishPressed() {
        self.dismiss()
    }
    
    internal func syncPressed() {
        self.showSync(self)
    }
    
    @IBAction func rightSwipe(recognizer:UISwipeGestureRecognizer) {
        if recognizer.state == .ended {
            finishPressed()
        }
    }
    
    // MARK: - View Overrides ========================================================================== -

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup default colors (previously done in StoryBoard
        self.defaultViewColors()
        
        if let setupCustomControls = self.delegate?.setupCustomControls {
            setupCustomControls(self.viewDidLoadContinued)
        } else {
            self.viewDidLoadContinued()
        }
    }
        
    private func viewDidLoadContinued() {
        
        // Format finish button
        self.setupBanner()
        
        // Setup help
        self.setupHelpView()
        
        // Check for network / iCloud login
        self.networkEnableSyncButton()
        
        // Set initial sort (if any)
        self.lastSortField = self.delegate?.initialSortField ?? ""
        self.lastSortDescending = self.delegate?.initialSortDescending ?? false
                
        // Set header / padding heights
        self.headerHeightConstraint.constant = self.delegate?.headerRowHeight ?? 44.0
    }
    
    private func setupBanner() {
        let finishImage = UIImage(named: self.delegate?.backImage ?? "home")
        let finishTitle = self.delegate?.backText
        let finishTextWidth = (finishTitle == nil ? 0 : finishTitle!.labelWidth(font: BannerButton.defaultFont) + 8)
        let finishWidth = finishTextWidth + (finishImage != nil ? 22 : 0)
        
        let syncType: BannerButtonType = (ScorecardUI.smallPhoneSize() ? .clear : .shadow)
        let syncTitle = (ScorecardUI.smallPhoneSize() ? nil : "Sync")
        let syncImage = (ScorecardUI.smallPhoneSize() ? UIImage(named: "cloud") : nil)
        let syncWidth = (ScorecardUI.smallPhoneSize() ? 30 : max(syncTitle!.labelWidth(font: BannerButton.defaultFont) + 16, 60))
        
        var leftBannerButtons = [
            BannerButton(title: finishTitle, image: finishImage, width: finishWidth, action: {[weak self] in self?.finishPressed()}, menuHide: true, id: finishButton)]
        
        if let customBannerButton = self.delegate?.setupCustomButton?(id: customButton) {
            leftBannerButtons.append(customBannerButton)
        }

        let rightBannerButtons = [
            BannerButton(action: {[weak self] in self?.helpPressed()}, type: .help),
            BannerButton(title: syncTitle, image: syncImage, width: syncWidth, action: {[weak self] in self?.syncPressed()}, type: syncType, id: syncButton)]
        
        self.banner.set(
            title: (self.delegate?.viewTitle ?? ""),
            leftButtons: leftBannerButtons, leftSpacing: 8,
            rightButtons: rightBannerButtons)
        
     }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        self.clearSortArrows()
        super.viewWillTransition(to: size, with: coordinator)
        self.view.setNeedsLayout()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if let availableFields = self.delegate?.availableFields {
            self.displayedFields = DataTableFormatter.checkFieldDisplay(availableFields, to: self.view.safeAreaLayoutGuide.layoutFrame.size, paddingWidth: paddingWidth, hideField: self.delegate?.hideField)
        } else {
            self.displayedFields = []
        }
        headerView.reloadData()
        bodyView.reloadData()
        firstTime = true
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.customHeaderView.layoutIfNeeded()
        self.delegate?.layoutSubviews?()
    }
    
    // MARK: - Method to refresh data================================================================== -
    
    public func refreshData(recordList: [DataTableViewerDataSource], completion: (()->())? = nil) {
        self.recordList = recordList
        self.bodyView.reloadData()
        completion?()
    }
    
    // MARK: - Utility Routines ======================================================================== -
    
    private func networkEnableSyncButton() {
        self.syncButtons(enabled: (Scorecard.reachability.isConnected))
        self.observer = Scorecard.reachability.startMonitor { (isConnected) in
            self.syncButtons(enabled: isConnected)
        }
    }
            
    private func syncButtons(enabled: Bool) {
        let allowSync = self.delegate?.allowSync ?? true
        self.banner.setButton(syncButton, isHidden: !allowSync || (ScorecardUI.smallPhoneSize() && !enabled), isEnabled: enabled)
        self.delegate?.syncButtons?(enabled: enabled)
    }
    
    // MARK: - Method to refresh a specific row in the table view====================================== -
    
    public func refreshRows(at indexPaths: [IndexPath]) {
        self.bodyView.reloadRows(at: indexPaths, with: .fade)
    }
    
    public func deleteRows(at indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            self.recordList.remove(at: indexPath.row)
        }
        self.bodyView.reloadData()
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
            cell.setCollectionViewDataSourceDelegate(self, forRow: 1000000 + indexPath.row)
            self.headerCollectionView = cell.dataTableCollection
        default:
            // Body table view
            cell = tableView.dequeueReusableCell(withIdentifier: "Data Table Body Cell", for: indexPath) as! DataTableCell
            Palette.normalStyle(cell)
            cell.setCollectionViewDataSourceDelegate(self, forRow: indexPath.row)
            cell.separatorHeightConstraint.constant = self.delegate?.separatorHeight ?? 0.3
        }

        return cell
    }

    // MARK: - Show other views =========================================================== -
    
    @objc public func showSync(_ sender: Any) {
        SyncViewController.show(from: self, completion: {
            // Refresh screen
            if let recordList = self.delegate?.refreshData?(recordList: self.recordList) {
                self.recordList = recordList
                self.bodyView.reloadData()
            }
        })
    }
    
    // MARK: - methods to show/dismiss this view controller ======================================================= -
    
    static public func create(delegate: DataTableViewerDelegate, recordList: [DataTableViewerDataSource], completion: (()->())? = nil) -> DataTableViewController {
        
        let storyboard = UIStoryboard(name: "DataTableViewController", bundle: nil)
        let dataTableViewController = storyboard.instantiateViewController(withIdentifier: "DataTableViewController") as! DataTableViewController
        
        dataTableViewController.recordList = recordList
        dataTableViewController.delegate = delegate
        
        return dataTableViewController
    }
     
    static public func show(_ dataTableViewController: DataTableViewController, from sourceViewController: ScorecardViewController) {

        dataTableViewController.modalPresentationStyle = .fullScreen
        
        sourceViewController.present(dataTableViewController, animated: true, container: .none, completion: nil)
     }
    
    private func dismiss() {
        if self.observer != nil {
            Notifications.removeObserver(self.observer)
            self.observer = nil
        }
        self.dismiss(animated: true, completion: self.delegate?.completion)
    }
    
    override internal func didDismiss() {
        self.delegate?.completion?()
    }   
    
}

// MARK: - Extension Override Handlers ============================================================= -

extension DataTableViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    // MARK: - CollectionView Overrides ================================================================ -
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return self.displayedFields.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let totalHeight: CGFloat = collectionView.bounds.size.height
        let column = displayedFields[indexPath.row]
        var width = column.adjustedWidth
        
        // Combine any headings as requested
        if collectionView.tag >= 1000000 {
            if let index = displayedFields.firstIndex(where: { $0.combineHeading == column.title }) {
                if abs(index - indexPath.row) == 1 {
                    // Is adjacent - combine
                    width += displayedFields[index].adjustedWidth
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
            self.defaultCellColors(cell: cell)
            cell.tag = indexPath.row
            cell.layoutIfNeeded()

            Palette.bannerStyle(cell.textLabel)
            cell.topSpacingView.backgroundColor = Palette.banner.background
            cell.topSpacingHeightConstraint.constant = self.delegate?.headerTopSpacingHeight ?? 0.0
            cell.headerUpArrowView.backgroundColor = Palette.banner.background
            cell.textLabel.text = column.title
            cell.textLabel.textAlignment = .center
            
            // Sort arrow
            cell.setupArrows()
            if column.field == lastSortField && column.combineHeading == "" {
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
                cell.bodyButton.tintColor = Palette.otherButton.background
                cell.bodyButton.setImage(UIImage(prefixed: column.field), for: .normal)
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
                                     label: cell.bodyThumbnailDisc,
                                     size: cell.frame.height - 6)
            default:
                cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Data Table Body Normal Cell", for: indexPath) as! DataTableCollectionCell
                Palette.normalStyle(cell.textLabel)
                cell.textLabel.text = DataTableFormatter.getValue(record: record, column: column)
                cell.textLabel.textAlignment = displayedFields[indexPath.row].align
            }
            cell.resetArrows()
        }
        
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        
        let column = displayedFields[indexPath.row]
        
        return (column.type != .button && column.field != "")
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        var defaultDescending: Bool
        var sortColumn: Int
        
        if collectionView.tag >= 1000000 {
            // Header row - sort

            let cell = collectionView.cellForItem(at: indexPath) as! DataTableCollectionCell
            
            let column = displayedFields[indexPath.row]
            
            self.clearSortArrows()
            
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
            let value1 = DataTableFormatter.getValue(record: sort1, column: column, sortValue: true)
            let value2 = DataTableFormatter.getValue(record: sort2, column: column, sortValue: true)

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
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -


class DataTableCell: UITableViewCell {
    
    @IBOutlet weak var dataTableCollection: UICollectionView!
    @IBOutlet weak var separatorHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var separator: UIView!

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

    @IBOutlet weak var topSpacingView: UIView!
    @IBOutlet weak var topSpacingHeightConstraint: NSLayoutConstraint!
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
        self.headerUpArrowShape = self.centralArrow(container: self.headerUpArrowView, up: true, color: Palette.normal.background)
        self.headerDownArrowShape = self.centralArrow(container: self.headerDownArrowView, up: false, color: Palette.banner.background)
    }
    
    private func centralArrow(container: UIView, up: Bool, color: UIColor) -> UIView {
        
        var points: [PolygonPoint] = []
        let cellSize = self.frame.size
        let size: CGFloat = container.frame.height
        
        let view = UIView(frame: CGRect(x: (cellSize.width / 2.0) - size, y: 0.0, width: size * 2.0, height: size))
        self.addSubview(view)
        view.isHidden = true

        if up == true {
            points.append(PolygonPoint(x: 0.0, y: container.frame.minY + size, pointType: .point))
            points.append(PolygonPoint(x: (size * 2.0), y: container.frame.minY + size, pointType: .point))
            points.append(PolygonPoint(x: size, y: container.frame.minY))
        } else {
            points.append(PolygonPoint(x: 0.0, y: container.frame.minY, pointType: .point))
            points.append(PolygonPoint(x: (size * 2.0), y: container.frame.minY, pointType: .point))
            points.append(PolygonPoint(x: size, y: container.frame.minY + size))
        }
        
        Polygon.roundedShape(in: view, definedBy: points, strokeColor: color, fillColor: color, lineWidth: 1.0, radius: 2.0)
        
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
    case collection
}

@objc public class DataTableField: NSObject {
    var field: String
    var title: String
    var sequence: Int
    var width: CGFloat
    var adjustedWidth: CGFloat
    var align: NSTextAlignment
    var type: DataTableVariableType
    var pad: Bool
    var combineHeading: String
    
    init(_ field: String,_ title: String, sequence: Int = 0, width: CGFloat, type: DataTableVariableType, align: NSTextAlignment = .center, pad: Bool = false, combineHeading: String = "") {
        self.field = field
        self.title = title
        self.sequence = sequence
        self.width = width
        self.adjustedWidth = width
        self.align = align
        self.type = type
        self.pad = pad
        self.combineHeading = combineHeading
    }
}

extension DataTableViewController {

    /** _Note that this code was generated as part of the move to themed colors_ */

    private func defaultViewColors() {

        self.customHeaderView.backgroundColor = Palette.banner.background
        self.leftPaddingView.backgroundColor = Palette.banner.background
        self.rightPaddingView.backgroundColor = Palette.banner.background
        self.view.backgroundColor = Palette.normal.background
    }

    private func defaultCellColors(cell: DataTableCell) {
        switch cell.reuseIdentifier {
        case "Data Table Body Cell":
            cell.separator.backgroundColor = Palette.separator.background
        default:
            break
        }
    }

    private func defaultCellColors(cell: DataTableCollectionCell) {
        switch cell.reuseIdentifier {
        case "Data Table Body Button Cell":
            cell.backgroundColor = Palette.normal.background
            cell.bodyButton.setTitleColor(Palette.normal.text, for: .normal)
        case "Data Table Body Normal Cell":
            cell.textLabel.textColor = Palette.normal.text
            cell.backgroundColor = Palette.normal.background
        case "Data Table Body Thumbnail Cell":
            cell.bodyThumbnailDisc.textColor = Palette.normal.text
            cell.backgroundColor = Palette.normal.background
        case "Data Table Header Cell":
            cell.textLabel.textColor = Palette.banner.text
            cell.backgroundColor = UIColor.clear
        default:
            break
        }
    }

}

class DataTableFormatter {
    
    public static func checkFieldDisplay(_ availableFields: [DataTableField], to size: CGSize, paddingWidth: CGFloat = 6.0, hideField: ((String) -> Bool)? = nil) -> [DataTableField] {
        // Check how many fields we can display
        var displayedFields: [DataTableField] = []
        var skipping = false
        let availableWidth = size.width - paddingWidth // Allow for padding each end and detail button
        var widthRemaining = availableWidth
        
        let columns = availableFields
        for column in columns {
            if !(hideField?(column.field) ?? false) {
                
                // Include if space and not already skipping
                if !skipping {
                    if column.adjustedWidth <= widthRemaining {
                        widthRemaining -= column.adjustedWidth
                        displayedFields.append(DataTableField(column.field,
                                                              column.title,
                                                              sequence: column.sequence,
                                                              width: column.adjustedWidth,
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
        
        // Sort selected columns by sequence
        displayedFields.sort(by: { $0.sequence < $1.sequence })
        
        // Find and expand pad columns
        if widthRemaining > 0 {
            let padFields = displayedFields.filter{$0.pad}
            let adjust: CGFloat = min(200, (widthRemaining - 1) / CGFloat(padFields.count))
            for field in padFields {
                field.adjustedWidth += adjust
                widthRemaining -= adjust
            }
        }
        
        // Use up remainder on extra blank last column
        displayedFields.append(DataTableField("",  "", width: paddingWidth + widthRemaining, type: .string))
        
        return displayedFields
    }
 
    public static func getValue(record: DataTableViewerDataSource, column: DataTableField, sortValue: Bool = false) -> String {
        let derived = (column.field.left(1) == "=")
        if derived {
            return record.derivedField?(field: column.field.right(column.field.length - 1), record: record, sortValue: sortValue, width: column.adjustedWidth) ?? ""
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
                        return Utility.dateString(object as! Date, format: "dd MMM yy",localized: false)
                    }
                case .dateTime:
                    if sortValue {
                        let valueString = "\(Int((object as! Date).timeIntervalSinceReferenceDate))"
                        return String(repeating: " ", count: 20 - valueString.count) + valueString
                    } else {
                        return Utility.dateString(object as! Date, format: "dd/MM/yy HH:mm")
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

extension DataTableViewController {
    
    internal func setupHelpView() {
        
        self.helpView.reset()
                
        self.delegate?.addHelp?(to: self.helpView, header: self.headerView, body: self.bodyView)
        
        helpView.add("Tap the @*/Sync@*/ button allows you to synchronize the data on this device with the data in iCloud.", bannerId: syncButton)
        
        let title = self.delegate?.viewTitle ?? ""
        helpView.add("Tap the {} to exit from @*/\(title)@*/ and return to the previous view.", bannerId: self.finishButton, horizontalBorder: 8, verticalBorder: 4)
    }
}
