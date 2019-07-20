//
//  SelectionViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 28/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit
import CoreData
import CoreServices

class SelectionViewController: CustomViewController, UICollectionViewDelegate, UICollectionViewDataSource,UICollectionViewDelegateFlowLayout, UIDropInteractionDelegate, UIGestureRecognizerDelegate, PlayerViewDelegate, SelectedPlayersViewDelegate {

    // MARK: - Class Properties ======================================================================== -

    // Main state properties
    private let scorecard = Scorecard.shared
    
    // Local class variables
    private var width: CGFloat = 0.0
    private var height: CGFloat = 0.0
    private var rowHeight: CGFloat = 0.0
    private let labelHeight: CGFloat = 30.0
    private let interRowSpacing:CGFloat = 10.0
    private let toolbarHeight: CGFloat = 44.0
    private var firstTime = true
    private var selectedAlpha: CGFloat = 0.5
    private var testMode = false

    // Main local state handlers
    private var availableList: [PlayerMO] = []
    private var unselectedList: [PlayerMO?] = []
    private var selectedList: [(slot: Int, playerMO: PlayerMO)] = []
    private var observer: NSObjectProtocol?
    private var animationView: PlayerView!
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var unselectedCollectionView: UICollectionView!
    @IBOutlet private weak var selectionView: UIView!
    @IBOutlet private weak var continueButton: UIButton!
    @IBOutlet private weak var clearButton: UIButton!
    @IBOutlet private weak var selectedPlayersView: SelectedPlayersView!
    @IBOutlet private weak var selectedViewHeight: NSLayoutConstraint!
    @IBOutlet private weak var selectedViewWidth: NSLayoutConstraint!
    @IBOutlet private weak var backgroundImage: UIImageView!
    @IBOutlet private weak var toolbar: UIToolbar!
    @IBOutlet private weak var toolbarBottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var navigationBar: UINavigationBar!
    
    // MARK: - IB Unwind Segue Handlers ================================================================ -
    
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
            createPlayers(newPlayers: createPlayerList, createMO: false)
        }
    }

    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func continuePressed(_ sender: UIButton) {
        continueAction()
    }

    @IBAction func clearPressed(_ sender: UIButton) {
        if selectedList.count > 0 {
            for selected in selectedList {
                self.removeSelection(selected.slot, animate: false)
            }
        }
    }

    @IBAction func finishPressed(_ sender: UIButton) {
        finishAction()
    }

    // MARK: - View Overrides ========================================================================== -

    override func viewDidLoad() {
        super.viewDidLoad()

        if let testModeValue = ProcessInfo.processInfo.environment["TEST_MODE"] {
            if testModeValue.lowercased() == "true" {
                self.testMode = true
            }
        }

        // Add players to available and unselected list
        for playerMO in scorecard.playerList {
            availableList.append(playerMO)
            unselectedList.append(playerMO)
        }
        
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
        layout.minimumInteritemSpacing = interRowSpacing
        
        // Check network
        scorecard.checkNetworkConnection(button: nil, label: nil)
        
        // Set nofification for image download
        observer = setImageDownloadNotification()
        
        // Set selection color
        self.toolbar.setBackgroundImage(UIImage(),
                                        forToolbarPosition: .any,
                                        barMetrics: .default)
        self.toolbar.setShadowImage(UIImage(), forToolbarPosition: .any)
        
        // Set up selected players view delegate
        self.selectedPlayersView.delegate = self
        
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.view.setNeedsLayout()
    }
    
    override func viewWillLayoutSubviews() {
        
        setSize(size: selectionView.frame.size)
        
        if firstTime {
            
            firstTime = false
            self.setupAnimationView()
            
            self.setupDragAndDrop()
            
            // Decide if buttons enabled
            formatButtons(false)
        }
        
        // Draw table
        self.selectedPlayersView.drawRoom(thumbnailWidth: self.width, thumbnailHeight: self.height, legHeight: self.toolbarHeight + self.view.safeAreaInsets.bottom)
        
        // Reload unselected player collection
        unselectedCollectionView.reloadData()
    }
    
    // MARK: - CollectionView Overrides ================================================================ -
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return unselectedList.count + 1 // Extra one for new player
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        return CGSize(width: self.width, height: self.height)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return interRowSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var cell: SelectionCell
        
        // Available players
        
        let playerNumber = indexPath.row
        
        if playerNumber == 0 {
            // Create add player thumbnail
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Add Player Cell", for: indexPath) as! SelectionCell
            if cell.playerView == nil {
                cell.playerView = PlayerView(type: .addPlayer, parent: cell, width: self.width, height: self.height, tag: -1)
                cell.playerView.delegate = self
            }
            cell.playerView.set(name: "Add", initials: "", alpha: 1.0)
            cell.playerView.set(imageName: "big plus")
            
        } else {
            // Create player thumbnail
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Unselected Cell", for: indexPath) as! SelectionCell
            if cell.playerView == nil {
                cell.playerView = PlayerView(type: .unselected, parent: cell, width: self.width, height: self.height, tag: playerNumber-1, tapGestureDelegate: self)
                cell.playerView.delegate = self
            }
            if let playerMO = unselectedList[playerNumber-1] {
                cell.playerView.set(playerMO: playerMO)
            } else {
                cell.playerView.clear()
            }
            cell.playerView.set(imageName: nil)
        }
        
        cell.playerView.frame = CGRect(x: 0.0, y: 0.0, width: self.width, height: self.height)
        cell.playerView.set(textColor: Palette.text)

        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let playerNumber = indexPath.row
        
        if playerNumber == 0 {
            // New player
            addNewPlayer()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        return true
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
            let unselectedIndex = self.unselectedList.firstIndex(where: {($0?.objectID == objectID)})
            if unselectedIndex != nil {
                // Found it - reload the cell
                self.unselectedCollectionView.reloadItems(at: [IndexPath(row: unselectedIndex! + 1, section: 0)])
            }
            if let selected = self.selectedList.first(where: {($0.playerMO.objectID == objectID)}) {
                // Found it - refresh the cell
                let playerMO = selected.playerMO
                self.selectedPlayersView.set(slot: selected.slot, playerMO: playerMO)
            }
        }
    }
    
    // MARK: - Form Presentation / Handling Routines =================================================== -
    
    func formatButtons(_ animated: Bool = true) {
        
        continueButton.isHidden = (selectedList.count >= 3 || testMode ? false : true)
        
        // Note the selected view extends 44 below the bottom of the screen. Setting the bottom constraint to zero makes the toolbar disappear
        let toolbarBottomOffset: CGFloat = (selectedList.count > 0 ? 44 + (self.view.safeAreaInsets.bottom * 0.40)	 : 0)
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
    
    func setSize(size: CGSize) {
        
        let totalWidth = size.width - view.safeAreaInsets.left - view.safeAreaInsets.right
        let totalHeight = size.height - view.safeAreaInsets.top - view.safeAreaInsets.bottom
        let numberThatFit = max(5, Int(totalWidth / (min(totalWidth, totalHeight) > 450 ? 120 : 75)))
        
        self.width = min((totalHeight - 170)/2, ((totalWidth - (CGFloat(numberThatFit + 1) * 10.0)) / CGFloat(numberThatFit)))
        self.height = self.width + self.labelHeight - 5.0
        self.rowHeight = self.height + self.interRowSpacing
    
        let unselectedRows: Int = max(3, Int((totalHeight * 0.6) / self.rowHeight))
        let unselectedHeight = CGFloat(unselectedRows) * rowHeight
        
        let selectedTop = unselectedHeight + self.navigationBar.frame.height + view.safeAreaInsets.top
        let selectedHeight: CGFloat = totalHeight + view.safeAreaInsets.top + view.safeAreaInsets.bottom - selectedTop
        selectedViewWidth?.constant = totalWidth / 2.0
        
        if ScorecardUI.landscapePhone() {
            selectedViewHeight?.constant = totalHeight - navigationBar.frame.height + view.safeAreaInsets.bottom
            self.selectedPlayersView.frame = CGRect(x: totalWidth / 2.0, y: navigationBar.frame.height + view.safeAreaInsets.top, width: totalWidth / 2.0, height: totalHeight - navigationBar.frame.height + view.safeAreaInsets.bottom)
        } else {
            selectedViewHeight?.constant = selectedHeight
            self.selectedPlayersView.frame = CGRect(x: 0.0, y: selectedTop, width: totalWidth, height: selectedHeight)
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
    
    // MARK: - Selected Players View delegate handlers =============================================== -
    
    func selectedPlayersView(wasTappedOn slot: Int) {
        self.removeSelection(slot)
    }
    
    func selectedPlayersView(wasDroppedOn slot: Int, from source: PlayerViewType, playerMO: PlayerMO) {
        
        if self.selectedPlayersView.playerViews[slot].inUse {
            self.removeSelection(slot, updateUnselected: true, animate: false)
        }
        
        self.addSelection(playerMO, toSlot: slot, updateUnselected: true, animate: false)
    }
    
    func selectedPlayersView(moved playerMO: PlayerMO, to slot: Int) {
        // Update related list element
        if let listIndex = self.selectedList.firstIndex(where: { $0.playerMO == playerMO }) {
            self.selectedList[listIndex].slot = slot
        }
    }
    
    // MARK: - Player view delegate handlers =========================================================== -

    internal func playerViewWasTapped(_ playerView: PlayerView) {
        let tag = playerView.tag
        if tag < 0 {
            self.addNewPlayer()
        } else {
            self.addSelection(playerView.playerMO!)
        }
    }
    
    // MARK: - Utility Routines ======================================================================== -

    func assignPlayers() {
        // Run round player list trying to patch in players from last time
        
        for playerNumber in 1...scorecard.currentPlayers {
            
            let playerURI = scorecard.playerURI(scorecard.enteredPlayer(playerNumber).playerMO)
            if playerURI != "" {
                if let playerMO = availableList.first(where: { self.scorecard.playerURI($0) == playerURI }) {
                    addSelection(playerMO, updateUnselectedCollection: false, animate: false)
                }
            }
        }
    }
    
    func removeSelection(_ selectedSlot: Int, updateUnselected: Bool = true, animate: Bool = true) {
        
        if  selectedPlayersView.inUse(slot: selectedSlot) {
            
            if let selectedIndex = selectedList.firstIndex(where: { $0.slot == selectedSlot }) {
                let (_, selectedPlayerMO) = self.selectedList[selectedIndex]
                
                selectedList.remove(at: selectedIndex)
                self.formatButtons(animate)
                
                if !animate || !updateUnselected {
                    // Just set the view and remove from current view
                    self.selectedPlayersView.clear(slot: selectedSlot)
                    if updateUnselected {
                        _ = self.addUnselected(selectedPlayerMO)
                    }
                    
                } else {
                    // Animation
                    
                    // Draw a new thumbnail over top of existing
                    let selectedPoint = selectedPlayersView.origin(slot: selectedSlot, in: self.selectionView)
                    self.animationView.frame = CGRect(origin: selectedPoint, size: CGSize(width: self.width, height: self.height))
                    self.animationView.set(playerMO: selectedPlayerMO)
                    self.animationView.set(textColor: Palette.darkHighlightText)
                    self.animationView.alpha = 1.0
                    
                    // Add new cell to unselected view
                    let unselectedPlayerIndex = addUnselected(selectedPlayerMO, leaveNil: true)
                    
                    // Clear selected cell
                    self.selectedPlayersView.clear(slot: selectedSlot)
                    
                    // Move animation thumbnail to the unselected area
                    let animation = UIViewPropertyAnimator(duration: 0.5, curve: .easeIn) {
                        
                        self.unselectedCollectionView.scrollToItem(at: IndexPath(item: unselectedPlayerIndex + 1, section: 0), at: .centeredHorizontally, animated: true)
                        if let destinationCell = self.unselectedCollectionView.cellForItem(at: IndexPath(item: unselectedPlayerIndex + 1, section: 0)) as? SelectionCell {
                            let unselectedPoint = destinationCell.playerView.thumbnail.convert(CGPoint(x: 0, y: 0), to: self.selectionView)
                            self.animationView.frame = CGRect(origin: unselectedPoint, size: CGSize(width: self.width, height: self.height))
                            self.animationView.set(textColor: Palette.text)
                        }
                    }
                    animation.addCompletion( {_ in
                        
                        // Replace nil entry with player and refresh collection view
                        self.unselectedList[unselectedPlayerIndex] = selectedPlayerMO
                        self.unselectedCollectionView.reloadItems(at: [IndexPath(item: unselectedPlayerIndex + 1, section: 0)])
                        
                        // Now hide animation thumbnail
                        self.animationView.alpha = 0.0
                        
                        // Unlock the views
                        self.setUserInteraction(true)
                        
                    })
                    animation.startAnimation()
                }
            }
        }
    }
    
    func addSelection(_ selectedPlayerMO: PlayerMO, toSlot: Int? = nil, updateUnselected: Bool = true, updateUnselectedCollection: Bool = true, animate: Bool = true) {
        
        if let slot = toSlot ?? self.selectedPlayersView.freeSlot() {
            
            selectedList.append((slot, selectedPlayerMO))
        
            self.formatButtons(animate)
            
            if !animate || !updateUnselected || !updateUnselectedCollection {
                // Just set the view and remove from current view
                selectedPlayersView.set(slot: slot, playerMO: selectedPlayerMO)
                if updateUnselected {
                    self.removeUnselected(selectedPlayerMO, updateUnselectedCollection: updateUnselectedCollection)
                }
                
            } else {
                // Animation
                
                // Calculate offsets for available collection view cell
                if let unselectedPlayerIndex = unselectedList.firstIndex(where: { $0 == selectedPlayerMO }) {
                    if let unselectedCell = unselectedCollectionView.cellForItem(at: IndexPath(item: unselectedPlayerIndex + 1, section: 0)) as! SelectionCell? {
                        let unselectedPoint = unselectedCell.convert(CGPoint(x: 0, y: 0), to: self.selectionView)
                        
                        // Draw a new thumbnail over top of existing - add in views which are uninstalled in IB to avoid warnings of no constraints
                        self.animationView.frame = CGRect(origin: unselectedPoint, size: CGSize(width: unselectedCell.frame.width, height: unselectedCell.frame.height))
                        self.animationView.set(playerMO: selectedPlayerMO)
                        self.animationView.set(textColor: Palette.darkHighlightText)
                        self.animationView.alpha = 1.0
                        
                        // Clear the source cell (and set it to a blank player to avoid spurious refreshes before we remove it)
                        self.removeUnselected(selectedPlayerMO)
                        
                        // Lock the views until animation completes
                        self.setUserInteraction(false)
                        
                        // Move animation thumbnail to the selected area
                        let animation = UIViewPropertyAnimator(duration: 0.5, curve: .easeIn) {
                            // Now move it to the selected area
                            let selectedPoint = self.selectedPlayersView.origin(slot: slot, in: self.selectionView)
                            self.animationView.frame = CGRect(origin: selectedPoint, size: CGSize(width: self.width, height: self.height))
                            self.animationView.set(textColor: Palette.darkHighlightText)
                            self.selectedPlayersView.clear(slot: slot)
                        }
                        animation.addCompletion( {_ in
                            
                            // Show player (under animation)
                            self.selectedPlayersView.set(slot: slot, playerMO: selectedPlayerMO)
                            
                            // Remove from unselected list
                            if updateUnselected {
                                self.removeUnselected(selectedPlayerMO)
                            }
                            
                            // Now hide animation thumbnail
                            self.animationView.alpha = 0.0
                            
                            // Unlock the views
                            self.setUserInteraction(true)
                            
                        })
                        animation.startAnimation()
                    }
                }
            }
        }
    }
    
    private func removeUnselected(_ playerMO: PlayerMO, updateUnselectedCollection: Bool = true) {
        if let index = self.unselectedList.firstIndex(where: { $0 == playerMO }) {
            if !updateUnselectedCollection {
                self.unselectedList.remove(at: index)
            } else {
                unselectedCollectionView.performBatchUpdates({
                    self.unselectedList.remove(at: index)
                    self.unselectedCollectionView.deleteItems(at: [IndexPath(item: index + 1, section: 0)])
                })
            }
        }
    }
    
    private func addUnselected(_ playerMO: PlayerMO, leaveNil: Bool = false) -> Int {
        var insertIndex = self.unselectedList.count
        if let index = self.unselectedList.firstIndex(where: { $0?.name ?? "" > playerMO.name! }) {
            insertIndex = index
        }
        unselectedCollectionView.performBatchUpdates({
            self.unselectedList.insert((leaveNil ? nil : playerMO), at: insertIndex)
            self.unselectedCollectionView.insertItems(at: [IndexPath(item: insertIndex + 1, section: 0)])
        })
        return insertIndex
    }
    
    private func setUserInteraction(_ enabled: Bool) {
        self.unselectedCollectionView.isUserInteractionEnabled = enabled
        self.selectedPlayersView.isEnabled = enabled
        self.clearButton.isUserInteractionEnabled = enabled
    }
    
    private func setupAnimationView() {
        self.animationView = PlayerView(type: .animation, parent: self.view, width: self.width, height: self.height, tag: -1)
    }
    
    private func setupDragAndDrop() {
        let unselectedDropInteraction = UIDropInteraction(delegate: self)
        self.unselectedCollectionView.addInteraction(unselectedDropInteraction)
    }
    
    private func createPlayers(newPlayers: [PlayerDetail], createMO: Bool) {
        let addToSelected = (selectedList.count + newPlayers.count <= self.scorecard.numberPlayers)
        
        for newPlayerDetail in newPlayers {
            if newPlayerDetail.name == "" {
                // Name not filled in - must have cancelled
            } else {
                
                var playerMO: PlayerMO?
                if createMO {
                    // Need to create Managed Object
                    _ = newPlayerDetail.createMO()
                } else {
                    playerMO = newPlayerDetail.playerMO
                }
                if let playerMO = playerMO {
                    // Add to available list
                    availableList.append(playerMO)
                    
                    // Add to unselected list and collection view
                    var unselectedIndex: Int! = self.unselectedList.firstIndex(where: {($0!.name! > newPlayerDetail.name)})
                    if unselectedIndex == nil {
                        // Insert at end
                        unselectedIndex = unselectedList.count
                    }
                    unselectedCollectionView.performBatchUpdates({
                        unselectedList.insert(playerMO, at: unselectedIndex)
                        unselectedCollectionView.insertItems(at: [IndexPath(row: unselectedIndex + 1, section: 0)])
                    })
                    
                    // Add to selection if there is space
                    if addToSelected {
                        addSelection(playerMO)
                    }
                }
            }
        }
    }
    
    func addNewPlayer() {
        if scorecard.settingSyncEnabled && scorecard.isNetworkAvailable && scorecard.isLoggedIn {
            self.performSegue(withIdentifier: "showSelectPlayers", sender: self)
        } else {
            PlayerDetailViewController.show(from: self, playerDetail: PlayerDetail(visibleLocally: true), mode: .create, sourceView: view,
                                            completion: { (playerDetail, deletePlayer) in
                                                if playerDetail != nil {
                                                    self.createPlayers(newPlayers: [playerDetail!], createMO: true)
                                                }
                                            })
        }
    }
    
    // MARK: - Drop delegate handlers ================================================================== -
    
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        return UIDropProposal(operation: .move)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: PlayerObject.self)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        
        for item in session.items {
            item.itemProvider.loadObject(ofClass: PlayerObject.self, completionHandler: { (playerObject, error) in
                if error == nil {
                    Utility.mainThread {
                        if let playerObject = playerObject as! PlayerObject? {
                            if let playerEmail = playerObject.playerEmail, let source = playerObject.source {
                                // Dropped on unselected view
                                
                                if source == .selected {
                                    // From selected area - remove it
                                    if let index = self.selectedPlayersView.playerViews.firstIndex(where: { $0.playerMO?.email == playerEmail }) {
                                        self.removeSelection(index)
                                    }
                                } else if source == .unselected {
                                    // From unselected - add it
                                    if let playerMO = self.availableList.first(where: { $0.email == playerEmail }) {
                                        self.addSelection(playerMO)
                                    }
                                } else if source == .addPlayer {
                                    // Add player button
                                    self.addNewPlayer()
                                }
                            }
                        }
                    }
                }
            })
        }
    }

    // MARK: - Segue Prepare Handler =================================================================== -

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier! {
            
        case "showGamePreview":
            let destination = segue.destination as! GamePreviewViewController
            selectedList.sort(by: { $0.slot < $1.slot })
            destination.selectedPlayers = selectedList.map{ $0.playerMO }
            destination.returnSegue = "hideGamePreview"
        
        case "showSelectPlayers":
            let destination = segue.destination as! SelectPlayersViewController

            destination.modalPresentationStyle = UIModalPresentationStyle.popover
            destination.isModalInPopover = true
            destination.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
            destination.popoverPresentationController?.sourceView = self.view
            destination.preferredContentSize = CGSize(width: 400, height: 600)
            
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
    fileprivate var playerView: PlayerView!
}

