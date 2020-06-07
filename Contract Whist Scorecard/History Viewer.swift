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
    public var allowSync = true
    public let initialSortField = "datePlayed"
    public let initialSortDescending = true
    public let headerRowHeight: CGFloat = 54.0
    public let headerTopSpacingHeight: CGFloat = 10.0
    public let bodyRowHeight: CGFloat = 40.0
    public var backImage: String = "home"
   
    private var history: History!
    private var winStreakPlayer: String?
    private var sourceViewController: UIViewController
    private var dataTableViewController: DataTableViewController!
    private var callerCompletion: (()->())?
    private var customView: UIView!
    private var customHeightConstraint: NSLayoutConstraint!
    private var filterState: FilterState = .notFiltered
    private var filterInstructionView: UIView!
    private var filterInstructionHeightConstraint: NSLayoutConstraint!
    private var filterInstructionLabel: UILabel!
    private var filterClearButton: UIButton!
    private var filterSelectionView: PlayerSelectionView!
    private var filterSelectionHeightConstraint: NSLayoutConstraint!
    private var filterSelectionViewHeight: CGFloat!
    private var filterButton: UIButton!
    private var filterButtonThumbnail: ThumbnailView!
    private var filterPlayerMO: PlayerMO!
    private var landscape = false
    
    // Local class variables
    let availableFields: [DataTableField] = [
        DataTableField("",              "",          sequence: 0,   width: 16,  type: .string),
        DataTableField("=count",        "Count",     sequence: 1,   width: 60,  type: .int),
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
        self.sourceViewController = viewController
        self.winStreakPlayer = winStreakPlayer
        
        if winStreakPlayer != nil {
            // Just showing the win streak for a player
            self.viewTitle = "Win Streak"
            self.allowSync = false
            self.backImage = "back"
        }
        
        super.init()
        self.getHistory()
        self.callerCompletion = completion
        
        // Call the data table viewer
        self.dataTableViewController = DataTableViewController.show(from: viewController, delegate: self, recordList: history.games)
        self.customView = self.dataTableViewController.customHeaderView
        self.customHeightConstraint = self.dataTableViewController.customHeaderViewHeightConstraint
    }
    
    internal func layoutSubviews() {
        if self.filterState == .selecting && self.landscape != ScorecardUI.landscape() {
            // Re-size window
            self.setFilterSelectionViewRequiredHeight()
            self.filterStateChange()
        }
    }
       
    internal func setupCustomButton(barButtonItem: UIBarButtonItem) {
        if self.winStreakPlayer == nil {
            self.filterButton = UIButton(frame: CGRect(origin: CGPoint(), size: CGSize(width: 22.0, height: 22.0)))
            self.filterButton.setImage(UIImage(named: "filter"), for: .normal)
            self.filterButton.contentHorizontalAlignment = .left
            self.filterButton.addTarget(self, action: #selector(HistoryViewer.filterButtonPressed(_:)), for: .touchUpInside)
            self.filterButtonThumbnail = ThumbnailView(frame: self.filterButton.imageView!.frame)
            self.filterButton.addSubview(self.filterButtonThumbnail)
            self.filterButtonThumbnail.isHidden = true
            self.filterButtonThumbnail.isUserInteractionEnabled = false
            barButtonItem.customView = self.filterButton
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
        case "=count", "cross red":
            result = !Scorecard.adminMode
        case "=location":
            result = !Scorecard.activeSettings.saveLocation
        default:
            break
        }
        
        return result
    }
    
    internal func derivedField(field: String, record: DataTableViewerDataSource, sortValue: Bool) -> String {
        var numericResult: Int?
        var result = ""
        
        let historyGame = record as! HistoryGame
        
        self.loadParticipants(historyGame)
        
        switch field  {
        case "count":
            if let index = self.history.games.firstIndex(where: { $0.gameUUID == historyGame.gameUUID }) {
                numericResult = index + 1
            } else {
                result = ""
            }
            
        case "location":
            if let location = historyGame.gameLocation.description {
                result = location
            } else {
                result = ""
            }
            
        case "player1", "player2", "player3", "player4":
            let player = Int(String(field.suffix(1)))!
            if player <= historyGame.participant?.count ?? 0 {
                if let participant = historyGame.participant?[player-1] {
                    result = participant.name
                } else {
                    result = ""
                }
            } else {
                result = ""
            }

        case "score1", "score2", "score3", "score4":
            let player = Int(String(field.suffix(1)))!
            if player <= historyGame.participant?.count ?? 0 {
                if let participant = historyGame.participant?[player-1] {
                    numericResult = Int(participant.totalScore)
                } else {
                    result = ""
                }
            } else {
                result = ""
            }

        default:
            result = ""
        }
        
        if numericResult != nil {
            if sortValue {
                let valueString = String(format: "%.4f", Double(numericResult!) + 1e14)
                result = String(repeating: " ", count: 20 - valueString.count) + valueString
            } else {
                result = "\(numericResult!)"
            }
        }
        
        return result
    }
    
    private func loadParticipants(_ historyGame: HistoryGame) {
        if historyGame.participant == nil {
            if let index = self.history.games.firstIndex(where: { $0.gameUUID == historyGame.gameUUID } ) {
                history.getParticipants(index: index)
            }
        }
    }
    
    internal func refreshData(recordList: [DataTableViewerDataSource]) -> [DataTableViewerDataSource] {
        self.getHistory()
        return history.games
    }
    
    internal func completion() {
        self.callerCompletion?()
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
        self.history.loadGames(playerEmail: self.filterPlayerMO.email!, sortDirection: .descending)
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
        case .notFiltered, .filtered:
            self.filterState = .selecting
        case .selecting:
            self.filterState = .notFiltered
        }
        self.filterStateChange()
    }
    
    private func filterStateChange() {
        var viewHeight = self.customHeightConstraint.constant
        var instructionHeight = self.filterInstructionHeightConstraint?.constant ?? 0.0
        
        switch self.filterState {
        case .selecting:
            if self.filterInstructionView == nil {
                self.createFilterInstructionView()
            }
            if self.filterSelectionView == nil {
                self.createFilterSelectionView()
            }

            viewHeight = self.filterSelectionViewHeight + 44.0
            instructionHeight = 44.0
            self.filterInstructionLabel.text = "Filter by Player"
            self.filterClearButton.isHidden = true
            self.filterInstructionView.isHidden = false
            self.filterButton?.setImage(UIImage(named: "cross white"), for: .normal)
            self.filterButtonThumbnail?.isHidden = true

        case .notFiltered:
            self.getHistory()
            self.dataTableViewController.refreshData(recordList: history.games)
            viewHeight = 0.0
            instructionHeight = 0.0
            self.filterInstructionView.isHidden = true
            self.filterButton?.setImage(UIImage(named: "filter"), for: .normal)
            self.filterButtonThumbnail?.isHidden = true

        case .filtered:
            self.getPlayerHistory()
            self.dataTableViewController.refreshData(recordList: history.games)
            self.filterInstructionLabel.text = "History for \(self.filterPlayerMO.name!)"
            viewHeight = 44.0
            instructionHeight = 44.0
            self.filterClearButton.isHidden = false
            self.filterInstructionView.isHidden = false
            self.filterButton?.setImage(UIImage(named: "filter"), for: .normal)
            self.filterButtonThumbnail?.set(playerMO: self.filterPlayerMO, nameHeight: 0.0)
            self.filterButtonThumbnail?.isHidden = false
        }
        
        if self.customHeightConstraint.constant != viewHeight ||
            self.filterInstructionHeightConstraint.constant != instructionHeight {
            Utility.animate(duration: viewHeight == 0.0 ? 0.3 : 0.5) {
                self.customHeightConstraint.constant = viewHeight
                self.filterInstructionHeightConstraint.constant = instructionHeight
            }
            self.filterSelectionView.set(players: Scorecard.shared.playerList, scrollEnabled: true, collectionViewInsets: UIEdgeInsets(top: 0, left: 10, bottom: 00, right: 0))
        }
    }
    
    @objc private func filterClearButtonPressed(_ sender: UIButton) {
        self.filterState = .notFiltered
        self.filterStateChange()
    }
    
    private func createFilterInstructionView() {
        self.filterInstructionView = UIView()
        self.filterInstructionView.backgroundColor = Palette.banner
        self.filterInstructionLabel = UILabel()
        self.filterInstructionLabel.textColor = Palette.bannerText
        self.filterInstructionLabel.font = UIFont.systemFont(ofSize: 24.0, weight: .light)
        self.filterClearButton = UIButton(frame: CGRect(x: 0.0, y: 0.0, width: 22.0, height: 22.0))
        self.filterClearButton.setTitle("X", for: .normal)
        self.filterClearButton.titleLabel?.font = UIFont.systemFont(ofSize: 24.0, weight: .light)
        self.filterClearButton.addTarget(self, action: #selector(HistoryViewer.filterClearButtonPressed(_:)), for: .touchUpInside)
        self.filterInstructionView.addSubview(self.filterInstructionLabel)
        self.filterInstructionView.addSubview(self.filterClearButton)
        Constraint.anchor(view: self.filterInstructionView, control: self.filterInstructionLabel, attributes: .centerX, .centerY)
        Constraint.anchor(view: self.filterInstructionView, control: self.filterClearButton, to: self.filterInstructionLabel, multiplier: 1.0, constant: 4.0, toAttribute: .trailing, attributes: .leading)
        Constraint.anchor(view: self.filterInstructionView, control: self.filterClearButton, attributes: .centerY)
        self.customView!.addSubview(self.filterInstructionView)
        Constraint.anchor(view: customView!, control: self.filterInstructionView, attributes: .top, .leading, .trailing)
        self.filterInstructionHeightConstraint = Constraint.setHeight(control: self.filterInstructionView, height: 0.0)
    }
    
    private func createFilterSelectionView() {
        self.filterSelectionView = PlayerSelectionView(parent: self.dataTableViewController, frame: CGRect(x: 0.0, y: 0.0, width: self.customView.frame.width, height: self.dataTableViewController.view.frame.height - self.customView.frame.minY), interRowSpacing: 10.0)
        self.filterSelectionView.delegate = self
        self.filterSelectionView.backgroundColor = UIColor.white
        self.filterSelectionView.set(textColor: Palette.text)
        
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
