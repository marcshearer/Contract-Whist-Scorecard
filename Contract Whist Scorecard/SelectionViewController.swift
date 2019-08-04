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
    case single
    case invitees
    case players
}

class SelectionViewController: CustomViewController, UICollectionViewDelegate, UICollectionViewDataSource,UICollectionViewDelegateFlowLayout, UIDropInteractionDelegate, UIGestureRecognizerDelegate, PlayerViewDelegate, SelectedPlayersViewDelegate, SlideOutButtonDelegate, GamePreviewDelegate {
    

    // MARK: - Class Properties ======================================================================== -

    // Main state properties
    private let scorecard = Scorecard.shared
    
    // Variables to decide how view behaves
    private var selectionMode: SelectionMode!
    private var preCompletion: (([PlayerMO]?)->())? = nil
    private var completion: (([PlayerMO]?)->())? = nil
    private var gamePreviewDelegate: GamePreviewDelegate!
    private var backText: String = "Back"
    private var backImage: String = "back"
    private var thisPlayer: String?
    private var thisPlayerFrame: CGRect?
    private var formTitle = "Selection"
    
    // Local class variables
    private var width: CGFloat = 0.0
    private var height: CGFloat = 0.0
    private var rowHeight: CGFloat = 0.0
    private let labelHeight: CGFloat = 30.0
    private let interRowSpacing:CGFloat = 10.0
    private var bannerContinuationHeight: CGFloat = 44.0
    private var haloWidth: CGFloat = 0.0
    private var firstTime = true
    private var selectedAlpha: CGFloat = 0.5
    private var testMode = false
    private var addPlayerThumbnail: Bool = false
    private var thisPlayerView: PlayerView!

    // Main local state handlers
    private var availableList: [PlayerMO] = []
    private var unselectedList: [PlayerMO?] = []
    private var selectedList: [(slot: Int, playerMO: PlayerMO)] = []
    private var observer: NSObjectProtocol?
    private var animationView: PlayerView!
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var unselectedCollectionView: UICollectionView!
    @IBOutlet private weak var unselectedCollectionViewTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var selectionView: UIView!
    @IBOutlet private weak var cancelButton: UIButton!
    @IBOutlet private weak var bannerContinueButton: UIButton!
    @IBOutlet private weak var continueButton: UIButton!
    @IBOutlet private weak var bannerAddPlayerButton: UIButton!
    @IBOutlet private weak var selectedPlayersView: SelectedPlayersView!
    @IBOutlet private weak var selectedViewHeight: NSLayoutConstraint!
    @IBOutlet private weak var selectedViewWidth: NSLayoutConstraint!
    @IBOutlet private weak var slideOutButton: SlideOutButtonView!
    @IBOutlet private weak var navigationBar: UINavigationBar!
    @IBOutlet private weak var navigationTitle: UINavigationItem!
    @IBOutlet private weak var bannerContinuationView: BannerContinuation!
    @IBOutlet private weak var bannerContinuationHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var thisPlayerViewContainter: UIView!
    @IBOutlet private weak var thisPlayerViewContainerWidthConstraint: NSLayoutConstraint!
    
    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func continuePressed(_ sender: UIButton) {
        continueAction()
    }

    @IBAction func addPlayerPressed(_ sender: UIButton) {
        self.addNewPlayer()
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
            if selectionMode != .single || self.thisPlayer != playerMO.email {
                availableList.append(playerMO)
                unselectedList.append(playerMO)
            }
        }
        
        if self.selectionMode == .single {
            self.setupSingleScreen()
            self.showThisPlayer()
        } else {
            // Try to find players from last time
            self.scorecard.loadGameDefaults()
            self.assignPlayers()
            if self.selectionMode == .invitees {
                // Make sure host is correct
                self.defaultOnlinePlayers()
            }
        }
        
        // Check if in recovery mode - if so (and found all players) go straight to game setup
        if scorecard.recoveryMode {
            if selectedList.count == scorecard.currentPlayers {
                self.continueAction()
           } else {
                scorecard.recoveryMode = false
            }
        }
        
        // Set interline space
        let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = interRowSpacing
        
        // Set cancel button and title
        self.navigationTitle.title = self.formTitle
        self.cancelButton.setImage(UIImage(named: self.backImage), for: .normal)
        self.cancelButton.setTitle(self.backText, for: .normal)
        
        // Check network
        scorecard.checkNetworkConnection(button: nil, label: nil)
        
        // Set nofification for image download
        observer = setImageDownloadNotification()
        
        // Set up selected players view delegate
        self.selectedPlayersView.delegate = self
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !self.firstTime && self.selectionMode == .single {
            self.showThisPlayer()
        }
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
            
        }
        
        // Decide if buttons enabled
        formatButtons(false)
    
        // Draw table
        self.selectedPlayersView.setHaloWidth(haloWidth: self.haloWidth)
        self.selectedPlayersView.setHaloColor(color: Palette.halo)
        self.selectedPlayersView.drawRoom(thumbnailWidth: self.width, thumbnailHeight: self.height, players: self.scorecard.numberPlayers, directions: (ScorecardUI.landscapePhone() ? .none : .up))
        
        // Reload unselected player collection
        unselectedCollectionView.reloadData()
        
        // If recovering go straight to preview
        if self.scorecard.recoveryMode {
            self.continueAction()
        }
    }
    
    // MARK: - CollectionView Overrides ================================================================ -
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return unselectedList.count + (addPlayerThumbnail ? 1 : 0)
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
        
        let playerNumber = indexPath.row + (addPlayerThumbnail ? 0 : 1)
        
        if addPlayerThumbnail && indexPath.row == 0 {
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
        
        let hidden = (selectedList.count >= 3 || testMode ? false : true)
        if (ScorecardUI.smallPhoneSize() || ScorecardUI.landscapePhone()) {
            // Banner continuation button used on small or landscape phone
            continueButton.isHidden = true
            bannerContinueButton.isHidden = hidden
            if self.selectionMode != .single {
                bannerContinueButton.setTitle("Continue", for: .normal)
            }
        } else {
            // Main continue button used on other devices
            bannerContinueButton.setTitle("X", for: .normal)
            continueButton.isHidden = hidden
            bannerContinueButton.isHidden = true
        }
        slideOutButton.isHidden = (selectedList.count == 0 && self.selectionMode != .single)
    }
    
    func setSize(size: CGSize) {
        
        if ScorecardUI.smallPhoneSize() || ScorecardUI.landscapePhone() {
            self.bannerContinuationHeight = (self.selectionMode == .single ? 60.0 : 0.0)
            self.bannerContinuationView.isHidden = self.selectionMode != .single
            addPlayerThumbnail = true
        } else {
            self.bannerContinuationHeight = 60.0
            self.bannerContinuationView.isHidden = false
            addPlayerThumbnail = false
        }
        self.bannerContinuationHeightConstraint.constant = self.bannerContinuationHeight
        
        let totalWidth = size.width - view.safeAreaInsets.left - view.safeAreaInsets.right
        let selectedWidth = (ScorecardUI.landscapePhone() ? (totalWidth / 2.0) : totalWidth)
        let totalHeight = size.height - view.safeAreaInsets.top - view.safeAreaInsets.bottom
        
        let size = SelectionViewController.thumbnailSize(view: self.view, labelHeight: self.labelHeight)
        self.width = size.width
        self.height = size.height
        self.rowHeight = self.height + self.interRowSpacing
    
        let unselectedRows: Int = max(3, Int((totalHeight * 0.55) / self.rowHeight))
        let unselectedHeight = CGFloat(unselectedRows) * rowHeight
        
        if self.selectionMode == .single {
            self.selectedViewHeight?.constant = 44.0 + 75.0 + self.view.safeAreaInsets.bottom
            self.selectedPlayersView.alpha = 0.0
            self.unselectedCollectionViewTopConstraint.constant = self.width + 16.0 + (self.labelHeight - 5.0) + self.interRowSpacing - self.bannerContinuationHeight
        } else {
            let selectedTop = unselectedHeight + self.navigationBar.intrinsicContentSize.height + self.bannerContinuationHeight + view.safeAreaInsets.top
            let selectedHeight: CGFloat = totalHeight + view.safeAreaInsets.top + view.safeAreaInsets.bottom - selectedTop
            selectedViewWidth?.constant = selectedWidth
            
            if ScorecardUI.landscapePhone() {
                selectedViewHeight?.constant = totalHeight - navigationBar.intrinsicContentSize.height + view.safeAreaInsets.bottom
                self.selectedPlayersView.frame = CGRect(x: size.width - view.safeAreaInsets.right - selectedWidth, y: navigationBar.intrinsicContentSize.height + view.safeAreaInsets.top, width: selectedWidth, height: totalHeight - navigationBar.intrinsicContentSize.height + view.safeAreaInsets.bottom)
            } else {
                selectedViewHeight?.constant = selectedHeight
                self.selectedPlayersView.frame = CGRect(x: 0.0, y: selectedTop, width: selectedWidth, height: selectedHeight)
            }
        }
    }
    
    /// Function used in other views to get the same thumbnail size
    
    class public func thumbnailSize(view: UIView, labelHeight: CGFloat) -> CGSize {
        let totalWidth = view.bounds.width - view.safeAreaInsets.left - view.safeAreaInsets.right
        let selectedWidth = (ScorecardUI.landscapePhone() ? (totalWidth / 2.0) : totalWidth)
        let totalHeight = view.bounds.height - view.safeAreaInsets.top - view.safeAreaInsets.bottom
        let numberThatFit = max(5, Int(selectedWidth / (min(totalWidth, totalHeight) > 450 ? 120 : 75)))
        
        let width = min((totalHeight - 170)/2, ((selectedWidth - (CGFloat(numberThatFit + 1) * 10.0)) / CGFloat(numberThatFit)))
        let height = width + labelHeight - 5.0
        
        return CGSize(width: width, height: height)
    }
    
    func finishAction() {
        NotificationCenter.default.removeObserver(observer!)
        self.preCompletion?(nil)
        self.dismiss(animated: true, completion: {
            self.completion?(nil)
        })
    }

    func continueAction() {
        self.completion?(self.selectedList.map {$0.playerMO})
        selectedList.sort(by: { $0.slot < $1.slot })
        self.showGamePreview()
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
        } else if tag == -2 {
            // This player thumbnail - just exit
            self.finishAction()
        } else {
            if self.selectionMode == .single {
                self.preCompletion?([playerView.playerMO!])
                self.dismiss(animated: true, completion: {
                    self.completion?([playerView.playerMO!])
                })
            } else {
                self.addSelection(playerView.playerMO!)
            }
        }
    }
    
    // MARK: - Slide out button delegate handler======================================================== -
    
    func slideOutButtonPressed(_ sender: SlideOutButtonView) {
        if self.selectionMode == .single {
            self.addNewPlayer()
        } else {
            if selectedList.count > 0 {
                for (index, selected) in selectedList.enumerated() {
                    if self.selectionMode != .invitees || index != 0 {
                        self.removeSelection(selected.slot, animate: false)
                    }
                }
            }
        }
    }
    
    // MARK: - Utility Routines ======================================================================== -
    
    private func showSelectPlayers() {
        SelectPlayersViewController.show(from: self, descriptionMode: .opponents, allowOtherPlayer: true, allowNewPlayer: true, completion: { (selected, playerList, selection) in
            if let selected = selected, let playerList = playerList, let selection = selection {
                if selected > 0 {
                    var createPlayerList: [PlayerDetail] = []
                    for playerNumber in 1...playerList.count {
                        if selection[playerNumber-1] {
                            createPlayerList.append(playerList[playerNumber-1])
                        }
                    }
                    self.createPlayers(newPlayers: createPlayerList, createMO: false)
                }
            }
        })
    }
    
    private func showThisPlayer() {
        if let thisPlayer = self.thisPlayer {
            if let playerMO = self.scorecard.findPlayerByEmail(thisPlayer) {
                var width: CGFloat = thisPlayerViewContainerWidthConstraint.constant - 10.0
                if let thisPlayerFrame = self.thisPlayerFrame {
                    width = thisPlayerFrame.width
                    self.thisPlayerViewContainerWidthConstraint.constant = width + 10.0
                }
                    
                self.thisPlayerView = PlayerView(type: .addPlayer, parent: self.thisPlayerViewContainter, width: width, height: width, tag: -2)
                self.thisPlayerView.delegate = self
                self.thisPlayerView.set(playerMO: playerMO, nameHeight: 0.0)
                self.thisPlayerView.set(textColor: UIColor.clear)
                self.thisPlayerViewContainter.isHidden = false
            }
        }
    }

    func assignPlayers() {
        // Run round player list trying to patch in players from last time
        
        for playerNumber in 1...scorecard.currentPlayers {
            
            let playerURI = scorecard.playerURI(scorecard.enteredPlayer(playerNumber).playerMO)
            if playerURI != "" {
                if let playerMO = availableList.first(where: { self.scorecard.playerURI($0) == playerURI }) {
                    addSelection(playerMO, toSlot: playerNumber - 1, updateUnselectedCollection: false, animate: false)
                }
            }
        }
    }
    
    func defaultOnlinePlayers() {
        let host = self.selectedPlayersView.playerViews[0].playerMO!
        if host.email != self.thisPlayer {
            for slot in 0..<self.scorecard.numberPlayers {
                self.removeSelection(slot, animate: false)
            }
            self.addSelection(self.scorecard.findPlayerByEmail(self.thisPlayer!)!, toSlot: 0, updateUnselected: true, updateUnselectedCollection: true, animate: false)
        }
        // Don't allow change of host player
        self.selectedPlayersView.setEnabled(slot: 0, enabled: false)
    }
    
    func setupSingleScreen() {
        // Switch banner type
        self.bannerContinuationView.shape = .upArrow
        self.bannerAddPlayerButton.isHidden = true
        // Change slide out button to add player
        self.slideOutButton.title = "Add Player"
        self.slideOutButton.isHidden = false
        self.slideOutButton.buttonFillColor = UIColor.clear
        self.slideOutButton.buttonStrokeColor = Palette.gameBanner
        self.slideOutButton.buttonTextColor = Palette.gameBanner
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
                        
                        self.unselectedCollectionView.scrollToItem(at: IndexPath(item: unselectedPlayerIndex + (self.addPlayerThumbnail ? 1 : 0), section: 0), at: .centeredHorizontally, animated: true)
                        if let destinationCell = self.unselectedCollectionView.cellForItem(at: IndexPath(item: unselectedPlayerIndex + (self.addPlayerThumbnail ? 1 : 0), section: 0)) as? SelectionCell {
                            let unselectedPoint = destinationCell.playerView.thumbnail.convert(CGPoint(x: 0, y: 0), to: self.selectionView)
                            self.animationView.frame = CGRect(origin: unselectedPoint, size: CGSize(width: self.width, height: self.height))
                            self.animationView.set(textColor: Palette.text)
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
                    if let unselectedCell = unselectedCollectionView.cellForItem(at: IndexPath(item: unselectedPlayerIndex + (self.addPlayerThumbnail ? 1 : 0), section: 0)) as! SelectionCell? {
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
                    self.unselectedCollectionView.deleteItems(at: [IndexPath(item: index + (self.addPlayerThumbnail ? 1 : 0), section: 0)])
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
            self.unselectedCollectionView.insertItems(at: [IndexPath(item: insertIndex + (self.addPlayerThumbnail ? 1 : 0), section: 0)])
        })
        return insertIndex
    }
    
    private func setUserInteraction(_ enabled: Bool) {
        self.unselectedCollectionView.isUserInteractionEnabled = enabled
        self.selectedPlayersView.isEnabled = enabled
        self.slideOutButton.isEnabled = enabled
    }
    
    private func setupAnimationView() {
        self.animationView = PlayerView(type: .animation, parent: self.view, width: self.width, height: self.height, tag: -1, haloWidth: self.haloWidth)
        // Move it off the screen
        self.animationView.frame = CGRect(x: -self.width, y: -self.height, width: self.width, height: self.height)
    }
    
    private func setupDragAndDrop() {
        if self.selectionMode != .single {
            let unselectedDropInteraction = UIDropInteraction(delegate: self)
            self.unselectedCollectionView.addInteraction(unselectedDropInteraction)
        }
    }
    
    private func createPlayers(newPlayers: [PlayerDetail], createMO: Bool) {
        let addToSelected = (self.selectionMode == .single ? (newPlayers.count == 1) :
                                                    (selectedList.count + newPlayers.count <= self.scorecard.numberPlayers))
        
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
                        unselectedCollectionView.insertItems(at: [IndexPath(row: unselectedIndex + (self.addPlayerThumbnail ? 1 : 0), section: 0)])
                    })
                    
                    // Add to selection if there is space
                    if addToSelected {
                        if self.selectionMode == .single {
                            self.preCompletion?([playerMO])
                            self.dismiss(animated: true, completion: {
                                self.completion?([playerMO])
                            })
                        } else {
                            self.addSelection(playerMO)
                        }
                    }
                }
            }
        }
    }
    
    func addNewPlayer() {
        if scorecard.settingSyncEnabled && scorecard.isNetworkAvailable && scorecard.isLoggedIn {
            self.showSelectPlayers()
        } else {
            PlayerDetailViewController.show(from: self, playerDetail: PlayerDetail(visibleLocally: true), mode: .create, sourceView: view,
                                            completion: { (playerDetail, deletePlayer) in
                                                if playerDetail != nil {
                                                    self.createPlayers(newPlayers: [playerDetail!], createMO: true)
                                                }
                                            })
        }
    }
    
    private func showGamePreview() {
        _ = GamePreviewViewController.show(from: self, selectedPlayers: selectedList.map{ $0.playerMO }, readOnly: false, delegate: self)
    }
    
    // MARK: - Game Preview Delegate handlers ============================================================================== -
    
    internal var gamePreviewCanStartGame: Bool {
        get {
            return self.gamePreviewDelegate?.gamePreviewCanStartGame ?? true
        }
    }
    
    internal var gamePreviewWaitMessage: NSAttributedString {
        get {
            return self.gamePreviewDelegate?.gamePreviewWaitMessage ?? NSAttributedString()
        }
    }
    
    internal func gamePreviewInitialisationComplete(gamePreviewViewController: GamePreviewViewController) {
        self.gamePreviewDelegate?.gamePreviewInitialisationComplete?(gamePreviewViewController: gamePreviewViewController)
    }
    
    internal func gamePreviewCompletion() {
        self.scorecard.loadGameDefaults()
        self.selectedList = []
        self.assignPlayers()
        self.gamePreviewDelegate?.gamePreviewCompletion?()
    }
    
    internal func gamePreview(isConnected playerMO: PlayerMO) -> Bool {
        return self.gamePreviewDelegate?.gamePreview?(isConnected: playerMO) ?? true
    }
    
    internal func gamePreview(moved playerMO: PlayerMO, to slot: Int) {
        self.gamePreviewDelegate?.gamePreview?(moved: playerMO, to: slot)
    }
    
    internal func gamePreviewStartGame() {
        self.gamePreviewDelegate?.gamePreviewStartGame?()
    }
    
    internal func gamePreviewStopGame() {
        self.gamePreviewDelegate?.gamePreviewStopGame?()
    }
    
    internal func gamePreviewShakeGestureHandler() {
        self.gamePreviewDelegate?.gamePreviewShakeGestureHandler?()
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
    
    // MARK: - Function to present this view ==============================================================
    
    class func show(from viewController: UIViewController, existing selectionViewController: SelectionViewController? = nil, mode: SelectionMode, thisPlayer: String = "", thisPlayerFrame: CGRect? = nil, formTitle: String = "Selection", backText: String = "Back", backImage: String = "back", preCompletion: (([PlayerMO]?)->())? = nil, completion: (([PlayerMO]?)->())? = nil, showCompletion: (()->())? = nil, gamePreviewDelegate: GamePreviewDelegate? = nil) -> SelectionViewController {
        var selectionViewController = selectionViewController
        
        if selectionViewController == nil {
            let storyboard = UIStoryboard(name: "SelectionViewController", bundle: nil)
            selectionViewController = storyboard.instantiateViewController(withIdentifier: "SelectionViewController") as? SelectionViewController
        }
        
        selectionViewController!.selectionMode = mode
        selectionViewController!.thisPlayer = thisPlayer
        selectionViewController!.thisPlayerFrame = thisPlayerFrame
        selectionViewController!.formTitle = formTitle
        selectionViewController!.backText = backText
        selectionViewController!.backImage = backImage
        selectionViewController!.preCompletion = preCompletion
        selectionViewController!.completion = completion
        selectionViewController?.gamePreviewDelegate = gamePreviewDelegate

        if let viewController = viewController as? ClientViewController {
            // Animating from client - use special view controller
            selectionViewController!.transitioningDelegate = viewController
        }
        
        viewController.present(selectionViewController!, animated: true, completion: showCompletion)
        
        return selectionViewController!
    }
    
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class SelectionCell: UICollectionViewCell {
    fileprivate var playerView: PlayerView!
}

class FadeAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    
    let duration = 0.5
    var presenting = true
    var originFrame = CGRect.zero
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView
        let toView = transitionContext.view(forKey: .to)!
    
        containerView.addSubview(toView)
        toView.alpha = 0.0
        UIView.animate(
            withDuration: duration,
            animations: {
                toView.alpha = 1.0
        },
            completion: { _ in
                transitionContext.completeTransition(true)
        })
    }
}

extension ClientViewController: UIViewControllerTransitioningDelegate {
    
    func animationController(
        forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        self.transition.presenting = true
        if presented is SelectionViewController {
            return self.transition
        } else {
            return nil
        }
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if dismissed is SelectionViewController {
            self.transition.presenting = false
            return self.transition
        } else {
            return nil
        }
    }
}
