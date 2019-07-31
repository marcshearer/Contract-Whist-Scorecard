//
//  SearchViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 21/06/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

class SearchViewController: CustomViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {

    // Main state properties
    private let scorecard = Scorecard.shared
    
    // Properties to determine how view behaves
    private  var formTitle = "Search"
    private  var backText = "Cancel"
    private  var backImage = "back"
    private  var minPlayers = 1
    private  var maxPlayers = 1
    private  var filter: ((PlayerMO)->Bool)!
    private  var disableOption: String!
    private  var instructions: String!
    private  var insufficientMessage: String! = "There are not enough players on this device"
    private var completion: ((Bool, [PlayerMO]?)->())?
    
    // Local class variables
    private var observer: NSObjectProtocol?
    private var results: [PlayerMO?] = []
    private var selected: [Bool] = []
    private var selectedCount: Int {
        get {
            var count = 0
            for value in selected {
                if value {
                    count += 1
                }
            }
            return count
        }
    }
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet weak var instructionsLabel: UILabel!
    @IBOutlet weak var instructionsHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var searchTableView: UITableView!
    @IBOutlet weak var finishButton: UIButton!
    @IBOutlet weak var navigationTitle: UINavigationItem!
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func finishPressed(_ sender: UIButton) {
        NotificationCenter.default.removeObserver(observer!)
        if self.selectedCount >= self.minPlayers {
            self.returnPlayers(complete: true, selected: self.selected)
        } else {
            self.returnPlayers(complete: false)
        }
    }
    
    @IBAction func addPressed(_ sender: UIButton) {
        self.showSelectPlayers()
    }
    
    // MARK: - Calling routine ========================================================================= -
    
    static public func identifyPlayers(from viewController: UIViewController, title: String = "Player for Device", disableOption: String! = nil, instructions: String! = nil, minPlayers: Int = 1, maxPlayers: Int = 1, insufficientMessage: String! = nil, completion: ((Bool, [PlayerMO]?)->())? = nil, filter: ((PlayerMO)->Bool)! = nil) {
        
        let storyboard = UIStoryboard(name: "SearchViewController", bundle: nil)
        let searchViewController = storyboard.instantiateViewController(withIdentifier: "SearchViewController") as! SearchViewController
        
        searchViewController.modalPresentationStyle = UIModalPresentationStyle.popover
        searchViewController.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
        if let sourceView = viewController.popoverPresentationController?.sourceView {
            searchViewController.popoverPresentationController?.sourceView = sourceView
        } else {
            searchViewController.popoverPresentationController?.sourceView = viewController.view
        }
        searchViewController.popoverPresentationController?.sourceRect = CGRect(x: UIScreen.main.bounds.size.width/2, y: UIScreen.main.bounds.size.height/2, width: 0 ,height: 0)
        searchViewController.preferredContentSize = CGSize(width: 400, height: 600)
        searchViewController.popoverPresentationController?.delegate = viewController as? UIPopoverPresentationControllerDelegate
        
        searchViewController.formTitle = title
        searchViewController.instructions = instructions
        searchViewController.disableOption = disableOption
        searchViewController.minPlayers = minPlayers
        searchViewController.maxPlayers = maxPlayers
        searchViewController.filter = filter
        searchViewController.completion = completion
        searchViewController.insufficientMessage = insufficientMessage
        
        viewController.present(searchViewController, animated: true, completion: nil)
    }
    
    // MARK: - View Overrides ========================================================================== -

    override func viewDidLoad() {
        super.viewDidLoad()
        getSearchList()
        if self.results.count < self.minPlayers {
            self.alertMessage(if: self.insufficientMessage != nil, self.insufficientMessage, okHandler: {
                self.returnPlayers(complete: false)
            })
        }
        navigationTitle.title = self.formTitle
        
        if self.instructions != nil {
            self.instructionsLabel.text = self.instructions
        }
        finishButton.setTitle(self.backText, for: .normal)
        finishButton.setImage(UIImage(named: self.backImage), for: .normal)
        
        if self.minPlayers > 1 {
            // Allow multi-select
            self.searchTableView.allowsMultipleSelection = true
        }
        
        self.enableSelectButton()
        
        // Set nofification for image download
        observer = setImageDownloadNotification()
        
    }
    
    override func viewWillLayoutSubviews() {
        scorecard.reCenterPopup(self)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        view.setNeedsLayout()
    }
    
    // MARK: - TableView Overrides ===================================================================== -
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return results.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell: SearchTableCell
        
        cell = tableView.dequeueReusableCell(withIdentifier: "Player Cell", for: indexPath) as! SearchTableCell
        if let playerMO = results[indexPath.row] {
            cell.playerNameLabel.text = playerMO.name
            cell.playerNameLabel.textColor = Palette.text
            Utility.setThumbnail(data: playerMO.thumbnail,
                                 imageView: cell.playerImage,
                                 initials: playerMO.name!,
                                 label: cell.playerDisc,
                                 size: 50)
        } else {
            // Disable option
            cell.playerNameLabel.text = self.disableOption!
            cell.playerNameLabel.textColor = Palette.textMessage
            cell.playerImage.image = UIImage(named: "cross blue")
            cell.playerImage.contentMode = .center
        }

        let backgroundView = UIView()
        let separator = UIView(frame: CGRect(x: 0, y: cell.frame.height - 1.0, width: cell.frame.width, height: 1.0))
        separator.backgroundColor = Palette.separator
        backgroundView.addSubview(separator)
        backgroundView.backgroundColor = Palette.highlight
        cell.selectedBackgroundView = backgroundView
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if selected[indexPath.row] {
            cell.setSelected(true, animated: false)
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        }
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if self.minPlayers > 1 && self.selectedCount >= maxPlayers {
            return nil
        } else {
            return indexPath
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if self.minPlayers > 1 {
            self.selected[indexPath.row] = true
            self.enableSelectButton()
        } else if self.results[indexPath.row] == nil {
            self.returnPlayers(complete: true, selected: nil)
        } else {
            self.selected[indexPath.row] = true
            self.returnPlayers(complete: true, selected: self.selected)
        }
        if let cell = tableView.cellForRow(at: indexPath) as! SearchTableCell? {
            cell.playerNameLabel?.textColor = Palette.highlightText
        }
    }
    
    func tableView(_ tableView: UITableView, willDeselectRowAt indexPath: IndexPath) -> IndexPath? {
        return indexPath
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        self.selected[indexPath.row] = false
        self.enableSelectButton()
        if let cell = tableView.cellForRow(at: indexPath) as! SearchTableCell? {
            cell.playerNameLabel?.textColor = Palette.text
        }
    }
    
    // MARK: - SearchBar delegate Overrides ============================================================= -
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        getSearchList()
    }
    
    // MARK: - Image download handlers =================================================== -
    
    func setImageDownloadNotification() -> NSObjectProtocol? {
        // Set a notification for images downloaded
        let observer = NotificationCenter.default.addObserver(forName: .playerImageDownloaded, object: nil, queue: nil) {
            (notification) in
            self.updateImage(objectID: notification.userInfo?["playerObjectID"] as! NSManagedObjectID)
        }
        return observer
    }
    
    func updateImage(objectID: NSManagedObjectID) {
        // Find any cells containing an image which has just been downloaded asynchronously
        Utility.mainThread {
            if let index = self.results.firstIndex(where: { ($0?.objectID)! == objectID }) {
                // Found it - reload the cell
                self.searchTableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
            }
        }
    }
    
    // MARK: - Utility Routines ======================================================================== -
    
    private func showSelectPlayers() {
        SelectPlayersViewController.show(from: self, descriptionMode: .opponents, allowOtherPlayer: true, allowNewPlayer: false, completion: { (selected, playerList, selection) in
            if let selected = selected, let playerList = playerList, let selection = selection {
                if selected > 0 {
                    var createPlayerList: [PlayerDetail] = []
                    for playerNumber in 1...playerList.count {
                        if selection[playerNumber-1] {
                            createPlayerList.append(playerList[playerNumber-1])
                        }
                    }
                    self.createPlayers(newPlayers: createPlayerList)
                }
            }
        })
    }
    
    func getSearchList() {
        if self.results.count > 0 {
            // Remove everything except the disable option and anything selected
            for index in (0..<self.results.count).reversed() {
                if self.results[index] != nil && !self.selected[index] {
                    self.results.remove(at: index)
                    self.selected.remove(at: index)
                }
            }
        } else if self.disableOption != nil {
            // Add in disable option
            self.results.append(nil)
            self.selected.append(false)
        }
        
        for playerMO in self.scorecard.playerList {
            if self.filter == nil || self.filter!(playerMO) {
                if playerMO.name!.left(self.searchBar.text!.length).lowercased() == self.searchBar.text?.lowercased() {
                    // Matches search
                    
                    if self.results.firstIndex(where: { $0 != nil && $0!.email! == playerMO.email!}) == nil  {
                        // Not already in list - add it to result set
                        
                        self.results.append(playerMO)
                        self.selected.append(false)
                    }
                }
            }
        }
        self.searchTableView.reloadData()
    }
    
    func enableSelectButton() {
        finishButton.setTitle((self.selectedCount < self.minPlayers ? "Cancel" : "Continue"), for: .normal )
    }
    
    func returnPlayers(complete: Bool, selected: [Bool]! = nil) {
        var playerMO: [PlayerMO]?
        self.dismiss(animated: true, completion: {
            if !complete || selected == nil || selected.count == 0 {
                playerMO = nil
            } else {
                playerMO = []
                for playerNumber in 1...selected.count {
                    if selected[playerNumber - 1] {
                        playerMO!.append(self.results[playerNumber - 1]!)
                    }
                }
            }
            self.completion?(complete, playerMO)
        })
    }
    
    private func createPlayers(newPlayers: [PlayerDetail]) {
        let select = (selectedCount + newPlayers.count < self.scorecard.numberPlayers)
        
        for newPlayerDetail in newPlayers {
            if newPlayerDetail.name == "" {
                // Name not filled in - must have cancelled
            } else {
                var index: Int! = self.results.firstIndex(where: {($0?.name)! > newPlayerDetail.name})
                searchTableView.performBatchUpdates({
                    if index == nil {
                        // Insert at end
                        index = newPlayers.count
                    }
                    results.insert(newPlayerDetail.playerMO, at: index)
                    selected.insert(select, at: index)
                    searchTableView.insertRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
                })
            }
        }
    }
}

class SearchTableCell: UITableViewCell {
    @IBOutlet weak var playerNameLabel: UILabel!
    @IBOutlet weak var playerImage: UIImageView!
    @IBOutlet weak var playerDisc: UILabel!
}
