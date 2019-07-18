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

class SelectionViewController: CustomViewController, UICollectionViewDelegate, UICollectionViewDataSource,UICollectionViewDelegateFlowLayout, UIDropInteractionDelegate, UIGestureRecognizerDelegate {

    // MARK: - Class Properties ======================================================================== -

    // Main state properties
    private let scorecard = Scorecard.shared
    
    // Local class variables
    private var width: CGFloat = 0.0
    private var height: CGFloat = 0.0
    private var rowHeight: CGFloat = 0.0
    private let labelHeight: CGFloat = 30.0
    private let interRowSpacing:CGFloat = 10.0
    private let selectedViewSpacing:CGFloat = 10.0
    private let toolbarHeight: CGFloat = 44.0
    private var firstTime = true
    private var selectedAlpha: CGFloat = 0.5
    private var testMode = false
    private var tableLayers: [CAShapeLayer] = []
    private var tableRect: CGRect!

    // Main local state handlers
    private var availableList: [PlayerMO] = []
    private var unselectedList: [PlayerMO?] = []
    private var selectedList: [(slot: Int, playerMO: PlayerMO)] = []
    private var observer: NSObjectProtocol?
    private var selectedViews: [PlayerView]!
    private var animationView: PlayerView!
    
    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var unselectedCollectionView: UICollectionView!
    @IBOutlet private weak var selectionView: UIView!
    @IBOutlet private weak var continueButton: UIButton!
    @IBOutlet private weak var clearButton: UIButton!
    @IBOutlet private weak var selectedView: SelectedView!
    @IBOutlet private weak var selectedViewHeight: NSLayoutConstraint!
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

        // Add players to available and unselected list
        for playerMO in scorecard.playerList {
            availableList.append(playerMO)
            unselectedList.append(playerMO)
        }
        
        // Setup selected players
        self.setupSelectedPlayers()
        
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
        self.drawTable()
        self.positionSelectedPlayers()
        
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
                cell.playerView = PlayerView(type: .addPlayer, parent: cell, width: self.width, height: self.height, tag: -1, tapAction: self.addPlayerViewTapAction)
            }
            cell.playerView.set(name: "Add", initials: "", alpha: 1.0)
            cell.playerView.set(imageName: "big plus")
            
        } else {
            // Create player thumbnail
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Unselected Cell", for: indexPath) as! SelectionCell
            if cell.playerView == nil {
                cell.playerView = PlayerView(type: .unselected, parent: cell, width: self.width, height: self.height, tag: playerNumber-1, tapGestureDelegate: self, tapAction: self.unselectedViewTapAction)
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
                self.selectedViews[selected.slot].set(playerMO: playerMO)
            }
        }
    }
    
    // MARK: - Form Presentation / Handling Routines =================================================== -
    
    func drawTable() {

        var points: [PolygonPoint] = []
        
        func insertPoint(_ point: PolygonPoint, at index: Int? = nil) {
            if index == nil {
                points.append(point)
            } else {
                points.insert(point, at: index!)
            }
        }
        
        // Remove previous layers
        self.tableLayers.forEach( { $0.removeFromSuperlayer() })
        self.tableLayers = []
        
        // Setup table co-ordinates
        insertPoint(PolygonPoint(x: tableRect.midX, y: tableRect.maxY + 10.0, pointType: .quadRounded))
        insertPoint(PolygonPoint(x: tableRect.minX, y: tableRect.midY + 10.0, pointType: .quadRounded))
        insertPoint(PolygonPoint(x: tableRect.midX, y: tableRect.minY + 10.0, pointType: .quadRounded))
        insertPoint(PolygonPoint(x: tableRect.maxX, y: tableRect.midY + 10.0, pointType: .quadRounded))
        let tablePoints = points
        
        // Add table
        let tableLayer = Polygon.roundedShapeLayer(definedBy: tablePoints, strokeColor: Palette.background, fillColor: Palette.tableTop, lineWidth: 5.0, radius: 10.0)
        self.selectedView.layer.insertSublayer(tableLayer, at: 0)
        self.tableLayers.append(tableLayer)
        
        points = []
        insertPoint(PolygonPoint(origin: self.add(point: tablePoints[1], x: 2.0).cgPoint, pointType: .point))
        insertPoint(PolygonPoint(origin: self.add(point: tablePoints[1], x: 2.0, y: 20.0).cgPoint, pointType: .quadRounded))
        insertPoint(PolygonPoint(origin: self.add(point: tablePoints[0], y: 20.0).cgPoint, pointType: .quadRounded))
        insertPoint(PolygonPoint(origin: self.add(point: tablePoints[3], x: -2.0, y: 20.0).cgPoint, pointType: .quadRounded))
        insertPoint(PolygonPoint(origin: self.add(point: tablePoints[3], x: -2.0).cgPoint, pointType: .point))
        insertPoint(PolygonPoint(origin: tablePoints[0].cgPoint, pointType: .quadRounded))
        
        
        // Add table shadow
        let tableShadowLayer = Polygon.roundedShapeLayer(definedBy: points, strokeColor: nil, fillColor: Palette.background, lineWidth: 0.0, radius: 10.0)
        self.selectedView.layer.insertSublayer(tableShadowLayer, above: tableLayer)
        self.tableLayers.append(tableShadowLayer)
        
        // Add table legs
        self.addTableLeg(
            point1: self.projectPoint(point1: tablePoints[1].cgPoint, point2: tablePoints[0].cgPoint, newX: tablePoints[1].x + 10.0),
            point2: self.projectPoint(point1: tablePoints[1].cgPoint, point2: tablePoints[0].cgPoint, newX: tablePoints[1].x + 25.0),
            point3: self.projectPoint(point1: tablePoints[1].cgPoint, point2: tablePoints[0].cgPoint, newX: tablePoints[1].x + 40.0),
            below: tableLayer)
        
        self.addTableLeg(
            point1: self.projectPoint(point1: tablePoints[0].cgPoint, point2: tablePoints[1].cgPoint, newX: tablePoints[0].x - 15.0),
            point2: tablePoints[0],
            point3: self.projectPoint(point1: tablePoints[0].cgPoint, point2: tablePoints[3].cgPoint, newX: tablePoints[0].x + 15.0),
            below: tableLayer)
        
        self.addTableLeg(
            point1: self.projectPoint(point1: tablePoints[3].cgPoint, point2: tablePoints[0].cgPoint, newX: tablePoints[3].x - 40.0),
            point2: self.projectPoint(point1: tablePoints[3].cgPoint, point2: tablePoints[0].cgPoint, newX: tablePoints[3].x - 25.0),
            point3: self.projectPoint(point1: tablePoints[3].cgPoint, point2: tablePoints[0].cgPoint, newX: tablePoints[3].x - 10.0),
            below: tableLayer)
        
        // Setup room co-ordinates
        points = []
        let apex = CGPoint(x: tablePoints[2].x, y: tablePoints[2].y - self.height - 25.0)
        insertPoint(self.projectPoint(point1: apex, point2: CGPoint(x: tablePoints[1].x, y: tablePoints[1].y - self.height - 25.0), newX: -2.5, pointType: .point))
        insertPoint(PolygonPoint(origin: apex, radius: 40.0))
        insertPoint(self.projectPoint(point1: apex, point2: CGPoint(x: tablePoints[3].x, y: tablePoints[3].y - self.height - 25.0), newX: self.selectedView.frame.width + 2.5, pointType: .point))
        insertPoint(PolygonPoint(x: self.selectedView.frame.width + 2.5, y: self.selectedView.frame.height, pointType: .point))
        insertPoint(PolygonPoint(x: -2.5, y: self.selectedView.frame.height, pointType: .point))
        
        // Add room
        let roomLayer = Polygon.roundedShapeLayer(definedBy: points, strokeColor: UIColor.white, fillColor: Palette.hand, lineWidth: 5.0, radius: 20.0)
        self.selectedView.layer.insertSublayer(roomLayer, below: tableLayer)
        self.tableLayers.append(roomLayer)
        self.selectedView.path = roomLayer.path
    }
    

    
    func add(point: PolygonPoint, x: CGFloat = 0.0, y: CGFloat = 0.0) -> PolygonPoint {
        return PolygonPoint(origin: CGPoint(x: point.x + x, y: point.y + y), pointType: point.pointType, radius: point.radius)
    }
    
    func projectPoint(point1: CGPoint, point2: CGPoint, newX: CGFloat, pointType: PolygonPointType? = nil, radius: CGFloat? = nil) -> PolygonPoint {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        let newY = point1.y - ((point1.x - newX) / dx) * dy
        return PolygonPoint(x: newX, y: newY, pointType: pointType, radius: radius)
    }
    
    func addTableLeg(point1: PolygonPoint, point2: PolygonPoint, point3: PolygonPoint, below layer: CALayer) {
        var points: [PolygonPoint]
        
        points = []
        points.append(PolygonPoint(origin: point1.cgPoint, pointType: .point))
        points.append(PolygonPoint(origin: point2.cgPoint, pointType: .point))
        points.append(PolygonPoint(x: point2.x, y: selectedView.frame.maxY, pointType: .point))
        points.append(PolygonPoint(x: point1.x, y: selectedView.frame.maxY, pointType: .point))
        let leg = Polygon.roundedShapeLayer(definedBy: points, strokeColor: nil, fillColor: Palette.shapeTableLeg, lineWidth: 0.0)
        self.selectedView.layer.insertSublayer(leg, above: layer)
        self.tableLayers.append(leg)
        
        points = []
        points.append(PolygonPoint(origin: point2.cgPoint, pointType: .point))
        points.append(PolygonPoint(origin: point3.cgPoint, pointType: .point))
        points.append(PolygonPoint(x: point3.x, y: selectedView.frame.maxY, pointType: .point))
        points.append(PolygonPoint(x: point2.x, y: selectedView.frame.maxY, pointType: .point))
        let shadow = Polygon.roundedShapeLayer(definedBy: points, strokeColor: nil, fillColor: Palette.shapeTableLegShadow, lineWidth: 0.0)
        self.selectedView.layer.insertSublayer(shadow, above: layer)
        self.tableLayers.append(shadow)
    }
    
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
        
        let selectedHeight: CGFloat = totalHeight - unselectedHeight - toolbarHeight - self.navigationBar.frame.height
        selectedViewHeight?.constant = selectedHeight + (toolbarHeight * 2.0) + self.view.safeAreaInsets.bottom
        
        self.tableRect = CGRect(x: 20.0, y: self.height + 20.0, width: self.selectedView.frame.width - 40.0, height: selectedHeight - self.height - 30.0)
    
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
    
    private func setupSelectedPlayers() {
        
        // Add buttons to view
        self.selectedViews = []
        
        for index in 0..<self.scorecard.numberPlayers {
        
            let selectedPlayerView = PlayerView(type: .selected, parent: self.selectedView, width: self.width, height: self.height, tag: index, dropAction: self.selectedViewDropAction, tapAction: self.selectedViewTapAction)
            selectedPlayerView.set(textColor: Palette.darkHighlightText)
            selectedPlayerView.clear(placeHolder: index)
            self.selectedViews.append(selectedPlayerView)
        }
        
    }
    
    private func positionSelectedPlayers() {
        
        enum Position {
            case low
            case middle
            case high
        }
        
        func positionSelectedView(horizontal: Position, vertical: Position) -> CGPoint {
            var y: CGFloat
            var x: CGFloat
            
            switch horizontal {
            case .low:
                x = tableRect.minX
            case .middle:
                x = tableRect.midX - (self.width / 2.0)
            case .high:
                x = tableRect.maxX - self.width
            }
            
            switch vertical {
            case .low:
                y = tableRect.minY - self.height - 5.0 + (((self.width / 2.0)) * tableRect.height / tableRect.width)
            case .middle:
                y = tableRect.midY - self.height - 5.0
            case .high:
                y = tableRect.maxY - self.height - CGFloat(5.0)
            }
            
            return CGPoint(x: x, y: y)
            
        }
        
        let viewSize = CGSize(width: self.width, height: self.height)
            selectedViews[0].frame = CGRect(origin: positionSelectedView(horizontal: .middle, vertical: .high), size: viewSize)
            selectedViews[1].frame = CGRect(origin: positionSelectedView(horizontal: .low, vertical: .middle), size: viewSize)
            selectedViews[2].frame = CGRect(origin: positionSelectedView(horizontal: .middle, vertical: .low), size: viewSize)
            selectedViews[3].frame = CGRect(origin: positionSelectedView(horizontal: .high, vertical: .middle), size: viewSize)
    }
    
    private func selectedViewDropAction(dropView: PlayerView? = nil, dropLocation: CGPoint? = nil, source: PlayerViewType, addedPlayerEmail: String) {
        
        if let addedPlayerMO = self.availableList.first(where: { $0.email == addedPlayerEmail }) {
            
            if source == .selected {
                // Moving an already selected player - rotate all players in between
                if let currentSlot = self.playerSelectedSlot(addedPlayerMO) {
                    // Got the players current slot - work out the drop slot
                    if let dropSlot = self.slotFromLocation(dropSlot: dropView?.tag, dropLocation: dropLocation, currentSlot: currentSlot, spacing: .between) {
                        
                        // Ignore if dropping on itself
                        if currentSlot != dropSlot {
                            // Work out where everything will be after rotation - stopping if we land on a blank
                            var holdingArea: [Int:PlayerMO?] = [:]
                            let rotateSlots =  clockwiseGap(from: dropSlot, to: currentSlot) + 1
                            var toSlot = dropSlot
                            for slot in 1...rotateSlots {
                                let fromSlot = (slot == 1 ? currentSlot : addSlots(to: toSlot, add: -1))

                                if self.selectedViews[fromSlot].inUse {
                                    holdingArea[toSlot] = self.selectedViews[fromSlot].playerMO
                                }

                                if !self.selectedViews[toSlot].inUse {
                                    // Found a blank slot - can stop rotation and blank out current view
                                    self.selectedViews[currentSlot].clear(placeHolder: slot)
                                    break
                                }

                                toSlot = addSlots(to: toSlot, add: 1)
                            }
                            // Now carry out actual moves
                            for index in 0..<rotateSlots {
                                toSlot = addSlots(to: dropSlot, add: index)
                                
                                if let playerMO = holdingArea[toSlot] {
                                    
                                    // Set selected view
                                    self.selectedViews[toSlot].set(playerMO: playerMO!)
                                    
                                    // Update related list element
                                    if let listIndex = self.selectedList.firstIndex(where: { $0.playerMO == playerMO }) {
                                        self.selectedList[listIndex].slot = toSlot
                                    }
                                }
                            }
                        }
                    }
                }
                
            } else if source == .unselected {
                // Move new player to selected
                if let dropSlot = self.slotFromLocation(dropSlot: dropView?.tag, dropLocation: dropLocation, spacing: .nearest) {
                    
                    if self.selectedViews[dropSlot].inUse {
                        self.removeSelection(dropSlot, updateUnselected: true, animate: false)
                    }
                    
                    self.addSelection(addedPlayerMO, toSlot: dropSlot, updateUnselected: true, animate: false)
                }
            }
        }
    }
    
    private func clockwiseGap(from: Int, to: Int) -> Int {
        return ((self.selectedViews.count + to - from) % self.selectedViews.count)
    }
    
    private func addSlots(to: Int, add: Int = 1) -> Int {
        return (to + self.selectedViews.count + add) % self.selectedViews.count
    }
    
    private enum Spacing {
        case between
        case nearest
    }
    
    private func slotFromLocation(dropSlot: Int?, dropLocation: CGPoint?, currentSlot: Int? = nil, spacing: Spacing) -> Int? {
        var slot: Int?
        if dropSlot != nil {
            slot = dropSlot!
        } else if dropLocation != nil {
            var distance: [(slot: Int, distance: CGFloat, gap: Int)] = []
            for slot in 0..<self.selectedViews.count {
                let gap = clockwiseGap(from: currentSlot ?? 0, to: slot)
                distance.append((slot, self.selectedViews[slot].frame.center.distance(to: dropLocation!), gap))
            }
            distance.sort(by: {$0.distance < $1.distance})
            
            if spacing == .nearest {
                slot = distance[0].slot
            } else {
                // Ignore if current slot is one of 2 nearest to drop
                if distance[0].slot != currentSlot && distance[1].slot != currentSlot {
                    // Use the one of the 2 furthrest which is closest clockwise
                    slot = distance[(distance[0].gap > distance[1].gap ? 0 : 1)].slot
                }
            }
            
         }
        
        return slot
    }
    
    private func selectedViewTapAction(_ selectedView: PlayerView) {
        self.removeSelection(selectedView.tag)
    }
    
    private func unselectedViewTapAction(_ selectedView: PlayerView) {
        self.addSelection(selectedView.playerMO!)
    }
    
    private func addPlayerViewTapAction(_ selectedView: PlayerView) {
        self.addNewPlayer()
    }
    
    func playerSelectedSlot(_ checkPlayer: PlayerMO) -> Int? {
        var result:Int?
        
        if let selected = selectedList.first(where: { $0.playerMO == checkPlayer}) {
            result = selected.slot
        }
        
        return result
    }
    
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
        
        // Setup source
        let selectedPlayerView = self.selectedViews[selectedSlot]
        
        if  selectedPlayerView.inUse {
            
            if let selectedIndex = selectedList.firstIndex(where: { $0.slot == selectedSlot }) {
                let (_, selectedPlayerMO) = self.selectedList[selectedIndex]
                
                selectedList.remove(at: selectedIndex)
                self.formatButtons(animate)
                
                if !animate || !updateUnselected {
                    // Just set the view and remove from current view
                    selectedPlayerView.clear(placeHolder: selectedSlot)
                    if updateUnselected {
                        _ = self.addUnselected(selectedPlayerMO)
                    }
                    
                } else {
                    // Animation
                    
                    // Draw a new thumbnail over top of existing
                    let selectedPoint = selectedPlayerView.thumbnail.convert(CGPoint(x: 0, y: 0), to: self.selectionView)
                    self.animationView.frame = CGRect(origin: selectedPoint, size: CGSize(width: self.width, height: self.height))
                    self.animationView.set(playerMO: selectedPlayerMO)
                    self.animationView.set(textColor: Palette.darkHighlightText)
                    self.animationView.alpha = 1.0
                    
                    // Add new cell to unselected view
                    let unselectedPlayerIndex = addUnselected(selectedPlayerMO, leaveNil: true)
                    
                    // Clear selected cell
                    self.selectedViews[selectedSlot].clear(placeHolder: selectedSlot)
                    
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
        
        if let slot = toSlot ?? self.selectedViews.firstIndex(where: { $0.inUse == false }) {
            
            selectedList.append((slot, selectedPlayerMO))
        
            // Setup destination
            let selectedPlayerView = self.selectedViews[slot]
            
            self.formatButtons(animate)
            
            if !animate || !updateUnselected || !updateUnselectedCollection {
                // Just set the view and remove from current view
                selectedPlayerView.set(playerMO: selectedPlayerMO)
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
                            let selectedPoint = selectedPlayerView.thumbnail.convert(CGPoint(x: 0, y: 0), to: self.selectionView)
                            self.animationView.frame = CGRect(origin: selectedPoint, size: CGSize(width: self.width, height: self.height))
                            self.animationView.set(textColor: Palette.darkHighlightText)
                            selectedPlayerView.clear()
                        }
                        animation.addCompletion( {_ in
                            
                            // Show player (under animation)
                            selectedPlayerView.set(playerMO: selectedPlayerMO)
                            
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
        for selectedPlayerView in self.selectedViews {
            selectedPlayerView.isEnabled(enabled)
        }
        self.clearButton.isUserInteractionEnabled = enabled
    }
    
    private func setupAnimationView() {
        self.animationView = PlayerView(type: .animation, parent: self.view, width: self.width, height: self.height, tag: -1)
    }
    
    private func setupDragAndDrop() {
        let unselectedDropInteraction = UIDropInteraction(delegate: self)
        self.unselectedCollectionView.addInteraction(unselectedDropInteraction)
        let selectedDropInteraction = UIDropInteraction(delegate: self)
        self.selectedView.addInteraction(selectedDropInteraction)
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
    
    // MARK: - Tap gesture delegate handlers =========================================================== -
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view == self.selectedView {
            return false
        } else {
            return true
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
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
                                if self.selectedView.frame.contains(session.location(in: self.view)) {
                                    // Dropped on selected view]
                                    let location = session.location(in: self.selectedView)
                                    self.selectedViewDropAction(dropLocation: location, source: source, addedPlayerEmail: playerEmail)
                                } else if self.unselectedCollectionView.frame.contains(session.location(in: self.view)) {
                                    // Dropped on unselected view
                                    if let index = self.selectedViews.firstIndex(where: { $0.playerMO?.email == playerEmail }) {
                                        self.removeSelection(index)
                                    }
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

public enum PlayerViewType: String {
    case selected = "selected"
    case unselected = "unselected"
    case addPlayer = "addPlayer"
    case animation = "animation"
    case unknown = ""
}

public class PlayerView : NSObject, UIDropInteractionDelegate, UIDragInteractionDelegate {
    
    public var parent: UIView
    public var tag: Int
    public var type: PlayerViewType
    public var thumbnail: ThumbnailView
    public var inUse = false
    public var playerMO: PlayerMO?
    public var tapAction: ((PlayerView)->())?
    public var dropAction: ((PlayerView?, CGPoint?, PlayerViewType, String)->())?
    
    init(type: PlayerViewType, parent: UIView, width: CGFloat, height: CGFloat, tag: Int = 0, tapGestureDelegate: UIGestureRecognizerDelegate? = nil, dropAction: ((PlayerView?, CGPoint?, PlayerViewType, String)->())? = nil, tapAction: ((PlayerView)->())? = nil) {

        // Save properties
        self.parent = parent
        self.type = type
        self.tag = tag
        self.tapAction = tapAction
        self.dropAction = dropAction
        
        // Setup thumbnail
        self.thumbnail = ThumbnailView(frame: CGRect(x: 5.0, y: 5.0, width: width, height: height))
        self.thumbnail.tag = tag
        
        super.init()
        
        parent.addSubview(self.thumbnail)
        parent.bringSubviewToFront(self.thumbnail)
        
        // Setup tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(PlayerView.tapSelector(_:)))
        tapGesture.delegate = tapGestureDelegate
        self.thumbnail.addGestureRecognizer(tapGesture)
        
        // Setup drag and drop
        if self.type == .unselected || self.type == .selected {
            let dragInteraction = UIDragInteraction(delegate: self)
            dragInteraction.isEnabled = true
            self.thumbnail.addInteraction(dragInteraction)
            self.thumbnail.isUserInteractionEnabled = true
        }
    }
    
    public var alpha: CGFloat {
        get {
            return self.thumbnail.alpha
        }
        set (newValue) {
            self.thumbnail.alpha = newValue
        }
    }
    
    public var frame: CGRect {
        get {
            return self.thumbnail.frame
        }
        set (newValue) {
            self.thumbnail.set(frame: newValue)
        }
    }
    
    public func set(data: Data? = nil, name: String? = nil, initials: String? = nil, nameHeight: CGFloat? = nil, alpha: CGFloat? = nil) {
        self.inUse = true
        self.playerMO = nil
        self.thumbnail.set(data: data, name: name, initials: initials, nameHeight: nameHeight ?? 30.0, alpha: alpha)
    }

    public func set(playerMO: PlayerMO) {
        self.set(data: playerMO.thumbnail, name: playerMO.name)
        self.playerMO = playerMO
    }

    
    public func clear(placeHolder: Int? = nil) {
        var initials = ""
        switch placeHolder ?? -1 {
        case 0:
            initials = "=You"
        case 1:
            initials = "=2nd"
        case 2:
            initials = "=3rd"
        case 3:
            initials = "=(4th)"
        default:
            break
        }
        
        self.inUse = false
        self.thumbnail.set(initials: initials, nameHeight: 30.0)
    }
    
    public func set(textColor: UIColor) {
        self.thumbnail.set(textColor: textColor)
    }
    
    public func set(imageName: String?) {
        self.thumbnail.set(imageName: imageName)
    }
    
    public func isEnabled(_ enabled: Bool) {
        self.thumbnail.isUserInteractionEnabled = enabled
    }
    
    @objc private func tapSelector(_ sender: Any?) {
        if self.inUse {
            self.tapAction?(self)
        }
    }
    
    // MARK: - Drop delegate handlers ================================================================== -
    
    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        return UIDropProposal(operation: .move)
    }
    
    public func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: PlayerObject.self)
    }
    
    public func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        
        for item in session.items {
            item.itemProvider.loadObject(ofClass: PlayerObject.self, completionHandler: { (playerObject, error) in
                
                if error == nil {
                    Utility.mainThread {
                        if let playerObject = playerObject as! PlayerObject? {
                            if let playerEmail = playerObject.playerEmail, let source = playerObject.source {
                                self.dropAction?(self, nil, source, playerEmail)
                            }
                        }
                    }
                }
            })
        }
    }
    
    // MARK: - Drag delegate handlers ==================================================================== -
    
    public func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
        if let playerEmail = self.playerMO?.email {
            return [ UIDragItem(itemProvider: NSItemProvider(object: PlayerObject(source: self.type, playerEmail: playerEmail)))]
        } else {
            return []
        }
    }
    
    public func dragInteraction(_ interaction: UIDragInteraction, previewForLifting item: UIDragItem, session: UIDragSession) -> UITargetedDragPreview? {
       // Create a new view to display the image as a drag preview.
        let previewView = ThumbnailView(frame: CGRect(origin: CGPoint(), size: self.frame.size))
        previewView.set(data: self.playerMO?.thumbnail, name: self.playerMO?.name)
        previewView.set(textColor: Palette.darkHighlightText)
        let center = CGPoint(x: self.frame.width / 2.0, y: self.frame.height / 2.0)
        let target = UIDragPreviewTarget(container: self.thumbnail, center: center)
        let previewParameters = UIDragPreviewParameters()
        previewParameters.backgroundColor = UIColor.clear
        return UITargetedDragPreview(view: previewView, parameters: previewParameters, target: target)
    }
    
}

// MARK: - Object for dragging and dropping a player ======================================================= -

@objc final public class PlayerObject: NSObject, NSItemProviderReading, NSItemProviderWriting {
    
    public var playerEmail: String?
    public var source: PlayerViewType?
    
    public static var readableTypeIdentifiersForItemProvider: [String] = ["shearer.com/whist/playerObject"]
    
    public static var writableTypeIdentifiersForItemProvider: [String] = ["shearer.com/whist/playerObject"]
    
    public func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
        
        let progress = Progress(totalUnitCount: 1)
        
        do {
            let data = try JSONSerialization.data(withJSONObject: ["playerEmail" : self.playerEmail,
                                                                   "source"      : self.source?.rawValue ?? ""],
                                                  options: .prettyPrinted)
            progress.completedUnitCount = 1
            completionHandler(data, nil)
        } catch {
            completionHandler(nil, error)
        }
        
        return progress
    }
    
    
    public static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> PlayerObject {
        let propertyList: [String : String] = try JSONSerialization.jsonObject(with: data, options: []) as! [String : String]
        return PlayerObject(source: PlayerViewType(rawValue: propertyList["source"]!) ?? .unknown, playerEmail: propertyList["playerEmail"]!)
    }
    
    init(source: PlayerViewType, playerEmail: String?) {
        super.init()
        self.source = source
        self.playerEmail = playerEmail
    }
}

class SelectedView : UIView {
    
    public var path: CGPath?
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // Pass on events that are not in the path
        if path == nil || path!.contains(point) {
            return true
        } else {
            return false
        }
    }
    
}
