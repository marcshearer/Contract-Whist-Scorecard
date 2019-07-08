//
//  SelectPlayersController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 19/03/2019.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

public enum DescriptionMode {
    case opponents
    case lastPlayed
    case none
}

class SelectPlayersViewController: CustomViewController, UITableViewDelegate, UITableViewDataSource, SyncDelegate {
    
    // MARK: - Class Properties ======================================================================== -
    
    // Main state properties
    private let scorecard = Scorecard.shared
    private var sync: Sync!
    
    // Properties to pass state to action controller
    public var selection: [Bool] = []
    public var playerList: [PlayerDetail] = []
    public var selected = 0

    // Properties to get state to/from calling segue
    public var specificEmail = ""
    public var descriptionMode: DescriptionMode = .none
    public var returnSegue = ""
    public var actionText = ""
    public var backText = "Back"
    public var backImage = "back"
    public var allowOtherPlayer = false
    public var allowNewPlayer = false
    
    // Local class variables
    private var combinedPlayerList: [Int : [PlayerDetail]] = [:]
    private var combinedSelection: [Int : [Bool]] = [:]
    private var selectedPlayer: IndexPath!
    private var syncStarted = false
    private var syncFinished = false
    private var otherPlayerRow = -1
    private var newPlayerRow = -1
    private var createdPlayerSection = 1
    private var downloadedPlayerSection = 2
    private var actionSection = 0
    private var relatedPlayerSection = 3
    private var actionRows = 0

    // Alert controller while waiting for cloud download
    private var cloudAlertController: UIAlertController!
    private var cloudIndicatorView: UIActivityIndicatorView!
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var backButton: RoundedButton!
    @IBOutlet private weak var continueButton: RoundedButton!
    @IBOutlet private weak var changeAllButton: RoundedButton!
    @IBOutlet private weak var navigationBar: UINavigationBar!
    @IBOutlet private weak var toolbarViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var footerPaddingTopConstraint: NSLayoutConstraint!
    
    // MARK: - IB Actions ============================================================================== -

    @IBAction private func changeAllPressed(sender: UIButton) {
        if self.selected == 0 {
            // Select all
            selectAll(true)
        } else {
            // Clear selection
            selectAll(false)
        }
        formatButtons()
    }
    
    @IBAction private func continuePressed(sender: UIButton) {
        
        if selected > 0 {
            // Action selection
            self.createPlayers()
        }
        
        // Abandon any sync in progress
        self.sync?.stop()
        
        // Return to calling program
        self.performSegue(withIdentifier: returnSegue, sender: self)
        
    }
    
    @IBAction private func backPressed(sender: UIButton) {
        
        // Clear lists
        self.selected = 0
        self.selection = []
        self.playerList = []
        
        // Abandon any sync in progress
        self.sync?.stop()
        
        // Return to calling program
        self.performSegue(withIdentifier: returnSegue, sender: self)
        
    }
    
    // MARK: - View Overrides ========================================================================== -
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupView()
        self.formatButtons()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.setNeedsLayout()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        scorecard.reCenterPopup(self)
        view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.formatButtons()
        if !syncStarted {
            self.selectCloudPlayers()
            syncStarted = true
        }
    }
    
    // MARK: - TableView Overrides ================================================================ -

    internal func numberOfSections(in tableView: UITableView) -> Int {
        return relatedPlayerSection + 1
    }
    
    internal func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if relatedPlayerSection > 0 && section == relatedPlayerSection {
            return 60
        } else if (section == createdPlayerSection || section == downloadedPlayerSection) && combinedPlayerList[section]!.count > 0 {
            return 30
        } else {
            return 0
        }
    }
    
    internal func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let frame = CGRect(x: 10.0, y: 0.0, width: tableView.frame.width - 15.0, height: (relatedPlayerSection > 0 && section == relatedPlayerSection ? 60 : 30))
        let view = UIView(frame: frame)
        view.backgroundColor = Palette.sectionHeading
        let title = UILabel(frame: frame)
        title.font = UIFont.boldSystemFont(ofSize: 20.0)
        title.textColor = Palette.sectionHeadingText
        if relatedPlayerSection > 0 {
            switch section {
            case createdPlayerSection:
                title.text = "Created players"
            case downloadedPlayerSection:
                title.text = "Downloaded players"
            case relatedPlayerSection:
                title.text =  "Add players who have previously played with those on this device"
                title.numberOfLines = 0
            default:
                return nil
            }
            view.addSubview(title)
        }
        return view
    }
    
    internal func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case actionSection:
            return actionRows
        case relatedPlayerSection:
            return max(1, self.combinedPlayerList[relatedPlayerSection]!.count)
        case createdPlayerSection, downloadedPlayerSection:
            return self.combinedPlayerList[section]?.count ?? 0
        default:
            return 0
        }
    }
    
    internal func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: SelectPlayersCell
        
        switch indexPath.section {
        case actionSection:
            // Specific player actions
            
            // Create cell
            cell = tableView.dequeueReusableCell(withIdentifier: "Action Cell", for: indexPath) as! SelectPlayersCell
            
            switch indexPath.row {
            case newPlayerRow:
                cell.playerName.text = "Create new player"
                cell.playerDescription.text = "Enter details manually"
            case otherPlayerRow:
                cell.playerName.text = "Download player"
                cell.playerDescription.text = "Download player using Unique ID"
            default:
                break
            }
            cell.playerName.textColor = Palette.text

        case relatedPlayerSection, createdPlayerSection, downloadedPlayerSection:
            // Players
            
            // Create cell
            cell = tableView.dequeueReusableCell(withIdentifier: "Player Cell", for: indexPath) as! SelectPlayersCell
            
            // Set sizes for no description
            if descriptionMode == .none {
                cell.playerNameBottomConstraint.constant = 0
                cell.playerDescriptionHeightConstraint.constant = 0
            }
            
            if indexPath.section == relatedPlayerSection && combinedPlayerList[relatedPlayerSection]!.count == 0 {
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

            } else {
                if let playerDetail = combinedPlayerList[indexPath.section]?[indexPath.row] {
                    
                    // Update cell text / format
                    cell.playerName.text = playerDetail.name
                    if indexPath.section == createdPlayerSection {
                        cell.playerDescription.text = "Manually created"
                    } else if indexPath.section == relatedPlayerSection && self.descriptionMode == .opponents {
                        cell.playerDescription.text = self.getOpponents(playerDetail)
                    } else {
                        cell.playerDescription.text = self.getLastPlayed(playerDetail)
                    }
                    self.setTick(cell, to: combinedSelection[indexPath.section]?[indexPath.row] ?? false)
                    
                    // Link detail button
                    cell.playerDetail.addTarget(self, action: #selector(SelectPlayersViewController.playerDetail(_:)), for: UIControl.Event.touchUpInside)
                    cell.playerDetail.tag = indexPath.section * 100000 + indexPath.row
                    cell.playerDetail.isHidden = false
                    cell.playerName.textColor = Palette.text
                    cell.selectionStyle = .none
                    
                }
            }
        default:
            cell = SelectPlayersCell()
        }
            
        return cell
    }
    
    internal func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        if indexPath.section != actionSection && self.combinedPlayerList[indexPath.section]?.count ?? 0 > 0 {
            if combinedSelection[indexPath.section]?[indexPath.row] ?? false {
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            } else {
                tableView.deselectRow(at: indexPath, animated: false)
            }
        }
    }
    
    internal func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        var playerDetail: PlayerDetail
        var selectedMode: DetailMode
        
        switch indexPath.section {
        case actionSection:
            switch indexPath.row {
            case newPlayerRow:
                selectedMode = .create
            default:
                selectedMode = .download
            }
            
            switch selectedMode {
            case .download, .create:
                // Blank player to download/create into
                playerDetail = PlayerDetail()
            default:
                // Display selected player
                playerDetail = self.combinedPlayerList[selectedPlayer.section]![selectedPlayer.item]
            }
            
            PlayerDetailViewController.show(from: self, playerDetail: playerDetail, mode: selectedMode, sourceView: self.view,
                                            completion: { (playerDetail, deletePlayer) in
                                                                switch selectedMode {
                                                                case .create, .download:
                                                                    if let newPlayerDetail = playerDetail {
                                                                        self.addNewPlayer(playerDetail: newPlayerDetail, section: (selectedMode == .download ? self.downloadedPlayerSection : self.createdPlayerSection))
                                                                    }
                                                                default:
                                                                    break
                                                                }
                                            })
            
            return nil
        default:
            return indexPath
        }
    }
    
    internal func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case relatedPlayerSection:
            combinedSelection[indexPath.section]![indexPath.row] = true
            selected += 1
            self.formatButtons()
            self.setTick(tableView.cellForRow(at: indexPath) as! SelectPlayersCell, to: true)
        default:
            break
        }
    }
    
    internal func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case relatedPlayerSection:
            combinedSelection[indexPath.section]![indexPath.row] = false
            selected -= 1
            self.formatButtons()
            self.setTick(tableView.cellForRow(at: indexPath) as! SelectPlayersCell, to: false)
        default:
            break
        }
    }
       
    // MARK: - Sync routines including the delegate methods ======================================== -
    
    private func selectCloudPlayers() {

        func syncGetPlayers() {
            
            self.sync?.delegate = self
            
            // Get related players from cloud
            if self.specificEmail != "" {
                _ = self.sync?.synchronise(syncMode: .syncGetPlayers, specificEmail: [self.specificEmail], waitFinish: true)
            } else {
                _ = self.sync?.synchronise(syncMode: .syncGetPlayers, waitFinish: true)
            }
        }
        
        sync = Sync()
        
        if allowNewPlayer || allowOtherPlayer {
            syncGetPlayers()
        } else {
            
            self.cloudAlertController = UIAlertController(title: title, message: "Searching Cloud for related Players\n\n\n\n", preferredStyle: .alert)
        
            //add the activity indicator as a subview of the alert controller's view
            self.cloudIndicatorView = UIActivityIndicatorView(frame: CGRect(x: 0, y: 100,
                                                      width: self.cloudAlertController.view.frame.width,
                                                      height: 100))
            self.cloudIndicatorView.style = .whiteLarge
            self.cloudIndicatorView.color = UIColor.black
            self.cloudIndicatorView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.cloudAlertController.view.addSubview(self.cloudIndicatorView)
            self.cloudIndicatorView.isUserInteractionEnabled = true
            self.cloudIndicatorView.startAnimating()
            
            self.present(self.cloudAlertController, animated: true, completion: {
                syncGetPlayers()
            })
        }
    }
    
    private func getImages(_ imageFromCloud: [PlayerMO]) {
        self.sync.fetchPlayerImagesFromCloud(imageFromCloud)
    }
    
    internal func syncMessage(_ message: String) {
    }
    
    internal func syncAlert(_ message: String, completion: @escaping ()->()) {
        
        syncComplete {
            self.alertMessage(message, title: "Contract Whist Scorecard", okHandler: {
                self.syncFinished = true
                self.formatButtons()
                completion()
            })
        }
    }
    
    internal func syncCompletion(_ errors: Int) {
        Utility.mainThread {
            self.syncComplete {
                self.syncFinished = true
                self.cloudAlertController = nil
                self.formatButtons()
                self.tableView.reloadData()
            }
        }
    }
    
    internal func syncReturnPlayers(_ returnedList: [PlayerDetail]!) {
        
        syncComplete{
            self.syncFinished = true
            if returnedList != nil {
                for playerDetail in returnedList {
                    var index = self.scorecard.playerList.firstIndex(where: {($0.email == playerDetail.email)})
                    if index == nil {
                        if self.combinedPlayerList[self.relatedPlayerSection]!.count == 0 {
                            // Replace status entry
                            self.tableView.performBatchUpdates({
                                self.combinedPlayerList[self.relatedPlayerSection]!.append(playerDetail)
                                self.combinedSelection[self.relatedPlayerSection]?.append(false)
                                self.tableView.reloadRows(at: [IndexPath(row: 0, section: self.relatedPlayerSection)], with: .automatic)
                            })
                        } else {
                            // Insert in order
                            index = self.combinedPlayerList[self.relatedPlayerSection]!.firstIndex(where: { $0.name > playerDetail.name})
                            if index == nil {
                                index = self.combinedPlayerList[self.relatedPlayerSection]!.count
                            }
                            self.tableView.performBatchUpdates({
                                self.combinedPlayerList[self.relatedPlayerSection]!.insert(playerDetail, at: index!)
                                self.combinedSelection[self.relatedPlayerSection]?.insert(false, at: index!)
                                self.tableView.insertRows(at: [IndexPath(row: index!, section: self.relatedPlayerSection)], with: .automatic)
                            })
                        }
                    }
                }
            }
            self.tableView.reloadData()
            self.formatButtons()
        }
    }
    
    internal func syncComplete(completion: @escaping ()->()) {
        Utility.mainThread {
            if self.cloudAlertController == nil {
                completion()
            } else {
                self.cloudAlertController.dismiss(animated: true, completion: completion)
            }
        }
    }
    
   // MARK: - Form Presentation / Handling Routines =================================================== -
    
    private func setupView() {
        
        // Check what specific options exist
        actionRows = 0
        if allowNewPlayer {
            newPlayerRow = actionRows
            actionRows += 1
        }
        if allowOtherPlayer {
            otherPlayerRow = actionRows
            actionRows += 1
        }
        if actionRows > 0 {
            actionSection = 0
            relatedPlayerSection = 3
        } else {
            actionSection = -1
            relatedPlayerSection = 0
        }
        
        // Set up lists / selection
        self.combinedPlayerList[relatedPlayerSection] = []
        self.combinedSelection[relatedPlayerSection] = []
        self.combinedPlayerList[createdPlayerSection] = []
        self.combinedSelection[createdPlayerSection] = []
        self.combinedPlayerList[downloadedPlayerSection] = []
        self.combinedSelection[downloadedPlayerSection] = []

        // Set back button image and text
        self.backButton.setImage(UIImage(named: self.backImage), for: .normal)
        self.backButton.setTitle(self.backText)
        
    }
    
    private func formatButtons() {
        var toolbarHeight:CGFloat = 0.0
        
        if self.combinedPlayerList[relatedPlayerSection]!.count > 0 {
            if selected == 0 {
                // Can't action - can select all
                changeAllButton.setTitle("Select all", for: .normal)
                continueButton.isHidden = true
                toolbarHeight = 44
            } else {
                // Can action - can clear all
                changeAllButton.setTitle("Clear all", for: .normal)
                continueButton.isHidden = false
                toolbarHeight = 44
            }
            continueButton.setTitle("Confirm")
            backButton.setTitle("Cancel")
        } else {
            continueButton.setTitle("Add")
            backButton.setTitle(self.backText)
        }
        
        let newToolbarTop = (toolbarHeight == 0 ? 44 : 44 + view.safeAreaInsets.bottom + toolbarHeight)
        if newToolbarTop != self.toolbarViewHeightConstraint.constant {
            Utility.animate {
                self.toolbarViewHeightConstraint.constant = newToolbarTop
            }
        }
    }
    
    private func setTick(_ cell: SelectPlayersCell, to: Bool) {
        var imageName: String
        
        if to {
            imageName = "boxtick"
        } else {
            imageName = "box"
        }
        cell.playerTick.image = UIImage(named: imageName)
        cell.playerTick.isHidden = false
    }
    
    private func selectAll(_ to: Bool) {
        // Select all
        selected = 0
        for (sectionIndex, list) in combinedSelection {
            for index in 0..<list.count {
                combinedSelection[sectionIndex]![index] = to
            }
            selected += (to ? combinedSelection[sectionIndex]!.count : 0)
            tableView.reloadData()
        }
    }
    
    @objc private func playerDetail(_ button: UIButton) {
        selectedPlayer = IndexPath(item: button.tag % 100000, section: button.tag / 100000)
        PlayerDetailViewController.show(from: self, playerDetail: self.combinedPlayerList[selectedPlayer.section]![selectedPlayer.item], mode: .display, sourceView: view)
    }
    
    private func createPlayers() {
        var imageList: [PlayerMO] = []
        self.playerList = []
        self.selection = []
        
        for (section, list) in combinedPlayerList {
            for (index, playerDetail) in list.enumerated() {
                if self.combinedSelection[section]?[index] ?? false {
                    let playerMO = playerDetail.createMO()
                    if playerMO != nil && playerDetail.thumbnailDate != nil {
                        imageList.append(playerMO!)
                    }
                    self.playerList.append(playerDetail)
                    self.selection.append(true)
                }
            }
        }
        
        if imageList.count > 0 {
            self.getImages(imageList)
        }

        // Add these players to list of subscriptions
        Notifications.updateHighScoreSubscriptions()
        
    }
    
    func addNewPlayer(playerDetail: PlayerDetail, section: Int) {
        var found = false
        for (sectionIndex, list) in self.combinedPlayerList {
            if let index = list.firstIndex(where: { $0.email == playerDetail.email}) {
                // Already in list - just select it (if not already)
                if !self.combinedSelection[sectionIndex]![index] {
                    self.selected += 1
                    self.combinedSelection[sectionIndex]![index] = true
                    self.tableView.reloadRows(at: [IndexPath(row: index, section: sectionIndex)], with: .automatic)
                    found = true
                }
            }
        }
        if !found {
            // Add to list
            var index = self.combinedPlayerList[section]!.firstIndex(where: { $0.email > playerDetail.email})
            if index == nil {
                index = combinedPlayerList[section]!.count
            }
            self.tableView.beginUpdates()
            self.combinedPlayerList[section]!.insert(playerDetail, at: index!)
            self.combinedSelection[section]!.insert(true, at: index!)
            self.tableView.insertRows(at: [IndexPath(row: index!, section: section)], with: .automatic)
            self.selected += 1
            self.tableView.endUpdates()
        }
    }
    
    private func getOpponents(_ playerDetail: PlayerDetail) -> String {
        var result: String
        
        let opponents = History.findOpponentNames(playerEmail: playerDetail.email)
        if opponents.count > 0 {
            result = "Played " + Utility.toString(opponents)
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
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class SelectPlayersCell: UITableViewCell {
    @IBOutlet public weak var playerName: UILabel!
    @IBOutlet public weak var playerDescription: UILabel!
    @IBOutlet public weak var playerTick: UIImageView!
    @IBOutlet public weak var playerDetail: UIButton!
    @IBOutlet public weak var playerNameBottomConstraint: NSLayoutConstraint!
    @IBOutlet public weak var playerDescriptionHeightConstraint: NSLayoutConstraint!
}
