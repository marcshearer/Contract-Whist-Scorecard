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
    
    @objc optional func selectedPlayersView(wasDeleted slot: Int)
    
    @objc optional func selectedPlayersView(wasDroppedOn slot: Int, from source: PlayerViewType, playerMO: PlayerMO)
    
    @objc optional func selectedPlayersView(moved playerMO: PlayerMO, to slot: Int)
}

// MARK: - Selected Players View Class ================================================================================= -

public enum ArrowDirection: Int {
    case none = -1
    case up = 0
    case left = 1
    case down = 2
    case right = 3
}

class SelectedPlayersView: UIView, PlayerViewDelegate, UIDropInteractionDelegate {

    // Public properties
    public var playerViews: [PlayerView]!
    public var delegate: SelectedPlayersViewDelegate?
    
    // Internal properties
    private var scorecard = Scorecard.shared
    private var messageLabel = UILabel()
    private var roomPath: CGPath?
    private var tableLayers: [CAShapeLayer] = []
    private var tablePoints: [PolygonPoint]!
    private var roomFrame: CGRect!
    private var squareFrame: CGRect!
    private var tableFrame: CGRect!
    private let tableRatio: CGFloat = 1/3
    private var width: CGFloat! = 50.0
    private var height: CGFloat! = 75.0
    private var haloWidth: CGFloat = 0.0
    private var allowHaloWidth: CGFloat = 5.0
    private let lineWidth: CGFloat = 5.0
    private let tableInset: CGFloat = 20.0
    private var additionalAdjustment: CGFloat = 0.0
    private var players: Int!
    private var arrowDirections: [ArrowDirection : Bool]!
    private var tapGesture: UIGestureRecognizer!

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
    
    public var message: NSAttributedString {
        get {
            return self.messageLabel.attributedText!
        }
        set(newValue) {
            self.messageLabel.attributedText = newValue
        }
    }
    
    public var messageAlpha: CGFloat {
        get {
            return self.messageLabel.alpha
        }
        set(newValue) {
            self.messageLabel.alpha = newValue
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
    
    convenience init(frame: CGRect, haloWidth: CGFloat, allowHaloWidth: CGFloat = 0.0) {
        self.init(frame: frame)
        self.haloWidth = haloWidth
        self.allowHaloWidth = allowHaloWidth
    }
    
    // MARK: - Public methods ============================================================================== -
    
    public func set(slot: Int, playerMO: PlayerMO) {
        self.playerViews[slot].set(playerMO: playerMO)
    }
    
    public func clear(slot: Int, keepInUse: Bool = false) {
        self.clear(playerView: self.playerViews[slot], slot: slot, keepInUse: keepInUse)
    }
    
    public func inUse(slot: Int) -> Bool {
        return self.playerViews[slot].inUse
    }
    
    public func setInUse(slot: Int, to inUse: Bool = true) {
        self.playerViews[slot].inUse = inUse
    }
    
    public func origin(slot: Int, in view: UIView) -> CGPoint {
        return self.playerViews[slot].thumbnailView.convert(CGPoint(x: 0, y: 0), to: view)
    }
    
    public func freeSlot() -> Int? {
        return self.playerViews.firstIndex(where: { $0.inUse == false })
    }
    
    public func setEnabled(slot: Int, enabled: Bool) {
        self.playerViews[slot].isEnabled = enabled
    }
    
    public func setThumbnailAlpha(slot: Int? = nil, alpha: CGFloat) {
        for index in 0..<self.playerViews.count {
            if slot == nil || slot == index {
                self.playerViews[index].set(thumbnailAlpha: alpha)
            }
        }
    }
    
    public func setAlpha(slot: Int? = nil, alpha: CGFloat) {
        for index in 0..<self.playerViews.count {
            if slot == nil || slot == index {
                self.playerViews[index].alpha = alpha
            }
        }
    }
    
    public func setHaloWidth(slot: Int? = nil, haloWidth: CGFloat, allowHaloWidth: CGFloat = 0.0) {
        for index in 0..<self.playerViews.count {
            if slot == nil || slot == index {
                self.playerViews[index].set(haloWidth: haloWidth, allowHaloWidth: allowHaloWidth)
            }
        }
    }
    
    public func setHaloColor(slot: Int? = nil, color: UIColor) {
        for index in 0..<self.playerViews.count {
            if slot == nil || slot == index {
                self.playerViews[index].set(haloColor: color)
            }
        }
    }
    
    public func setTapDelegate(_ delegate: UIGestureRecognizerDelegate) {
        self.tapGesture.delegate = delegate
    }
    
    public func getMessageViewFrame(size: CGSize, in view: UIView) -> CGRect {
        return CGRect(origin: self.contentView.convert(CGPoint(x: self.tableFrame.midX - (size.width / 2.0), y: self.tableFrame.midY - 16 - size.height), to: view), size: size)
    }
    
    public func drawRoom(thumbnailWidth: CGFloat? = nil, thumbnailHeight: CGFloat? = nil, players: Int? = nil, directions: ArrowDirection...) -> CGRect{
        
        // Save leg height and thumbnail sizes etc
        self.setThumbnailSize(width: thumbnailWidth ?? 60.0, height: thumbnailHeight ?? 90.0)
        self.players = players ?? self.scorecard.currentPlayers
        
        // save arrow directions
        self.arrowDirections = [:]
        for arrowDirection in directions {
            self.arrowDirections[arrowDirection] = true
        }
        
        // Draw room components
        self.drawRoomComponents()
        
        return self.roomFrame
    }
    
    public func startDeleteWiggle(slot: Int? = nil) {
        for index in 0..<self.playerViews.count {
            if slot == nil || slot == index {
                self.playerViews[index].startDeleteWiggle()
            }
        }
    }
    
    public func stopDeleteWiggle(slot: Int? = nil) {
        for index in 0..<self.playerViews.count {
            if slot == nil || slot == index {
                self.playerViews[index].stopDeleteWiggle()
            }
        }
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
        
        // Set up message view
        self.addSubview(messageLabel)
        self.bringSubviewToFront(messageLabel)
        self.messageLabel.numberOfLines = 0
        self.messageLabel.textAlignment = .center
        self.messageLabel.textColor = Palette.roomInteriorText
        
        // Setup tap gesture
        self.tapGesture = UITapGestureRecognizer(target: self, action: #selector(SelectedPlayersView.tapSelector(_:)))
        self.contentView.addGestureRecognizer(self.tapGesture)
    }
    
    @objc internal func tapSelector(_ sender: Any) {
        self.playerViews.forEach { (playerView) in
            playerView.stopDeleteWiggle()
        }
    }
    
    private func setupSelectedPlayers(dropAction: ((PlayerView?, CGPoint?, PlayerViewType, String)->())? = nil, tapAction: ((PlayerView)->())? = nil) {
        
        // Add buttons to view
        self.playerViews = []
        
        for index in 0..<self.scorecard.numberPlayers {
            
            let playerView = PlayerView(type: .selected, parent: self.contentView, width: self.width, height: self.height, tag: index, haloWidth: self.haloWidth, allowHaloWidth: self.allowHaloWidth)
            playerView.delegate = self
            playerView.set(textColor: Palette.roomInteriorText)
            self.clear(playerView: playerView, slot: index)
            self.playerViews.append(playerView)
        }
    }
    
    private func clear(playerView: PlayerView, slot: Int, keepInUse: Bool = false) {
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
        playerView.clear(initials: initials, keepInUse: keepInUse)
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
        self.drawRoomBackground(below: tableLayer)
        self.drawTableLegs(below: tableLayer)
        
        // Position player views
        self.positionSelectedPlayers()
        
        // Position message label
        self.messageLabel.frame = CGRect(x: self.tableFrame.minX + 20.0, y: self.tableFrame.minY, width: self.tableFrame.width - 40.0, height: self.tableFrame.height)
    }
    
    private func setupTablePoints() {
        
        // Calculate room rectangle
        var widthElements: CGFloat = 2.0
        var heightElements: CGFloat = 2.0
        var leftElements: CGFloat = 0.0
        var topElements: CGFloat = 0.0

        if self.arrowDirections[.up] ?? false {
            heightElements += 1.0
            topElements += 1.0
        }
        if self.arrowDirections[.down] ?? false {
            heightElements += 1.0
        }
        if self.arrowDirections[.left] ?? false {
            leftElements += 1.0
            widthElements += 1.0
        }
        if self.arrowDirections[.right] ?? false {
            widthElements += 1.0
        }
        
        let widthComponent = self.frame.width / widthElements
        let heightComponent = widthComponent * self.tableRatio
        let heightInset = tableInset * heightComponent / widthComponent
        
        let unadjustedHeight: CGFloat = 2.0 * heightComponent
        var topAdjustment: CGFloat = self.height + 20.0 - ((self.arrowDirections[.up] ?? false) ? heightComponent : 0)
        self.additionalAdjustment = (self.arrowDirections[.down] ?? false ? 50.0 : 0.0)
        var adjustedHeight: CGFloat = unadjustedHeight + topAdjustment + additionalAdjustment
        
        let hideAdjustment: CGFloat = (0.5 * self.lineWidth)
        let roomX: CGFloat = ((arrowDirections[.left] ?? false) ? 0.0 : -hideAdjustment)
        let roomY: CGFloat = ((arrowDirections[.up] ?? false) ? 0.0 : -hideAdjustment)
        let roomWidth: CGFloat = (self.frame.width - roomX + ((arrowDirections[.right] ?? false) ? 0.0 : hideAdjustment))
        var roomHeight: CGFloat
        let normalRoomHeight: CGFloat = (heightComponent * (heightElements - 2.0)) + adjustedHeight
        let adjustment: CGFloat = self.frame.height + hideAdjustment - roomX - normalRoomHeight
        if (self.arrowDirections[.down] ?? false) || adjustment <= 0 {
            // Just use what you need
            roomHeight = normalRoomHeight
        } else {
            // Extend to the edge (and beyond)
            roomHeight = normalRoomHeight + adjustment
            topAdjustment += max(0, min(adjustment - 50.0 - self.safeAreaInsets.bottom, adjustment * ((self.arrowDirections[.up] ?? false) ? 0.75 : 0.4)))
        }
        
        if roomHeight > self.frame.height {
            // Use up bottom adjustment to save space
            let adjust = min(roomHeight - self.frame.height, additionalAdjustment)
            roomHeight -= adjust
            adjustedHeight -= adjust
            additionalAdjustment -= adjust
        }
        
        var safeAreaInsets: CGFloat = 0.0
        if !(self.arrowDirections[.right] ?? false) {
            // If no right arrow extend to edge of superview
            safeAreaInsets = self.superview!.safeAreaInsets.right
        }
        
        self.roomFrame = CGRect(x: roomX,
                                y: roomY,
                                width: roomWidth + safeAreaInsets,
                                height: roomHeight)
        
        self.squareFrame = CGRect(x: roomFrame.minX + leftElements * widthComponent,
                                  y: roomFrame.minY + topElements * heightComponent,
                                  width: roomWidth - ((widthElements - 2.0) * widthComponent) + safeAreaInsets,
                                  height: adjustedHeight)
        
        // Calculate table rectangle
        self.tableFrame = CGRect(x: squareFrame.minX + tableInset,
                                y: squareFrame.minY + heightInset + topAdjustment + additionalAdjustment,
                                width: squareFrame.width - (2.0 * tableInset) - safeAreaInsets,
                                height: unadjustedHeight - (2.0 * heightInset))
        
        // Setup table co-ordinates
        self.tablePoints = []
        self.tablePoints.append(PolygonPoint(x: tableFrame.midX, y: tableFrame.maxY, pointType: .quadRounded))
        self.tablePoints.append(PolygonPoint(x: tableFrame.minX, y: tableFrame.midY, pointType: .quadRounded))
        self.tablePoints.append(PolygonPoint(x: tableFrame.midX, y: tableFrame.minY, pointType: .quadRounded))
        self.tablePoints.append(PolygonPoint(x: tableFrame.maxX, y: tableFrame.midY, pointType: .quadRounded))
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
        
        let apex = CGPoint(x: self.squareFrame.midX, y: self.roomFrame.maxY - (0.5 * self.lineWidth))
        let left = CGPoint(x: self.squareFrame.minX, y: self.squareFrame.maxY - (0.5 * self.lineWidth))
        let right = CGPoint(x: self.squareFrame.maxX, y: self.squareFrame.maxY - (0.5 * self.lineWidth))
        
        var bottom1: CGFloat
        var bottom2: CGFloat
        var bottom3: CGFloat
        if arrowDirections[.down] ?? false {
            bottom1 = projectPoint(point1: (point1.x < self.tableFrame.midX ? left : right), point2: apex, newX: point1.x).y
            bottom2 = projectPoint(point1: (point2.x < self.tableFrame.midX ? left : right), point2: apex, newX: point2.x).y
            bottom3 = projectPoint(point1: (point3.x < self.tableFrame.midX ? left : right), point2: apex, newX: point3.x).y
        } else {
            bottom1 = contentView.frame.maxY
            bottom2 = contentView.frame.maxY
            bottom3 = contentView.frame.maxY
        }
        
        // Draw left hand side
        var points: [PolygonPoint] = []
        points.append(PolygonPoint(origin: point1.cgPoint, pointType: .point))
        points.append(PolygonPoint(origin: point2.cgPoint, pointType: .point))
        points.append(PolygonPoint(x: point2.x, y: bottom2, pointType: .point))
        points.append(PolygonPoint(x: point1.x, y: bottom1, pointType: .point))
        let leg = Polygon.roundedShapeLayer(definedBy: points, strokeColor: nil, fillColor: Palette.shapeTableLeg, lineWidth: 0.0)
        self.contentView.layer.insertSublayer(leg, above: layer)
        self.tableLayers.append(leg)
        
        // Draw right hand shadow
        points = []
        points.append(PolygonPoint(origin: point2.cgPoint, pointType: .point))
        points.append(PolygonPoint(origin: point3.cgPoint, pointType: .point))
        points.append(PolygonPoint(x: point3.x, y: bottom3, pointType: .point))
        points.append(PolygonPoint(x: point2.x, y: bottom2, pointType: .point))
        let shadow = Polygon.roundedShapeLayer(definedBy: points, strokeColor: nil, fillColor: Palette.shapeTableLegShadow, lineWidth: 0.0)
        self.contentView.layer.insertSublayer(shadow, above: layer)
        self.tableLayers.append(shadow)
    }
    
    private func drawRoomBackground(below tableLayer: CAShapeLayer) {
        
        // Setup room co-ordinates - draw slightly outside view to avoid stroke in some areas
        var points: [PolygonPoint] = []
        
        points.append(PolygonPoint(x: squareFrame.minX, y: squareFrame.minY, pointType: .point))
        
        // Add top side or arrow
        if arrowDirections[.up] ?? false {
            points.append(PolygonPoint(x: squareFrame.midX, y: roomFrame.minY, pointType: .quadRounded))
        } else {
            points.append(PolygonPoint(x: squareFrame.minX, y: roomFrame.minY, pointType: .point))
            points.append(PolygonPoint(x: squareFrame.maxX, y: roomFrame.minY, pointType: .point))
        }
        points.append(PolygonPoint(x: squareFrame.maxX, y: squareFrame.minY, pointType: .point))
        
        // Add right side or arrow
        if arrowDirections[.right] ?? false {
            points.append(PolygonPoint(x: roomFrame.maxX, y: squareFrame.midY, pointType: .quadRounded))
        } else {
            points.append(PolygonPoint(x: roomFrame.maxX, y: squareFrame.minY, pointType: .point))
            points.append(PolygonPoint(x: roomFrame.maxX, y: squareFrame.maxY, pointType: .point))
        }
        points.append(PolygonPoint(x: squareFrame.maxX, y: squareFrame.maxY, pointType: .point))
        
        // Add bottom side or arrow
        if arrowDirections[.down] ?? false {
            points.append(PolygonPoint(x: squareFrame.midX, y: roomFrame.maxY, pointType: .quadRounded))
        } else {
            points.append(PolygonPoint(x: squareFrame.maxX, y: roomFrame.maxY, pointType: .point))
            points.append(PolygonPoint(x: squareFrame.minX, y: roomFrame.maxY, pointType: .point))
        }
        points.append(PolygonPoint(x: squareFrame.minX, y: squareFrame.maxY, pointType: .point))
        
        // Add left side or arrow
        if arrowDirections[.left] ?? false {
            points.append(PolygonPoint(x: roomFrame.minX, y: squareFrame.midY, pointType: .quadRounded))
        } else {
            points.append(PolygonPoint(x: roomFrame.minX, y: squareFrame.maxY, pointType: .point))
            points.append(PolygonPoint(x: roomFrame.minX, y: squareFrame.minY, pointType: .point))
        }
        
        // Add room
        let roomStrokeLayer = Polygon.roundedShapeLayer(definedBy: points, strokeColor: UIColor.white, fillColor: UIColor.clear, lineWidth: 5.0, radius: 20.0)
        self.contentView.layer.insertSublayer(roomStrokeLayer, above: tableLayer)
        self.tableLayers.append(roomStrokeLayer)
        
        let roomFillLayer = Polygon.roundedShapeLayer(definedBy: points, strokeColor: UIColor.white, fillColor: Palette.roomInterior, lineWidth: 0.0, radius: 20.0)
        self.contentView.layer.insertSublayer(roomFillLayer, below: tableLayer)
        self.tableLayers.append(roomFillLayer)
        self.roomPath = roomFillLayer.path
    }
    
    private func setThumbnailSize(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }
    
    public func positionSelectedPlayers(players: Int? = nil) {
        
        self.players = players ?? self.players
        
        let apex = CGPoint(x: self.tableFrame.midX - (self.width / 2.0), y: self.tableFrame.minY - self.height - 10.0 - (additionalAdjustment / 2.0))
        let left = CGPoint(x: self.tableFrame.minX - (self.width / 2.0), y: self.tableFrame.midY - self.height - 10.0 - (additionalAdjustment / 2.0))
        let right = CGPoint(x: self.tableFrame.maxX - (self.width / 2.0), y: self.tableFrame.midY - self.height - 10.0 - (additionalAdjustment / 2.0))
        
        func positionSelectedView(_ newX: CGFloat) -> CGPoint {
            var result: CGPoint
            
            if newX < apex.x {
                result = self.projectPoint(point1: apex, point2: left, newX: newX).cgPoint
            } else {
                result = self.projectPoint(point1: apex, point2: right, newX: newX).cgPoint
            }
            
            return result
            
        }
        
        let viewSize = CGSize(width: self.width, height: self.height)
        let middleX: CGFloat = (self.players == self.scorecard.numberPlayers ? 0.0 : (self.tableFrame.width / 8.0)) + (self.width / 2.0)
        var position: [Int]
        switch self.players {
        case 1:
            position = [0, -1, -1, -1]
        case 2:
            position = [0, 2, -1, -1]
        case 3:
            position = [0, 1, 3, -1]
        default:
            position = [0, 1, 2, 3]
        }
        
        for slot in 0..<position.count {
            playerViews[slot].isHidden = false
            switch position[slot] {
            case 0:
                playerViews[slot].frame = CGRect(origin: CGPoint(x: apex.x, y: self.tableFrame.maxY - self.height - 2.0), size: viewSize)
            case 1:
                playerViews[slot].frame = CGRect(origin: positionSelectedView(left.x + middleX), size: viewSize)
            case 2:
                playerViews[slot].frame = CGRect(origin: positionSelectedView(apex.x), size: viewSize)
            case 3:
                playerViews[slot].frame = CGRect(origin: positionSelectedView(right.x - middleX), size: viewSize)
            default:
                playerViews[slot].isHidden = true
            }
        }
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
    
    internal func playerViewWasDeleted(_ playerView: PlayerView) {
        // Can't handle here - pass back
        
        self.delegate?.selectedPlayersView?(wasDeleted: playerView.tag)
    }
    
    // MARK: - Main drag/drop handling method ====================================================================== -
    
    internal func selectedViewDropAction(dropLocation: CGPoint, source: PlayerViewType, withEmail: String) {
        
        if let addedPlayerMO = scorecard.playerList.first(where: { $0.email == withEmail }) {
            // Found the player from their email
            
            if source == .selected {
                // Moving a player in selected view - rotate all players in between
                
                if let currentSlot = self.playerViewSlot(addedPlayerMO) {
                    // Got the players current slot - work out the drop slot
                    
                    let (dropSlot, rotate) = self.slotFromLocation(dropLocation: dropLocation, currentSlot: currentSlot)
                        
                    if let dropSlot = dropSlot {
                        // Ignore if dropping on itself
                        if currentSlot != dropSlot {
                            
                            var holdingArea: [Int:PlayerMO?] = [:]
                            if !rotate {
                                // Just swap
                                holdingArea[dropSlot] = addedPlayerMO
                                if self.playerViews[dropSlot].inUse {
                                    holdingArea[currentSlot] = self.playerViews[dropSlot].playerMO
                                } else {
                                    self.clear(slot: currentSlot)
                                }
                            } else {
                                // Work out where everything will be after rotation - stopping if we land on a blank
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
                let (slot, _) = self.slotFromLocation(dropLocation: dropLocation, currentSlot: nil)
                if let slot = slot {
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
    
    private func slotFromLocation(dropLocation: CGPoint, currentSlot: Int?) -> (Int?, Bool) {
        var slot: Int?
        var rotate = false
        
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
              // Dropped nearest 'You' player slot - drop on it
                slot = 0
            } else if distance[1].slot == currentSlot {
                // Second closest is self - just drop on closest
                slot = distance[0].slot
            } else if distance[0].distance <= distance[1].distance / 3.0 {
                // Within a quarter of the slot - just drop on closest
                slot = distance[0].slot
            } else if !self.playerViews[distance[0].slot].inUse {
                // Nearest slot not in use - drop on it
                slot = distance[0].slot
            } else if !self.playerViews[distance[1].slot].inUse {
                // Second nearest slot not in use - drop on it
                slot = distance[1].slot
            } else if distance[1].slot == 0 {
                // Between the 'You' player and another - drop on the other
                slot = max(distance[0].slot, distance[1].slot)
            } else if currentSlot == 0 {
                // 'You' player dropped between 2 others - swap with closest
                slot = distance[0].slot
            } else {
                // Dropped between other 2 players
                slot = (currentSlot == 1 ? 3 : (currentSlot == 3 ? 2 : 1))
                rotate = true
            }
        }
        
        return (slot, rotate)
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
