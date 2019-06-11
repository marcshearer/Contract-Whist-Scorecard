//
//  SelectionViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 28/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData

class SelectionViewController: CustomViewController, UICollectionViewDelegate, UICollectionViewDataSource,UICollectionViewDelegateFlowLayout {

    // MARK: - Class Properties ======================================================================== -

    // Main state properties
    public var scorecard: Scorecard!
    
    // Local class variables
    private var width: CGFloat = 0
    private let selectedViewSpacing:CGFloat = 10.0
    private var firstTime = true
    private var selectedAlpha: CGFloat = 0.5
    private var testMode = false
    
    // Main local state handlers
    private var availableList: [PlayerMO] = []
    private var selectedList = [PlayerMO?]()
    private var observer: NSObjectProtocol?
    
    // UI component pointers
    private var availableCell = [SelectionCell?]()
    private var selectedCell = [SelectionCell?]()

    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet weak var availableCollectionView: UICollectionView!
    @IBOutlet weak var selectedCollectionView: UICollectionView!
    @IBOutlet weak var selectionView: UIView!
    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var animationThumbnail: UIImageView!
    @IBOutlet weak var animationThumbnailView: UIView!
    @IBOutlet weak var animationDisc: UILabel!
    @IBOutlet weak var animationName: UILabel!
    @IBOutlet weak var selectedHeadingView: UIView!
    @IBOutlet weak var selectedView: UIView!
    @IBOutlet weak var selectedViewHeight: NSLayoutConstraint!
    @IBOutlet weak var selectedSubheadingHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var selectedViewWidth: NSLayoutConstraint!
    @IBOutlet weak var backgroundImage: UIImageView!
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var toolbarBottomConstraint: NSLayoutConstraint!
    
    // MARK: - IB Unwind Segue Handlers ================================================================ -
    
    @IBAction func hideSelectionPlayerDetail(segue:UIStoryboardSegue) {
        // Returning from new player
        let source = segue.source as! PlayerDetailViewController
        createPlayers(newPlayers: [source.playerDetail])
    }

    @IBAction func hideGamePreview(segue:UIStoryboardSegue) {
        // Returning from game setup
    }
    
    @IBAction func hideSelectionSelectPlayers(segue:UIStoryboardSegue) {
        let source = segue.source as! SelectPlayersViewController
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
        if selectedList.count > 0 {
            for _ in 1...selectedList.count {
                removeSelection(1)
            }
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

        if let testModeValue = ProcessInfo.processInfo.environment["TEST_MODE"] {
            if testModeValue.lowercased() == "true" {
                self.testMode = true
            }
        }

        // Cell for new player
        availableCell.append(nil)
        
        // Add other cells/players
        for playerMO in scorecard.playerList {
            availableList.append(playerMO)
            availableCell.append(nil)
        }
        
        for _ in 1...availableList.count + 1 {

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
        
        // Check if in recovery mode - if so (and found all players) go straight to game setup
        if scorecard.recoveryMode {
            if selectedList.count == scorecard.currentPlayers {
                self.performSegue(withIdentifier: "showGamePreview", sender: self)
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
        
        // Set selection color
        ScorecardUI.totalStyleView(self.selectedView)
        ScorecardUI.totalStyleView(self.selectedHeadingView)
        self.toolbar.setBackgroundImage(UIImage(),
                                        forToolbarPosition: .any,
                                        barMetrics: .default)
        self.toolbar.setShadowImage(UIImage(), forToolbarPosition: .any)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        // Select watermark background
        // ScorecardUI.selectBackground(size: size, backgroundImage: backgroundImage)
        // Resize cells
        setWidth(size: size)
        availableCollectionView.reloadData()
        selectedCollectionView.reloadData()
    }
    
    override func viewWillLayoutSubviews() {
        
        if firstTime {
            // Select watermark background
            // ScorecardUI.selectBackground(size: selectionView.frame.size, backgroundImage: backgroundImage)
            // Resize cells
            setWidth(size: selectionView.frame.size)
            firstTime = false
            
            // Decide if buttons enabled
            formatButtons(false)
        }
    }
    
    // MARK: - CollectionView Overrides ================================================================ -
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        if collectionView.tag == 1 {
            return availableList.count + 1 // Extra one for new player
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
                
                cell.name.text = "Add"
                cell.thumbnailView.alpha = 1.0
                cell.name.alpha = 1.0
                cell.tick.image = UIImage(named: "big plus")
                cell.tick.isHidden = false
                
            } else {
                
                // Create new thumbnail
                Utility.setThumbnail(data: availableList[playerNumber-1].thumbnail,
                                     imageView: cell.thumbnail,
                                     initials: availableList[playerNumber-1].name!,
                                     label: cell.disc)
                
                cell.name.text = availableList[playerNumber-1].name!
                
                let isSelected = (playerIsSelected(availableList[playerNumber-1]) != 0)
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
                let selectionSlot = playerIsSelected(availableList[playerNumber-1])
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
            let availableIndex = self.availableList.firstIndex(where: {($0.objectID == objectID)})
            if availableIndex != nil {
                // Found it - reload the cell
                self.availableCollectionView.reloadItems(at: [IndexPath(row: availableIndex! + 1, section: 0)])
            }
            let selectedIndex = self.selectedList.firstIndex(where: {($0!.objectID == objectID)})
            if selectedIndex != nil {
                // Found it - reload the cell
                self.selectedCollectionView.reloadItems(at: [IndexPath(row: selectedIndex!, section: 0)])
            }
        }
    }
    
    // MARK: - Form Presentation / Handling Routines =================================================== -
    
    func formatButtons(_ animated: Bool = true) {
        
        continueButton.isHidden = (selectedList.count >= 3 || testMode ? false : true)
        
        // Note the selected view extends 44 below the bottom of the screen. Setting the bottom constraint to zero makes the toolbar disappear
        let toolbarBottomOffset: CGFloat = (selectedList.count > 0 ? 44 + self.view.safeAreaInsets.bottom : 0)
        if toolbarBottomOffset != self.toolbarBottomConstraint.constant {
            if animated {
                Utility.animate(duration: 0.3) {
                    self.toolbarBottomConstraint.constant = toolbarBottomOffset
                }
            } else {
                self.toolbarBottomConstraint.constant = toolbarBottomOffset
            }
        }
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
            selectedSubheadingHeightConstraint.constant = 0
        }
        setSelectedViewWidthContstraint(selectedList.count)
    }
    
    func setSelectedViewWidthContstraint(_ numberDiscs: Int) {
        self.selectedViewWidth.constant  = (CGFloat(numberDiscs) * self.width) + (CGFloat(numberDiscs - 1) * self.selectedViewSpacing)
    }
    
    @objc func handleLongGesture(gesture: UILongPressGestureRecognizer) {
        
        switch(gesture.state) {
            
        case UIGestureRecognizer.State.began:
            guard let selectedIndexPath = selectedCollectionView.indexPathForItem(at: gesture.location(in: selectedCollectionView)) else {
                break
            }
            selectedCollectionView.beginInteractiveMovementForItem(at: selectedIndexPath)
        case UIGestureRecognizer.State.changed:
            selectedCollectionView.updateInteractiveMovementTargetPosition(gesture.location(in: gesture.view!))
        case UIGestureRecognizer.State.ended:
            selectedCollectionView.endInteractiveMovement()
        default:
            selectedCollectionView.cancelInteractiveMovement()
        }
    }
    
    func finishAction() {
        NotificationCenter.default.removeObserver(observer!)
        self.performSegue(withIdentifier: "hideSelection", sender: self)
    }

    func continueAction() {
        if selectedList.count >= 3 {
            self.performSegue(withIdentifier: "showGamePreview", sender: self)
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
                while playerListNumber <= availableList.count {
                    
                    if playerURI == scorecard.playerURI(availableList[playerListNumber-1]) {
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
        for playerNumberLoop in 1...availableList.count {
            if availableList[playerNumberLoop-1] == selectedList[playerNumber-1] &&
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
            selectedList.append(updateDisplay ? nil : self.availableList[addPlayerNumber-1])
            numberSelected += 1
            
            formatButtons(updateDisplay)
            
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
                
                // Draw a new thumbnail over top of existing - add in views which are uninstalled in IB to avoid warnings of no constraints
                view.addSubview(self.animationThumbnailView)
                view.addSubview(self.animationName)
                self.animationThumbnailView.frame = CGRect(x: availablePoint.x, y: availablePoint.y, width: self.width, height: self.width)
                self.animationThumbnail.frame = CGRect(x: 0, y: 0, width: self.width, height: self.width)
                self.animationDisc.frame = CGRect(x: 0, y: 0, width: self.width, height: self.width)
                self.animationName.frame = CGRect(x: availableLabelPoint.x , y: availableLabelPoint.y, width: labelWidth, height: labelHeight)
                Utility.setThumbnail(data: self.availableList[addPlayerNumber-1].thumbnail,
                                     imageView: self.animationThumbnail,
                                     initials: self.availableList[addPlayerNumber-1].name!,
                                     label: self.animationDisc)
                self.animationThumbnailView.superview!.bringSubviewToFront(self.animationThumbnailView)
                self.animationName.text = self.availableList[addPlayerNumber-1].name
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
                    self.selectedList[numberSelected-1] = self.availableList[addPlayerNumber-1]

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
                        self.animationThumbnailView.superview!.bringSubviewToFront(self.animationThumbnailView)
                        self.animationName.superview!.bringSubviewToFront(self.animationName)
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
    
    private func createPlayers(newPlayers: [PlayerDetail]) {
        let add = (selectedList.count + newPlayers.count <= self.scorecard.numberPlayers)
        
        for newPlayerDetail in newPlayers {
            if newPlayerDetail.name == "" {
                // Name not filled in - must have cancelled
            } else {
                var availableIndex: Int! = self.availableList.firstIndex(where: {($0.name! > newPlayerDetail.name)})
                selectedCollectionView.performBatchUpdates({
                    if availableIndex == nil {
                        // Insert at end
                        availableIndex = availableList.count
                    }
                    availableList.insert(newPlayerDetail.playerMO, at: availableIndex)
                    availableCell.insert(nil, at: availableIndex + 1)
                    availableCollectionView.insertItems(at: [IndexPath(row: availableIndex + 1, section: 0)])
                })
                if add {
                    addSelection(availableIndex + 1)
                }
            }
        }
    }
    
    func addNewPlayer() {
        if scorecard.settingSyncEnabled && scorecard.isNetworkAvailable && scorecard.isLoggedIn {
            self.performSegue(withIdentifier: "showSelectPlayers", sender: self)
        } else {
            self.performSegue(withIdentifier: "showPlayerDetail", sender: self)
        }
    }
    
    // MARK: - Segue Prepare Handler =================================================================== -

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier! {
            
        case "showPlayerDetail":
            let destination = segue.destination as! PlayerDetailViewController

            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.isModalInPopover = true
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = selectionView
            destination.preferredContentSize = CGSize(width: 400, height: 300)

            destination.playerDetail = PlayerDetail(scorecard, visibleLocally: true)
            destination.mode = .create
            destination.returnSegue = "hideSelectionPlayerDetail"
            destination.scorecard = self.scorecard
            destination.sourceView = view
            
        case "showGamePreview":
            let destination = segue.destination as! GamePreviewViewController
            destination.selectedPlayers = selectedList
            destination.scorecard = self.scorecard
            destination.returnSegue = "hideGamePreview"
        
        case "showSelectPlayers":
            let destination = segue.destination as! SelectPlayersViewController

            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.isModalInPopover = true
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = self.view
            destination.preferredContentSize = CGSize(width: 400, height: 600)
            
            destination.scorecard = self.scorecard
            destination.descriptionMode = .opponents
            destination.returnSegue = "hideSelectionSelectPlayers"
            destination.backText = "Cancel"
            destination.actionText = "Download"
            destination.allowOtherPlayer = true
            destination.allowNewPlayer = true
            
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
