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
    private var sourceViewController: UIViewController!
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
    private var filterThumbnail: ThumbnailView!
    private var filterPlayerMO: PlayerMO!
    private var bannerFilterButton: UIButton!
    private var syncButton: ShadowButton!
    private var landscape = false
    
    // Local class variables
    let availableFields: [DataTableField] = [
        DataTableField("",              "",          sequence: 0,   width: 16,  type: .string),
        DataTableField("=location",     "Location",  sequence: 2,   width: 100, type: .string,      align: NSTextAlignment.left, pad: true),
        DataTableField("info",          "",          sequence: 14,  width: 40,  type: .button),
        DataTableField("cross red",     "",          sequence: 13,  width: 40,  type: .button),
        DataTableField("datePlayed",    "Date",      sequence: 3,   width: 100, type: .date),
        DataTableField("=player1",      "Winner",    sequence: 5,   width: 80,  type: .string),
        DataTableField("=score1",       "Score",     sequence: 6,   width: 50,  type: .int),
        DataTableField("=player2",      "Second",    sequence: 7,   width: 80,  type: .string),
        DataTableField("=score2",       "Score",     sequence: 8,   width: 50,  type: .int),
        DataTableField("=player3",      "Third",     sequence: 9,   width: 80,  type: .string),
        DataTableField("=score3",       "Score",     sequence: 10,  width: 50,  type: .int),
        DataTableField("=player4",      "Fourth",    sequence: 11,  width: 80,  type: .string),
        DataTableField("=score4",       "Score",     sequence: 12,  width: 50,  type: .int),
        DataTableField("datePlayed",    "",          sequence: 4,   width: 60,  type: .time,        combineHeading: "Date")
    ]
    
    init(from viewController: UIViewController, winStreakPlayer: String? = nil, completion: (()->())? = nil) {
        super.init()
        
        self.sourceViewController = viewController
        self.winStreakPlayer = winStreakPlayer
        
        if winStreakPlayer != nil {
            // Just showing the win streak for a player
            self.viewTitle = "Win Streak"
            self.allowSync = false
            self.backImage = "back"
        }
        
        self.getHistory()
        self.callerCompletion = completion
        
        // Call the data table viewer
        self.dataTableViewController = DataTableViewController.show(from: viewController, delegate: self, recordList: history.games)
        
        // Setup the custom (filter) view
        if self.winStreakPlayer == nil {
            self.customView = self.dataTableViewController.customHeaderView
            self.customHeightConstraint = self.dataTableViewController.customHeaderViewHeightConstraint
            self.customView.layoutIfNeeded()
            self.filterStateChange()
        }
    }
    
    internal func layoutSubviews() {
        if self.filterState == .selecting && self.landscape != ScorecardUI.landscape() {
            // Re-size window
            self.setFilterSelectionViewRequiredHeight()
            self.filterStateChange()
        }
    }
       
    internal func setup(customButton: UIButton) {
        if self.winStreakPlayer == nil && ScorecardUI.smallPhoneSize() {
            self.bannerFilterButton = customButton
            self.bannerFilterButton.setImage(UIImage(named: "filter"), for: .normal)
            self.bannerFilterButton.contentHorizontalAlignment = .center
            self.bannerFilterButton.addTarget(self, action: #selector(HistoryViewer.filterButtonPressed(_:)), for: .touchUpInside)
            self.filterThumbnail = ThumbnailView(frame: self.bannerFilterButton.imageView!.frame)
            self.bannerFilterButton.addSubview(self.filterThumbnail)
            Constraint.anchor(view: self.bannerFilterButton, control: self.filterThumbnail, attributes: .leading, .trailing, .top, .bottom)
            self.filterThumbnail.isHidden = true
            self.filterThumbnail.isUserInteractionEnabled = false
        }
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
        
        return history.games
    }
    
    internal func completion() {
        self.callerCompletion?()
    }
    
    internal func syncButtons(enabled: Bool) {
        self.syncButton?.isEnabled = enabled
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
                self.dataTableViewController.deleteRows(at: [IndexPath(row: row, section: 0)])
            })
        }
    }
    
    // MARK: - Filter button logic ======================================================================== -
    
    @objc private func filterButtonPressed(_ sender: UIButton) {
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
            self.filterThumbnail?.isHidden = true

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
            self.filterThumbnail?.isHidden = true

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
            self.filterThumbnail?.set(playerMO: self.filterPlayerMO, nameHeight: 0.0)
            self.filterThumbnail?.isHidden = false
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
        self.filterInstructionView.backgroundColor = Palette.banner
        self.customView!.addSubview(self.filterInstructionView)
        self.customView!.superview?.bringSubviewToFront(self.customView!)
        Constraint.anchor(view: customView!, control: self.filterInstructionView, attributes: .top, .leading, .trailing)
        self.filterInstructionHeightConstraint = Constraint.setHeight(control: self.filterInstructionView, height: small ? 0.0 : 44.0)
        if small {
            // Create instruction label
            self.filterInstructionLabel = UILabel()
            self.filterInstructionLabel.textColor = Palette.bannerText
            self.filterInstructionLabel.font = UIFont.systemFont(ofSize: 24.0, weight: .light)
            self.filterInstructionView.addSubview(self.filterInstructionLabel)
            Constraint.anchor(view: self.filterInstructionView, control: self.filterInstructionLabel, attributes: .centerX, .centerY)

            // Create clear button
            self.filterClearButton = RoundedButton(frame: CGRect(x: 0.0, y: 0.0, width: 22.0, height: 22.0))
            self.filterClearButton.setTitle("X", for: .normal)
            self.filterClearButton.titleLabel?.font = UIFont.systemFont(ofSize: 24.0, weight: .light)
            self.filterClearButton.addTarget(self, action: #selector(HistoryViewer.filterButtonPressed(_:)), for: .touchUpInside)
            self.filterInstructionView.addSubview(self.filterClearButton)
            Constraint.anchor(view: self.filterInstructionView, control: self.filterClearButton, to: self.filterInstructionLabel, multiplier: 1.0, constant: 4.0, toAttribute: .trailing, attributes: .leading)
            Constraint.anchor(view: self.filterInstructionView, control: self.filterClearButton, attributes: .centerY)
            
        } else {
            let buttonHeight: CGFloat = 36
            let buttonWidth: CGFloat = 130
            let clearHeight: CGFloat = 25
            let clearImageHeight: CGFloat = 10
            let thumbnailHeight: CGFloat = 50

            // Create the filter button
            self.filterButton = ShadowButton(frame: CGRect(x: 0, y: 0, width: buttonWidth, height: buttonHeight), cornerRadius: 7.0)
            self.filterButton.setBackgroundColor(Palette.bannerShadow)
            self.filterButton.setTitleColor(Palette.bannerText, for: .normal)
            Constraint.setWidth(control: self.filterButton, width: buttonWidth)
            Constraint.setHeight(control: self.filterButton, height: buttonHeight)
            self.filterButton.setTitle("Filter", for: .normal)
            self.filterInstructionView.addSubview(self.filterButton)
            Constraint.anchor(view: self.filterInstructionView, control: filterButton, attributes: .centerY)
            Constraint.anchor(view: self.filterInstructionView, control: filterButton, constant: -((buttonWidth / 2.0) + 5.0), attributes: .centerX)
            self.filterButton.addTarget(self, action: #selector(HistoryViewer.filterButtonPressed(_:)), for: .touchUpInside)
            
            // Add cancel view
            self.filterClearView = UIView(frame: CGRect(x: 0, y: 0, width: clearHeight, height: clearHeight))
            self.filterClearView.isUserInteractionEnabled = false
            self.filterClearView.roundCorners(cornerRadius: clearHeight / 2.0)
            self.filterClearView.backgroundColor = Palette.banner
            Constraint.setWidth(control: self.filterClearView, width: clearHeight)
            Constraint.setHeight(control: self.filterClearView, height: clearHeight)
            self.filterButton.addSubview(self.filterClearView)
            Constraint.anchor(view: self.filterButton, control: self.filterClearView, attributes: .centerY)
            Constraint.anchor(view: self.filterButton, control: self.filterClearView, constant: 5, attributes: .leading)
            let filterClearImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: clearImageHeight, height: clearImageHeight))
            Constraint.setWidth(control: filterClearImageView, width: clearImageHeight)
            Constraint.setHeight(control: filterClearImageView, height: clearImageHeight)
            filterClearImageView.image = UIImage(named: "cross white")?.asTemplate()
            filterClearImageView.contentMode = .scaleAspectFit
            filterClearImageView.tintColor = Palette.bannerText
            self.filterClearView.addSubview(filterClearImageView)
            Constraint.anchor(view: self.filterClearView, control: filterClearImageView, attributes: .centerX, .centerY)

            // Create the sync button
            self.syncButton = ShadowButton(frame: CGRect(x: 0, y: 0, width: buttonWidth, height: buttonHeight), cornerRadius: 7)
            self.syncButton.setBackgroundColor(Palette.bannerShadow)
            self.syncButton.setTitleColor(Palette.bannerText, for: .normal)
            Constraint.setWidth(control: self.syncButton, width: buttonWidth)
            Constraint.setHeight(control: self.syncButton, height: buttonHeight)
            self.syncButton.setTitle("Sync", for: .normal)
            self.filterInstructionView.addSubview(syncButton)
            Constraint.anchor(view: self.filterInstructionView, control: syncButton, attributes: .centerY)
            Constraint.anchor(view: self.filterInstructionView, control: syncButton, constant: ((buttonWidth / 2.0) + 5.0), attributes: .centerX)
            self.syncButton.addTarget(self.dataTableViewController, action: #selector(DataTableViewController.showSync(_:)), for: .touchUpInside)
            
            // Create the player thumbnail
            self.filterThumbnail = ThumbnailView(frame: CGRect(x: 0, y: 0, width: thumbnailHeight, height: thumbnailHeight))
            Constraint.setWidth(control: self.filterThumbnail, width: thumbnailHeight)
            Constraint.setHeight(control: self.filterThumbnail, height: thumbnailHeight)
            self.filterInstructionView.addSubview(self.filterThumbnail)
            Constraint.anchor(view: self.filterInstructionView, control: self.filterThumbnail, attributes: .centerX, .centerY)
            self.filterThumbnail.setShadow()
        }
    }
    
    private func createFilterSelectionView() {
        self.filterSelectionView = PlayerSelectionView(parent: self.dataTableViewController, frame: CGRect(x: 0.0, y: 0.0, width: self.customView.frame.width, height: self.dataTableViewController.view.frame.height - self.customView.frame.minY), interRowSpacing: 10.0)
        self.filterSelectionView.delegate = self
        self.filterSelectionView.backgroundColor = Palette.banner
        self.filterSelectionView.set(textColor: Palette.bannerText)
        
        self.setFilterSelectionViewRequiredHeight()
        
        self.customView.addSubview(self.filterSelectionView)
        Constraint.anchor(view: customView!, control: self.filterSelectionView, attributes: .bottom, .leading, .trailing)
        Constraint.anchor(view: customView!, control: self.filterSelectionView, to: self.filterInstructionView, toAttribute: .bottom, attributes: .top)
        
    }
    
    private func setFilterSelectionViewRequiredHeight() {
        
        self.filterSelectionViewHeight = self.filterSelectionView.getHeightFor(items: Scorecard.shared.playerList.count)
        self.filterSelectionViewHeight = min(self.filterSelectionViewHeight, self.dataTableViewController.view.frame.height - self.customView.frame.minY - 88)
        
        self.landscape = ScorecardUI.landscape()
        
    }
    
}
