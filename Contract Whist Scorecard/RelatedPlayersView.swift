//
//  RelatedPlayersView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 30/06/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

@objc protocol RelatedPlayersDelegate {
        
    @objc optional func didCancel() // Not required if accessing via RelatedPlayersViewController
    
    func didDownloadPlayers(playerDetailList: [PlayerDetail], emailPlayerUUID: String?)
}

public enum DescriptionMode {
    case opponents
    case lastPlayed
}

class RelatedPlayersView : UIView, UITableViewDelegate, UITableViewDataSource, SyncDelegate {
    
    @IBInspectable private var showCancel: Bool = true
    
    private var sync = Sync()
    private var syncStarted = false
    private var syncFinished = false
    internal let syncDelegateDescription = "RelatedPlayers"

    private var email: String?
    private var playerDetailList: [(playerDetail: PlayerDetail, selected: Bool)] = []
    private var descriptionMode: DescriptionMode = .opponents
    private var emailPlayerUUID: String?
    
    private var rowHeight: CGFloat = 50.0
    
    private var selected: Int {
        get {
            return self.playerDetailList.filter({ $0.selected }).count
        }
    }

    // MARK: - IB Outlets ============================================================================== -
    
    @IBOutlet private weak var delegate: RelatedPlayersDelegate!
    @IBOutlet private weak var parent: ScorecardViewController!
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var buttonContainerView: UIView!
    @IBOutlet private weak var cancelButton: ShadowButton!
    @IBOutlet private weak var cancelButtonLeadingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var cancelButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var changeAllButton: ShadowButton!
    @IBOutlet private weak var confirmButton: ShadowButton!
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func cancelButtonPressed(_ sender: UIButton) {
        // Abandon any sync in progress
        self.sync.stop()
        
        self.delegate?.didCancel?()
    }
    
    @IBAction private func changeAllButtonPressed(_ sender: UIButton) {
        self.changeAll(self.selected == 0)
        self.enableButtons()
    }
    
    @IBAction private func confirmButtonPressed(_ sender: UIButton) {
        
        // Abandon any sync in progress
        self.sync.stop()
        
        if selected > 0 {
            // Action selection
            self.createPlayers()
            
            // Return to calling program
            self.delegate?.didDownloadPlayers(playerDetailList: self.playerDetailList.filter({$0.selected}).map{$0.playerDetail}, emailPlayerUUID: self.emailPlayerUUID)
        }
     }
    
    // MARK: - Initialisers and view overrides ========================================================== -
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.loadRelatedPlayersView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.loadRelatedPlayersView()
    }
    
    internal override func awakeFromNib() {
        super.awakeFromNib()
        self.cancelButton.isHidden = !self.showCancel
        self.cancelButtonLeadingConstraint.constant = (self.showCancel ? 20 : 0)
        self.cancelButtonWidthConstraint.constant = (self.showCancel ? self.confirmButton.frame.width : 0)
    }
    
    internal override func layoutSubviews() {
        super.layoutSubviews()
        self.tableView.layoutIfNeeded()
        self.buttonContainerView.layoutIfNeeded()
        self.setRowHeight()
    }
    
    // MARK: - Public methods =========================================================================== -
    
    public func set(email: String?, descriptionMode: DescriptionMode = .opponents) {
        self.email = email
        self.descriptionMode = descriptionMode
        self.selectCloudPlayers()
        syncStarted = true
    }
    
    public func remove(email: String) {
        if let playerUUID = Scorecard.shared.playerUUID(email: email) {
            self.remove(playerUUID: playerUUID)
        }
    }
    
    public func remove(playerUUID: String) {
        if let row = self.playerDetailList.firstIndex(where: {$0.playerDetail.playerUUID == playerUUID}) {
            self.tableView.beginUpdates()
            self.playerDetailList.remove(at: row)
            if self.playerDetailList.count > 0 {
                self.tableView.deleteRows(at: [IndexPath(row: row, section: 0)], with: .automatic)
            } else {
                // Replace with placeholder
                self.tableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: .automatic)
            }
            self.tableView.endUpdates()
        }
    }
    
    // MARK: - Load view from xib file ================================================================== -
    
    private func loadRelatedPlayersView() {
        Bundle.main.loadNibNamed("RelatedPlayersView", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Register table view cell
        let nib = UINib(nibName: "RelatedPlayersTableViewCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "Player Cell")
        
        self.defaultViewColors()
    }
    
    // MARK: - Sync routines including the delegate methods ======================================== -
    
    private func selectCloudPlayers() {

        self.sync.delegate = self
        
        // Get related players from cloud
        if !(self.sync.synchronise(syncMode: .syncGetPlayers, specificEmail: self.email, waitFinish: true, okToSyncWithTemporaryPlayerUUIDs: true)) {
            self.syncCompletion(-1)
        }
    }
    
    private func getImages(_ imageFromCloud: [PlayerMO]) {
        self.sync.fetchPlayerImagesFromCloud(imageFromCloud)
    }
    
    internal func syncMessage(_ message: String) {
    }
    
    internal func syncAlert(_ message: String, completion: @escaping ()->()) {
        Utility.mainThread {
            self.parent.alertMessage(message, title: "Contract Whist Scorecard", okHandler: {
                self.syncFinished = true
                self.enableButtons()
                completion()
            })
        }
    }
    
    internal func syncCompletion(_ errors: Int) {
    }
    
    internal func syncReturnPlayers(_ returnedList: [PlayerDetail]!, _ thisPlayerUUID: String?) {
        Utility.mainThread {
            self.syncFinished = true
            if returnedList != nil {
                self.playerDetailList = []
                for playerDetail in returnedList {
                    let index = Scorecard.shared.playerList.firstIndex(where: {($0.playerUUID == playerDetail.playerUUID)})
                    if index == nil {
                        self.playerDetailList.append((playerDetail, false))
                    }
                }
                if thisPlayerUUID != nil {
                    self.emailPlayerUUID = thisPlayerUUID
                }
            }
            self.tableView.reloadData()
            self.enableButtons()
        }
    }
    
    // MARK: - TableView Overrides ================================================================ -
    
    internal func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.rowHeight
    }
    
    internal func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return max(1, self.playerDetailList.count)
    }
    
    internal func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: RelatedPlayersTableViewCell
        
        // Create cell
        cell = tableView.dequeueReusableCell(withIdentifier: "Player Cell", for: indexPath) as! RelatedPlayersTableViewCell
        // Setup default colors (previously done in StoryBoard)
        self.defaultCellColors(cell: cell)
                
        if self.playerDetailList.count == 0 {
            // No related players found
            if syncFinished {
                cell.playerName.text = "No related players found"
                cell.playerDescription.text = ""
            } else {
                cell.playerName.text = "Searching for related players..."
                cell.playerDescription.text = ""
            }
            
            cell.playerTick.isHidden = true
            cell.playerDetail.isHidden = true
            cell.playerName.textColor = Palette.text.withAlphaComponent(0.5)
            cell.playerSeparatorView.isHidden = true
            
        } else {
            let listItem = self.playerDetailList[indexPath.row]
            let playerDetail = listItem.playerDetail
            let selected = listItem.selected
            
            // Update cell text / format
            cell.playerName.text = playerDetail.name
            if self.descriptionMode == .opponents {
                cell.playerDescription.text = self.getOpponents(playerDetail)
            } else {
                cell.playerDescription.text = self.getLastPlayed(playerDetail)
            }
            self.setTick(cell, to: selected)
            
            // Link detail button
            cell.playerDetail.addTarget(self, action: #selector(RelatedPlayersView.playerDetail(_:)), for: UIControl.Event.touchUpInside)
            cell.playerDetail.tag = indexPath.row
            cell.playerDetail.isHidden = false
            cell.playerName.textColor = Palette.text
            cell.playerSeparatorView.isHidden = false
            cell.selectionStyle = .none
        }
        
        return cell
    }
    
    internal func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
       
        if indexPath.row < self.playerDetailList.count {
            self.playerDetailList[indexPath.row].selected.toggle()
            self.enableButtons()
            self.setTick(tableView.cellForRow(at: indexPath) as! RelatedPlayersTableViewCell, to: self.playerDetailList[indexPath.row].selected)
        }
        
        return nil
        
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        if scrollView == tableView {
            let cellHeight = CGFloat(self.rowHeight)
            let y          = targetContentOffset.pointee.y + scrollView.contentInset.top + (cellHeight / 2)
            let cellIndex  = floor(y / cellHeight)
            targetContentOffset.pointee.y = cellIndex * cellHeight - scrollView.contentInset.top
        }
    }
    
    // MARK: - Form presentation / Handling Routines =================================================== -
    
    private func enableButtons() {
        let somePlayers = (self.playerDetailList.count > 0)
        let someSelected = (self.selected > 0)
        self.changeAllButton.isEnabled = somePlayers
        self.changeAllButton.setTitle((someSelected ? "Clear All" : "Select All"), for: .normal)
        self.confirmButton.isEnabled = someSelected
    }
    
    private func setTick(_ cell: RelatedPlayersTableViewCell, to set: Bool) {
        var imageName: String
        
        if set {
            imageName = "on"
        } else {
            imageName = "off"
        }
        cell.playerTick.image = UIImage(named: imageName)?.asTemplate()
        cell.playerTick.tintColor = (set ? Palette.confirmButton : Palette.otherButton)
        cell.playerTick.isHidden = false
    }
    
    private func changeAll(_ to: Bool) {
        // Select all
        for index in 0..<self.playerDetailList.count {
            self.playerDetailList[index].selected = to
        }
        self.tableView.reloadData()
    }
    
    private func setRowHeight() {
        let availableHeight = self.tableView.frame.height + 0.5 // to lose the bottom separator
        let rows = Utility.round(Double(availableHeight) / 60.0)
        self.rowHeight = availableHeight / CGFloat(rows)
    }
    
    // MARK: - Utility Routines ======================================================================== -

    private func createPlayers() {
        var imageList: [PlayerMO] = []
        
        for playerDetail in self.playerDetailList.filter({$0.selected}).map({$0.playerDetail}) {
            let playerMO = playerDetail.createMO(saveToICloud: false)
            if playerMO != nil && playerDetail.thumbnailDate != nil {
                imageList.append(playerMO!)
            }
        }
 
        // Reload shared player list
        Scorecard.shared.getPlayerList()
        
        if imageList.count > 0 {
            self.getImages(imageList)
        }
    }
    
    private func getOpponents(_ playerDetail: PlayerDetail) -> String {
        var result: String
        
        let opponents = History.findOpponentNames(playerUUID: playerDetail.playerUUID)
        if opponents.count > 0 {
            result = "played " + Utility.toString(opponents)
        } else {
            result = "No opponents on device"
        }
        return result
    }

    private func getLastPlayed(_ playerDetail: PlayerDetail) -> String {
        var result: String
        
        if playerDetail.datePlayed == nil {
            result = "No last played date"
        } else {
            result = "Last played " + Utility.dateString(playerDetail.datePlayed, format: "MMMM YYYY")
        }
    
        return result
    }
    
    private func defaultViewColors() {
        self.cancelButton.setBackgroundColor(Palette.otherButton)
        self.cancelButton.setTitleColor(Palette.otherButtonText, for: .normal)
        self.changeAllButton.setBackgroundColor(Palette.otherButton)
        self.changeAllButton.setTitleColor(Palette.otherButtonText, for: .normal)
        self.confirmButton.setBackgroundColor(Palette.confirmButton)
        self.confirmButton.setTitleColor(Palette.confirmButtonText, for: .normal)
    }
    
    private func defaultCellColors(cell: RelatedPlayersTableViewCell) {
        switch cell.reuseIdentifier {
        case "Player Cell":
            cell.playerDescription.textColor = Palette.text
            cell.playerName.textColor = Palette.textTitle
            cell.playerSeparatorView.backgroundColor = Palette.separator
            cell.playerDetail.backgroundColor = Palette.otherButton
            cell.playerDetail.setTitleColor(Palette.otherButtonText, for: .normal)
            cell.playerDetail.toCircle()
        default:
            break
        }
    }
    
    // MARK: - Show / Hide other views ================================================================== -
    
    @objc private func playerDetail(_ button: UIButton) {
        let selectedIndex = button.tag
        PlayerDetailViewController.show(from: self.parent, playerDetail: self.playerDetailList[selectedIndex].playerDetail, mode: .display, sourceView: self)
    }
    
}

class RelatedPlayersTableViewCell: UITableViewCell {
        
    @IBOutlet public weak var playerName: UILabel!
    @IBOutlet public weak var playerDescription: UILabel!
    @IBOutlet public weak var playerTick: UIImageView!
    @IBOutlet public weak var playerDetail: RoundedButton!
    @IBOutlet public weak var playerSeparatorView: UIView!
}
