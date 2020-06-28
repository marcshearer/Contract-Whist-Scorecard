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
    
    @objc optional func getData(personal: Bool, count: Int) -> [DataTableViewerDataSource]
    
    @objc optional func adjustWidth(_ availableWidth: CGFloat)
}

class DataTableTileView: UIView, DashboardTileDelegate, UITableViewDataSource, UITableViewDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    private var detailType: DashboardDetailType = .history
    private var displayedFields: [DataTableField] = []
    private var records: [DataTableViewerDataSource]!
    private var dataSource: DataTableTileViewDataSource!
    private var collectionViewNib: UINib!
    private var rows: Int = 0
    private var rowHeight: CGFloat = 0.0
    private var minRowHeight: CGFloat = 30.0
    private let maxRowHeight: CGFloat = 50.0
    
    @IBInspectable private var detail: Int {
        get {
            return self.detailType.rawValue
        }
        set(detail) {
            self.detailType = DashboardDetailType(rawValue: detail) ?? .history
        }
    }
    @IBInspectable private var personal: Bool = true
    @IBInspectable private var title: String = ""
    @IBInspectable private var headings: Bool = false
    @IBInspectable private var maxRows: Int = 0

    @IBOutlet private weak var dashboardDelegate: DashboardActionDelegate?

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
        
        // Setup tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(DataTableTileView.tapSelector(_:)))
        self.contentView.addGestureRecognizer(tapGesture)
        
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
             
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
        self.typeButton.tintColor = Dashboard.color(detailView: detailType)
        self.typeButton.setImage(Dashboard.image(detailView: detailType), for: .normal)
       
        self.contentView.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0))
        self.tileView.roundCorners(cornerRadius: 8.0)
        
        if self.tableView.frame.width > 0 {
            self.tableView.layoutIfNeeded()
            self.calculateRows()
            if self.headings {
                self.tableViewTopConstraint.constant = -self.rowHeight
            }
            
            self.dataSource?.adjustWidth?(self.tableView.frame.width)
            if let availableFields = self.dataSource?.availableFields {
                self.displayedFields = DataTableFormatter.checkFieldDisplay(availableFields, to: self.tableView.frame.size, paddingWidth: 1.0)
            } else {
                self.displayedFields = []
            }
            
            self.moveTypeButton()
            
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
        cell.setCollectionViewDataSourceDelegate(self, nib: self.collectionViewNib, forRow: 1000000+indexPath.row)
        return cell
    }
    
    // MARK: - Collection view delegates ================================================================ -
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.displayedFields.count
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: self.displayedFields[indexPath.item].adjustedWidth, height: self.rowHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Collection Cell", for: indexPath) as! DataTableTileCollectionViewCell
        let row = collectionView.tag - 1000000
        let headingRows = (self.headings ? 1 : 0)
        if row == 0 && self.headings {
            cell.textLabel.text = self.displayedFields[indexPath.item].title
            cell.textLabel.numberOfLines = 0
        } else {
            let record = records[row - headingRows]
            let column = displayedFields[indexPath.item]
            Palette.normalStyle(cell.textLabel)
            cell.textLabel.text = DataTableFormatter.getValue(record: record, column: column)
            cell.textLabel.numberOfLines = 1
        }
        cell.textLabel.textAlignment = displayedFields[indexPath.row].align
        return cell
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
}

class DataTableTileHistoryDataSource : DataTableTileViewDataSource {
    
    private var history = History()
    
    let availableFields: [DataTableField] = [
        DataTableField("        ",      "",          sequence: 1,   width: 7,   type: .string),
        DataTableField("        ",      "",          sequence: 7,   width: 2,   type: .string),
        DataTableField("=shortDate",    "Date",      sequence: 3,   width: 50,  type: .date,        align: .left, pad: true),
        DataTableField("=player1",      "Winner",    sequence: 5,   width: 80,  type: .string),
        DataTableField("=score1",       "Score",     sequence: 6,   width: 50,  type: .int),
        DataTableField("=location",     "Location",  sequence: 2,   width: 100, type: .string,      align: .left),
    ]
    
    internal func adjustWidth(_ availableWidth: CGFloat) {
        if availableWidth < 150 {
            for field in self.availableFields {
                field.adjustedWidth = field.width * availableWidth / 150
            }
        }
    }
    
    internal func getData(personal: Bool, count: Int) -> [DataTableViewerDataSource] {
        self.history = History(playerUUID: (personal ? Scorecard.settings.thisPlayerUUID : nil), limit: count)
        return self.history.games
    }
    
}

class DataTableTilePersonalStatsDataSource : DataTableTileViewDataSource {

    let availableFields: [DataTableField] = [
        DataTableField("",              "",          sequence: 1,   width: 7,   type: .string),
        DataTableField("",              "",          sequence: 4,   width: 7,   type: .string),
        DataTableField("name",          "Stat",      sequence: 2,   width: 100, type: .string,        align: .left),
        DataTableField("value",         "Value",     sequence: 3,   width: 30,  type: .string)
    ]
    
    internal func adjustWidth(_ availableWidth: CGFloat) {
        if availableWidth < 150 {
            for field in self.availableFields {
                field.adjustedWidth = field.width * availableWidth / 150
            }
        }
    }
    
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

class DataTableTileStatsDataSource : DataTableTileViewDataSource {

    let availableFields: [DataTableField] = [
        DataTableField("",             "",                 sequence: 1,     width: 7,     type: .string),
        DataTableField("",             "",                 sequence: 9,     width: 7,     type: .string),
        DataTableField("name",         "",                 sequence: 2,     width: 140,    type: .string,    align: .left,   pad: true),
        DataTableField("=gamesWon%",   "Games Won",        sequence: 5,     width: 60.0,  type: .double),
        DataTableField("=averageScore","Av. Score",        sequence: 6,     width: 60.0,  type: .double),
        DataTableField("=handsMade%",  "Hands Made",       sequence: 7,     width: 60.0,  type: .double),
        DataTableField("=twosMade%",   "Twos Made",        sequence: 8,     width: 60.0,  type: .double),
        DataTableField("gamesPlayed",  "Games Played",     sequence: 3,     width: 60.0,  type: .int),
        DataTableField("gamesWon",     "Games Won",        sequence: 4,     width: 60.0,  type: .int)
    ]
    
    internal func adjustWidth(_ availableWidth: CGFloat) {
        if availableWidth < 225 {
            for field in self.availableFields {
                field.adjustedWidth = field.width * availableWidth / 225
            }
        }
    }
    
    internal func getData(personal: Bool, count: Int) -> [DataTableViewerDataSource] {
        Scorecard.shared.playerDetailList().sorted(by: {self.gamesWon($0) > self.gamesWon($1)})
    }
    
    private func gamesWon(_ playerDetail: PlayerDetail) -> Double {
        if playerDetail.gamesPlayed == 0 {
            return 0
        } else {
            return Double(playerDetail.gamesWon) / Double(playerDetail.gamesPlayed)
        }
    }
}

