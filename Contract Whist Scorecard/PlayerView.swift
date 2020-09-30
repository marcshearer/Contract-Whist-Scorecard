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
    case imagePicker = 5
}

@objc public protocol PlayerViewDelegate {
    
    @objc optional func playerViewWasTapped(_ playerView: PlayerView)
    
    @objc optional func playerViewWasDeleted(_ playerView: PlayerView)
    
    @objc optional func playerViewWasDroppedOn(_ playerView: PlayerView, from source: PlayerViewType, withPlayerUUID: String)
    
}

@objc public protocol PlayerViewImagePickerDelegate {
    func playerViewImageChanged(to: Data?)
}

public class PlayerView : NSObject, UIDropInteractionDelegate, UIDragInteractionDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIGestureRecognizerDelegate {
    
    public weak var delegate: PlayerViewDelegate?
    public weak var imagePickerDelegate: PlayerViewImagePickerDelegate?
    
    private weak var parentView: UIView!
    private weak var parentViewController: ScorecardViewController!
    public var tag: Int
    public var type: PlayerViewType
    public var thumbnailView: ThumbnailView!
    private var deleteOnTap = false
    public var inUse = false
    public var playerMO: PlayerMO?
    public var haloWidth: CGFloat = 0.0
    public var allowHaloWidth: CGFloat = 0.0
    
    init(type: PlayerViewType, parentViewController: ScorecardViewController? = nil, parentView: UIView! = nil, width: CGFloat, height: CGFloat, tag: Int = 0, haloWidth: CGFloat = 0.0, allowHaloWidth: CGFloat = 0.0, tapGestureDelegate: UIGestureRecognizerDelegate? = nil, cameraTintColor: UIColor? = nil) {
        
        // Save properties
        self.parentViewController = parentViewController
        self.parentView = parentView ?? parentViewController?.view
        self.type = type
        self.tag = tag
        self.haloWidth = haloWidth
        
        super.init()
        
        // Setup thumbnail
        self.thumbnailView = ThumbnailView(frame: CGRect(x: 5.0, y: 5.0, width: width, height: height), haloWidth: haloWidth, allowHaloWidth: allowHaloWidth)
        self.haloWidth = haloWidth
        self.thumbnailView.tag = tag
    
        parentView.addSubview(self.thumbnailView)
        parentView.bringSubviewToFront(self.thumbnailView)
        
        // Setup tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(PlayerView.tapSelector(_:)))
        if let tapGestureDelegate = tapGestureDelegate {
            tapGesture.delegate = tapGestureDelegate
        }
        self.thumbnailView.addGestureRecognizer(tapGesture)
        
        // Setup drag and drop
        if self.type == .unselected || self.type == .selected {
            let dragInteraction = UIDragInteraction(delegate: self)
            dragInteraction.isEnabled = true
            self.thumbnailView.addInteraction(dragInteraction)
            self.thumbnailView.isUserInteractionEnabled = true
        }
        
        // Set up image picker
        self.updateCameraImage(tintColor: cameraTintColor)
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
        self.updateCameraImage()
    }
    
    public func set(playerMO: PlayerMO, nameHeight: CGFloat? = nil) {
        self.set(data: playerMO.thumbnail, name: playerMO.name, nameHeight: nameHeight)
        self.playerMO = playerMO
        self.updateCameraImage()
    }
    
    public func set(haloWidth: CGFloat, allowHaloWidth: CGFloat) {
        self.haloWidth = haloWidth
        self.allowHaloWidth = allowHaloWidth
        self.thumbnailView.set(haloWidth: haloWidth, allowHaloWidth: allowHaloWidth)
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
        self.updateCameraImage()
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
    
    public func set(imageName: String?, tintColor: UIColor? = nil) {
        self.thumbnailView.set(imageName: imageName, tintColor: tintColor)
    }
    
    @objc private func tapSelector(_ sender: Any?) {
        if self.type == .imagePicker {
            self.imagePickerTapped()
        } else if self.inUse {
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
                view.startWiggle()
                self.deleteOnTap = true
            }
        }
    }
    
    public func stopDeleteWiggle() {
        if let view = self.thumbnailView {
            view.stopWiggle()
            self.deleteOnTap = false
        }
    }
    
    private func updateCameraImage(tintColor: UIColor? = nil) {
        if self.type == .imagePicker {
            if self.thumbnailView.discImage.image != nil {
                self.thumbnailView.additionalImage.isHidden = true
            } else {
                self.thumbnailView.additionalImage.isHidden = false
                self.thumbnailView.set(imageName: "camera", tintColor: tintColor, systemImage: true)
            }
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
                            if let playerUUID = playerObject.playerUUID, let source = playerObject.source {
                                self.delegate?.playerViewWasDroppedOn?(self, from: source, withPlayerUUID: playerUUID)
                            }
                        }
                    }
                }
            })
        }
    }
    
    // MARK: - Drag delegate handlers ==================================================================== -
    
    public func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
        if let playerUUID = self.playerMO?.playerUUID {
            return [ UIDragItem(itemProvider: NSItemProvider(object: PlayerObject(source: self.type, playerUUID: playerUUID)))]
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
    
    // MARK: - Image Picker Routines / Overrides ============================================================ -

    private func imagePickerTapped() {
        let actionSheet = ActionSheet("Thumbnail Image", message: "\(self.playerMO?.thumbnail == nil ? "Add a" : "Replace") thumbnail image for this player", sourceView: parentView, sourceRect: thumbnailView.frame, direction: UIPopoverArrowDirection.right)
        if !Utility.isSimulator {
            actionSheet.add("Take Photo", handler: {
                self.getPicture(from: .camera)
            })
        }
        actionSheet.add("Use Photo Library",handler: {
            self.getPicture(from: .photoLibrary)
        })
        if self.thumbnailView.discImage.image != nil {
            actionSheet.add("Remove Photo", handler: {
                self.set(data: nil)
                self.imagePickerDelegate?.playerViewImageChanged(to: nil)
                
            })
        }
        actionSheet.add("Cancel", style: .cancel, handler:nil)
        actionSheet.present(from: self.parentViewController)
    }
    
    private func getPicture(from: UIImagePickerController.SourceType) {
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.allowsEditing = false
            imagePicker.sourceType = from
            
            self.parentViewController?.present(imagePicker, animated: true)
        }
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let selectedImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            let rotatedImage = self.rotateImage(image: selectedImage)
            if let imageData = rotatedImage.pngData() {
                self.thumbnailView.set(data: imageData)
                self.imagePickerDelegate?.playerViewImageChanged(to: imageData)
            } else {
                self.thumbnailView.set(data: nil)
                self.imagePickerDelegate?.playerViewImageChanged(to: nil)
            }
        }
        picker.dismiss(animated: true, completion: nil)
        self.updateCameraImage()
    }
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
        
    func rotateImage(image: UIImage) -> UIImage {
        
        if (image.imageOrientation == UIImage.Orientation.up ) {
            return image
        }
        
        UIGraphicsBeginImageContext(image.size)
        
        image.draw(in: CGRect(origin: CGPoint.zero, size: image.size))
        let copy = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return copy!
    }
}

// MARK: - Object for dragging and dropping a player ======================================================= -

@objc final public class PlayerObject: NSObject, NSItemProviderReading, NSItemProviderWriting {
    
    public var playerUUID: String?
    public var source: PlayerViewType?
    
    public static var readableTypeIdentifiersForItemProvider: [String] = ["shearer.com/whist/playerObject"]
    
    public static var writableTypeIdentifiersForItemProvider: [String] = ["shearer.com/whist/playerObject"]
    
    public func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
        
        let progress = Progress(totalUnitCount: 1)
        
        do {
            let data = try JSONSerialization.data(withJSONObject: ["playerUUID" : self.playerUUID,
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
        return PlayerObject(source: PlayerViewType(rawValue: Int(propertyList["source"]!)!) ?? .unknown, playerUUID: propertyList["playerUUID"]!)
    }
    
    init(source: PlayerViewType, playerUUID: String?) {
        super.init()
        self.source = source
        self.playerUUID = playerUUID
    }
}


