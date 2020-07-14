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

class SelectedPlayersView: UIView, PlayerViewDelegate, UIDropInteractionDelegate {

    // Public properties
    public var playerViews: [PlayerView]!
    public weak var delegate: SelectedPlayersViewDelegate?
    
    // Internal properties
    private var messageLabel = UILabel()
    private var width: CGFloat! = 50.0
    private var height: CGFloat! = 75.0
    private var haloWidth: CGFloat = 0.0
    private var allowHaloWidth: CGFloat = 5.0
    private let lineWidth: CGFloat = 5.0
    private var players: Int!
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
        return CGRect(origin: self.contentView.convert(CGPoint(x: (self.frame.width - size.width) / 2.0, y: ((self.frame.height - size.height) / 2) - 16), to: view), size: size)
    }
    
    public func drawRoom(thumbnailWidth: CGFloat? = nil, thumbnailHeight: CGFloat? = nil, players: Int? = nil) {
        
        // Save thumbnail sizes etc
        self.setThumbnailSize(width: thumbnailWidth ?? 60.0, height: thumbnailHeight ?? 90.0)
        self.players = players ?? Scorecard.game.currentPlayers
        
        // Draw room components
        self.drawRoomComponents()
        
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
        Constraint.anchor(view: self, control: messageLabel, attributes: .leading, .trailing, .bottom)
        Constraint.anchor(view: self, control: messageLabel, constant: self.height, attributes: .top)
        self.bringSubviewToFront(messageLabel)
        self.messageLabel.numberOfLines = 0
        self.messageLabel.textAlignment = .center
        self.messageLabel.textColor = Palette.bannerText
        
        // Setup tap gesture
        self.tapGesture = UITapGestureRecognizer(target: self, action: #selector(SelectedPlayersView.tapSelector(_:)))
        self.contentView.addGestureRecognizer(self.tapGesture)
    }
    
    @objc internal func tapSelector(_ sender: Any) {
        self.playerViews.forEach { (playerView) in
            playerView.stopDeleteWiggle()
        }
    }
    
    private func setupSelectedPlayers() {
        
        // Add buttons to view
        self.playerViews = []
        
        for index in 0..<Scorecard.shared.maxPlayers {
            
            let playerView = PlayerView(type: .selected, parentView: self.contentView, width: self.width, height: self.height, tag: index, haloWidth: self.haloWidth, allowHaloWidth: self.allowHaloWidth)
            playerView.delegate = self
            playerView.set(textColor: Palette.tableTopText)
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
        
        self.layoutIfNeeded()
        
        // Set background
        self.backgroundColor = Palette.tableTop
        
        // Position player views
        self.positionSelectedPlayers()
        
        // Position message label
        self.messageLabel.frame = CGRect(x: self.frame.minX + 20.0, y: self.frame.minY, width: self.frame.width - 40.0, height: self.frame.height)
    }
    
    private func setThumbnailSize(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }
    
    public func positionSelectedPlayers(players: Int? = nil) {
        
        self.players = players ?? self.players
        
        let playerFrame = CGRect(origin: CGPoint(), size: self.frame.size).inset(by: UIEdgeInsets(top: 18, left: 18, bottom: self.height + 10, right: self.width + 18))
        let apex = CGPoint(x: playerFrame.midX, y: playerFrame.minY)
        let left = CGPoint(x: playerFrame.minX, y: playerFrame.midY )
        let right = CGPoint(x: playerFrame.maxX, y: playerFrame.midY)
        
        
        let viewSize = CGSize(width: self.width, height: self.height)
        let middleXOffset: CGFloat = (self.players == 4 ? 0 : 8)
        let middleY: CGFloat = (self.players == 4 ? playerFrame.midY : playerFrame.minY + middleXOffset)
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
                playerViews[slot].frame = CGRect(origin: CGPoint(x: apex.x, y: playerFrame.maxY), size: viewSize)
            case 1:
                playerViews[slot].frame = CGRect(origin: CGPoint(x: left.x + middleXOffset, y: middleY), size: viewSize)
            case 2:
                playerViews[slot].frame = CGRect(origin: apex, size: viewSize)
            case 3:
                playerViews[slot].frame = CGRect(origin: CGPoint(x: right.x - middleXOffset, y: middleY), size: viewSize)
            default:
                playerViews[slot].isHidden = true
            }
        }
    }
    
    func projectPoint(point1: CGPoint, point2: CGPoint, newX: CGFloat, pointType: PolygonPointType? = nil, radius: CGFloat? = nil) -> PolygonPoint {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        let newY = point1.y - ((point1.x - newX) / dx) * dy
        return PolygonPoint(x: newX, y: newY, pointType: pointType, radius: radius)
    }
    
    // MARK: - Player View delegate handlers ======================================================================= -
    
    internal func playerViewWasDroppedOn(_ playerView: PlayerView, from source: PlayerViewType, withPlayerUUID: String) {
        
        // Nothing to do here - pass on to delegate
        if let playerMO = Scorecard.shared.playerList.first(where: { $0.playerUUID == withPlayerUUID }) {
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
    
    internal func selectedViewDropAction(dropLocation: CGPoint, source: PlayerViewType, withPlayerUUID: String) {
        
        if let addedPlayerMO = Scorecard.shared.playerList.first(where: { $0.playerUUID == withPlayerUUID }) {
            // Found the player from their playerUUID
            
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
        for slot in 0..<self.players {
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
                                let location = session.location(in: self.contentView)
                                self.selectedViewDropAction(dropLocation: location, source: source, withPlayerUUID: playerUUID)
                            }
                        }
                    }
                }
            })
        }
    }
}
