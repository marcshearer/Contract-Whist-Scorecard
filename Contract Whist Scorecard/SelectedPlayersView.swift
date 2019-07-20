//
//  SelectedPlayersView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 18/07/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit

// MARK: - Selected Players View Protocol ============================================================================== -

@objc protocol SelectedPlayersViewDelegate {
    
    @objc optional func selectedPlayersView(wasTappedOn slot: Int)
    
    @objc optional func selectedPlayersView(wasDroppedOn slot: Int, from source: PlayerViewType, playerMO: PlayerMO)
    
    @objc optional func selectedPlayersView(moved playerMO: PlayerMO, to slot: Int)
}

// MARK: - Selected Players View Class ================================================================================= -

class SelectedPlayersView: UIView, PlayerViewDelegate, UIDropInteractionDelegate {

    // Public properties
    public var playerViews: [PlayerView]!
    public var delegate: SelectedPlayersViewDelegate?
    
    // Internal properties
    private var scorecard = Scorecard.shared
    private var roomPath: CGPath?
    private var tableLayers: [CAShapeLayer] = []
    private var tablePoints: [PolygonPoint]!
    private var tableRect: CGRect!
    private var width: CGFloat! = 50.0
    private var height: CGFloat! = 75.0
    private var legHeight: CGFloat! = 100.0
    private let lineWidth: CGFloat = 5.0

    // MARK: - IB Outlets ============================================================================== -
    
    @IBOutlet private weak var contentView: UIView!
    
    // MARK: - Calculated properties ====================================================================== -
    
    public var isEnabled: Bool {
        get {
            return self.playerViews.first!.isEnabled
        }
        set(newValue) {
            for view in self.playerViews {
                view.isEnabled = newValue
            }
        }
    }
    
    public override var bounds: CGRect {
        didSet {
            contentView.frame = self.bounds
        }
    }
    
    // MARK: - Constructors ============================================================================== -
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.loadSelectedPlayersView()
        self.frame = frame
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.loadSelectedPlayersView()
    }
    
    // MARK: - Public methods ============================================================================== -
    
    public func set(slot: Int, playerMO: PlayerMO) {
        self.playerViews[slot].set(playerMO: playerMO)
    }
    
    public func clear(slot: Int) {
        self.clear(playerView: self.playerViews[slot], slot: slot)
    }
    
    public func inUse(slot: Int) -> Bool {
        return self.playerViews[slot].inUse
    }
    
    public func origin(slot: Int, in view: UIView) -> CGPoint {
        return self.playerViews[slot].thumbnail.convert(CGPoint(x: 0, y: 0), to: view)
    }
    
    public func freeSlot() -> Int? {
        return self.playerViews.firstIndex(where: { $0.inUse == false })
    }
    
    public func setEnabled(slot: Int, enabled: Bool) {
        self.playerViews[slot].isEnabled = enabled
    }
    
    public func drawRoom(thumbnailWidth: CGFloat, thumbnailHeight: CGFloat, legHeight: CGFloat) {
        
        // Save leg height and thumbnail sizes
        self.legHeight = legHeight
        self.setThumbnailSize(width: thumbnailWidth, height: thumbnailHeight)
        
        // Draw room components
        self.drawRoomComponents()
    }
    
    // MARK: - Load view and setup objects ============================================================================== -
    
    private func loadSelectedPlayersView() {
        Bundle.main.loadNibNamed("SelectedPlayersView", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        self.setupSelectedPlayers()
        
        // Setup view as drop zone
        let selectedDropInteraction = UIDropInteraction(delegate: self)
        self.addInteraction(selectedDropInteraction)
    }
    
    private func setupSelectedPlayers(dropAction: ((PlayerView?, CGPoint?, PlayerViewType, String)->())? = nil, tapAction: ((PlayerView)->())? = nil) {
        
        // Add buttons to view
        self.playerViews = []
        
        for index in 0..<self.scorecard.numberPlayers {
            
            let playerView = PlayerView(type: .selected, parent: self.contentView, width: self.width, height: self.height, tag: index)
            playerView.delegate = self
            playerView.set(textColor: Palette.darkHighlightText)
            self.clear(playerView: playerView, slot: index)
            self.playerViews.append(playerView)
        }
    }
    
    private func clear(playerView: PlayerView, slot: Int) {
        var initials = ""
        switch slot {
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
        playerView.clear(initials: initials)
    }
    
    // MARK: - Main methods to draw room components ======================================================================= -

   
    private func drawRoomComponents() {
        
        // Remove previous layers
        self.tableLayers.forEach( { $0.removeFromSuperlayer() })
        self.tableLayers = []
        
        // Setup position of table
        self.setupTablePoints()
        
        // Draw elements
        let tableLayer = self.drawTabletop()
        self.drawTableShadow(above: tableLayer)
        self.drawTableLegs(below: tableLayer)
        self.drawRoomBackground(below: tableLayer)
        
        // Position player views
        self.positionSelectedPlayers()
    }
    
    private func setupTablePoints() {
        
        // Calculate table rectangle
        self.tableRect = CGRect(x: 20.0, y: self.height + 20.0, width: self.frame.width - 40.0, height: self.frame.height - self.height - 30.0 - self.legHeight)
        
        // Setup table co-ordinates
        self.tablePoints = []
        self.tablePoints.append(PolygonPoint(x: tableRect.midX, y: tableRect.maxY + 10.0, pointType: .quadRounded))
        self.tablePoints.append(PolygonPoint(x: tableRect.minX, y: tableRect.midY + 10.0, pointType: .quadRounded))
        self.tablePoints.append(PolygonPoint(x: tableRect.midX, y: tableRect.minY + 10.0, pointType: .quadRounded))
        self.tablePoints.append(PolygonPoint(x: tableRect.maxX, y: tableRect.midY + 10.0, pointType: .quadRounded))
    }
    
    private func drawTabletop() -> CAShapeLayer{
        
        // Add table top
        let tableLayer = Polygon.roundedShapeLayer(definedBy: tablePoints, strokeColor: Palette.background, fillColor: Palette.tableTop, lineWidth: lineWidth, radius: 10.0)
        self.contentView.layer.insertSublayer(tableLayer, at: 0)
        self.tableLayers.append(tableLayer)
        
        return tableLayer
    }
    
    private func drawTableShadow(above tableLayer: CAShapeLayer) {
        
        // Draw table shadow
        var points: [PolygonPoint] = []
        points.append(PolygonPoint(origin: self.add(point: self.tablePoints[1], x: 2.0).cgPoint, pointType: .point))
        points.append(PolygonPoint(origin: self.add(point: self.tablePoints[1], x: 2.0, y: 20.0).cgPoint, pointType: .quadRounded))
        points.append(PolygonPoint(origin: self.add(point: self.tablePoints[0], y: 20.0).cgPoint, pointType: .quadRounded))
        points.append(PolygonPoint(origin: self.add(point: self.tablePoints[3], x: -2.0, y: 20.0).cgPoint, pointType: .quadRounded))
        points.append(PolygonPoint(origin: self.add(point: self.tablePoints[3], x: -2.0).cgPoint, pointType: .point))
        points.append(PolygonPoint(origin: self.tablePoints[0].cgPoint, pointType: .quadRounded))
        
        // Add table shadow
        let tableShadowLayer = Polygon.roundedShapeLayer(definedBy: points, strokeColor: nil, fillColor: Palette.background, lineWidth: 0.0, radius: 10.0)
        self.contentView.layer.insertSublayer(tableShadowLayer, above: tableLayer)
        self.tableLayers.append(tableShadowLayer)
    }
    
    private func drawTableLegs(below tableLayer: CAShapeLayer) {
        // Add table legs
        self.addTableLeg(
            point1: self.projectPoint(point1: self.tablePoints[1].cgPoint,
                                      point2: self.tablePoints[0].cgPoint,
                                      newX: self.tablePoints[1].x + 10.0),
            point2: self.projectPoint(point1: self.tablePoints[1].cgPoint,
                                      point2: self.tablePoints[0].cgPoint,
                                      newX: self.tablePoints[1].x + 25.0),
            point3: self.projectPoint(point1: self.tablePoints[1].cgPoint,
                                      point2: self.tablePoints[0].cgPoint,
                                      newX: self.tablePoints[1].x + 40.0),
            above: tableLayer)
        
        self.addTableLeg(
            point1: self.projectPoint(point1: self.tablePoints[0].cgPoint,
                                      point2: self.tablePoints[1].cgPoint,
                                      newX: self.tablePoints[0].x - 15.0),
            point2: self.tablePoints[0],
            point3: self.projectPoint(point1: self.tablePoints[0].cgPoint,
                                      point2: self.tablePoints[3].cgPoint,
                                      newX: self.tablePoints[0].x + 15.0),
            above: tableLayer)
        
        self.addTableLeg(
            point1: self.projectPoint(point1: self.tablePoints[3].cgPoint,
                                      point2: self.tablePoints[0].cgPoint,
                                      newX: self.tablePoints[3].x - 40.0),
            point2: self.projectPoint(point1: self.tablePoints[3].cgPoint,
                                      point2: self.tablePoints[0].cgPoint,
                                      newX: self.tablePoints[3].x - 25.0),
            point3: self.projectPoint(point1: self.tablePoints[3].cgPoint,
                                      point2: self.tablePoints[0].cgPoint,
                                      newX: self.tablePoints[3].x - 10.0),
            above: tableLayer)
    }
    
    func addTableLeg(point1: PolygonPoint, point2: PolygonPoint, point3: PolygonPoint, above layer: CALayer) {
        
        // Draw left hand side
        var points: [PolygonPoint] = []
        points.append(PolygonPoint(origin: point1.cgPoint, pointType: .point))
        points.append(PolygonPoint(origin: point2.cgPoint, pointType: .point))
        points.append(PolygonPoint(x: point2.x, y: contentView.frame.maxY, pointType: .point))
        points.append(PolygonPoint(x: point1.x, y: contentView.frame.maxY, pointType: .point))
        let leg = Polygon.roundedShapeLayer(definedBy: points, strokeColor: nil, fillColor: Palette.shapeTableLeg, lineWidth: 0.0)
        self.contentView.layer.insertSublayer(leg, above: layer)
        self.tableLayers.append(leg)
        
        // Draw right hand shadow
        points = []
        points.append(PolygonPoint(origin: point2.cgPoint, pointType: .point))
        points.append(PolygonPoint(origin: point3.cgPoint, pointType: .point))
        points.append(PolygonPoint(x: point3.x, y: contentView.frame.maxY, pointType: .point))
        points.append(PolygonPoint(x: point2.x, y: contentView.frame.maxY, pointType: .point))
        let shadow = Polygon.roundedShapeLayer(definedBy: points, strokeColor: nil, fillColor: Palette.shapeTableLegShadow, lineWidth: 0.0)
        self.contentView.layer.insertSublayer(shadow, above: layer)
        self.tableLayers.append(shadow)
    }
    
    private func drawRoomBackground(below tableLayer: CAShapeLayer) {
        
        // Setup room co-ordinates - draw slightly outside view to avoid stroke in some areas
        var points: [PolygonPoint] = []
        let apex = CGPoint(x: self.tablePoints[2].x, y: self.tablePoints[2].y - self.height - 25.0)
        points.append(self.projectPoint(point1: apex,
                                        point2: CGPoint(x: self.tablePoints[1].x, y: self.tablePoints[1].y - self.height - 25.0),
                                        newX: -(lineWidth / 2.0), pointType: .point))
        points.append(PolygonPoint(origin: apex, radius: 40.0))
        points.append(self.projectPoint(point1: apex,
                                        point2: CGPoint(x: self.tablePoints[3].x, y: self.tablePoints[3].y - self.height - 25.0),
                                        newX: self.contentView.frame.width + (lineWidth / 2.0), pointType: .point))
        points.append(PolygonPoint(x: self.contentView.frame.width + (lineWidth / 2.0), y: self.contentView.frame.height + (lineWidth / 2.0), pointType: .point))
        points.append(PolygonPoint(x: -(lineWidth / 2.0), y: self.contentView.frame.height + (lineWidth / 2.0), pointType: .point))
        
        // Add room
        let roomLayer = Polygon.roundedShapeLayer(definedBy: points, strokeColor: UIColor.white, fillColor: Palette.hand, lineWidth: 5.0, radius: 20.0)
        self.contentView.layer.insertSublayer(roomLayer, below: tableLayer)
        self.tableLayers.append(roomLayer)
        self.roomPath = roomLayer.path
    }
    
    private func setThumbnailSize(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
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
                x = self.tableRect.minX
            case .middle:
                x = self.tableRect.midX - (self.width / 2.0)
            case .high:
                x = self.tableRect.maxX - self.width
            }
            
            switch vertical {
            case .low:
                let halfPlayerAdjustment = (((self.width / 2.0)) * (tableRect.height / tableRect.width))
                y = self.tableRect.minY - self.height - 5.0 + halfPlayerAdjustment
            case .middle:
                y = self.tableRect.midY - self.height - 5.0
            case .high:
                y = self.tableRect.maxY - self.height - CGFloat(5.0)
            }
            
            return CGPoint(x: x, y: y)
            
        }
        
        let viewSize = CGSize(width: self.width, height: self.height)
        playerViews[0].frame = CGRect(origin: positionSelectedView(horizontal: .middle, vertical: .high), size: viewSize)
        playerViews[1].frame = CGRect(origin: positionSelectedView(horizontal: .low, vertical: .middle), size: viewSize)
        playerViews[2].frame = CGRect(origin: positionSelectedView(horizontal: .middle, vertical: .low), size: viewSize)
        playerViews[3].frame = CGRect(origin: positionSelectedView(horizontal: .high, vertical: .middle), size: viewSize)
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
    
    // MARK: - Player View delegate handlers ======================================================================= -
    
    internal func playerViewWasDroppedOn(_ playerView: PlayerView, from source: PlayerViewType, withEmail: String) {
        
        // Nothing to do here - pass on to delegate
        if let playerMO = self.scorecard.playerList.first(where: { $0.email == withEmail }) {
            self.delegate?.selectedPlayersView?(wasDroppedOn: playerView.tag, from: source, playerMO: playerMO)
        }
        
    }
    
    internal func playerViewWasTapped(_ playerView: PlayerView) {
        // Can't handle here - pass back
        
        self.delegate?.selectedPlayersView?(wasTappedOn: playerView.tag)
        
    }
    
    // MARK: - Main drag/drop handling method ====================================================================== -
    
    internal func selectedViewDropAction(dropLocation: CGPoint, source: PlayerViewType, withEmail: String) {
        
        if let addedPlayerMO = scorecard.playerList.first(where: { $0.email == withEmail }) {
            // Found the player from their email
            
            if source == .selected {
                // Moving a player in selected view - rotate all players in between
                
                if let currentSlot = self.playerViewSlot(addedPlayerMO) {
                    // Got the players current slot - work out the drop slot
                    
                    if let dropSlot = self.slotFromLocation(dropLocation: dropLocation, currentSlot: currentSlot) {
                        
                        // Ignore if dropping on itself
                        if currentSlot != dropSlot {
                            // Work out where everything will be after rotation - stopping if we land on a blank
                            var holdingArea: [Int:PlayerMO?] = [:]
                            if dropSlot == 0 || currentSlot == 0  {
                                // Dropping on or from the 'You' player - just swap
                                holdingArea[dropSlot] = addedPlayerMO
                                if self.playerViews[dropSlot].inUse {
                                    holdingArea[currentSlot] = self.playerViews[dropSlot].playerMO
                                } else {
                                    self.clear(slot: currentSlot)
                                }
                            } else {
                                let rotateSlots =  self.clockwiseGap(from: dropSlot, to: currentSlot) + 1
                                var toSlot = dropSlot
                                for slot in 1...rotateSlots {
                                    let fromSlot = (slot == 1 ? currentSlot : addSlots(to: toSlot, add: -1))
                                    
                                    if self.playerViews[fromSlot].inUse {
                                        holdingArea[toSlot] = self.playerViews[fromSlot].playerMO
                                    }
                                    
                                    if !self.playerViews[toSlot].inUse {
                                        // Found a blank slot - can stop rotation and blank out current view
                                        self.clear(slot: currentSlot)
                                        break
                                    }
                                    
                                    toSlot = addSlots(to: toSlot, add: 1)
                                }
                            }
                            // Now carry out actual moves
                            for (toSlot, playerMO) in holdingArea {
                                
                                // Set selected view
                                self.playerViews[toSlot].set(playerMO: playerMO!)
                                
                                // Call back calling view to see if they want to do anything
                                self.delegate?.selectedPlayersView?(moved: playerMO!, to: toSlot)
                            }
                            
                        }
                        
                    }
                }
            } else {
                // Can't handle here - pass back for delegate to handle
                if let slot = self.slotFromLocation(dropLocation: dropLocation, currentSlot: nil) {
                    self.delegate?.selectedPlayersView?(wasDroppedOn: slot, from: source, playerMO: addedPlayerMO)
                }
            }
        }
    }
    
    

    private func playerViewSlot(_ checkPlayer: PlayerMO) -> Int? {
        var result:Int?
        
        if let index = self.playerViews.firstIndex(where: { $0.playerMO == checkPlayer}) {
            result = index
        }
        
        return result
    }
    
    private func slotFromLocation(dropLocation: CGPoint, currentSlot: Int?) -> Int? {
        var slot: Int?
        
        var distance: [(slot: Int, distance: CGFloat)] = []
        
        // Build list of distances to players
        for slot in 0..<self.playerViews.count {
            if self.playerViews[slot].isEnabled {
                distance.append((slot, self.playerViews[slot].frame.center.distance(to: dropLocation)))
            }
        }
        distance.sort(by: {$0.distance < $1.distance})
        
        if currentSlot == nil {
            // Just use nearest
            slot = distance[0].slot
        } else {
            // Work out which 2 slots the drop occurred between and choose appropriate one
            
            if distance[0].slot == currentSlot {
                // Dropped nearest self - do nothing
            } else if distance[0].slot == 0 {
              // Dropped nearest unused 'You' player slot
                slot = 0
            } else if distance[1].slot == currentSlot {
                // Second closest is self - just drop on closest
                slot = distance[0].slot
            } else if distance[0].slot == 0 || distance[1].slot == 0 {
                // Between the 'You' player and another - drop on the other
                slot = max(distance[0].slot, distance[1].slot)
            } else {
                // Dropped between other 2 players
                slot = (currentSlot == 1 ? 3 : (currentSlot == 2 ? 1 : 2))
            }
        }
        
        return slot
    }
    
    private func clockwiseGap(from: Int, to: Int) -> Int {
        let count = self.playerViews.count - 1
        return (count + (to - from)) % count
    }
    
    private func addSlots(to: Int, add: Int = 1) -> Int {
        let count = self.playerViews.count - 1
        return ((to - 1) + count + add) % count + 1
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // Pass on events that are not in the path
        if self.roomPath == nil || self.roomPath!.contains(point) {
            return true
        } else {
            return false
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
                                let location = session.location(in: self.contentView)
                                self.selectedViewDropAction(dropLocation: location, source: source, withEmail: playerEmail)
                            }
                        }
                    }
                }
            })
        }
    }
}
