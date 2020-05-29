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

class SelectionViewController: ScorecardViewController, UICollectionViewDelegate, UICollectionViewDataSource,UICollectionViewDelegateFlowLayout, UIDropInteractionDelegate, UIGestureRecognizerDelegate, PlayerViewDelegate, SelectedPlayersViewDelegate {

    // MARK: - Class Properties ======================================================================== -

    // Variables to decide how view behaves
    private var selectionMode: SelectionMode!
    private var completion: ((Bool, [PlayerMO]?)->())? = nil
    private var backText: String = "Back"
    private var backImage: String = "back"
    private var thisPlayer: String?
    private var thisPlayerFrame: CGRect?
    private var showThisPlayerName = false
    private var formTitle = "Selection"
    private var smallFormTitle: String?
    private var bannerColor: UIColor?
    
    // Local class variables
    private var selectedHeight: CGFloat = 0.0
    private var selectedWidth: CGFloat = 0.0
    private var thumbnailWidth: CGFloat = 0.0
    private var thumbnailHeight: CGFloat = 0.0
    private var rowHeight: CGFloat = 0.0
    private let labelHeight: CGFloat = 30.0
    private let interRowSpacing:CGFloat = 10.0
    private var navigationBarHeight: CGFloat = 0.0
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
    @IBOutlet private weak var unselectedCollectionView: UICollectionView!
    @IBOutlet private weak var unselectedCollectionViewTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var unselectedCollectionViewLandscapeTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var unselectedCollectionViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var cancelButton: ClearButton!
    @IBOutlet private weak var bannerContinueButton: ClearButton!
    @IBOutlet private weak var continueButton: AngledButton!
    @IBOutlet private weak var continueButtonView: UIView!
    @IBOutlet private weak var continueButtonViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var continueButtonFooterView: Footer!
    @IBOutlet private weak var continueButtonFooterPaddingView: UIView!
    @IBOutlet private weak var selectedPlayersView: SelectedPlayersView!
    @IBOutlet private weak var selectedViewHeight: NSLayoutConstraint!
    @IBOutlet private weak var selectedViewWidth: NSLayoutConstraint!
    @IBOutlet private weak var clearAllButton: AngledButton!
    @IBOutlet private weak var bannerPaddingView: InsetPaddingView!
    @IBOutlet private weak var navigationBar: NavigationBar!
    @IBOutlet private weak var navigationBarHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var navigationTitle: UINavigationItem!
    @IBOutlet private weak var continueButtonItem: UIBarButtonItem!
    @IBOutlet private weak var bannerContinuationView: BannerContinuation!
    @IBOutlet private weak var bannerContinuationHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var thisPlayerViewContainer: UIView!
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
    
    @IBAction func clearAllButtonPressed(_ sender: UIButton) {
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

        // Check network
        Scorecard.shared.checkNetworkConnection(button: nil, label: nil)
        
        // Set nofification for image download
        observer = setImageDownloadNotification()
        
        // Setup selected players view delegate
        self.selectedPlayersView.delegate = self
        
        // Notify app controller view has loaded
        self.controllerDelegate?.didLoad()
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.rotated = true
        Scorecard.shared.reCenterPopup(self)
        self.view.setNeedsLayout()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.setupScreenSize()
        self.setSize()
        
        if firstTime {
            self.setupAnimationView()
            self.setupDragAndDrop()
        }
        
        // Draw selected players room
        if self.selectionMode != .single {
            self.drawRoom()
        }

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
        
        return CGSize(width: self.thumbnailWidth, height: self.thumbnailHeight)
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
                cell.playerView = PlayerView(type: .addPlayer, parent: cell, width: self.thumbnailWidth, height: self.thumbnailHeight, tag: -1)
                cell.playerView.delegate = self
            }
            cell.playerView.set(name: "", initials: "", alpha: 1.0)
            cell.playerView.set(imageName: "big plus green")
            cell.playerView.set(backgroundColor: UIColor.clear)
            
        } else {
            // Create player thumbnail
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Unselected Cell", for: indexPath) as! SelectionCell
            if cell.playerView == nil {
                cell.playerView = PlayerView(type: .unselected, parent: cell, width: self.thumbnailWidth, height: self.thumbnailHeight, tag: playerNumber-1, tapGestureDelegate: self)
                cell.playerView.delegate = self
            }
            if let playerMO = unselectedList[playerNumber-1] {
                cell.playerView.set(playerMO: playerMO)
            } else {
                cell.playerView.clear()
            }
            cell.playerView.set(imageName: nil)
        }
        
        cell.playerView.frame = CGRect(x: 0.0, y: 0.0, width: self.thumbnailWidth, height: self.thumbnailHeight)
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
        
        if self.smallScreen {
            // Banner continuation button used on small or landscape phone
            self.continueButton(isHidden: true)
            bannerContinueButton.isHidden = hidden
            if self.selectionMode != .single {
                bannerContinueButton.setTitle("Continue", for: .normal)
                continueButtonItem.width = 95.0
            }
        } else {
            // Main continue button used on other devices
            bannerContinueButton.setTitle("X", for: .normal)
            self.continueButton(isHidden: hidden, animate: animated)
            bannerContinueButton.isHidden = true
            continueButtonItem.width = 0.0
            self.navigationBar.layoutIfNeeded()
        }
        if selectionMode == .single {
            clearAllButton.isHidden = true
        } else {
            clearAllButton.isHidden = (selectedList.count <= (self.selectionMode == .invitees ? 1 : 0))
        }
    }
    
    func continueButton(isHidden: Bool, animate: Bool = false) {
        let continueButtonBottom = (isHidden ? -continueButtonView.frame.height : 0.0)
        if continueButtonBottom != self.continueButtonViewBottomConstraint.constant {
            Utility.animate(if: animate, duration: 0.3) {
                self.continueButtonViewBottomConstraint.constant = continueButtonBottom
            }
        }
    }
    
    func setSize() {
        
        // Set nav bar height - need to do this as otherwise gets compressed by layout
        self.navigationBarHeightConstraint?.constant = ScorecardUI.navigationBarHeight
        
        // Setup sizes of thumbnail and a row in the collection
        let thumbnailSize = SelectionViewController.thumbnailSize(labelHeight: self.labelHeight)
        self.thumbnailWidth = thumbnailSize.width
        self.thumbnailHeight = thumbnailSize.height
        self.rowHeight = self.thumbnailHeight + self.interRowSpacing
        
        // Mode specific setup
        if self.selectionMode == .single {
            self.setSingleModeSize()
        } else {
            self.setOtherModeSize()
        }
    }
    
    func setSingleModeSize() {
        
        // Banner continuation is always 60.0 up arrow
        self.bannerContinuationHeightConstraint.constant = 60.0
        
        // Selected view not shown in this mode
        self.selectedViewHeight?.constant = 0.0
        self.selectedViewWidth?.constant = 0.0
        self.selectedPlayersView.alpha = 0.0
        
        // Attach selected view to top of form below this player
        self.unselectedCollectionViewLandscapeTopConstraint?.constant = rowHeight + 20.0
        self.unselectedCollectionViewTopConstraint?.constant = rowHeight
        
    }
    
    func setOtherModeSize() {
        
        // No banner continuation on landscape phone
        self.bannerContinuationHeightConstraint.constant  = (ScorecardUI.landscapePhone() ? 0 : 60.0 + (self.selectedHeight / 2.0))
        
        // Set total size inside safe area
        let totalWidth = self.view.safeAreaLayoutGuide.layoutFrame.width
        let totalHeight = self.view.safeAreaLayoutGuide.layoutFrame.height
    
        // Set widht of selected view to full width (portrait) or half width (landscape)
        self.selectedWidth = (ScorecardUI.landscapePhone() ? (totalWidth / 2.0) : totalWidth)
        selectedViewWidth?.constant = self.selectedWidth

        // Set selected view height to half width in portrait to compress out any excess space - it will stretch to the space it needs when we draw it
        self.selectedHeight = (ScorecardUI.landscapePhone() ? totalHeight : 0.5 * self.selectedWidth)
        self.selectedViewHeight?.constant = self.selectedHeight
        
        if self.smallScreen || selectedList.count < 3 {
            // No bottom arrow - anchor to superview
            self.unselectedCollectionViewBottomConstraint?.constant = 0.0
        } else {
            // Allow collection view to flow under bottom arrow
            self.unselectedCollectionViewBottomConstraint?.constant = 0.0
        }

        // Set collection view insets
        let collectionViewLayout = self.unselectedCollectionView.collectionViewLayout as? UICollectionViewFlowLayout
        if ScorecardUI.landscapePhone() {
            // No insets in landscape
            collectionViewLayout?.sectionInset = UIEdgeInsets()
        } else {
            // Allow collection view to flow under other table top
            collectionViewLayout?.sectionInset = UIEdgeInsets(top: 62.5, left: 0.0, bottom: (smallScreen || selectedList.count < 3 ? 0.0 : 80.0), right: 0.0)
        }
        collectionViewLayout?.invalidateLayout()
    }
    
    private func drawRoom() {
        let alreadyDrawing = self.alreadyDrawing
        self.alreadyDrawing = true
        
        // Configure selected players view
        self.selectedPlayersView.setHaloWidth(haloWidth: self.haloWidth, allowHaloWidth: dealerHaloWidth)
        self.selectedPlayersView.setHaloColor(color: Palette.halo)
        self.selectedPlayersView.setTapDelegate(self)
        
        // Update layout to get correct size
        if !alreadyDrawing {
            self.view.layoutIfNeeded()
        }
        
        // Draw room
        let selectedFrame = self.selectedPlayersView.drawRoom(thumbnailWidth: self.thumbnailWidth, thumbnailHeight: self.thumbnailHeight, players: Scorecard.shared.maxPlayers, directions: (ScorecardUI.landscapePhone() ? .none : .up), (ScorecardUI.landscapePhone() ? .none : .down))
        
        // Reset height
        self.selectedHeight = selectedFrame.height
        self.selectedViewHeight?.constant = self.selectedHeight
        
        self.alreadyDrawing = false
    }
    
    private func showThisPlayer() {
        if let thisPlayer = self.thisPlayer {
            if let playerMO = Scorecard.shared.findPlayerByEmail(thisPlayer) {
                var size: CGSize
                let nameHeight: CGFloat = (self.showThisPlayerName ? 30.0 : 0.0)
                self.lastPlayerMO = playerMO
                if let thisPlayerFrame = self.thisPlayerFrame {
                    size = thisPlayerFrame.size
                } else {
                    size = SelectionViewController.thumbnailSize(labelHeight: nameHeight)
                }
                self.thisPlayerViewContainerWidthConstraint.constant = size.width + 10.0
                
                self.thisPlayerView?.removeFromSuperview()
                self.thisPlayerView = PlayerView(type: .addPlayer, parent: self.thisPlayerViewContainer, width: size.width, height: size.height, tag: -2)
                self.thisPlayerView.delegate = self
                self.thisPlayerView.set(playerMO: playerMO, nameHeight: nameHeight)
                self.thisPlayerView.set(textColor: Palette.text)
                self.thisPlayerViewContainer.isHidden = false
            }
        }
    }
    
    private func setUserInteraction(_ enabled: Bool) {
        self.unselectedCollectionView.isUserInteractionEnabled = enabled
        self.selectedPlayersView.isEnabled = enabled
        if enabled && self.selectionMode == .invitees {
            self.selectedPlayersView.setEnabled(slot: 0, enabled: false)
        }
        self.clearAllButton.isEnabled = enabled
    }
    
    
    /// Function used in other views to get the same thumbnail size
    
    class public func thumbnailSize(labelHeight: CGFloat, marginWidth: CGFloat = 10.0, spacing: CGFloat = 10.0, maxHeight: CGFloat = 80.0) -> CGSize {
        var result: CGSize
        if let viewController = Utility.getActiveViewController(ignoreAlertController: true), let view = viewController.view {
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
        
        // Set cancel button and title
        self.navigationTitle.title = (self.smallScreen && !ScorecardUI.landscapePhone() ? (smallFormTitle ?? self.formTitle) : self.formTitle)
        self.cancelButton.setImage(UIImage(named: self.backImage), for: .normal)
        self.cancelButton.setTitle(self.backText, for: .normal)
        if let bannerColor = self.bannerColor {
            self.bannerPaddingView.bannerColor = bannerColor
            self.navigationBar.bannerColor = bannerColor
            self.bannerContinuationView.bannerColor = bannerColor
            self.bannerContinuationView.borderColor = bannerColor
        }
    }
    
    private func setupScreenSize() {
        // Check if need to restrict bottom because of screen size
        self.smallScreen = (ScorecardUI.screenHeight < 800 || ScorecardUI.landscapePhone()) && ScorecardUI.phoneSize()
    }
    
    private func setupForm() {
        // Setup form
        if self.selectionMode == .single {
            self.showThisPlayer()
            if let playerMO = self.unselectedList.first(where: {$0!.email == self.thisPlayer}) {
                self.removeUnselected(playerMO!, updateUnselectedCollection: false)
            }
        } else {
            // Switch banner mode
            bannerContinuationView.shape = .rectangle

            // Try to find players from last time
            self.assignPlayers()
            if self.selectionMode == .invitees {
                // Make sure host is correct
                self.defaultOnlinePlayers()
            }
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
        if host?.email != self.thisPlayer {
            for slot in 0..<Scorecard.shared.maxPlayers {
                self.removeSelection(slot, updateUnselectedCollection: false, animate: false)
            }
            self.addSelection(Scorecard.shared.findPlayerByEmail(self.thisPlayer!)!, toSlot: 0, updateUnselected: true, updateUnselectedCollection: false, animate: false)
        }
        // Don't allow change of host player
        self.selectedPlayersView.setEnabled(slot: 0, enabled: false)
    }
    
   private func setupAnimationView() {
        self.animationView = PlayerView(type: .animation, parent: self.view, width: self.thumbnailWidth, height: self.thumbnailHeight, tag: -1, haloWidth: self.haloWidth, allowHaloWidth: self.dealerHaloWidth)
        // Move it off the screen
        self.animationView.frame = CGRect(x: -self.thumbnailWidth, y: -self.thumbnailHeight, width: self.thumbnailWidth, height: self.thumbnailHeight)
    }
    
    private func setupDragAndDrop() {
        if self.selectionMode != .single {
            let unselectedDropInteraction = UIDropInteraction(delegate: self)
            self.unselectedCollectionView.addInteraction(unselectedDropInteraction)
        }
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
                    self.animationView.set(textColor: Palette.darkHighlightText)
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
                        self.animationView.set(textColor: Palette.darkHighlightText)
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
                            self.animationView.set(textColor: Palette.darkHighlightText)
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
    
    private func createPlayers(newPlayers: [PlayerDetail], createMO: Bool) {
        let addToSelected = (self.selectionMode == .single ? (newPlayers.count == 1) :
                                                    (selectedList.count + newPlayers.count <= Scorecard.shared.maxPlayers))
        
        for newPlayerDetail in newPlayers {
            var playerMO: PlayerMO?
            if createMO {
                // Need to create Managed Object
                _ = newPlayerDetail.createMO()
            } else {
                playerMO = newPlayerDetail.playerMO
            }
            if let playerMO = playerMO {
                
                // Add to available list and unselected list if not there already
                if self.availableList.firstIndex(where: { $0.email! == newPlayerDetail.email } ) == nil {
                    
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
                    if self.selectionMode == .single {
                        self.dismiss([playerMO])
                    } else {
                        self.addSelection(playerMO)
                    }
                }
            }
        }
    }
    
    // MARK: - Show other views ============================================================================================ -
    
    func addNewPlayer() {
        if Scorecard.activeSettings.syncEnabled && Scorecard.shared.isNetworkAvailable && Scorecard.shared.isLoggedIn {
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
    
    private func showSelectPlayers() {
        self.controllerDelegate?.didInvoke(.selectPlayers) { (context) in
            if let selected = context?["selected"] as? Int,
               let playerList = context?["playerList"] as? [PlayerDetail],
               let selection = context?["selection"] as? [Bool] {
               
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
            if self.selectionMode == .single {
                self.dismiss([playerView.playerMO!])
            } else {
                self.addSelection(playerView.playerMO!)
            }
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
    
    class func show(from viewController: ScorecardViewController, appController: ScorecardAppController? = nil, existing selectionViewController: SelectionViewController? = nil, mode: SelectionMode, thisPlayer: String? = nil, thisPlayerFrame: CGRect? = nil, showThisPlayerName: Bool = false, formTitle: String = "Selection", smallFormTitle: String? = nil, backText: String = "Back", backImage: String = "", bannerColor: UIColor? = nil, fullScreen: Bool = false, completion: ((Bool, [PlayerMO]?)->())? = nil) -> SelectionViewController {
        var selectionViewController = selectionViewController
        
        if selectionViewController == nil {
            let storyboard = UIStoryboard(name: "SelectionViewController", bundle: nil)
            selectionViewController = storyboard.instantiateViewController(withIdentifier: "SelectionViewController") as? SelectionViewController
        }
        selectionViewController!.preferredContentSize = CGSize(width: 400, height: min(viewController.view.frame.height, 700))
        selectionViewController!.modalPresentationStyle = (ScorecardUI.phoneSize() ? .fullScreen : .automatic)
        
        selectionViewController!.selectionMode = mode
        selectionViewController!.thisPlayer = thisPlayer ?? ""
        selectionViewController!.thisPlayerFrame = thisPlayerFrame
        selectionViewController!.showThisPlayerName = showThisPlayerName
        selectionViewController!.formTitle = formTitle
        selectionViewController!.smallFormTitle = smallFormTitle
        selectionViewController!.bannerColor = bannerColor
        selectionViewController!.backText = backText
        selectionViewController!.backImage = backImage
        selectionViewController!.completion = completion
        selectionViewController?.controllerDelegate = appController

        // Let view controller know that this is a new 'instance' even though possibly re-using
        selectionViewController!.firstTime = true
        
        viewController.present(selectionViewController!, appController: appController, sourceView: viewController.popoverPresentationController?.sourceView ?? viewController.view, animated: true)
        
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

        self.bannerContinuationView.bannerColor = Palette.gameBanner
        self.bannerContinuationView.borderColor = Palette.gameBanner
        self.bannerPaddingView.bannerColor = Palette.gameBanner
        self.clearAllButton.setTitleColor(Palette.roomInteriorText, for: .normal)
        self.clearAllButton.fillColor = Palette.roomInterior
        self.clearAllButton.strokeColor = Palette.roomInteriorText
        self.continueButton.setTitleColor(Palette.continueButtonText, for: .normal)
        self.continueButton.fillColor = Palette.continueButton
        self.continueButton.strokeColor = Palette.continueButton
        self.continueButtonFooterPaddingView.backgroundColor = Palette.tableTop
        self.continueButtonFooterView.footerColor = Palette.tableTop
        self.continueButtonFooterView.borderColor = Palette.gameBannerText
        self.navigationBar.bannerColor = Palette.gameBanner
        self.view.backgroundColor = Palette.background
    }

}
