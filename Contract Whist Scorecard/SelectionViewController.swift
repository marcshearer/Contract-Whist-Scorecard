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

enum SelectionMode {
    case invitees
    case players
}

class SelectionViewController: ScorecardViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIDropInteractionDelegate, UIGestureRecognizerDelegate, PlayerViewDelegate, SelectedPlayersViewDelegate, BannerDelegate {

    // MARK: - Class Properties ======================================================================== -

    // Variables to decide how view behaves
    private var selectionMode: SelectionMode!
    private var completion: ((Bool, [PlayerMO]?)->())? = nil
    private var thisPlayer: String?
    private var formTitle = "Selection"
    private var smallFormTitle: String?
    
    // Local class variables
    private var thumbnailWidth: CGFloat = 0.0
    private var thumbnailHeight: CGFloat = 0.0
    private var rowHeight: CGFloat = 0.0
    private let labelHeight: CGFloat = 30.0
    private let interRowSpacing:CGFloat = 10.0
    private var smallScreen = false
    private var haloWidth: CGFloat = 3.0
    private var dealerHaloWidth: CGFloat = 5.0
    private var firstTime = true
    private var loadedView = true
    private var rotated = false
    private var selectedAlpha: CGFloat = 0.5
    internal var testMode = false
    private var addPlayerThumbnail: Bool = true
    private var thisPlayerView: PlayerView!
    private var lastPlayerMO: PlayerMO!
    private var refreshCollection = true
    private var alreadyDrawing = false

    // Main local state handlers
    private var availableList: [PlayerMO] = []
    private var unselectedList: [PlayerMO?] = []
    private var selectedList: [(slot: Int, playerMO: PlayerMO)] = []
    private var observer: NSObjectProtocol?
    private var animationView: PlayerView!
    
    // MARK: - IB Outlets ============================================================================== -
    
    @IBOutlet private weak var banner: Banner!
    @IBOutlet private weak var unselectedCollectionView: UICollectionView!
    @IBOutlet private weak var topSectionView: UIView!
    @IBOutlet private weak var selectedPlayersView: SelectedPlayersView!
    @IBOutlet private weak var bottomSection: UIView!
    @IBOutlet private weak var bottomSectionHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var clearAllButton: ShadowButton!
    @IBOutlet private weak var continueButton: ShadowButton!
    @IBOutlet private var sideBySideConstraints: [NSLayoutConstraint]!
    @IBOutlet private var aboveAndBelowConstraints: [NSLayoutConstraint]!
    @IBOutlet private var sideBySideTabletConstraints: [NSLayoutConstraint]!
    @IBOutlet private var notSideBySideTabletConstraints: [NSLayoutConstraint]!

    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func continuePressed(_ sender: UIButton) {
        self.continuePressed()
    }
    
    internal func continuePressed() {
        continueAction()
    }

    internal func finishPressed() {
        finishAction()       
    }
    
    @IBAction func clearAllButtonPressed(_ sender: UIButton) {
        if selectedList.count > 0 {
            for (index, selected) in selectedList.enumerated() {
                if self.selectionMode != .invitees || index != 0 {
                    self.removeSelection(selected.slot, animate: false)
                }
            }
        }
    }
    
    // MARK: - View Overrides ========================================================================== -

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup default colors (previously done in StoryBoard)
        self.defaultViewColors()

        // Set test mode
        self.setTestMode()
        
        // Setup buttons and nav bar
        self.setupScreenSize()
        self.setupButtons()

        // Set nofification for image download
        observer = setImageDownloadNotification()
        
        // Setup selected players view delegate
        self.selectedPlayersView.delegate = self
        
        // Notify app controller view has loaded
        self.controllerDelegate?.didLoad()
        
        // Setup help
        self.setupHelpView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if self.firstTime {
            // Initialise game
             if self.selectionMode == .players {
                 Scorecard.game = Game()
             }
            
            // Setup available players
            self.setupAvailablePlayers()
            self.unselectedList = self.availableList
            
            // Setup form
            self.setupForm()
            self.refreshCollection = true
            self.view.setNeedsLayout()
        }

        // Check if in recovery mode - if so (and found all players) go straight to game setup
        if Scorecard.recovery.recovering {
            if selectedList.count == Scorecard.game.currentPlayers {
                self.continueAction()
            } else {
                Scorecard.recovery.recovering = false
            }
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.rotated = true
        Scorecard.shared.reCenterPopup(self)
        self.view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if firstTime || rotated {
            self.setupConstraints()
        }
        
        if !self.alreadyDrawing {
            self.selectedPlayersView.layoutIfNeeded()
        }
        
        self.setupScreenSize()
        self.setSize()
        
        if firstTime {
            self.setupAnimationView()
            self.setupDragAndDrop()
        }
        
        // Draw selected players room
        self.drawRoom()

        if !self.loadedView || self.rotated || self.refreshCollection {
            Utility.mainThread {
                // Need to do this on main thread to avoid crash
                self.unselectedCollectionView.reloadData()
                self.refreshCollection = false
            }

        }
        
        // Decide if buttons enabled
        if self.firstTime || self.rotated {
            if self.firstTime {
                self.controllerDelegate?.didAppear()
            }
            self.firstTime = false
            self.rotated = false
            formatButtons(false)
        }
        
        self.loadedView = false
    }
    
    override internal func willDismiss() {
        if observer != nil {
            NotificationCenter.default.removeObserver(observer!)
            observer = nil
        }
    }
    
    // MARK: - CollectionView Overrides ================================================================ -
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return (unselectedList.count + (addPlayerThumbnail ? 1 : 0))
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        return CGSize(width: self.thumbnailWidth, height: self.thumbnailHeight - 10.0)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return interRowSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        var cell: SelectionCell
        
        // Available players - Note this uses a thumbnail size reduced by 10 to allow for haloes elsewhere
        
        let playerNumber = indexPath.row + (addPlayerThumbnail ? 0 : 1)
        
        if addPlayerThumbnail && indexPath.row == 0 {
            // Create add player thumbnail
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Add Player Cell", for: indexPath) as! SelectionCell
            if cell.playerView == nil {
                cell.playerView = PlayerView(type: .addPlayer, parentViewController: self, parentView: cell, width: self.thumbnailWidth - 10.0, height: self.thumbnailHeight - 10, tag: -1)
                cell.playerView.delegate = self
            }
            cell.playerView.set(name: "", initials: "", alpha: 1.0)
            cell.playerView.set(backgroundColor: UIColor.clear)
            cell.playerView.set(imageName: "big plus white", tintColor: Palette.continueButton.background)
            
        } else {
            // Create player thumbnail
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Unselected Cell", for: indexPath) as! SelectionCell
            if cell.playerView == nil {
                cell.playerView = PlayerView(type: .unselected, parentViewController: self, parentView: cell, width: self.thumbnailWidth - 10.0, height: self.thumbnailHeight - 10.0, tag: playerNumber-1, tapGestureDelegate: self)
                cell.playerView.delegate = self
            }
            if let playerMO = unselectedList[playerNumber-1] {
                cell.playerView.set(playerMO: playerMO, nameHeight: 32.0)
            } else {
                cell.playerView.clear()
            }
            cell.playerView.set(imageName: nil)
        }
        
        cell.playerView.frame = CGRect(x: 5.0, y: 0.0, width: self.thumbnailWidth - 10, height: self.thumbnailHeight - 10)
        cell.playerView.set(textColor: Palette.normal.text)

        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        if addPlayerThumbnail && indexPath.row == 0 {
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
                self.unselectedCollectionView.reloadItems(at: [IndexPath(row: unselectedIndex! + (self.addPlayerThumbnail ? 1 : 0), section: 0)])
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
        
        let hidden = (selectedList.count < 3 && !testMode)

        if self.smallScreen {
            // Banner continuation button used on small or landscape phone
            self.continueButton.isHidden = true
            self.banner.setButton("continue", isHidden: false)
            self.banner.setButton("continue", isEnabled: !hidden)
            self.bottomSectionHeightConstraint.constant = 0
        } else {
            // Main continue button used on other devices
            self.continueButton.isHidden = false
            self.continueButton.isEnabled = !hidden
            self.banner.setButton("continue", isHidden: true)
            self.bottomSectionHeightConstraint.constant = ((self.menuController?.isVisible ?? false) ? 75 : 58) + (self.view.safeAreaInsets.bottom == 0 ? 8.0 : 0.0)
        }
        clearAllButton.isHidden = true // Left this in case we reinstate (selectedList.count > (self.selectionMode == .invitees ? 1 : 0))
        
        self.banner.set(title: (self.smallScreen && !ScorecardUI.landscapePhone() ? (smallFormTitle ?? self.formTitle) : self.formTitle))
        
    }
    
    func setSize() {
        
        
        // Setup sizes of thumbnail and a row in the collection
        let thumbnailSize = SelectionViewController.thumbnailSize(from: self, labelHeight: self.labelHeight)
        self.thumbnailWidth = thumbnailSize.width
        self.thumbnailHeight = thumbnailSize.height
        self.rowHeight = self.thumbnailHeight + self.interRowSpacing
                        
        // Set collection view insets
        let collectionViewLayout = self.unselectedCollectionView.collectionViewLayout as? UICollectionViewFlowLayout
        if ScorecardUI.landscapePhone() {
            // No insets in landscape
            collectionViewLayout?.sectionInset = UIEdgeInsets(top: 10.0, left: 20.0, bottom: -10.0, right: 0.0)
        } else {
            // Allow collection view to flow under other table top
            collectionViewLayout?.sectionInset = UIEdgeInsets(top: 15.0, left: 0.0, bottom: 0.0, right: 0.0)
        }
        collectionViewLayout?.invalidateLayout()
    }
    
    private func drawRoom() {
        let wasAlreadyDrawing = self.alreadyDrawing
        self.alreadyDrawing = true
        
        // Configure selected players view
        self.selectedPlayersView.roundCorners(cornerRadius: 40.0)
        self.selectedPlayersView.setHaloWidth(haloWidth: self.haloWidth, allowHaloWidth: dealerHaloWidth)
        self.selectedPlayersView.setHaloColor(color: Palette.halo.background)
        self.selectedPlayersView.setTapDelegate(self)
        
        // Update layout to get correct size
        if !wasAlreadyDrawing {
            self.view.layoutIfNeeded()
        }
        
        // Draw room
        self.selectedPlayersView.drawRoom(thumbnailWidth: self.thumbnailWidth, thumbnailHeight: self.thumbnailHeight, players: Scorecard.shared.maxPlayers)
        
        self.alreadyDrawing = wasAlreadyDrawing
    }
    
    private func setUserInteraction(_ enabled: Bool) {
        self.unselectedCollectionView.isUserInteractionEnabled = enabled
        self.selectedPlayersView.isEnabled = enabled
        if enabled && self.selectionMode == .invitees {
            self.selectedPlayersView.setEnabled(slot: 0, enabled: false)
        }
    }
    
    
    /// Function used in other views to get the same thumbnail size
    
    class public func thumbnailSize(from viewController: ScorecardViewController, labelHeight: CGFloat, marginWidth: CGFloat = 10.0, spacing: CGFloat = 10.0, maxHeight: CGFloat = 80.0) -> CGSize {
        var result: CGSize
        if let view = viewController.view {
            let viewSize = view.bounds
            let totalWidth = viewSize.width
            let totalHeight = viewSize.height
            let availableWidth = min(totalWidth, totalHeight) // Get portrait height - relies on no side safe area insets in portrait
            
            let numberThatFit = max(5, Int(availableWidth / (min(totalWidth, totalHeight) > 450 ? 120 : 75)))
            
            let width = min(maxHeight, ((availableWidth - (CGFloat(numberThatFit - 1) * spacing) - (2.0 * marginWidth)) / CGFloat(numberThatFit)))
            let height = width + labelHeight - 5.0
            result = CGSize(width: width, height: height)
        } else {
            result = CGSize(width: 60.0, height: 60.0 + labelHeight - 5.0)
        }
        return result
    }
    
    func finishAction() {
        self.willDismiss()
        self.controllerDelegate?.didCancel()
    }

    func continueAction() {
        selectedList.sort(by: { $0.slot < $1.slot })
        self.completion?(false, self.selectedList.map {$0.playerMO})
        self.willDismiss()
        self.controllerDelegate?.didProceed()
    }
    
    // MARK: - Initial setup routines ======================================================================== -
    
    private func setupButtons() {
        
        self.banner.set(rightButtons: [
            BannerButton(action: self.helpPressed, type: .help),
            BannerButton(title: "Continue", image: UIImage(named: "forward"), width: 100, action: self.continuePressed, menuHide: true, id: "continue")])
        
        // Set cancel button and title
        self.continueButton.toCircle()
    }
    
    private func setupScreenSize() {
        // Check if need to restrict bottom because of screen size - only now doing this on landscape phone
        self.smallScreen = ScorecardUI.landscapePhone()
    }
    
    private func setupForm() {
        
        // Try to find players from last time
        self.assignPlayers()
        if self.selectionMode == .invitees {
            // Make sure host is correct
            self.defaultOnlinePlayers()
        }
    }
    
    private func setupAvailablePlayers() {
        // Add players to available and unselected list
        self.availableList = []
        for playerMO in Scorecard.shared.playerList {
            availableList.append(playerMO)
        }
    }
    
    private func assignPlayers() {
        // Run round player list trying to patch in players from last time
        
        self.selectedList = []
        
        for slot in 0..<Scorecard.shared.maxPlayers {
            // Clear any existing selection
            self.selectedPlayersView.clear(slot: slot)
        }
        
        for playerNumber in 1...Scorecard.game.currentPlayers {
            // Add in player if set up
            if let playerURI = Scorecard.game.player(enteredPlayerNumber: playerNumber).playerMO?.uri {
                if playerURI != "" {
                    if let playerMO = availableList.first(where: { $0.uri == playerURI }) {
                        addSelection(playerMO, toSlot: playerNumber - 1, updateUnselectedCollection: false, animate: false)
                    }
                }
            }
        }
    }
    
    private func defaultOnlinePlayers() {
        let host = self.selectedPlayersView.playerViews[0].playerMO
        if host?.playerUUID != self.thisPlayer {
            for slot in 0..<Scorecard.shared.maxPlayers {
                self.removeSelection(slot, updateUnselectedCollection: false, animate: false)
            }
            self.addSelection(Scorecard.shared.findPlayerByPlayerUUID(self.thisPlayer!)!, toSlot: 0, updateUnselected: true, updateUnselectedCollection: false, animate: false)
        }
        // Don't allow change of host player
        self.selectedPlayersView.setEnabled(slot: 0, enabled: false)
    }
    
   private func setupAnimationView() {
        self.animationView = PlayerView(type: .animation, parentViewController: self, parentView: self.view, width: self.thumbnailWidth, height: self.thumbnailHeight, tag: -1, haloWidth: self.haloWidth, allowHaloWidth: self.dealerHaloWidth)
        // Move it off the screen
        self.animationView.frame = CGRect(x: -self.thumbnailWidth, y: -self.thumbnailHeight, width: self.thumbnailWidth, height: self.thumbnailHeight)
    }
    
    private func setupDragAndDrop() {
        let unselectedDropInteraction = UIDropInteraction(delegate: self)
        self.unselectedCollectionView.addInteraction(unselectedDropInteraction)
    }
    
    private func setupConstraints() {
        var sideBySide = false
        var sideBySideTablet = false
        if ScorecardUI.landscapePhone() {
            sideBySide = true
        } else if self.container == .mainRight && self.view.frame.width > 700 {
            sideBySide = true
            sideBySideTablet = true
        }
        Constraint.setActive(self.sideBySideConstraints, to: sideBySide)
        Constraint.setActive(self.aboveAndBelowConstraints, to: !sideBySide)
        Constraint.setActive(self.sideBySideTabletConstraints, to: sideBySideTablet)
        Constraint.setActive(self.notSideBySideTabletConstraints, to: !sideBySideTablet)
    }
    
   // MARK: - Add / remove player from selection ============================================================== -
    
    private func removeSelection(_ selectedSlot: Int, updateUnselected: Bool = true, updateUnselectedCollection: Bool = true, animate: Bool = true) {
        
        if  selectedPlayersView.inUse(slot: selectedSlot) {
            
            if let selectedIndex = selectedList.firstIndex(where: { $0.slot == selectedSlot }) {
                let (_, selectedPlayerMO) = self.selectedList[selectedIndex]
                
                selectedList.remove(at: selectedIndex)
                self.formatButtons(animate)
                
                if !animate || !updateUnselected {
                    // Just set the view and remove from current view
                    self.selectedPlayersView.clear(slot: selectedSlot)
                    if updateUnselected {
                        _ = self.addUnselected(selectedPlayerMO, updateUnselectedCollection: updateUnselectedCollection)
                    }
                    
                } else {
                    // Animation
                    
                    // Draw a new thumbnail over top of existing
                    let selectedPoint = selectedPlayersView.origin(slot: selectedSlot, in: self.view)
                    self.animationView.frame = CGRect(origin: selectedPoint, size: CGSize(width: self.thumbnailWidth, height: self.thumbnailHeight))
                    self.animationView.set(playerMO: selectedPlayerMO)
                    self.animationView.set(textColor: Palette.darkHighlight.text)
                    self.animationView.alpha = 1.0
                    
                    // Add new cell to unselected view
                    let unselectedPlayerIndex = addUnselected(selectedPlayerMO, leaveNil: true)
                    
                    // Clear selected cell
                    self.selectedPlayersView.clear(slot: selectedSlot)
                    
                    // Lock the views until animation completes
                    self.setUserInteraction(false)
                    
                    // Move animation thumbnail to the unselected area
                    let animation = UIViewPropertyAnimator(duration: 0.5, curve: .easeIn) {
                        
                        self.unselectedCollectionView.scrollToItem(at: IndexPath(item: unselectedPlayerIndex + (self.addPlayerThumbnail ? 1 : 0), section: 0), at: .centeredHorizontally, animated: true)
                        if let destinationCell = self.unselectedCollectionView.cellForItem(at: IndexPath(item: unselectedPlayerIndex + (self.addPlayerThumbnail ? 1 : 0), section: 0)) as? SelectionCell {
                            let unselectedPoint = destinationCell.playerView.thumbnailView.convert(CGPoint(x: 0, y: 0), to: self.view)
                            self.animationView.frame = CGRect(origin: unselectedPoint, size: CGSize(width: self.thumbnailWidth, height: self.thumbnailHeight))
                            self.animationView.set(textColor: Palette.normal.text)
                        }
                    }
                    animation.addCompletion( {_ in
                        
                        // Replace nil entry with player and refresh collection view
                        self.unselectedList[unselectedPlayerIndex] = selectedPlayerMO
                        self.unselectedCollectionView.reloadItems(at: [IndexPath(item: unselectedPlayerIndex + (self.addPlayerThumbnail ? 1 : 0), section: 0)])
                        
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
    
    private func addSelection(_ selectedPlayerMO: PlayerMO, toSlot: Int? = nil, updateUnselected: Bool = true, updateUnselectedCollection: Bool = true, animate: Bool = true) {
        
        if let slot = toSlot ?? self.selectedPlayersView.freeSlot() {
            
            // Flag this slot as in use to avoid overwrite while animation ongoing
            self.selectedPlayersView.setInUse(slot: slot)
            
            // Add to selected list
            selectedList.append((slot, selectedPlayerMO))
        
            if !self.firstTime {
                self.formatButtons(animate)
            }
            
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
                    if let unselectedCell = unselectedCollectionView.cellForItem(at: IndexPath(item: unselectedPlayerIndex + (self.addPlayerThumbnail ? 1 : 0), section: 0)) as! SelectionCell? {
                        let unselectedPoint = unselectedCell.convert(CGPoint(x: 0, y: 0), to: self.view)
                        
                        // Draw a new thumbnail over top of existing - add in views which are uninstalled in IB to avoid warnings of no constraints
                        self.animationView.frame = CGRect(origin: unselectedPoint, size: CGSize(width: unselectedCell.frame.width, height: unselectedCell.frame.height))
                        self.animationView.set(playerMO: selectedPlayerMO)
                        self.animationView.set(textColor: Palette.darkHighlight.text)
                        self.animationView.alpha = 1.0
                        
                        // Clear the source cell (and set it to a blank player to avoid spurious refreshes before we remove it)
                        self.removeUnselected(selectedPlayerMO)
                        
                        // Lock the views until animation completes
                        self.setUserInteraction(false)
                        
                        // Move animation thumbnail to the selected area
                        let animation = UIViewPropertyAnimator(duration: 0.5, curve: .easeIn) {
                            // Now move it to the selected area
                            let selectedPoint = self.selectedPlayersView.origin(slot: slot, in: self.view)
                            self.animationView.frame = CGRect(origin: selectedPoint, size: CGSize(width: self.thumbnailWidth, height: self.thumbnailHeight))
                            self.animationView.set(textColor: Palette.darkHighlight.text)
                            self.selectedPlayersView.clear(slot: slot, keepInUse: true)
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
                    self.unselectedCollectionView.deleteItems(at: [IndexPath(item: index + (self.addPlayerThumbnail ? 1 : 0), section: 0)])
                })
            }
        }
    }
    
    private func addUnselected(_ playerMO: PlayerMO, leaveNil: Bool = false, updateUnselectedCollection: Bool = true) -> Int {
        var insertIndex = self.unselectedList.count
        if let index = self.unselectedList.firstIndex(where: { $0?.name ?? "" > playerMO.name! }) {
            insertIndex = index
        }
        if !updateUnselectedCollection {
            self.unselectedList.insert((leaveNil ? nil : playerMO), at: insertIndex)
        } else {
            unselectedCollectionView.performBatchUpdates({
                self.unselectedList.insert((leaveNil ? nil : playerMO), at: insertIndex)
                self.unselectedCollectionView.insertItems(at: [IndexPath(item: insertIndex + (self.addPlayerThumbnail ? 1 : 0), section: 0)])
            })
        }
        return insertIndex
    }
    
    // MARK: - Create players on return from Add Player ================================================================ -
    
    private func createPlayers(newPlayers: [PlayerDetail]) {
        let addToSelected = (selectedList.count + newPlayers.count <= Scorecard.shared.maxPlayers)
        
        for newPlayerDetail in newPlayers {
            if let playerMO = newPlayerDetail.playerMO {
                
                // Add to available list and unselected list if not there already
                if self.availableList.firstIndex(where: { $0.playerUUID! == newPlayerDetail.playerUUID } ) == nil {
                    
                    availableList.append(playerMO)
                    
                    // Add to unselected list and collection view
                    var unselectedIndex: Int! = self.unselectedList.firstIndex(where: {($0!.name! > newPlayerDetail.name)})
                    if unselectedIndex == nil {
                        // Insert at end
                        unselectedIndex = unselectedList.count
                    }
                    unselectedCollectionView.performBatchUpdates({
                        unselectedList.insert(playerMO, at: unselectedIndex)
                        unselectedCollectionView.insertItems(at: [IndexPath(row: unselectedIndex + (self.addPlayerThumbnail ? 1 : 0), section: 0)])
                    })
                }
                
                // Add to selection if there is space
                if addToSelected {
                    self.addSelection(playerMO)
                }
            }
        }
    }
    
    // MARK: - Show other views ============================================================================================ -
    
    func addNewPlayer() {
        self.showSelectPlayers()
    }
    
    private func showSelectPlayers() {
        self.controllerDelegate?.didInvoke(.selectPlayers) { (context) in
            if let playerList = context?["playerList"] as? [PlayerDetail] {
                if playerList.count > 0 {
                    self.createPlayers(newPlayers: playerList)
                }
            }
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
        if tag == -1 {
            // New player button
            self.addNewPlayer()
        } else {
            self.addSelection(playerView.playerMO!)
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
                            if let playerUUID = playerObject.playerUUID, let source = playerObject.source {
                                // Dropped on unselected view
                                
                                if source == .selected {
                                    // From selected area - remove it
                                    if let index = self.selectedPlayersView.playerViews.firstIndex(where: { $0.playerMO?.playerUUID == playerUUID }) {
                                        self.removeSelection(index)
                                    }
                                } else if source == .unselected {
                                    // From unselected - add it
                                    if let playerMO = self.availableList.first(where: { $0.playerUUID == playerUUID }) {
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
    
    // MARK: - Tap gesture delegate handlers =========================================================== -
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view == self.selectedPlayersView {
            return false
        } else {
            return true
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    // MARK: - Function to present and dismiss this view ==============================================================
    
    class func show(from viewController: ScorecardViewController, appController: ScorecardAppController? = nil, existing selectionViewController: SelectionViewController? = nil, mode: SelectionMode, thisPlayer: String? = nil, formTitle: String = "Selection", smallFormTitle: String? = nil, completion: ((Bool, [PlayerMO]?)->())? = nil) -> SelectionViewController {
        var selectionViewController = selectionViewController
        
        if selectionViewController == nil {
            let storyboard = UIStoryboard(name: "SelectionViewController", bundle: nil)
            selectionViewController = storyboard.instantiateViewController(withIdentifier: "SelectionViewController") as? SelectionViewController
        }
        
        selectionViewController!.selectionMode = mode
        selectionViewController!.thisPlayer = thisPlayer ?? ""
        selectionViewController!.formTitle = formTitle
        selectionViewController!.smallFormTitle = smallFormTitle
        selectionViewController!.completion = completion
        selectionViewController?.controllerDelegate = appController

        // Let view controller know that this is a new 'instance' even though possibly re-using
        selectionViewController!.firstTime = true
        
        viewController.present(selectionViewController!, appController: appController, animated: true, container: .mainRight)
        
        return selectionViewController!
    }
    
    private func dismiss(returnHome: Bool = false, _ players: [PlayerMO]? = nil, completion: (()->())? = nil) {
        self.dismiss(animated: !returnHome, completion: {
            self.completion?(returnHome, players)
            completion?()
        })
    }
    
    override internal func didDismiss() {
        NotificationCenter.default.removeObserver(observer!)
        self.completion?(false, nil)
    }
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class SelectionCell: UICollectionViewCell {
    fileprivate var playerView: PlayerView!
}

class TaplessView: UIView {
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        if hitView == self {
            return nil
        } else {
            return hitView
        }
    }
}

extension SelectionViewController {

    /** _Note that this code was generated as part of the move to themed colors_ */

    private func defaultViewColors() {

        self.view.backgroundColor = Palette.normal.background
        self.topSectionView.backgroundColor = ((self.menuController?.isVisible ?? false) ? Palette.normal.background : Palette.banner.background)
        self.clearAllButton.setBackgroundColor(Palette.buttonFace.background)
        self.clearAllButton.setTitleColor(Palette.buttonFace.text, for: .normal)
        self.continueButton.setBackgroundColor(Palette.continueButton.background)
        self.continueButton.setTitleColor(Palette.continueButton.text, for: .normal)
        self.view.backgroundColor = Palette.normal.background
    }
}

extension SelectionViewController {
    
    internal func setupHelpView() {
        
        self.helpView.reset()
        
        self.helpView.add("This screen allows you to select players \(self.gameMode == .scoring ? "for your game" : "to invite to your online game").\n\nClick (or drag) players in the list \(ScorecardUI.portraitPhone() ? "on the bottom" : "at the right") of the screen to add them to the game.\n\nClick (or drag) players in the room to remove them.\n\nClick on the '+' to add a new player to your device")
        
        self.helpView.add("The @*/Room@*/ contains the players who you select to take part in the game.\(self.gameMode == .scoring ? "" : " Your own player always appears at the bottom of the room.") Click on a player to remove them from the room.", views: [self.selectedPlayersView], radius: 44)
        
        self.helpView.add("This area contains other players on the device. Click on a player to add them to the game (assuming there is a space in the room).", views: [self.unselectedCollectionView], item: 1, itemTo: 9999, border: 4)
        
        self.helpView.add("You can use the {} to add a new player to the device (and hence to the available players).", descriptor: "@*+@* button", views: [self.unselectedCollectionView], item: 0)
        
        self.helpView.add("\((selectedList.count < 3 ? "When enough players have been added to the game, the {} will be enabled. ": ""))Click the {} to \(self.gameMode == .scoring ? "review the selected players and set the dealer prior to starting the game" : "send invitations to the other players and start the game").", descriptor: "@*/Continue@*/ button", views: [self.continueButton], bannerId: "continue", radius: self.continueButton.frame.height / 2)
        
        self.helpView.add("The {} abandons the game and takes you back to the home screen.", bannerId: Banner.finishButton, horizontalBorder: 8, verticalBorder: 4)
    }
}
