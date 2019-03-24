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
    public weak var scorecard: Scorecard!
    private var sync: Sync!
    
    // Properties to pass state to action controller
    public var selection = [Bool]()
    public var selected = 0

    // Properties to get state to/from calling segue
    public var playerList: [PlayerDetail] = []
    public var specificEmail = ""
    public var descriptionMode: DescriptionMode = .none
    public var returnSegue = ""
    public var actionText = ""
    public var backText = "Back"
    public var backImage = "back"
    public var allowOtherPlayer = false
    public var allowNewPlayer = false
    
    // Local class variables
    private var selectedPlayer = 0
    private var selectedMode: DetailMode!
    private var syncStarted = false
    private var syncFinished = false
    private var otherPlayerRow = -1
    private var newPlayerRow = -1
    private var specificPlayerSection = 0
    private var connectedPlayerSection = 1
    private var specificPlayerRows = 0

    // Alert controller while waiting for cloud download
    private var cloudAlertController: UIAlertController!
    private var cloudIndicatorView: UIActivityIndicatorView!
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var backButton: RoundedButton!
    @IBOutlet private weak var changeAllButton: RoundedButton!
    @IBOutlet private weak var navigationBar: UINavigationBar!
    @IBOutlet private weak var toolbarViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var footerPaddingTopConstraint: NSLayoutConstraint!
    
    // MARK: - IB Unwind Segue Handlers ================================================================ -
    @IBAction private func hideSelectPlayersPlayerDetail(segue:UIStoryboardSegue) {
        let source = segue.source as! PlayerDetailViewController
        
        switch self.selectedMode! {
        case .create, .download:
            if let newPlayerDetail = source.playerDetail {
                if newPlayerDetail.name != "" {
                    self.addNewPlayer(playerDetail: newPlayerDetail)
                }
            }
        default:
            break
        }
    }
    
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
    
    @IBAction private func backPressed(sender: UIButton) {
        
        if selected > 0 {
            // Action selection
            self.createPlayers()
        }
        
        // Abandon any sync in progress
        self.sync?.stop()
        self.sync?.delegate = nil
        self.sync = nil
        
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
        return connectedPlayerSection + 1
    }
    
    internal func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if connectedPlayerSection > 0 {
            switch section {
            case specificPlayerSection:
                return "Add Specific Players"
            case connectedPlayerSection:
                return "Add Connected Players"
            default:
                return ""
            }
        } else {
            return nil
        }
    }
    
    internal func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case specificPlayerSection:
            return specificPlayerRows
        case connectedPlayerSection:
            return max(1, self.playerList.count)
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        ScorecardUI.sectionHeaderStyleView(header.backgroundView!)
    }


    internal func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: SelectPlayersCell
        
        // Create cell
        cell = tableView.dequeueReusableCell(withIdentifier: "Select Players Cell", for: indexPath) as! SelectPlayersCell

        // Set sizes for no description
        if descriptionMode == .none {
            cell.playerNameBottomConstraint.constant = 0
            cell.playerDescriptionHeightConstraint.constant = 0
        }

        switch indexPath.section {
        case specificPlayerSection:
            // Specific player options
            switch indexPath.row {
            case newPlayerRow:
                cell.playerName.text = "Create new player"
                cell.playerDescription.text = "Enter details manually"
            case otherPlayerRow:
                cell.playerName.text = "Add existing player"
                cell.playerDescription.text = "Download player using Unique ID"
            default:
                break
            }
            self.setTick(cell, to: false)
            cell.playerDetail.isHidden = true
            cell.playerName.textColor = .black

        case connectedPlayerSection:
            // Connected players
            
            if playerList.count == 0 {
                // No connected players found
                if syncFinished {
                    cell.playerName.text = "No connected players found"
                } else {
                    cell.playerName.text = "Downloading connected players..."
                }
                cell.playerDescription.text = ""
                cell.playerTick.isHidden = true
                cell.playerDetail.isHidden = true
                cell.playerName.textColor = .lightGray

            } else {
                let playerNumber = indexPath.row + 1
                
                // Update cell text / format
                cell.playerName.text = playerList[playerNumber-1].name
                switch self.descriptionMode {
                case .opponents:
                    cell.playerDescription.text = self.getOpponents(playerList[playerNumber-1])
                case .lastPlayed:
                    cell.playerDescription.text = self.getLastPlayed(playerList[playerNumber-1])
                default:
                    break
                }
                self.setTick(cell, to: selection[playerNumber-1])
                
                // Link detail button
                cell.playerDetail.addTarget(self, action: #selector(SelectPlayersViewController.playerDetail(_:)), for: UIControl.Event.touchUpInside)
                cell.playerDetail.tag = playerNumber
                cell.playerDetail.isHidden = false
                cell.playerName.textColor = .black
            }
        default:
            break
        }
            
        return cell
    }
    
    internal func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        if indexPath.section == connectedPlayerSection && self.playerList.count > 0 {
            let playerNumber = indexPath.row + 1
            if selection[playerNumber-1] {
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            } else {
                tableView.deselectRow(at: indexPath, animated: false)
            }
        }
    }
    
    internal func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        switch indexPath.section {
        case specificPlayerSection:
            switch indexPath.row {
            case newPlayerRow:
                selectedMode = .create
            default:
                selectedMode = .download
            }
            self.performSegue(withIdentifier: "showPlayerDetail", sender: self)
            return nil
        default:
            return indexPath
        }
    }
    
    internal func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case connectedPlayerSection:
            let playerNumber = indexPath.row+1
            selection[playerNumber-1] = true
            selected += 1
            self.formatButtons()
            self.setTick(tableView.cellForRow(at: indexPath) as! SelectPlayersCell, to: true)
        default:
            break
        }
    }
    
    internal func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case connectedPlayerSection:
            let playerNumber = indexPath.row+1
            selection[playerNumber-1] = false
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
            
            self.sync?.initialise(scorecard: scorecard!)
            self.sync?.delegate = self
            
            // Get connected players from cloud
            if self.specificEmail != "" {
                self.sync?.synchronise(syncMode: .syncGetPlayers, specificEmail: [self.specificEmail], waitFinish: true)
            } else {
                self.sync?.synchronise(syncMode: .syncGetPlayers, waitFinish: true)
            }
        }
        
        sync = Sync()
        
        if allowNewPlayer || allowOtherPlayer {
            syncGetPlayers()
        } else {
            
            self.cloudAlertController = UIAlertController(title: title, message: "Searching Cloud for Connected Players\n\n\n\n", preferredStyle: .alert)
        
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
        
        syncComplete {
            self.syncFinished = true
            self.cloudAlertController = nil
            self.formatButtons()
            self.tableView.reloadData()
        }
    }
    
    internal func syncReturnPlayers(_ returnedList: [PlayerDetail]!) {
        
        syncComplete{
            self.syncFinished = true
            if returnedList != nil {
                for playerDetail in returnedList {
                    var index = self.scorecard.playerList.index(where: {($0.email == playerDetail.email)})
                    if index == nil {
                        if self.playerList.count == 0 {
                            // Replace status entry
                            self.tableView.beginUpdates()
                            self.playerList.append(playerDetail)
                            self.selection.append(false)
                            self.tableView.reloadRows(at: [IndexPath(row: 0, section: self.connectedPlayerSection)], with: .automatic)
                            self.tableView.endUpdates()
                        } else {
                            // Insert in order
                            index = self.playerList.index(where: { $0.name > playerDetail.name})
                            if index == nil {
                                index = self.playerList.count
                            }
                            self.tableView.beginUpdates()
                            self.playerList.insert(playerDetail, at: index!)
                            self.selection.insert(false, at: index!)
                            self.tableView.insertRows(at: [IndexPath(row: index!, section: self.connectedPlayerSection)], with: .automatic)
                            self.tableView.endUpdates()
                        }
                    }
                }
            }
            self.formatButtons()
        }
    }
    
    private func syncComplete(completion: @escaping ()->()) {
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
        specificPlayerRows = 0
        if allowNewPlayer {
            newPlayerRow = specificPlayerRows
            specificPlayerRows += 1
        }
        if allowOtherPlayer {
            otherPlayerRow = specificPlayerRows
            specificPlayerRows += 1
        }
        if specificPlayerRows > 0 {
            specificPlayerSection = 0
            connectedPlayerSection = 1
        } else {
            specificPlayerSection = -1
            connectedPlayerSection = 0
        }
        
        // Set back button image and text
        self.backButton.setImage(UIImage(named: self.backImage), for: .normal)
        self.backButton.setTitle(self.backText)
        
    }
    
    private func formatButtons() {
        var toolbarHeight:CGFloat = 0.0
        
        if self.playerList.count > 0 {
            if selected == 0 {
                // Can't action - can select all
                changeAllButton.setTitle("Select all", for: .normal)
                backButton.setTitle("Cancel")
                toolbarHeight = 44
            } else {
                // Can action - can clear all
                changeAllButton.setTitle("Clear all", for: .normal)
                backButton.setTitle("Download")
                toolbarHeight = 44
            }
        } else {
            backButton.setTitle("Cancel")
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
        if selection.count > 0 {
            for playerNumber in 1...selection.count {
                selection[playerNumber-1] = to
            }
            selected = (to ? selection.count : 0)
            tableView.reloadData()
        }
    }
    
    @objc private func playerDetail(_ button: UIButton) {
        selectedMode = .display
        selectedPlayer = button.tag
        self.performSegue(withIdentifier: "showPlayerDetail", sender: self)
    }
    
    private func createPlayers() {
        var imageList: [PlayerMO] = []
        
        for (index, playerDetail) in playerList.enumerated() {
            if self.selection[index] {
                let playerMO = playerDetail.createMO()
                if playerMO != nil && playerDetail.thumbnailDate != nil {
                    imageList.append(playerMO!)
                }
            }
        }
        
        if imageList.count > 0 {
            self.getImages(imageList)
        }
        
    }
    
    func addNewPlayer(playerDetail: PlayerDetail) {
        var index = self.playerList.index(where: { $0.name == playerDetail.name})
        if index != nil {
            // Already in list - just select it (if not already)
            if !self.selection[index!] {
                self.selected += 1
                self.selection[index!] = true
                self.tableView.reloadRows(at: [IndexPath(row: index!, section: connectedPlayerSection)], with: .automatic)
            }
        } else {
            // Add to list
            let clearStatusEntry = (self.playerList.count == 0)
            index = self.playerList.index(where: { $0.name > playerDetail.name})
            if index == nil {
                index = playerList.count
            }
            self.tableView.beginUpdates()
            if clearStatusEntry {
                // Remove dummy status entry
                self.tableView.deleteRows(at: [IndexPath(row: 0, section: connectedPlayerSection)], with: .automatic)
            }
            self.playerList.insert(playerDetail, at: index!)
            self.selection.insert(true, at: index!)
            self.tableView.insertRows(at: [IndexPath(row: index!, section: connectedPlayerSection)], with: .automatic)
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
            switch selectedMode! {
            case .download, .create:
                // Blank player to download/create into
                destination.playerDetail = PlayerDetail(self.scorecard)
            default:
                // Display selected player
                destination.playerDetail = self.playerList[selectedPlayer - 1]
            }
            destination.returnSegue = "hideSelectPlayersPlayerDetail"
            destination.mode = selectedMode
            destination.scorecard = self.scorecard
            destination.sourceView = view
            
        default:
            break
        }
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
