//
//  History Viewer.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 29/06/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

class HistoryViewer : NSObject, DataTableViewerDelegate, PlayerSelectionViewDelegate {

    private enum FilterState {
        case notFiltered
        case selecting
        case filtered
    }
    
    public var viewTitle = "History"
    public var allowSync = ScorecardUI.smallPhoneSize()
    public let initialSortField = "datePlayed"
    public let initialSortDescending = true
    public let headerRowHeight: CGFloat = 54.0
    public let headerTopSpacingHeight: CGFloat = 10.0
    public let bodyRowHeight: CGFloat = 40.0
    public var backImage: String = "back"
   
    private var history: History!
    private var winStreakPlayer: String?
    private weak var sourceViewController: ScorecardViewController!
    private var dataTableViewController: DataTableViewController!
    private var callerCompletion: (()->())?
    private var customView: UIView!
    private var customHeightConstraint: NSLayoutConstraint!
    private var filterState: FilterState = .notFiltered
    private var filterInstructionView: UIView!
    private var filterInstructionLabel: UILabel!
    private var filterInstructionHeightConstraint: NSLayoutConstraint!
    private var filterButton: ShadowButton!
    private var filterClearButton: RoundedButton!
    private var filterClearView: UIView!
    private var filterSelectionView: PlayerSelectionView!
    private var filterSelectionHeightConstraint: NSLayoutConstraint!
    private var filterSelectionViewHeight: CGFloat!
    private var filterPlayerMO: PlayerMO!
    private var bannerFilterButton: UIButton!
    private var syncButton: ShadowButton!
    private var customButtonId: AnyHashable?
    private var landscape = false
    
    // Local class variables
    let availableFields: [DataTableField] = [
        DataTableField("",              "",                 sequence: 0,   width: 16,  type: .string),
        DataTableField("=location",     "Location",         sequence: 2,   width: 100, type: .string,      align: NSTextAlignment.left, pad: true),
        DataTableField(DataTableViewController.infoImageName, "",  sequence: 14,  width: 40,  type: .button),
        DataTableField("cross red",     "",                 sequence: 13,  width: 40,  type: .button),
        DataTableField("datePlayed",    "Date",             sequence: 3,   width: 100, type: .date),
        DataTableField("=player1",      "Winner",           sequence: 5,   width: 80,  type: .string),
        DataTableField("=score1",       "Score",            sequence: 6,   width: 50,  type: .int),
        DataTableField("=player2",      "Second",           sequence: 7,   width: 80,  type: .string),
        DataTableField("=score2",       "Score",            sequence: 8,   width: 50,  type: .int),
        DataTableField("=player3",      "Third",            sequence: 9,   width: 80,  type: .string),
        DataTableField("=score3",       "Score",            sequence: 10,  width: 50,  type: .int),
        DataTableField("=player4",      "Fourth",           sequence: 11,  width: 80,  type: .string),
        DataTableField("=score4",       "Score",            sequence: 12,  width: 50,  type: .int),
        DataTableField("datePlayed",    "",                 sequence: 4,   width: 60,  type: .time,        combineHeading: "Date")
    ]
    
    init(from viewController: ScorecardViewController, playerUUID: String? = nil, winStreak: Bool = false, completion: (()->())? = nil) {
        super.init()
        
        self.sourceViewController = viewController
        
        if let playerUUID = playerUUID {
            if winStreak {
                // Just showing the win streak for a player
                self.winStreakPlayer = playerUUID
                self.viewTitle = "Win Streak"
                self.allowSync = false
                self.backImage = "back"
            } else {
                // Filter by player
                self.filterPlayerMO = Scorecard.shared.findPlayerByPlayerUUID(playerUUID)
                self.filterState = .filtered
            }
        }
        
        self.getHistory()
        self.callerCompletion = completion
        
        // Call the data table viewer
        self.dataTableViewController = DataTableViewController.create(delegate: self, recordList: history.games)
        
        DataTableViewController.show(self.dataTableViewController, from: viewController)
    }
    
    func setupCustomControls(completion: ()->()) {
        // Setup the custom (filter) view
        if self.winStreakPlayer == nil {
            self.customView = self.dataTableViewController.customHeaderView
            self.customHeightConstraint = self.dataTableViewController.customHeaderViewHeightConstraint
            self.customView.layoutIfNeeded()
            self.filterStateChange()
        }
        completion()
    }
    
    internal func layoutSubviews() {
        if self.filterState == .selecting && self.landscape != ScorecardUI.landscape() {
            // Re-size window
            self.setFilterSelectionViewRequiredHeight()
            self.filterStateChange()
        } 
    }
       
    internal func setupCustomButton(id: AnyHashable?) -> BannerButton? {
        var result: BannerButton?
        self.customButtonId = id
        if self.winStreakPlayer == nil && ScorecardUI.smallPhoneSize() {
            result = BannerButton(image: UIImage(named: "filter"), action: self.filterButtonPressed, alignment: .center, id: id)
        }
        return result
    }
    
    internal func didSelect(playerMO: PlayerMO) {
        self.filterPlayerMO = playerMO
        self.filterState = .filtered
        self.filterStateChange()
    }
    
    internal func didSelect(record: DataTableViewerDataSource, field: String) {
        let historyGame = record as! HistoryGame
        switch field {
        case "cross red":
            self.deleteHistory(historyGame: historyGame)
        default:
            self.showDetail(historyGame: historyGame)
        }
        
    }
    
    internal func hideField(field: String) -> Bool {
        var result = false
        
        switch field {
        case "cross red":
            result = !Scorecard.adminMode
        case "=location":
            result = !Scorecard.activeSettings.saveLocation
        default:
            break
        }
        
        return result
    }
        
    internal func refreshData(recordList: [DataTableViewerDataSource]) -> [DataTableViewerDataSource] {
        if self.filterState != .filtered {
            self.getHistory()
        } else {
            self.getPlayerHistory()
        }
        
        return self.history.games
    }
    
    internal func completion() {
        self.callerCompletion?()
    }
    
    internal func syncButtons(enabled: Bool) {
        self.syncButton?.isEnabled = enabled
    }
    
    internal func addHelp(to helpView: HelpView, header: UITableView, body: UITableView) {
        
        helpView.add("The @*/\(self.viewTitle)@*/ screen \(self.winStreakPlayer != nil ? "shows you the games that make up a win streak" : "allows you to review the game history for all players on this device, or for a single player").")
        
        helpView.add("The @*/Filter@*/ button allows you to view the game history for a specific player.\n\n\(self.filterState == .notFiltered ? "If you tap it you will see a list of players.\n\nTap a player to show only their history" : (self.filterState == .selecting ? "When you are filtering the filter button becomes a cancel button.\n\nTap it to return to showing all players' history" : "When you are filtering the player's name will appear on the filter button with a cross beside it.\n\nTap it to stop filtering and return to all players' history")).", views: [self.filterButton], bannerId: self.customButtonId)
        
        if let syncButton = self.syncButton {
            helpView.add("The @*/Sync@*/ button allows you to synchronize the data on this device with the data in iCloud.", views: [syncButton])
        }
        
        helpView.add("As you have tapped the filter button you have a list of current players on the device to select from to start filtering.\n\nTap a player to view their history.\n\nTap the cancel button to return to showing all players' history.", views: [self.filterSelectionView], condition: { self.filterState == .selecting })
        
        helpView.add("The header row contains the column titles.\n\nTap on a column title to sort the data by that column's value.\n\nTap the same column again to reverse the order of the sort.\n\nThe up / down arrow shows the order of the sort.", views: [header])
        
        helpView.add("The body of the screen contains the data.\n\nTap on a row to show the game detail and, if required, you can update the location of the game.", views: [body], item: 0, itemTo: 999, shrink: true, direction: .up)
        
    }
    
    // MARK: - Load data ================================================================= -
    
    func getHistory() {
        // Load list of games from core data
        if let winStreakPlayer = self.winStreakPlayer {
            // Limiting to win streak for a player
            self.history = History(winStreakFor: winStreakPlayer)
        } else {
            // All games
            if self.history == nil {
                self.history = History(getParticipants: false, includeBF: Scorecard.adminMode)
            } else {
                self.history.loadGames(getParticipants: false, includeBF: Scorecard.adminMode)
            }
        }
    }
    
    func getPlayerHistory() {
        self.history.loadGames(playerUUID: self.filterPlayerMO.playerUUID!, sortDirection: .descending)
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
                self.history.games.remove(at: row)
                self.dataTableViewController.deleteRows(at: [IndexPath(row: row, section: 0)])
            })
        }
    }
    
    // MARK: - Filter button logic ======================================================================== -
    
    
    @objc private func filterButtonPressed(_ sender: UIButton) {
        self.filterButtonPressed()
    }
    
    private func filterButtonPressed() {
        switch self.filterState {
            case .notFiltered:
                self.filterState = .selecting
        case .filtered:
            if ScorecardUI.smallPhoneSize() {
                self.filterState = .selecting
            } else {
                self.filterState = .notFiltered
            }
        case .selecting:
            self.filterState = .notFiltered
        }
        self.filterStateChange()
    }
    
    private func filterStateChange() {
        var viewHeight = self.customHeightConstraint.constant
        var instructionHeight = self.filterInstructionHeightConstraint?.constant ?? 0.0
        let small = ScorecardUI.smallPhoneSize()
        let filteredHeight: CGFloat = (small ? 44 : 60)
        let unfilteredHeight: CGFloat = (small ? 0 : 60)

        if self.filterInstructionView == nil {
            self.createFilterInstructionView()
        }
        if self.filterSelectionView == nil {
            self.createFilterSelectionView()
        }

        switch self.filterState {
        case .selecting:
            viewHeight = self.filterSelectionViewHeight + filteredHeight
            instructionHeight = filteredHeight
            if small {
                self.filterInstructionLabel.text = "Filter by Player"
                self.filterClearButton.isHidden = true
                self.filterInstructionView.isHidden = false
                self.bannerFilterButton?.setImage(UIImage(named: "cross white")!, for: .normal)
            } else {
                self.filterButton.setTitle("Cancel", for: .normal)
                self.filterClearView?.isHidden = true
            }

        case .notFiltered:
            self.getHistory()
            self.dataTableViewController.refreshData(recordList: history.games)
            viewHeight = unfilteredHeight
            instructionHeight = (small ? 0.0 : filteredHeight)
            if small {
                self.filterInstructionView.isHidden = true
                self.bannerFilterButton?.setImage(UIImage(named: "filter")!, for: .normal)
            } else {
                self.filterButton.setTitle("Filter", for: .normal)
                self.filterClearView?.isHidden = true
            }

        case .filtered:
            self.getPlayerHistory()
            self.dataTableViewController.refreshData(recordList: history.games)
            viewHeight = filteredHeight
            instructionHeight = filteredHeight
            if small {
                self.filterInstructionLabel.text = "History for \(self.filterPlayerMO.name!)"
                self.filterClearButton.isHidden = false
                self.filterInstructionView.isHidden = false
                self.bannerFilterButton?.setImage(UIImage(named: "filter")!, for: .normal)
            } else {
                self.filterButton.setTitle(self.filterPlayerMO.name!, for: .normal)
                self.filterClearView?.isHidden = false
            }
        }
        
        if self.customHeightConstraint.constant != viewHeight ||
            self.filterInstructionHeightConstraint.constant != instructionHeight {
            Utility.animate(duration: viewHeight == 0.0 ? 0.3 : 0.5) {
                self.customHeightConstraint.constant = viewHeight
                self.filterInstructionHeightConstraint.constant = instructionHeight
            }
            self.filterSelectionView.set(players: Scorecard.shared.playerList, scrollEnabled: true, collectionViewInsets: UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10))
        }
    }
    
    @objc private func filterClearButtonPressed(_ sender: UIButton) {
        self.filterState = .notFiltered
        self.filterStateChange()
    }
    
    private func createFilterInstructionView() {
        let small = ScorecardUI.smallPhoneSize()
        self.filterInstructionView = UIView()
        self.filterInstructionView.backgroundColor = Palette.banner.background
        self.filterInstructionView.accessibilityIdentifier = "filterInstruction"
        self.customView!.addSubview(self.filterInstructionView)
        self.customView!.superview?.bringSubviewToFront(self.customView!)
        Constraint.anchor(view: customView!, control: self.filterInstructionView, attributes: .top, .leading, .trailing)
        self.filterInstructionHeightConstraint = Constraint.setHeight(control: self.filterInstructionView, height: small ? 0.0 : 44.0)
        self.customHeightConstraint.constant = self.filterInstructionHeightConstraint.constant
        if small {
            // Create instruction label
            self.filterInstructionLabel = UILabel()
            self.filterInstructionLabel.textColor = Palette.banner.text
            self.filterInstructionLabel.font = UIFont.systemFont(ofSize: 24.0, weight: .light)
            self.filterInstructionView.addSubview(self.filterInstructionLabel)
            Constraint.anchor(view: self.filterInstructionView, control: self.filterInstructionLabel, attributes: .centerX, .centerY)

            // Create clear button
            self.filterClearButton = RoundedButton(frame: CGRect(x: 0.0, y: 0.0, width: 22.0, height: 22.0))
            self.filterClearButton.setTitle("X", for: .normal)
            self.filterClearButton.titleLabel?.font = UIFont.systemFont(ofSize: 24.0, weight: .light)
            self.filterClearButton.addTarget(self, action: #selector(HistoryViewer.filterButtonPressed(_:)), for: .touchUpInside)
            self.filterClearButton.accessibilityIdentifier = "filterClearButton"
            self.filterInstructionView.addSubview(self.filterClearButton)
            Constraint.anchor(view: self.filterInstructionView, control: self.filterClearButton, to: self.filterInstructionLabel, multiplier: 1.0, constant: 4.0, toAttribute: .trailing, attributes: .leading)
            Constraint.anchor(view: self.filterInstructionView, control: self.filterClearButton, attributes: .centerY)
            
        } else {
            let buttonHeight: CGFloat = 36
            let buttonWidth: CGFloat = 130
            let clearHeight: CGFloat = 25
            let clearImageHeight: CGFloat = 10

            // Create the filter button
            self.filterButton = ShadowButton(frame: CGRect(x: 0, y: 0, width: buttonWidth, height: buttonHeight), cornerRadius: 7.0)
            self.filterButton.setBackgroundColor(Palette.bannerShadow.background)
            self.filterButton.setTitleColor(Palette.bannerShadow.text, for: .normal)
            Constraint.setWidth(control: self.filterButton, width: buttonWidth)
            Constraint.setHeight(control: self.filterButton, height: buttonHeight)
            self.filterButton.setTitle("Filter", for: .normal)
            self.filterButton.accessibilityIdentifier = "filterButton"
            self.filterInstructionView.addSubview(self.filterButton)
            Constraint.anchor(view: self.filterInstructionView, control: filterButton, attributes: .centerY)
            Constraint.anchor(view: self.filterInstructionView, control: filterButton, constant: -((buttonWidth / 2.0) + 5.0), attributes: .centerX)
            self.filterButton.addTarget(self, action: #selector(HistoryViewer.filterButtonPressed(_:)), for: .touchUpInside)
            
            // Add cancel view
            self.filterClearView = UIView(frame: CGRect(x: 0, y: 0, width: clearHeight, height: clearHeight))
            self.filterClearView.isUserInteractionEnabled = false
            self.filterClearView.roundCorners(cornerRadius: clearHeight / 2.0)
            self.filterClearView.backgroundColor = Palette.banner.background
            self.filterClearView.accessibilityIdentifier = "filterClearView"
            Constraint.setWidth(control: self.filterClearView, width: clearHeight)
            Constraint.setHeight(control: self.filterClearView, height: clearHeight)
            self.filterButton.addSubview(self.filterClearView)
            Constraint.anchor(view: self.filterButton, control: self.filterClearView, attributes: .centerY)
            Constraint.anchor(view: self.filterButton, control: self.filterClearView, constant: 5, attributes: .leading)
            let filterClearImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: clearImageHeight, height: clearImageHeight))
            Constraint.setWidth(control: filterClearImageView, width: clearImageHeight)
            Constraint.setHeight(control: filterClearImageView, height: clearImageHeight)
            filterClearImageView.image = UIImage(named: "cross white")?.asTemplate
            filterClearImageView.contentMode = .scaleAspectFit
            filterClearImageView.tintColor = Palette.banner.text
            self.filterClearView.addSubview(filterClearImageView)
            Constraint.anchor(view: self.filterClearView, control: filterClearImageView, attributes: .centerX, .centerY)

            // Create the sync button
            self.syncButton = ShadowButton(frame: CGRect(x: 0, y: 0, width: buttonWidth, height: buttonHeight), cornerRadius: 7)
            self.syncButton.setBackgroundColor(Palette.bannerShadow.background)
            self.syncButton.setTitleColor(Palette.bannerShadow.text, for: .normal)
            Constraint.setWidth(control: self.syncButton, width: buttonWidth)
            Constraint.setHeight(control: self.syncButton, height: buttonHeight)
            self.syncButton.setTitle("Sync", for: .normal)
            self.syncButton.accessibilityIdentifier = "syncButton"
            self.filterInstructionView.addSubview(syncButton)
            Constraint.anchor(view: self.filterInstructionView, control: syncButton, attributes: .centerY)
            Constraint.anchor(view: self.filterInstructionView, control: syncButton, constant: ((buttonWidth / 2.0) + 5.0), attributes: .centerX)
            self.syncButton.addTarget(self.dataTableViewController, action: #selector(DataTableViewController.showSync(_:)), for: .touchUpInside)
        }
    }
    
    private func createFilterSelectionView() {
        let filterSelectionContainerView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: self.customView.frame.width, height: 0.0))
        filterSelectionContainerView.backgroundColor = UIColor.clear
        filterSelectionContainerView.clipsToBounds = true
        filterSelectionContainerView.accessibilityIdentifier = "filterSelectionContainer"
        self.customView.addSubview(filterSelectionContainerView)
        Constraint.anchor(view: customView!, control: filterSelectionContainerView, attributes: .bottom, .leading, .trailing)
        Constraint.anchor(view: customView!, control: filterSelectionContainerView, to: self.filterInstructionView, toAttribute: .bottom, attributes: .top)
        
        self.filterSelectionView = PlayerSelectionView(parent: self.dataTableViewController, frame: CGRect(x: 0.0, y: 0.0, width: self.customView.frame.width, height: self.dataTableViewController.view.frame.height - self.customView.frame.minY), interRowSpacing: 10.0)
        self.filterSelectionView.delegate = self
        self.filterSelectionView.backgroundColor = Palette.banner.background
        self.filterSelectionView.set(textColor: Palette.banner.text)
        
        self.setFilterSelectionViewRequiredHeight()
        
        filterSelectionContainerView.addSubview(self.filterSelectionView)
        Constraint.anchor(view: filterSelectionContainerView, control: self.filterSelectionView, attributes: .bottom, .leading, .trailing)
        self.filterSelectionHeightConstraint = Constraint.setHeight(control: self.filterSelectionView, height: self.filterSelectionViewHeight)
    }
    
    private func setFilterSelectionViewRequiredHeight() {
        
        self.filterSelectionViewHeight = self.filterSelectionView.getHeightFor(items: Scorecard.shared.playerList.count)
        self.filterSelectionViewHeight = min(self.filterSelectionViewHeight, self.dataTableViewController.view.frame.height - self.customView.frame.minY - 88)
        
        self.landscape = ScorecardUI.landscape()
        
    }
    
}
