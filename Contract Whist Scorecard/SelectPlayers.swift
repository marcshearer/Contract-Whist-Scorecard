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
    public var scorecard: Scorecard!
    private let sync = Sync()
    
    // Properties to pass state to action controller
    public var selection = [Bool]()
    public var selected = 0

    // Properties to get state to/from calling segue
    public var playerList: [PlayerDetail] = []
    public var specificEmail = ""
    public var descriptionMode: DescriptionMode = .none
    public var returnSegue = ""
    public var actionText = ""
    public var actionSegue = ""
    public var backText = "Back"
    public var backImage = "back"
    public var helpText = ""
    public var allowOtherPlayer = false
    
    // Local class variables
    private var selectedPlayer = 0
    private var selectedMode: DetailMode!
    private var syncStarted = false

    // Alert controller while waiting for cloud download
    private var cloudAlertController: UIAlertController!
    private var cloudIndicatorView: UIActivityIndicatorView!
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var actionButton: RoundedButton!
    @IBOutlet private weak var backButton: RoundedButton!
    @IBOutlet private weak var changeAllButton: RoundedButton!
    @IBOutlet private weak var otherPlayerButton: RoundedButton!
    @IBOutlet private weak var navigationBar: UINavigationBar!
    @IBOutlet private weak var helpLabel: UILabel!
    @IBOutlet private weak var separatorView: UIView!
    @IBOutlet private weak var headingViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var otherPlayerButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var toolbarViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var footerPaddingTopConstraint: NSLayoutConstraint!
    
    // MARK: - IB Unwind Segue Handlers ================================================================ -
    @IBAction private func hideSelectPlayersPlayerDetail(segue:UIStoryboardSegue) {
        if let segue = segue as? UIStoryboardSegueWithCompletion {
            segue.completion = {
                let source = segue.source as! PlayerDetailViewController
                if source.playerDetail != nil && source.playerDetail.name != "" {
                    // Player downloaded - add to local database and exit
                    let _ = source.playerDetail.createMO()
                    // Simulate this player being selected from list
                    self.playerList = [source.playerDetail]
                    self.selected = 1
                    self.selection[0] = true
                    // Return to calling program
                    self.performSegue(withIdentifier: self.returnSegue, sender: self)
                }
            }
        }
        
    }
    
    // MARK: - IB Actions ============================================================================== -
    @IBAction private func actionPressed(sender: UIButton) {
        
        if selected > 0 {
            // Action selection
            self.createPlayers()
            self.performSegue(withIdentifier: actionSegue, sender: self)
        } else {
            // Shouldn't happen - but just in case
            formatButtons()
        }
    }
    
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
        
        // Undo any selection
        selectAll(false)
        self.performSegue(withIdentifier: returnSegue, sender: self)
    }
    
    @IBAction func otherPlayerPressed(_ sender: UIButton) {
        selectedMode = .download
        self.performSegue(withIdentifier: "showPlayerDetail", sender: self)
    }
    
    // MARK: - View Overrides ========================================================================== -
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        
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

    internal func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.playerList.count
    }

    internal func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: SelectPlayersCell
        let playerNumber = indexPath.row + 1
        
        // Create cell
        cell = tableView.dequeueReusableCell(withIdentifier: "Select Players Cell", for: indexPath) as! SelectPlayersCell
        
        // Update cell text / format
        cell.playerName.text = playerList[playerNumber-1].name
        switch self.descriptionMode {
        case .opponents:
            cell.playerDescription.text = self.getOpponents(playerList[playerNumber-1])
        case .lastPlayed:
            cell.playerDescription.text = self.getLastPlayed(playerList[playerNumber-1])
        case .none:
            cell.playerNameBottomConstraint.constant = 0
            cell.playerDescriptionHeightConstraint.constant = 0
        }
        self.setTick(cell, to: selection[playerNumber-1])
        
        // Link detail button
        cell.playerDetail.addTarget(self, action: #selector(SelectPlayersViewController.playerDetail(_:)), for: UIControl.Event.touchUpInside)
        cell.playerDetail.tag = playerNumber
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let playerNumber = indexPath.row + 1
        
        if selection[playerNumber-1] {
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        } else {
            tableView.deselectRow(at: indexPath, animated: false)
        }
    }
    
    internal func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let playerNumber = indexPath.row+1
        selection[playerNumber-1] = true
        selected += 1
        formatButtons()
        self.setTick(tableView.cellForRow(at: indexPath) as! SelectPlayersCell, to: true)
    }
    
    internal func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let playerNumber = indexPath.row+1
        selection[playerNumber-1] = false
        selected -= 1
        formatButtons()
        self.setTick(tableView.cellForRow(at: indexPath) as! SelectPlayersCell, to: false)
    }
       
    // MARK: - Sync routines including the delegate methods ======================================== -
    
    func selectCloudPlayers() {

        sync.initialise(scorecard: scorecard)

        self.cloudAlertController = UIAlertController(title: title, message: "Searching Cloud for Connected Players\n\n\n\n", preferredStyle: .alert)
        
        self.sync.delegate = self
        if self.sync.connect() {
            
            //add the activity indicator as a subview of the alert controller's view
            self.cloudIndicatorView = UIActivityIndicatorView(frame: CGRect(x: 0, y: 30,
                                                      width: self.cloudAlertController.view.frame.width,
                                                      height: 50))
            self.cloudIndicatorView.style = .whiteLarge
            self.cloudIndicatorView.color = UIColor.black
            self.cloudIndicatorView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.cloudAlertController.view.addSubview(self.cloudIndicatorView)
            self.cloudIndicatorView.isUserInteractionEnabled = true
            self.cloudIndicatorView.startAnimating()
            
            self.present(self.cloudAlertController, animated: true, completion: nil)
            
            // Sync
            if specificEmail != "" {
                self.sync.synchronise(syncMode: .syncGetPlayers, specificEmail: [specificEmail])
            } else {
                self.sync.synchronise(syncMode: .syncGetPlayers)
            }
        } else {
            self.alertMessage("Error getting players from iCloud")
        }
    }
    
    func getImages(_ imageFromCloud: [PlayerMO]) {
        self.sync.fetchPlayerImagesFromCloud(imageFromCloud)
    }
    
    func syncMessage(_ message: String) {
    }
    
    func syncAlert(_ message: String, completion: @escaping ()->()) {
        Utility.mainThread {
            self.cloudAlertController.dismiss(animated: true, completion: {
                self.alertMessage(message, title: "Contract Whist Scorecard", okHandler: {
                    completion()
                })
            })
        }
    }
    
    func syncCompletion(_ errors: Int) {
    }
    
    func syncReturnPlayers(_ returnedList: [PlayerDetail]!) {
        
        Utility.mainThread {
            self.cloudAlertController.dismiss(animated: true, completion: {
                if returnedList != nil {
                    var returnedList = returnedList!
                    returnedList.sort(by: { $0.name < $1.name})
                    self.playerList = []
                    self.selection = []
                    self.selected = 0
                    for playerDetail in returnedList {
                        let index = self.scorecard.playerList.index(where: {($0.email == playerDetail.email)})
                        if index == nil {
                            self.playerList.append(playerDetail)
                            self.selection.append(false)
                        }
                    }
                    
                    if self.playerList.count == 0 {
                        self.alertMessage("No additional players have been found who have played a game with the players on your device",title: "Download from Cloud", buttonText: "Continue", okHandler:
                            {
                                self.exitController()
                            })
                    } else {
                        self.tableView.reloadData()
                    }
                    
                } else {
                    self.alertMessage("Unable to connect to Cloud", buttonText: "Continue", okHandler:
                        {
                            self.exitController()
                        })
                }
            })
        }
    }
    
    private func exitController() {
        self.performSegue(withIdentifier: returnSegue, sender: self)
    }
    
    // MARK: - Form Presentation / Handling Routines =================================================== -
    
    private func setupView() {
        
        // Set action button text
        self.actionButton.setTitle(actionText)
        
        // Set back button image and text
        self.backButton.setImage(UIImage(named: self.backImage), for: .normal)
        self.backButton.setTitle(self.backText)
        
        // Set help text
        if self.helpText != "" {
            self.helpLabel.text = self.helpText
            self.helpLabel.sizeToFit()
            self.headingViewHeightConstraint.isActive = false
            separatorView.isHidden = false
        } else {
            self.headingViewHeightConstraint.isActive = true
            separatorView.isHidden = true
        }

        // Setup other user button
        if self.helpText == "" || !self.allowOtherPlayer {
            self.otherPlayerButtonWidthConstraint.constant = 0
        }
        
    }
    
    private func formatButtons() {
        var toolbarHeight: CGFloat
        
        if selected == 0 {
            // Can't action - can select all
            changeAllButton.setTitle("Select all", for: .normal)
            actionButton.isHidden = true
            otherPlayerButton.isEnabled(true)
            toolbarHeight = 44
        } else {
            // Can action - can clear all
            changeAllButton.setTitle("Clear all", for: .normal)
            actionButton.isHidden = false
            otherPlayerButton.isEnabled(false)
            toolbarHeight = 44
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
            if selectedMode == .download {
                // Blank player to download into
                destination.playerDetail = PlayerDetail(self.scorecard)
            } else {
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
