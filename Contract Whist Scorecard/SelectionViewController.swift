//
//  SelectionViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 28/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

class SelectionViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource,UICollectionViewDelegateFlowLayout, SyncDelegate {

    // MARK: - Class Properties ======================================================================== -

    // Main state properties
    var scorecard: Scorecard!
    private let sync = Sync()
    
    // Properties to pass state to / from segues
    public var cloudPlayerList: [PlayerDetail]!

    // Local class variables
    private var width: CGFloat = 0
    private let selectedViewSpacing:CGFloat = 10.0
    private var firstTime = true
    private var selectedAlpha: CGFloat = 0.5
    
    // Main local state handlers
    private var selectedList = [PlayerMO?]()
    private var observer: NSObjectProtocol?
    
    // UI component pointers
    private var availableCell = [SelectionCell?]()
    private var selectedCell = [SelectionCell?]()
    
    // Alert controller while waiting for cloud download
    var cloudAlertController: UIAlertController!
    var cloudIndicatorView: UIActivityIndicatorView!

    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet weak var availableCollectionView: UICollectionView!
    @IBOutlet weak var selectedCollectionView: UICollectionView!
    @IBOutlet weak var selectionView: UIView!
    @IBOutlet weak var continueButton: RoundedButton!
    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var animationThumbnail: UIImageView!
    @IBOutlet weak var animationThumbnailView: UIView!
    @IBOutlet weak var animationDisc: UILabel!
    @IBOutlet weak var animationName: UILabel!
    @IBOutlet weak var selectedViewHeight: NSLayoutConstraint!
    @IBOutlet weak var selectedSubheadingHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var selectedViewWidth: NSLayoutConstraint!
    @IBOutlet weak var backgroundImage: UIImageView!
    
    
    // MARK: - IB Unwind Segue Handlers ================================================================ -
    
    @IBAction func selectionHidePlayer(segue:UIStoryboardSegue) {
        // Returning from new player
        let source = segue.source as! PlayerDetailViewController
        createPlayers(newPlayers: [source.playerDetail])
    }

    @IBAction func hideGameSetup(segue:UIStoryboardSegue) {
        // Returning from game setup
    }
    
    @IBAction func selectionHideCloudPlayers(segue:UIStoryboardSegue) {
        let source = segue.source as! StatsViewController
        if source.selected > 0 {
            var createPlayerList: [PlayerDetail] = []
            for playerNumber in 1...source.playerList.count {
                if source.selection[playerNumber-1] {
                    createPlayerList.append(source.playerList[playerNumber-1])
                }
            }
            createPlayers(newPlayers: createPlayerList)
        }
    }

    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func continuePressed(_ sender: UIButton) {
        continueAction()
    }

    @IBAction func clearPressed(_ sender: UIButton) {
        for _ in 1...selectedList.count {
            removeSelection(1)
        }
    }

    @IBAction func finishPressed(_ sender: UIButton) {
        finishAction()
    }
    
    @IBAction func leftSwipe(recognizer:UISwipeGestureRecognizer) {
        if recognizer.state == .ended {
            continueAction()
        }
    }
    
    @IBAction func rightSwipe(recognizer:UISwipeGestureRecognizer) {
        if recognizer.state == .ended {
            finishAction()
        }
    }

    // MARK: - View Overrides ========================================================================== -

    override func viewDidLoad() {
        super.viewDidLoad()

        sync.initialise(scorecard: scorecard)
        
         for _ in 1...scorecard.playerList.count+1 {
            availableCell.append(nil)
        }
        
        for _ in 1...scorecard.numberPlayers {
            selectedCell.append(nil)
        }
        
        // Allow movement
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongGesture(gesture:)))
        selectedCollectionView.addGestureRecognizer(longPressGesture)
        
        // Try to find players from last time
        scorecard.loadGameDefaults()
        assignPlayers()
        
        // Decide if buttons enabled
        formatButtons()
        
        // Check if in recovery mode - if so (and found all players) go straight to game setup
        if scorecard.recoveryMode {
            if selectedList.count == scorecard.currentPlayers {
                self.performSegue(withIdentifier: "showGameSetup", sender: self)
            } else {
                scorecard.recoveryMode = false
            }
        }
        
        // Set interline space
        let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = selectedViewSpacing
        
        // Check network
        scorecard.checkNetworkConnection(button: nil, label: nil)
        
        // Set nofification for image download
        observer = setImageDownloadNotification()

    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        // Select watermark background
        ScorecardUI.selectBackground(size: size, backgroundImage: backgroundImage)
       // Resize cells
        setWidth(size: size)
        availableCollectionView.reloadData()
        selectedCollectionView.reloadData()
    }
    
    override func viewWillLayoutSubviews() {
        
        if firstTime {
            // Select watermark background
            ScorecardUI.selectBackground(size: selectionView.frame.size, backgroundImage: backgroundImage)
            // Resize cells
            setWidth(size: selectionView.frame.size)
            firstTime = false
        }
    }
    
    // MARK: - CollectionView Overrides ================================================================ -
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        if collectionView.tag == 1 {
            return scorecard.playerList.count + 1 // Extra one for new player
        } else {
            return min(selectedList.count, scorecard.numberPlayers)
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        return CGSize(width: width, height: width+30)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var cell: SelectionCell
        
        if collectionView.tag == 1 {
            // Available players
            
            let playerNumber = indexPath.row
                        
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Available Cell", for: indexPath) as! SelectionCell
            
             availableCell[playerNumber] = cell
            
            if playerNumber == 0 {
                // New player
                // Create new thumbnail
                Utility.setThumbnail(data: nil,
                                     imageView: cell.thumbnail,
                                     initials: "",
                                     label: cell.disc)
                
                cell.name.text = "New"
                cell.name.textColor = UIColor.blue
                cell.thumbnailView.alpha = 1.0
                cell.disc.backgroundColor = ScorecardUI.totalColor
                cell.name.alpha = 1.0
                cell.tick.image = UIImage(named: "big plus gray")
                cell.tick.isHidden = false
                
            } else {
                
                // Create new thumbnail
                Utility.setThumbnail(data: scorecard.playerList[playerNumber-1].thumbnail,
                                     imageView: cell.thumbnail,
                                     initials: scorecard.playerList[playerNumber-1].name!,
                                     label: cell.disc)
                
                cell.name.text = scorecard.playerList[playerNumber-1].name!
                
                let isSelected = (playerIsSelected(scorecard.playerList[playerNumber-1]) != 0)
                let newAlpha:CGFloat = (isSelected ? selectedAlpha : 1.0)
                cell.thumbnailView.alpha = newAlpha
                cell.name.alpha = newAlpha
                cell.tick.image = UIImage(named: "big tick")
                cell.tick.isHidden = !isSelected
            }
            
        } else {
            // Selected players
            
            let playerNumber = indexPath.row + 1
            
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Selected Cell", for: indexPath) as! SelectionCell
            
            selectedCell[playerNumber-1] = cell
            
            if playerNumber > selectedList.count || selectedList[playerNumber-1] == nil {
                // Create empty disc
                Utility.setThumbnail(data: nil,
                                     imageView: cell.thumbnail,
                                     initials: "",
                                     label: cell.disc)
                cell.name.text = ""
                cell.disc.backgroundColor = UIColor.clear
            } else {
                Utility.setThumbnail(data: selectedList[playerNumber-1]!.thumbnail,
                                     imageView: cell.thumbnail,
                                     initials: selectedList[playerNumber-1]!.name!,
                                     label: cell.disc)
                cell.name.text = selectedList[playerNumber-1]!.name!
                cell.disc.textColor = UIColor.black
            }

        }
        
        cell.thumbnailView.isHidden = false
        cell.name.isHidden = false

        ScorecardUI.veryRoundCorners(cell.thumbnail, radius: width/2)
        ScorecardUI.veryRoundCorners(cell.disc, radius: width/2)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView.tag == 1 {
            
            let playerNumber = indexPath.row
            
            if playerNumber == 0 {
                // New player
                addNewPlayer()
                
            } else {
                // Existing player
                let selectionSlot = playerIsSelected(scorecard.playerList[playerNumber-1])
                if selectionSlot == 0 {
                    // Wasn't selected - add it
                    addSelection(playerNumber)
                    
                } else {
                    // Was selected - remove it
                    removeSelection(selectionSlot)
                }
            }
        } else {
            if indexPath.row <= selectedList.count-1 {
                removeSelection(indexPath.row+1)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath,
                                 to destinationIndexPath: IndexPath) {
        
        // Swap the cells
        let cellToMove = selectedCell[sourceIndexPath.row]
        selectedCell.remove(at: sourceIndexPath.row)
        selectedCell.insert(cellToMove, at: destinationIndexPath.row)

        // Also move selected list around
        let selectedListToMove = selectedList[sourceIndexPath.row]
        selectedList.remove(at: sourceIndexPath.row)
        selectedList.insert(selectedListToMove, at: destinationIndexPath.row)
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
            let availableIndex = self.scorecard.playerList.index(where: {($0.objectID == objectID)})
            if availableIndex != nil {
                // Found it - reload the cell
                self.availableCollectionView.reloadItems(at: [IndexPath(row: availableIndex! + 1, section: 0)])
            }
            let selectedIndex = self.selectedList.index(where: {($0!.objectID == objectID)})
            if selectedIndex != nil {
                // Found it - reload the cell
                self.selectedCollectionView.reloadItems(at: [IndexPath(row: selectedIndex!, section: 0)])
            }
        }
    }
    
    // MARK: - Form Presentation / Handling Routines =================================================== -
    
    func formatButtons() {
        continueButton.isHidden = (selectedList.count >= 3 ? false : true)
        clearButton.isHidden = (selectedList.count > 0 ? false : true)
    }
    
    func setWidth(size: CGSize) {
        let totalWidth: CGFloat = size.width
        let totalHeight: CGFloat = size.height
        let numberThatFit = max(5, Int(totalWidth / (min(totalWidth, totalHeight) > 450 ? 120 : 75)))
        width = min((totalHeight - 170)/2, ((totalWidth - (CGFloat(numberThatFit+1) * 10.0)) / CGFloat(numberThatFit)))
        selectedViewHeight.constant = width+30
        if (totalHeight <= 400) {
            selectedSubheadingHeightConstraint.constant = 0
        } else {
            selectedSubheadingHeightConstraint.constant = 32
        }
        setSelectedViewWidthContstraint(selectedList.count)
    }
    
    func setSelectedViewWidthContstraint(_ numberDiscs: Int) {
        self.selectedViewWidth.constant  = (CGFloat(numberDiscs) * self.width) + (CGFloat(numberDiscs - 1) * self.selectedViewSpacing)
    }
    
    @objc func handleLongGesture(gesture: UILongPressGestureRecognizer) {
        
        switch(gesture.state) {
            
        case UIGestureRecognizerState.began:
            guard let selectedIndexPath = selectedCollectionView.indexPathForItem(at: gesture.location(in: selectedCollectionView)) else {
                break
            }
            selectedCollectionView.beginInteractiveMovementForItem(at: selectedIndexPath)
        case UIGestureRecognizerState.changed:
            selectedCollectionView.updateInteractiveMovementTargetPosition(gesture.location(in: gesture.view!))
        case UIGestureRecognizerState.ended:
            selectedCollectionView.endInteractiveMovement()
        default:
            selectedCollectionView.cancelInteractiveMovement()
        }
    }
    
    func finishAction() {
        NotificationCenter.default.removeObserver(observer!)
        self.performSegue(withIdentifier: "returnSelection", sender: self)
    }

    func continueAction() {
        if selectedList.count >= 3 {
            self.performSegue(withIdentifier: "showGameSetup", sender: self)
        }
    }
    
    // MARK: - Sync routines including the delegate methods ======================================== -
    
    func selectCloudPlayers() {
        self.cloudAlertController = UIAlertController(title: title, message: "Searching Cloud for Available Players\n\n\n\n", preferredStyle: .alert)
        
        self.sync.delegate = self
        if self.sync.connect() {
            
            //add the activity indicator as a subview of the alert controller's view
            self.cloudIndicatorView =
                UIActivityIndicatorView(frame: CGRect(x: 0, y: 100,
                                                      width: self.cloudAlertController.view.frame.width,
                                                      height: 100))
            self.cloudIndicatorView.activityIndicatorViewStyle = .whiteLarge
            self.cloudIndicatorView.color = UIColor.black
            self.cloudIndicatorView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.cloudAlertController.view.addSubview(self.cloudIndicatorView)
            self.cloudIndicatorView.isUserInteractionEnabled = true
            self.cloudIndicatorView.startAnimating()
            
            self.present(self.cloudAlertController, animated: true, completion: nil)
            
            // Sync
            self.sync.synchronise(syncMode: .syncGetPlayers)
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
    
    func syncReturnPlayers(_ playerList: [PlayerDetail]!) {
        Utility.mainThread {
            self.cloudAlertController.dismiss(animated: true, completion: {
                if playerList != nil {
                    self.cloudPlayerList = []
                    for playerDetail in playerList {
                        let index = self.scorecard.playerList.index(where: {($0.email == playerDetail.email)})
                        if index == nil {
                            self.cloudPlayerList.append(playerDetail)
                        }
                    }
                    
                    if self.cloudPlayerList.count == 0 {
                        self.alertMessage("No additional players have been found who have played a game with the players on your device",title: "Download from Cloud", buttonText: "Continue")
                    } else {
                        self.performSegue(withIdentifier: "selectionCloudPlayers", sender: self)
                    }
                    
                } else {
                    self.alertMessage("Unable to connect to Cloud", buttonText: "Continue")
                }
            })
        }
    }

    // MARK: - Utility Routines ======================================================================== -
    
    func playerIsSelected(_ checkPlayer: PlayerMO) -> Int {
        var playerNumber = 1
        var result = 0
        
        while playerNumber <= selectedList.count && selectedList[playerNumber-1] != nil {
            if checkPlayer == selectedList[playerNumber-1] {
                result = playerNumber
                break
            }
            playerNumber += 1
        }
        return result
    }
    
    func assignPlayers() {
        // Run round player list trying to patch in players from last time
        var playerListNumber = 0
        
        for playerNumber in 1...scorecard.currentPlayers {
            let playerURI = scorecard.playerURI(scorecard.enteredPlayer(playerNumber).playerMO)
            if playerURI != "" {
                
                playerListNumber = 1
                while playerListNumber <= scorecard.playerList.count {
                    
                    if playerURI == scorecard.playerURI(scorecard.playerList[playerListNumber-1]) {
                        addSelection(playerListNumber, updateDisplay: false)
                        
                        break
                    }
                    
                    playerListNumber += 1
                }
                
            }
        }
    }
    
    func removeSelection(_ playerNumber: Int) {

        // Remove selected indication in available
        for playerNumberLoop in 1...scorecard.playerList.count {
            if scorecard.playerList[playerNumberLoop-1] == selectedList[playerNumber-1] &&
                    availableCell[playerNumberLoop] != nil {
                availableCell[playerNumberLoop]?.thumbnailView.alpha = 1.0
                availableCell[playerNumberLoop]?.name.alpha = 1.0
                availableCell[playerNumberLoop]?.tick.isHidden = true
            }
        }

        // Remove from collection view, list of cells and selected list
        selectedList.remove(at: playerNumber-1)
        selectedCell[playerNumber-1]?.thumbnailView.isHidden = true
        selectedCell[playerNumber-1]?.name.isHidden = true
        selectedCell.remove(at: playerNumber-1)
        selectedCell.append(nil)
        
        selectedCollectionView.performBatchUpdates({
            // Remove from collection view            
            self.selectedCollectionView.deleteItems(at: [IndexPath(row: playerNumber-1, section: 0)])

        })
        
        formatButtons()
        setSelectedViewWidthContstraint(selectedList.count)
    }
    
    func addSelection(_ addPlayerNumber: Int, updateDisplay: Bool = true) {
        var selectedLabel: UILabel!
        var selectedCell: SelectionCell!
        var selectedPoint: CGPoint!
        var selectedLabelPoint: CGPoint!
        var emptyCell: SelectionCell!
        var numberSelected = selectedList.count
        
        if numberSelected < scorecard.numberPlayers {
            // There is a space 
            selectedList.append(updateDisplay ? nil : self.scorecard.playerList[addPlayerNumber-1])
            numberSelected += 1
            
            formatButtons()
            
            if updateDisplay {
                // Animation
                
                // Calculate available label offsets / width / height
                let availableLabel = self.availableCell[addPlayerNumber]?.name!
                let labelWidth = availableLabel!.bounds.width
                let labelHeight = availableLabel!.bounds.height
                
                // Calculate offsets for available collection view cell
                let availableCell = self.availableCell[addPlayerNumber]!
                let availablePoint = availableCell.convert(CGPoint(x: 0, y: 0), to: self.selectionView)
                let availableLabelPoint = availableLabel!.convert(CGPoint(x:0, y: 0), to: self.selectionView)
                
                // Mark available player as selected
                availableCell.thumbnailView.alpha = self.selectedAlpha
                availableCell.name.alpha = self.selectedAlpha
                availableCell.tick.isHidden = false
                
                // Draw a new thumbnail over top of existing
                self.animationThumbnailView.frame = CGRect(x: availablePoint.x, y: availablePoint.y, width: self.width, height: self.width)
                self.animationThumbnail.frame = CGRect(x: 0, y: 0, width: self.width, height: self.width)
                self.animationDisc.frame = CGRect(x: 0, y: 0, width: self.width, height: self.width)
                self.animationName.frame = CGRect(x: availableLabelPoint.x , y: availableLabelPoint.y, width: labelWidth, height: labelHeight)
                Utility.setThumbnail(data: self.scorecard.playerList[addPlayerNumber-1].thumbnail,
                                     imageView: self.animationThumbnail,
                                     initials: self.scorecard.playerList[addPlayerNumber-1].name!,
                                     label: self.animationDisc)
                self.animationThumbnailView.superview!.bringSubview(toFront: self.animationThumbnailView)
                self.animationName.text = self.scorecard.playerList[addPlayerNumber-1].name
                self.animationThumbnailView.isHidden = false
                self.animationName.isHidden = false
                // Lock the views until animation completes
                self.availableCollectionView.isUserInteractionEnabled = false
                self.selectedCollectionView.isUserInteractionEnabled = false
                self.clearButton.isUserInteractionEnabled = false
                
                let animation = UIViewPropertyAnimator(duration: 0.1, curve: .easeIn) {
                
                    // Reset width
                    self.setSelectedViewWidthContstraint(numberSelected)
                    
                    // Shouldn't need to do this, but we do!
                    self.selectedCollectionView.frame = CGRect(x: self.selectedCollectionView.frame.minX,
                                                           y: self.selectedCollectionView.frame.minY,
                                                           width: self.selectedViewWidth.constant,
                                                           height: self.selectedCollectionView.frame.height)
                
                
                    // Add a new blank cell to fill
                    self.selectedCollectionView.insertItems(at: [IndexPath(row: numberSelected-1, section: 0)])
                    // Can now fill in the player
                    self.selectedList[numberSelected-1] = self.scorecard.playerList[addPlayerNumber-1]

                }
                animation.addCompletion( {_ in
                    
                    // Remember blank selected cell
                    
                    emptyCell = self.selectedCell[numberSelected-1]!
                    
                    // Calculate offsets for selected collection view cell
                    selectedLabel = emptyCell.name!
                    selectedCell = emptyCell!
                    selectedPoint = selectedCell.convert(CGPoint(x: 0, y: 0), to: self.selectionView)
                    selectedLabelPoint = selectedLabel.convert(CGPoint(x:0, y: 0), to: self.selectionView)
                    
                    // And move it to the selected area
                    let animation = UIViewPropertyAnimator(duration: 0.3, curve: .easeIn) {
                        // Now move it to the selected area
                        self.animationThumbnailView.frame = CGRect(x: selectedPoint.x, y: selectedPoint.y, width: self.width, height: self.width)
                        self.animationThumbnail.frame = CGRect(x: 0, y: 0, width: self.width, height: self.width)
                        self.animationDisc.frame = CGRect(x: 0, y: 0, width: self.width, height: self.width)
                        self.animationName.frame = CGRect(x: selectedLabelPoint.x, y: selectedLabelPoint.y, width: labelWidth, height: labelHeight)
                        self.animationThumbnailView.superview!.bringSubview(toFront: self.animationThumbnailView)
                        self.animationName.superview!.bringSubview(toFront: self.animationName)
                    }
                    animation.addCompletion( {_ in
                        // Cell will have been filled when we inserted it - just need to make it visible
                        Utility.setThumbnail(data: self.selectedList[numberSelected-1]!.thumbnail,
                                             imageView: emptyCell.thumbnail,
                                             initials: self.selectedList[numberSelected-1]!.name!,
                                             label: emptyCell.disc)
                        emptyCell.name.text = self.selectedList[numberSelected-1]!.name!
                        
                        // Now hide thumbnail and tick available player
                        self.animationThumbnailView.isHidden = true
                        self.animationName.isHidden = true
                        availableCell.tick.isHidden = false
                        
                        // Unlock the views
                        self.availableCollectionView.isUserInteractionEnabled = true
                        self.selectedCollectionView.isUserInteractionEnabled = true
                        self.clearButton.isUserInteractionEnabled = true
                        
                    })
                    animation.startAnimation()
                })
                animation.startAnimation()
            }
        }
    }
    
    func createPlayers(newPlayers: [PlayerDetail]) {
        var added = 0
        var addedRow = 0
        var imageList: [PlayerMO] = []
        
        for newPlayerDetail in newPlayers {
            if newPlayerDetail.name == "" {
                // Name not filled in - must have cancelled
            } else {
                let playerMO = newPlayerDetail.createMO()
                let createdIndexPath = IndexPath(row: newPlayerDetail.indexMO!+1, section: 0)
                availableCell.insert(nil, at: createdIndexPath.row)
                availableCollectionView.insertItems(at: [createdIndexPath])
                added += 1
                addedRow = createdIndexPath.row
                if playerMO != nil && newPlayerDetail.thumbnailDate != nil {
                    imageList.append(playerMO!)
                }
            }
        }
        if added == 1 {
            addSelection(addedRow)
        }
        if imageList.count > 0 {
            getImages(imageList)
        }
        
        // Add these players to list of subscriptions
        Notifications.updateHighScoreSubscriptions(scorecard: self.scorecard)
    }
    
    func addNewPlayer() {
        if scorecard.settingSyncEnabled && scorecard.isNetworkAvailable && scorecard.isLoggedIn {
            // Either enter a new player or choose from cloud
            let actionSheet = ActionSheet("Add Player", dark: true, view: availableCollectionView, direction: .left, x: width, y: width / 2)
            actionSheet.add("Find existing player", handler: self.selectCloudPlayers)
            actionSheet.add("Create player manually", handler: {
                self.performSegue(withIdentifier: "selectionNewPlayer", sender: self)
            })
            actionSheet.add("Cancel", style: .cancel)
            actionSheet.present()
            
        } else {
            self.performSegue(withIdentifier: "selectionNewPlayer", sender: self)
        }
    }
    
    // MARK: - Segue Prepare Handler =================================================================== -

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier! {
            
        case "selectionNewPlayer":
            let destination = segue.destination as! PlayerDetailViewController
            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = selectionView
            destination.preferredContentSize = CGSize(width: 400, height: 300)
            destination.playerDetail = PlayerDetail(scorecard, visibleLocally: true)
            destination.selectedPlayer = 0
            destination.mode = .create
            destination.returnSegue = "selectionHidePlayer"
            destination.scorecard = self.scorecard
            destination.sourceView = view
            
        case "showGameSetup":
            let destination = segue.destination as! GameSetupViewController
            destination.selectedPlayers = selectedList
            destination.scorecard = self.scorecard
            destination.returnSegue = "hideGameSetup"
        
        case "selectionCloudPlayers":
            let destination = segue.destination as! StatsViewController
            destination.playerList = self.cloudPlayerList
            destination.scorecard = self.scorecard
            destination.mode = .none
            destination.returnSegue = "selectionHideCloudPlayers"
            destination.backText = "Cancel"
            destination.actionText = "Download"
            destination.actionSegue = "selectionHideCloudPlayers"
            destination.allowSync = false
                
        default:
            break
        }
    }
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class SelectionCell: UICollectionViewCell {
    @IBOutlet weak var thumbnail: UIImageView!
    @IBOutlet weak var thumbnailView: UIView!
    @IBOutlet weak var disc: UILabel!
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var tick: UIImageView!
}
