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

class SelectPlayersViewController: ScorecardViewController, UITableViewDelegate, UITableViewDataSource, SyncDelegate {
    
    
    // MARK: - Class Properties ======================================================================== -
    
    // Main state properties
    private var sync: Sync!
    
    // Properties to pass state to action controller
    private var selection: [Bool] = []
    private var playerList: [PlayerDetail] = []
    private var selected = 0
    private var completion: ((Int?, [PlayerDetail]?, [Bool]?, String?)->())? = nil
 
    // Properties to pass state 
    private var specificEmail: String?
    private var descriptionMode: DescriptionMode = .none
    private var actionText = ""
    private var backText = "Back"
    private var backImage = "back"
    private var allowOtherPlayer = false
    private var allowNewPlayer = false
    private var saveToICloud = true
    
    // Local class variables
    private var combinedPlayerList: [Int : [PlayerDetail]] = [:]
    private var combinedSelection: [Int : [Bool]] = [:]
    private var thisPlayerUUID: String?
    private var selectedPlayerHexagonView: [Int: HexagonView] = [:]
    private var selectedPlayer: IndexPath!
    private var syncStarted = false
    private var syncFinished = false
    private var otherPlayerRow = -1
    private var newPlayerRow = -1
    private var actionSection = -1
    private var relatedPlayerSection = -1
    private var actionRows = 0
    private var sections = 0
    private var rotated = false

    // Alert controller while waiting for cloud download
    private var cloudAlertController: UIAlertController!
    private var cloudIndicatorView: UIActivityIndicatorView!
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var backButton: RoundedButton!
    @IBOutlet private weak var continueButton: RoundedButton!
    @IBOutlet private weak var navigationBar: UINavigationBar!
    @IBOutlet private weak var toolbarViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var footerPaddingTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var bannerContinuation: UIView!
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction private func continuePressed(sender: UIButton) {
        
        if selected > 0 {
            // Action selection
            self.createPlayers()
        }
        
        // Abandon any sync in progress
        self.sync?.stop()
        
        // Return to calling program
        self.dismiss(selected: self.selected, playerList: self.playerList, selection: self.selection, thisPlayerUUID: self.thisPlayerUUID)
        
    }
    
    @IBAction private func backPressed(sender: UIButton) {
        
        // Clear lists
        self.selected = 0
        self.selection = []
        self.playerList = []
        
        self.cancelAction()
        
        // Return to calling program
        self.dismiss()
        
    }
    
    // MARK: - View Overrides ========================================================================== -
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup default colors (previously done in StoryBoard)
        self.defaultViewColors()

        self.setupView()
        self.formatButtons()
    }
    

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.setNeedsLayout()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        Scorecard.shared.reCenterPopup(self)
        view.setNeedsLayout()
        self.rotated = true
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.formatButtons()
        if !syncStarted {
            self.selectCloudPlayers()
            syncStarted = true
        }
        if self.rotated {
            self.rotated = false
            self.tableView.reloadData()
        }
    }
    
    // MARK: - TableView Overrides ================================================================ -

    internal func numberOfSections(in tableView: UITableView) -> Int {
        return self.sections
    }
    
    internal func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return sectionHeaderHeight(for: section)
    }
    
    internal func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let height = self.sectionHeaderHeight(for: section)
        if height != 0.0 {
            var titleText = ""
            var detailText = ""
            var buttonText = ""
            let frame = CGRect(x:0.0, y: 0.0, width: tableView.frame.width, height: height)
            switch section {
            case relatedPlayerSection:
                titleText =  "Add existing players"
                detailText = "who have played players on this device"
                buttonText = "Select all"
            default:
                return nil
            }
            self.selectedPlayerHexagonView[section] = HexagonView(frame: frame, titleText: titleText, detailText: detailText, buttonText: buttonText, separator: true, bannerColor: (section == relatedPlayerSection ? Palette.banner : Palette.background), fillColor: (section == relatedPlayerSection ? Palette.banner : Palette.banner), textColor: (section == relatedPlayerSection ? Palette.bannerText : Palette.bannerText), buttonAction: self.changeAllPressed)
        
            return self.selectedPlayerHexagonView[section]
            
        } else {
            return nil
        }
    }
    
    private func sectionHeaderHeight(for section: Int) -> CGFloat {
        if section == relatedPlayerSection {
            return (ScorecardUI.smallPhoneSize() && ScorecardUI.landscapePhone() ? 86.0 : 101.0)
        } else {
            return 0.0
        }
    }
    
    internal func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case actionSection:
            return (ScorecardUI.smallPhoneSize() && ScorecardUI.landscapePhone() ? 71.0 : 86.0)
        case relatedPlayerSection:
            return 60.0
        default:
            return 0.0
        }
    }
    
    internal func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case actionSection:
            return actionRows
        case relatedPlayerSection:
            return max(1, self.combinedPlayerList[relatedPlayerSection]!.count)
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
            // Setup default colors (previously done in StoryBoard)
            self.defaultCellColors(cell: cell)
            
            // Fill in text
            var titleText = ""
            var detailText = ""
            switch indexPath.row {
            case newPlayerRow:
                titleText = "Create new player"
                detailText = "entering details manually"
            case otherPlayerRow:
                titleText = "Download player"
                detailText = "using their Unique ID"
            default:
                break
            }
            
            // Create hexagon view
            let frame = CGRect(x:0.0, y: 0.0, width: tableView.frame.width, height: self.tableView(self.tableView, heightForRowAt: indexPath))
            cell.actionHexagonView?.removeFromSuperview()
            cell.actionHexagonView = HexagonView(frame: frame, titleText: titleText, detailText: detailText, bannerColor: Palette.banner, fillColor: Palette.banner, textColor: Palette.bannerText)
            cell.addSubview(cell.actionHexagonView)

        case relatedPlayerSection:
            // Players
            
            // Create cell
            cell = tableView.dequeueReusableCell(withIdentifier: "Player Cell", for: indexPath) as! SelectPlayersCell
            // Setup default colors (previously done in StoryBoard)
            self.defaultCellColors(cell: cell)
            
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
                cell.playerSeparatorView.isHidden = true

            } else {
                if let playerDetail = combinedPlayerList[indexPath.section]?[indexPath.row] {
                    
                    // Update cell text / format
                    cell.playerName.text = playerDetail.name
                    if indexPath.section == relatedPlayerSection && self.descriptionMode == .opponents {
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
                    cell.playerSeparatorView.isHidden = false
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
                                                                        self.addNewPlayer(playerDetail: newPlayerDetail)
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
            if !(self.sync?.synchronise(syncMode: .syncGetPlayers, specificEmail: self.specificEmail, waitFinish: true, okToSyncWithTemporaryPlayerUUIDs: true) ?? false) {
                self.syncCompletion(-1)
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
            self.cloudIndicatorView.style = UIActivityIndicatorView.Style.large
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
                self.tableView.beginUpdates()
                self.tableView.reloadData()
                self.tableView.endUpdates()
            }
        }
    }
    
    internal func syncReturnPlayers(_ returnedList: [PlayerDetail]!, _ thisPlayerUUID: String?) {
        
        syncComplete{
            self.syncFinished = true
            if returnedList != nil {
                for playerDetail in returnedList {
                    var index = Scorecard.shared.playerList.firstIndex(where: {($0.playerUUID == playerDetail.playerUUID)})
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
                    if thisPlayerUUID != nil {
                        self.thisPlayerUUID = thisPlayerUUID
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
            relatedPlayerSection = 1
            self.sections = 2
        } else {
            actionSection = -1
            relatedPlayerSection = 0
            self.sections = 1
        }
        
        // Set up lists / selection
        self.combinedPlayerList[relatedPlayerSection] = []
        self.combinedSelection[relatedPlayerSection] = []

        // Set back button image and text
        self.backButton.setImage(UIImage(named: self.backImage), for: .normal)
        self.backButton.setTitle(self.backText)
        
    }
    
    private func formatButtons() {
        let relatedHexagonView = self.selectedPlayerHexagonView[relatedPlayerSection]

        if self.combinedPlayerList[relatedPlayerSection]!.count > 0 {
            if selected == 0 {
                // Can't action - can select all
                relatedHexagonView?.setButton(isHidden: false, buttonText: "Select all")
                continueButton.isHidden = true
            } else {
                // Can action - can clear all
                relatedHexagonView?.setButton(isHidden: false, buttonText: "Clear all")
                continueButton.isHidden = false
            }
            continueButton.setTitle("Confirm")
            backButton.setTitle("Cancel")
        } else {
            relatedHexagonView?.setButton(isHidden: true)
            continueButton.setTitle("Add")
            backButton.setTitle(self.backText)
        }
    }
    
    private func setTick(_ cell: SelectPlayersCell, to: Bool) {
        var imageName: String
        
        if to {
            imageName = "on"
        } else {
            imageName = "off"
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
                    let playerMO = playerDetail.createMO(saveToICloud: false)
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
        
        if self.saveToICloud {
            // Save to iCloud
            Scorecard.settings.saveToICloud()

        }
    }
    
    func addNewPlayer(playerDetail: PlayerDetail) {
        // Add new player to local database and return
        
        if let playerMO = playerDetail.createMO() {
            if playerDetail.thumbnailDate != nil && playerDetail.syncRecordID != nil {
                self.getImages([playerMO])
            }
            
            // Abandon any sync in progress
            self.sync?.stop()
            
            // Return to calling program
            self.dismiss(animated: true, completion: {
                self.completion?(1, [playerDetail], [true], nil)
            })
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
    
    // MARK: - Utility Routines ======================================================================== -
    
    private func changeAllPressed() {
        if self.selected == 0 {
            // Select all
            selectAll(true)
        } else {
            // Clear selection
            selectAll(false)
        }
        formatButtons()
    }
    
    // MARK: - Function to show and dismiss this view  ============================================================================== -
    
    public class func show(from viewController: ScorecardViewController, appController: ScorecardAppController? = nil, specificEmail: String? = nil, descriptionMode: DescriptionMode = .none, backText: String = "Cancel", actionText: String = "Download", allowOtherPlayer: Bool = true, allowNewPlayer: Bool = true, saveToICloud: Bool = true, completion: ((Int?, [PlayerDetail]?, [Bool]?, String?)->())? = nil) -> SelectPlayersViewController? {
        
        let storyboard = UIStoryboard(name: "SelectPlayersViewController", bundle: nil)
        let selectPlayersViewController = storyboard.instantiateViewController(withIdentifier: "SelectPlayersViewController") as! SelectPlayersViewController
        
        selectPlayersViewController.preferredContentSize = CGSize(width: 400, height: 700)
        selectPlayersViewController.modalPresentationStyle = (ScorecardUI.phoneSize() ? .fullScreen : .automatic)
        
        selectPlayersViewController.specificEmail = specificEmail
        selectPlayersViewController.descriptionMode = descriptionMode
        selectPlayersViewController.backText = backText
        selectPlayersViewController.actionText = actionText
        selectPlayersViewController.allowOtherPlayer = allowOtherPlayer
        selectPlayersViewController.allowNewPlayer = allowNewPlayer
        selectPlayersViewController.saveToICloud = saveToICloud
        selectPlayersViewController.completion = completion
    
        viewController.present(selectPlayersViewController, appController: appController, sourceView: viewController.popoverPresentationController?.sourceView ?? viewController.view, animated: true, completion: nil)
        
        return selectPlayersViewController
    }
    
    private func dismiss(selected: Int? = nil, playerList: [PlayerDetail]? = nil, selection: [Bool]? = nil, thisPlayerUUID: String? = nil)->() {
        self.dismiss(animated: true, completion: {
            self.completion?(selected, playerList, selection, thisPlayerUUID)
        })
    }
    
    override internal func didDismiss() {
        self.cancelAction()
        self.completion?(0, [], [], nil)
    }
    
    private func cancelAction() {
        
        // Abandon any sync in progress
        self.sync?.stop()
    }
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class SelectPlayersCell: UITableViewCell {
    
    public var actionHexagonView: HexagonView!
    
    @IBOutlet public weak var playerName: UILabel!
    @IBOutlet public weak var playerDescription: UILabel!
    @IBOutlet public weak var playerTick: UIImageView!
    @IBOutlet public weak var playerDetail: UIButton!
    @IBOutlet public weak var playerNameBottomConstraint: NSLayoutConstraint!
    @IBOutlet public weak var playerDescriptionHeightConstraint: NSLayoutConstraint!
    @IBOutlet public weak var playerSeparatorView: UIView!
}

extension SelectPlayersViewController {

    /** _Note that this code was generated as part of the move to themed colors_ */

    private func defaultViewColors() {

        self.bannerContinuation.backgroundColor = Palette.banner
        self.continueButton.setTitleColor(Palette.bannerText, for: .normal)
        self.view.backgroundColor = Palette.background
    }

    private func defaultCellColors(cell: SelectPlayersCell) {
        switch cell.reuseIdentifier {
        case "Player Cell":
            cell.playerDescription.textColor = Palette.text
            cell.playerName.textColor = Palette.text
            cell.playerSeparatorView.backgroundColor = Palette.separator
        default:
            break
        }
    }

}
