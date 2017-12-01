//
//  SearchViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 21/06/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit

protocol SearchDelegate : class {
    
    func returnPlayers(complete: Bool, playerMO: [PlayerMO]?, info: [String : Any?]?)
    
}

class SearchViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {

    // Main state properties
    public var scorecard: Scorecard!
    
    // Properties to pass state to / from segues
    public var formTitle = "Search"
    public var backText = "Cancel"
    public var backImage = "back"
    public var minPlayers = 1
    public var maxPlayers = 1
    public var filter: ((PlayerMO)->Bool)!
    public var disableOption: String!
    public var instructions: String!
    public var insufficientMessage: String! = "There are not enough players on this device"
    public var info: [String : Any?]!
    public weak var delegate: SearchDelegate?
    
    // Local class variables
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
    @IBOutlet weak var selectButton: UIButton!
    @IBOutlet weak var navigationTitle: UINavigationItem!
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func finishPressed(_ sender: UIButton) {
        self.returnPlayers(complete: false)
    }
    
    @IBAction func selectPressed(_ sender: UIButton) {
        self.returnPlayers(complete: true, selected: self.selected)
    }
    
    // MARK: - View Overrides ========================================================================== -

    override func viewDidLoad() {
        super.viewDidLoad()
        getSearchList()
        if self.results.count < self.minPlayers {
            self.alertMessage(if: self.insufficientMessage != nil, self.insufficientMessage, completion: {
                self.returnPlayers(complete: false)
            })
        }
        navigationTitle.title = self.formTitle
        
        if self.instructions != nil {
            self.instructionsLabel.text = self.instructions
            // self.instructionsHeightConstraint.constant = 100
        } else {
            // self.instructionsHeightConstraint.constant = 0
        }
        finishButton.setTitle(self.backText, for: .normal)
        finishButton.setImage(UIImage(named: self.backImage), for: .normal)
        
        if self.minPlayers > 1 {
            // Allow multi-select
            self.searchTableView.allowsMultipleSelection = true
        }
        
        self.enableSelectButton()
        
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
            Utility.setThumbnail(data: playerMO.thumbnail,
                                 imageView: cell.playerImage,
                                 initials: playerMO.name!,
                                 label: cell.playerDisc,
                                 size: 50)
        } else {
            // Disable option
            cell.playerNameLabel.text = self.disableOption!
            cell.playerNameLabel.textColor = UIColor.blue
            cell.playerImage.image = UIImage(named: "cross blue")
            cell.playerImage.contentMode = .center
        }

        return cell
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
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if self.minPlayers > 1 {
            self.selected[indexPath.row] = false
            self.enableSelectButton()
        }
    }
    
    // MARK: - SearchBar delegate Overrides ============================================================= -
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        getSearchList()
    }
    
    // MARK: - Utility Routines ======================================================================== -
    
    func getSearchList() {
        self.results = []
        if self.disableOption != nil {
            self.results.append(nil)
            self.selected.append(false)
        }
        for playerMO in self.scorecard.playerList {
            if self.filter == nil || self.filter!(playerMO) {
                if playerMO.name!.left(self.searchBar.text!.length).lowercased() == self.searchBar.text?.lowercased() {
                    self.results.append(playerMO)
                    self.selected.append(false)
                }
            }
        }
        self.searchTableView.reloadData()
    }
    
    func enableSelectButton() {
        selectButton.isHidden = self.selectedCount < self.minPlayers
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
            self.delegate?.returnPlayers(complete: complete, playerMO: playerMO, info: self.info)
        })
    }
}

class SearchTableCell: UITableViewCell {
    @IBOutlet weak var playerNameLabel: UILabel!
    @IBOutlet weak var playerImage: UIImageView!
    @IBOutlet weak var playerDisc: UILabel!
}
