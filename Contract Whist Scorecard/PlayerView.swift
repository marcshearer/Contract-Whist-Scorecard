//
//  PlayerView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 18/07/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit

@objc public enum PlayerViewType: Int {
    case unknown = 0
    case selected = 1
    case unselected = 2
    case addPlayer = 3
    case animation = 4
}

@objc public protocol PlayerViewDelegate {
    
    @objc optional func playerViewWasTapped(_ playerView: PlayerView)
    
    @objc optional func playerViewWasDeleted(_ playerView: PlayerView)
    
    @objc optional func playerViewWasDroppedOn(_ playerView: PlayerView, from source: PlayerViewType, withEmail: String)
    
}

public class PlayerView : NSObject, UIDropInteractionDelegate, UIDragInteractionDelegate {
    
    public weak var delegate: PlayerViewDelegate?
    
    public weak var parent: UIView!
    public var tag: Int
    public var type: PlayerViewType
    public var thumbnailView: ThumbnailView!
    private var deleteView: UIView!
    private var deleteOnTap = false
    public var inUse = false
    public var playerMO: PlayerMO?
    public var haloWidth: CGFloat = 0.0
    public var allowHaloWidth: CGFloat = 0.0
    
    init(type: PlayerViewType, parent: UIView, width: CGFloat, height: CGFloat, tag: Int = 0, haloWidth: CGFloat = 0.0, allowHaloWidth: CGFloat = 0.0, tapGestureDelegate: UIGestureRecognizerDelegate? = nil) {
        
        // Save properties
        self.parent = parent
        self.type = type
        self.tag = tag
        self.haloWidth = haloWidth
        
        super.init()
        
        // Setup thumbnail
        self.thumbnailView = ThumbnailView(frame: CGRect(x: 5.0, y: 5.0, width: width, height: height), haloWidth: haloWidth, allowHaloWidth: allowHaloWidth)
        self.haloWidth = haloWidth
        self.thumbnailView.tag = tag
    
        parent.addSubview(self.thumbnailView)
        parent.bringSubviewToFront(self.thumbnailView)
        
        // Setup tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(PlayerView.tapSelector(_:)))
        tapGesture.delegate = tapGestureDelegate
        self.thumbnailView.addGestureRecognizer(tapGesture)
        
        // Setup drag and drop
        if self.type == .unselected || self.type == .selected {
            let dragInteraction = UIDragInteraction(delegate: self)
            dragInteraction.isEnabled = true
            self.thumbnailView.addInteraction(dragInteraction)
            self.thumbnailView.isUserInteractionEnabled = true
        }
    }
    
    public var alpha: CGFloat {
        get {
            return self.thumbnailView.alpha
        }
        set (newValue) {
            self.thumbnailView.alpha = newValue
        }
    }
    
    public var frame: CGRect {
        get {
            return self.thumbnailView.frame
        }
        set (newValue) {
            self.thumbnailView.set(frame: newValue)
        }
    }
    
    public var isEnabled: Bool {
        get {
            return self.thumbnailView.isUserInteractionEnabled
        }
        set(newValue) {
            self.thumbnailView.isUserInteractionEnabled = newValue
        }
    }
    
    public var isHidden: Bool {
        get {
            return self.thumbnailView.isHidden
        }
        set(newValue) {
            self.thumbnailView.isHidden = newValue
        }
    }
    
    public func set(data: Data? = nil, name: String? = nil, initials: String? = nil, nameHeight: CGFloat? = nil, alpha: CGFloat? = nil) {
        self.inUse = true
        self.playerMO = nil
        self.thumbnailView.set(data: data, name: name, initials: initials, nameHeight: nameHeight ?? 30.0, alpha: alpha)
        self.stopDeleteWiggle()
    }
    
    public func set(playerMO: PlayerMO, nameHeight: CGFloat? = nil) {
        self.set(data: playerMO.thumbnail, name: playerMO.name, nameHeight: nameHeight)
        self.playerMO = playerMO
    }
    
    public func set(haloWidth: CGFloat, allowHaloWidth: CGFloat) {
        self.haloWidth = haloWidth
        self.allowHaloWidth = allowHaloWidth
        self.thumbnailView.set(haloWidth: haloWidth, allowHaloWidth: allowHaloWidth)
        self.thumbnailView.set(frame: self.frame)
    }
    
    public func set(haloColor: UIColor) {
        self.thumbnailView.set(haloColor: haloColor)
    }
    
    public func set(thumbnailAlpha: CGFloat) {
        self.thumbnailView.set(thumbnailAlpha: thumbnailAlpha)
    }
    
    public func clear(initials: String? = nil, keepInUse: Bool = false) {
        self.inUse = keepInUse
        self.playerMO = nil
        self.thumbnailView.set(initials: initials, nameHeight: 30.0, placeholder: true)
    }
    
    public func set(textColor: UIColor) {
        self.thumbnailView.set(textColor: textColor)
    }
    
    public func set(font: UIFont) {
        self.thumbnailView.set(font: font)
       }
       
    public func set(backgroundColor: UIColor) {
        self.thumbnailView.set(backgroundColor: backgroundColor)
    }
    
    public func set(imageName: String?) {
        self.thumbnailView.set(imageName: imageName)
    }
    
    @objc private func tapSelector(_ sender: Any?) {
        if self.inUse {
            if self.deleteOnTap {
                self.stopDeleteWiggle()
                self.delegate?.playerViewWasDeleted?(self)
            } else {
                self.delegate?.playerViewWasTapped?(self)
            }
        }
    }
    
    public func removeFromSuperview() {
        self.thumbnailView.removeFromSuperview()
    }
    
    public func startDeleteWiggle() {
        if let view = self.thumbnailView {
            if self.inUse {
                let animation  = CAKeyframeAnimation(keyPath:"transform")
                animation.values  = [NSValue(caTransform3D: CATransform3DMakeRotation(0.05, 0.0, 0.0, 1.0)),
                                     NSValue(caTransform3D: CATransform3DMakeRotation(-0.05 , 0, 0, 1))]
                animation.autoreverses = true
                animation.duration  = 0.1
                animation.repeatCount = Float.infinity
                view.layer.add(animation, forKey: "transform")
                self.deleteView = UIImageView(frame: CGRect(x: 0.0, y: 0.0, width: 20.0, height: 20.0))
                let deleteImageView = UIImageView(frame: CGRect(x: 5.0, y: 5.0, width: 10.0, height: 10.0))
                deleteImageView.image = UIImage(named: "cross red")
                deleteView.backgroundColor = Palette.background
                deleteView.addSubview(deleteImageView)
                ScorecardUI.veryRoundCorners(deleteView, radius: 10.0)
                view.addSubview(deleteView)
                self.deleteOnTap = true
            }
        }
    }
    
    public func stopDeleteWiggle() {
        if let view = self.thumbnailView {
            view.layer.removeAllAnimations()
            self.deleteView?.removeFromSuperview()
            self.deleteOnTap = false
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
                                self.delegate?.playerViewWasDroppedOn?(self, from: source, withEmail: playerEmail)
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
        let previewView = ThumbnailView(frame: CGRect(origin: CGPoint(), size: CGSize(width: self.frame.width, height: self.frame.width)), haloWidth: self.haloWidth)
        previewView.set(data: self.playerMO?.thumbnail)
        ScorecardUI.veryRoundCorners(previewView)
        let center = CGPoint(x: self.frame.width / 2.0, y: self.frame.height / 2.0)
        let target = UIDragPreviewTarget(container: self.thumbnailView, center: center)
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
                                                                   "source"      : "\(self.source?.rawValue ?? 0)"],
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
        return PlayerObject(source: PlayerViewType(rawValue: Int(propertyList["source"]!)!) ?? .unknown, playerEmail: propertyList["playerEmail"]!)
    }
    
    init(source: PlayerViewType, playerEmail: String?) {
        super.init()
        self.source = source
        self.playerEmail = playerEmail
    }
}


