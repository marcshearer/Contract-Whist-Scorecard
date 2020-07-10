//
//  DataTableView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 23/06/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

@objc public protocol DataTableTileViewDataSource : class {
    var availableFields: [DataTableField] { get }
    var minColumns: Int { get }
    
    @objc optional func getData(personal: Bool, count: Int) -> [DataTableViewerDataSource]
    
}

class DataTableTileView: UIView, DashboardTileDelegate, UITableViewDataSource, UITableViewDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    private var detailType: DashboardDetailType = .history
    private var highScoreType: HighScoreType = .totalScore
    private var displayedFields: [DataTableField] = []
    private var records: [DataTableViewerDataSource]!
    private var dataSource: DataTableTileViewDataSource!
    private var collectionViewNib: UINib!
    private var contentCollectionViewNib: UINib!
    private var rows: Int = 0
    private var rowHeight: CGFloat = 0.0
    private var minRowHeight: CGFloat = 30.0
    
    @IBInspectable private var detail: Int {
        get {
            return self.detailType.rawValue
        }
        set(detail) {
            self.detailType = DashboardDetailType(rawValue: detail) ?? .history
        }
    }
    @IBInspectable private var highScore: Int {
        get {
            return self.highScoreType.rawValue
        }
        set(highScore) {
            self.highScoreType = HighScoreType(rawValue: highScore) ?? .totalScore
        }
    }
    @IBInspectable private var personal: Bool = true
    @IBInspectable private var title: String = ""
    @IBInspectable private var headings: Bool = false
    @IBInspectable private var maxRows: Int = 0
    @IBInspectable private var separator: Bool = true
    @IBInspectable private var fontSize: CGFloat = 15.0
    @IBInspectable private var showTypeButton: Bool = true
    @IBInspectable private var maxRowHeight: CGFloat = 50.0
    @IBInspectable private var detailDrill: Bool = false

    @IBOutlet private weak var dashboardDelegate: DashboardActionDelegate?
    @IBOutlet private weak var parentDashboardView: DashboardView?
    
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var tileView: UIView!

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var typeButton: ClearButton!
    @IBOutlet private weak var typeButtonTrailingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var tableViewTopConstraint: NSLayoutConstraint!
    
    
    // MARK: - Initialisers ============================================================================== -
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.loadDataTableTileView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.loadDataTableTileView()
    }

    private func loadDataTableTileView() {
        Bundle.main.loadNibNamed("DataTableTileView", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Register table view cell
        let nib = UINib(nibName: "DataTableTileTableViewCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "Table Cell")
        
        // Load collection view cell
        self.collectionViewNib = UINib(nibName: "DataTableTileCollectionViewCell", bundle: nil)
        
        // Load collection view cell
        self.contentCollectionViewNib = UINib(nibName: "DataTableTileContentCollectionViewCell", bundle: nil)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        if !detailDrill {
            // Setup tap gesture
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(DataTableTileView.tapSelector(_:)))
            self.contentView.addGestureRecognizer(tapGesture)
        }
        
        // Setup data source
        switch detailType {
        case .history:
            self.dataSource = DataTableTileHistoryDataSource()
        case .statistics:
            if self.personal {
                self.dataSource = DataTableTilePersonalStatsDataSource()
            } else {
                self.dataSource = DataTableTileStatsDataSource()
            }
        case .highScores:
            self.dataSource = DataTableTileHighScoreDataSource(type: self.highScoreType, parentDashboardView: self.parentDashboardView)
        default:
            break
        }
        
        self.getData()
     }
    
    @objc private func tapSelector(_ sender: UIView) {
        self.dashboardDelegate?.action(view: detailType)
    }
    
    override internal func layoutSubviews() {
        super.layoutSubviews()
        
        self.tileView.layoutIfNeeded()
        
        self.titleLabel.text = self.title
         
        self.tileView.backgroundColor = Palette.buttonFace
        self.titleLabel.textColor = Palette.textTitle
        Dashboard.formatTypeButton(detailView: detailType, button: self.typeButton)

        self.contentView.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0))
        self.tileView.roundCorners(cornerRadius: 8.0)
        
        if self.tableView.frame.width > 0 {
            self.tableView.layoutIfNeeded()
            self.calculateRows()
            if self.headings {
                self.tableViewTopConstraint.constant = -self.rowHeight
            }
            
            if let availableFields = self.dataSource?.availableFields,
               let minColumns = self.dataSource?.minColumns {
                
                // Make sure that the minimum number of columns will fit
                var minWidth: CGFloat = 0.0
                for index in 0..<minColumns {
                    minWidth += availableFields[index].width
                }
                for index in 0..<availableFields.count {
                    if self.tableView.frame.width < minWidth {
                        availableFields[index].adjustedWidth = availableFields[index].width * self.tableView.frame.width / minWidth
                    } else {
                        availableFields[index].adjustedWidth = availableFields[index].width
                    }
                }
                
                // Fill in the columns
                self.displayedFields = DataTableFormatter.checkFieldDisplay(availableFields, to: self.tableView.frame.size, paddingWidth: 1.0)
            } else {
                self.displayedFields = []
            }
            
            if !self.showTypeButton {
                self.typeButton.isHidden = true
            } else {
                self.moveTypeButton()
            }
            
            if !self.separator {
                self.tableView.separatorStyle = .none
            }
                        
            self.tableView.reloadData()
        }
    }
    
    internal func reloadData() {
        self.setNeedsLayout()
        self.layoutIfNeeded()
        self.getData()
        self.calculateRows()
        self.tableView.reloadData()
    }
    
    private func getData() {
        self.records = self.dataSource?.getData?(personal: self.personal, count: self.maxRows)
    }
    
    private func calculateRows() {
        let totalHeight = self.tableView.frame.height
        self.minRowHeight = max(self.minRowHeight, ScorecardUI.screenHeight / 24)
        self.rows = Int(totalHeight / self.minRowHeight)
        var fitRows = self.rows
        if self.rows > self.records.count {
            fitRows = Int(totalHeight / CGFloat(self.maxRowHeight))
            self.rows = self.records.count
        }
        self.rowHeight = totalHeight / CGFloat(max(fitRows, self.rows))
    }
    
    private func moveTypeButton() {
        if self.headings == true {
            // Need to move the button across into the last column with no title
            var totalWidth: CGFloat = 0
            for field in self.displayedFields {
                if field.title != "" {
                    break
                }
                totalWidth += field.width
            }
            if totalWidth > 0 {
                self.typeButtonTrailingConstraint.constant = self.tileView.frame.width - totalWidth - 8.0
            }
        }
    }
    
    // MARK: - Table view delegates ========================================================== -
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.rows + (self.headings ? 1 : 0)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.rowHeight
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Table Cell", for: indexPath) as! DataTableTileTableViewCell
        cell.setCollectionViewDataSourceDelegate(self, nib: self.collectionViewNib, forRow: indexPath.row)
        
        cell.selectedBackgroundView = UIView()
        cell.selectedBackgroundView?.backgroundColor = UIColor.clear
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if self.detailDrill {
            let data = self.records[indexPath.row - (self.headings ? 1 : 0)]
            switch self.detailType {
            case .history:
                if let gameUUID = data.value(forKey: "gameUUID") as? String {
                    self.showHistoryDetail(gameUUID: gameUUID)
                }
            case .statistics:
                if let playerUUID = data.value(forKey: "playerUUID") as? String {
                    self.showPlayerDetail(playerUUID: playerUUID)
                }
            case .highScores:
                if let playerUUID = data.value(forKey: "playerUUID") as? String {
                    self.parentDashboardView?.drillHighScore(from: self.parentDashboardView!.parentViewController!, sourceView: self, type: self.highScoreType, occurrence: indexPath.row - (self.headings ? 1 : 0), detailParticipantMO: nil, playerUUID: playerUUID)
                }
            }
        }
        return nil
    }
    
    // MARK: - Collection view delegates ================================================================ -
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView.tag < 1000000 {
            return self.displayedFields.count
        } else {
            return collectionView.tag - 1000000
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView.tag < 1000000 {
            return CGSize(width: self.displayedFields[indexPath.item].adjustedWidth, height: self.rowHeight)
        } else {
            let value = collectionView.tag - 1000000
            let cellsPerRow = max(5, (value + 1) / 2)
            let size: CGFloat = collectionView.frame.width / CGFloat(cellsPerRow)
            return CGSize(width: size, height: size)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView.tag < 1000000 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Collection Cell", for: indexPath) as! DataTableTileCollectionViewCell
            let headingRows = (self.headings ? 1 : 0)
            let row = collectionView.tag
            let column = displayedFields[indexPath.item]
            Palette.normalStyle(cell.textLabel)
            if row == 0 && self.headings {
                cell.textLabel.text = column.title
                cell.textLabel.numberOfLines = 0
                cell.textLabel.font = UIFont.systemFont(ofSize: self.fontSize, weight: .semibold)
                cell.textLabel.textAlignment = .center
            } else {
                let record = records[row - headingRows]
                cell.textLabel.text = ""
                cell.thumbnailView.set(data: nil)
                switch displayedFields[indexPath.row].type {
                case .thumbnail:
                    var data: Data?
                    if let content = record.value(forKey: column.field) {
                        if !(content is NSNull) {
                            data = content as? Data
                        }
                    }
                    cell.thumbnailView.set(data: data, diameter: cell.frame.width - 4)
                case .collection:
                    cell.setCollectionViewDataSourceDelegate(self, nib: self.contentCollectionViewNib, forValue: record.value(forKey: column.field) as! Int)
                default:
                    cell.textLabel.text = DataTableFormatter.getValue(record: record, column: column)
                    cell.textLabel.font = UIFont.systemFont(ofSize: self.fontSize)
                }
                cell.textLabel.numberOfLines = 1
                cell.textLabel.textAlignment = column.align
            }
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Content Collection Cell", for: indexPath) as! DataTableTileContentCollectionViewCell
            cell.imageView.image = UIImage(named: "cup")?.asTemplate()
            cell.imageView.tintColor = Palette.highScores
            
            return cell
        }
    }
    
    // MARK: - Routines to load other views ============================================================ -
    
    private func showHistoryDetail(gameUUID: String) {
        let history = History(gameUUID: gameUUID, getParticipants: true)
        if !history.games.isEmpty {
            HistoryDetailViewController.show(from: self.parentDashboardView!.parentViewController!, gameDetail: history.games.first!, sourceView: self, completion: { (historyGame) in
            })
        }
    }
    
    private func showPlayerDetail(playerUUID: String) {
        if let playerMO = Scorecard.shared.findPlayerByPlayerUUID(playerUUID) {
            let playerDetail = PlayerDetail()
            playerDetail.fromManagedObject(playerMO: playerMO)
            PlayerDetailViewController.show(from: self.parentDashboardView!.parentViewController!, playerDetail: playerDetail, mode: .display, sourceView: self)
        }
    }
}

// MARK: - Cell classes ================================================================ -

class DataTableTileTableViewCell: UITableViewCell {
    @IBOutlet fileprivate weak var collectionView: UICollectionView!
    
    func setCollectionViewDataSourceDelegate
         <D: UICollectionViewDataSource & UICollectionViewDelegate>
        (_ dataSourceDelegate: D, nib: UINib, forRow row: Int) {
         
         collectionView.delegate = dataSourceDelegate
         collectionView.dataSource = dataSourceDelegate
         collectionView.register(nib, forCellWithReuseIdentifier: "Collection Cell")
         collectionView.tag = row
         collectionView.reloadData()
     }
}

class DataTableTileCollectionViewCell: UICollectionViewCell {
    @IBOutlet fileprivate weak var textLabel: UILabel!
    @IBOutlet fileprivate weak var thumbnailView: ThumbnailView!
    @IBOutlet fileprivate weak var collectionView: UICollectionView!
    @IBOutlet fileprivate weak var collectionViewHeightConstraint: NSLayoutConstraint!
    
    func setCollectionViewDataSourceDelegate
        <D: UICollectionViewDataSource & UICollectionViewDelegate>
        (_ dataSourceDelegate: D, nib: UINib, forValue value: Int) {
        
        collectionView.delegate = dataSourceDelegate
        collectionView.dataSource = dataSourceDelegate
        collectionView.register(nib, forCellWithReuseIdentifier: "Content Collection Cell")
        let cellsPerRow = max(5, (value + 1) / 2)
        let size: CGFloat = self.frame.width / CGFloat(cellsPerRow)
        collectionViewHeightConstraint.constant = (value > cellsPerRow ? (size * 2) + 4 : size)
        collectionView.tag = 1000000 + value
        collectionView.reloadData()
    }
}

class DataTableTileContentCollectionViewCell: UICollectionViewCell {
    @IBOutlet fileprivate weak var imageView: UIImageView!
}

