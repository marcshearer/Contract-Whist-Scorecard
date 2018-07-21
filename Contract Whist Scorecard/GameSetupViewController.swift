//
//  GamePreviewViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 27/11/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

class GameSetupViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, CutDelegate, UIPopoverPresentationControllerDelegate {
    
    // MARK: - Class Properties ================================================================ -
    
    // Main state properties
    public var scorecard: Scorecard!
    private var recovery: Recovery!

    // Properties to pass state to / from segues
    public var selectedPlayers = [PlayerMO?]()          // Selected players passed in from player selection
    public var returnSegue: String!                    // View to return to
    public var rabbitMQService: RabbitMQService!
    
    // Local class variables
    private var buttonMode = "Triangle"
    private var buttonRowHeight:CGFloat = 0.0
    private var playerRowHeight:CGFloat = 0.0
    private var observer: NSObjectProtocol?
    
    // UI component pointers
    private var gameSetupNameCell = [GameSetupNameCell?]()
    private var actionCell: GameSetupActionCell!
    
    // MARK: - IB Outlets ================================================================ -
    
    @IBOutlet weak var gameSetupView: UIView!
    @IBOutlet weak var playerTableView: UITableView!
    @IBOutlet weak var backgroundImage: UIImageView!
    @IBOutlet weak var overrideButton: UIButton!

    // MARK: - IB Unwind Segue Handlers ================================================================ -

    @IBAction func hideScorepad(segue:UIStoryboardSegue) {
        self.scorecard.setGameInProgress(false)
        self.formatOverrideButton()
    }

    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func finishGamePressed(_ sender: Any) {
        // Link back to selection
        self.showNavigationBar()
        NotificationCenter.default.removeObserver(observer!)
        self.scorecard.resetOverrideSettings()
        self.performSegue(withIdentifier: returnSegue, sender: self)
    }
    
    @IBAction func continuePressed(_ sender: Any) {
        self.goToScorepad()
    }

    @IBAction func leftSwipe(recognizer:UISwipeGestureRecognizer) {
        if recognizer.state == .ended {
            showScorepad()
        }
    }
    
    @IBAction func rightSwipe(recognizer:UISwipeGestureRecognizer) {
        if recognizer.state == .ended {
            self.finishGamePressed(self)
        }
    }
    
    @IBAction func rotationGesture(recognizer:UIRotationGestureRecognizer) {
        if recognizer.state == .ended {
            showDealer(playerNumber: scorecard.dealerIs, forceHide: true)
            if recognizer.rotation > 0 {
                scorecard.nextDealer()
            } else {
                scorecard.previousDealer()
            }
            showCurrentDealer()
        }
    }
    
    // MARK: - View Overrides ================================================================ -

    override func viewDidLoad() {
        super.viewDidLoad()
        
        recovery = scorecard.recovery

        for _ in 1...scorecard.numberPlayers {
            gameSetupNameCell.append(nil)
        }
        
        // Make sure dealer not too high
        if self.scorecard.dealerIs > self.scorecard.currentPlayers {
            self.scorecard.dealerIs = 1
        }
        
        updateSelectedPlayers(selectedPlayers)
        setupScreen(size: gameSetupView.frame.size)
        scorecard.saveMaxScores()
        
        // Check if in recovery mode and if so go straight to scorecard
        if scorecard.recoveryMode {
            self.recoveryScorepad()
        }
        
        // Set nofification for image download
        observer = setImageDownloadNotification()

    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        setupScreen(size: size)
        playerTableView.reloadData()
    }
    
    override internal func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Hide duplicate navigation bar
        self.hideNavigationBar()
    }
 
    // MARK: - Popover Overrides ================================================================ -
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        let childViewController = popoverPresentationController.presentedViewController
        if childViewController is CutViewController {
            self.showCurrentDealer()
        }
    }
    
    // MARK: - TableView Overrides ================================================================ -
   
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        switch section {
        case 0:
            return scorecard.currentPlayers
        case 1:
            return 1
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            return playerRowHeight
        default:
            return buttonRowHeight
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell: UITableViewCell?
        
        switch indexPath.section {
        case 0:
            // Player names
                let playerNumber = indexPath.row+1
                
                gameSetupNameCell[playerNumber-1] = tableView.dequeueReusableCell(withIdentifier: "Game Setup Name Cell", for: indexPath) as? GameSetupNameCell
             
                // Setup the text input field
                gameSetupNameCell[playerNumber-1]!.playerName.text = "\(scorecard.enteredPlayer(playerNumber).playerMO!.name!)"
                
                // Setup the dealer button
                gameSetupNameCell[playerNumber-1]!.playerButton.setTitle("Dealer", for: .normal)
                showDealer(playerNumber: playerNumber)
                
                // Setup the thumbnail picture
                var thumbnail: Data?
                if let playerDetail = scorecard.enteredPlayer(playerNumber).playerMO {
                    thumbnail = playerDetail.thumbnail
                }
                Utility.setThumbnail(data: thumbnail,
                                     imageView: gameSetupNameCell[playerNumber-1]!.playerImage,
                                     initials: scorecard.enteredPlayer(playerNumber).playerMO!.name!,
                                     label: gameSetupNameCell[playerNumber-1]!.playerDisc,
                                     size: playerRowHeight-4)
                // Setup return value
                cell = gameSetupNameCell[playerNumber-1]
            
        case 1:
            // Action buttons
            actionCell = tableView.dequeueReusableCell(withIdentifier: "Game Setup Action Cell " + buttonMode, for: indexPath) as! GameSetupActionCell
            
            actionCell.cutForDealerButton.setTitle("Cut for Dealer")
            actionCell.cutForDealerButton.addTarget(self, action: #selector(GameSetupViewController.actionButtonPressed(_:)), for: UIControlEvents.touchUpInside)
            
            actionCell.nextDealerButton.setTitle("Next Dealer")
            actionCell.nextDealerButton.addTarget(self, action: #selector(GameSetupViewController.actionButtonPressed(_:)), for: UIControlEvents.touchUpInside)
          
            actionCell.overrideSettingsButton.setTitle("Override Settings")
            actionCell.overrideSettingsButton.addTarget(self, action: #selector(GameSetupViewController.actionButtonPressed(_:)), for: UIControlEvents.touchUpInside)
            
            cell = actionCell

        default:
            cell = nil
        }
        return cell!
    }
    
    // MARK: - Action Handlers ================================================================ -

    @objc func actionButtonPressed(_ button: UIButton)
    {
        switch button.tag {
        case 1:
            // Choose dealer at random
            
            // Hide the current dealer
            showDealer(playerNumber: scorecard.dealerIs, forceHide: true)
            // Link to cut for dealer animation
            _ = CutViewController.cutForDealer(viewController: self, view: view, scorecard: scorecard, cutDelegate: self, popoverDelegate: self)
        case 2:
            // Move dealer to next player
            showDealer(playerNumber: scorecard.dealerIs, forceHide: true)
            scorecard.nextDealer()
            showCurrentDealer()
            UserDefaults.standard.set(scorecard.dealerIs, forKey: "dealerIs")
       default:
            // Link to override selection
            let overrideViewController = OverrideViewController()
            overrideViewController.show(scorecard: scorecard, completion: {
                self.formatOverrideButton()
            })
        }
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
            let index = self.scorecard.enteredIndex(objectID)
            if index != nil {
                // Found it - reload the cell
                self.playerTableView.reloadRows(at: [IndexPath(row: index!, section: 0)], with: .fade)
            }
        }
    }
    
    // MARK: - Cut for dealer delegate routines ===================================================================== -
    
    func cutComplete() {
        showCurrentDealer()
    }
    
    // MARK: - Form Presentation / Handling Routines ================================================================ -
    
    func setupScreen(size: CGSize) {
        if size.width >= 530 {
            buttonMode = "Row"
            buttonRowHeight = 162
        } else {
            buttonMode = "Triangle"
            buttonRowHeight = 290
        }
        
        playerRowHeight = max(48, min(80, (size.height - buttonRowHeight - 100) / CGFloat(scorecard.currentPlayers)))
        
        if playerRowHeight > 48 {
            playerTableView.isScrollEnabled = false
        } else {
            playerTableView.isScrollEnabled = true
        }
        
        ScorecardUI.selectBackground(size: size, backgroundImage: backgroundImage)

    }
    
    private func goToScorepad() {
        if self.scorecard.overrideSelected {
            self.alertDecision("Overrides for the number of cards/rounds have been selected. Are you sure you want to continue",
                               title: "Warning",
                               okButtonText: "Use Overrides",
                               okHandler: {
                                self.showScorepad()
            },
                               otherButtonText: "Use Settings",
                               otherHandler: {
                                self.scorecard.resetOverrideSettings()
                                self.showScorepad()
            },
                               cancelButtonText: "Cancel")
        } else {
            self.showScorepad()
        }
    }
    
    private func recoveryScorepad() {
        self.alertMessage(if: self.scorecard.overrideSelected, "This game was being played with Override Settings", title: "Reminder", okHandler: {
            self.performSegue(withIdentifier: "showScorepad", sender: self )
        })
    }
    
    func showScorepad() {
        recovery.saveInitialValues()
        self.scorecard.setGameInProgress(true)
        self.performSegue(withIdentifier: "showScorepad", sender: self )
    }
    
    func showCurrentDealer() {
        showDealer(playerNumber: scorecard.dealerIs)
    }
    
    func showDealer(playerNumber: Int, forceHide: Bool = false) {
        gameSetupNameCell[playerNumber-1]!.playerButton.isHidden =
            (playerNumber == scorecard.dealerIs && !playerTableView.isEditing && !forceHide ? false : true)
    }
    
    private func formatOverrideButton() {
        // No longer required
    }
    
    // MARK: - Utility Routines ================================================================ -

    func updateSelectedPlayers(_ selectedPlayers: [PlayerMO?]) {
        scorecard.updateSelectedPlayers(selectedPlayers)
        scorecard.checkReady()

    }
    
    // MARK: - Segue Prepare Handler ================================================================ -

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier! {
        case "showScorepad":
            let destination = segue.destination as! ScorepadViewController
            destination.scorecard = self.scorecard
            destination.scorepadMode = (self.scorecard.isHosting || self.scorecard.hasJoined ? .display : .amend)
            if self.scorecard.checkOverride() {
                destination.cards = scorecard.overrideCards
                destination.bounce = scorecard.overrideBounceNumberCards
                destination.rounds = scorecard.calculateRounds(cards: destination.cards,
                                                               bounce: destination.bounce)
            } else {
                destination.cards = scorecard.settingCards
                destination.bounce = scorecard.settingBounceNumberCards
                destination.rounds = scorecard.rounds
            }
            destination.bonus2 = scorecard.settingBonus2
            destination.suits = scorecard.suits
            destination.returnSegue = "hideScorepad"
            destination.rabbitMQService = self.rabbitMQService
            destination.recoveryMode = self.scorecard.recoveryMode
            self.scorecard.recoveryMode = false
            
        default:
            break
        }
    }
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class GameSetupNameCell: UITableViewCell {
    @IBOutlet var playerName: UILabel!
    @IBOutlet var playerButton: UIButton!
    @IBOutlet weak var playerImage: UIImageView!
    @IBOutlet weak var playerDisc: UILabel!
}

class GameSetupActionCell: UITableViewCell {
    @IBOutlet weak var cutForDealerButton: ImageButton!
    @IBOutlet weak var nextDealerButton: ImageButton!
    @IBOutlet weak var overrideSettingsButton: ImageButton!
}

// MARK: - Utility Classes ================================================================ -

class UIStoryboardSegueWithCompletion: UIStoryboardSegue {
    // This is an affectation to allow a segue to wait for its completion before doing something else - e.g. fire another segue
    // For it to work the exit segue has to have this class filled in in the Storyboard
    var completion: (() -> Void)?
    
    override func perform() {
        super.perform()
        if let completion = completion {
            completion()
        }
    }
}
