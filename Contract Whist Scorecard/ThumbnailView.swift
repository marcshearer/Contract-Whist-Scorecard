//
//  ThumbnailView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 12/07/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit

public class ThumbnailView: UIView {

    private var haloWidth: CGFloat = 0.0
    private var allowHaloWidth: CGFloat = 0.0 // Used to avoid disc changing size if halo changes
    private var deleteView: UIView!
    
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet public weak var discImage: UIImageView!
    @IBOutlet public weak var discInitials: UILabel!
    @IBOutlet public weak var discHalo: UIView!
    @IBOutlet public weak var name: UILabel!
    @IBOutlet public weak var nameHeightConstraint: NSLayoutConstraint!
    @IBOutlet public weak var additionalImage: UIImageView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.loadThumbnailView()
        self.set(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.loadThumbnailView()
    }
    
    convenience init(frame: CGRect, haloWidth: CGFloat, allowHaloWidth: CGFloat = 0.0) {
        self.init(frame: frame)
        self.set(haloWidth: haloWidth, allowHaloWidth: allowHaloWidth)
    }
    
    private func loadThumbnailView() {
        Bundle.main.loadNibNamed("ThumbnailView", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    
    public override var alpha: CGFloat {
        get {
            return super.alpha
        }
        set (newValue) {
            super.alpha = newValue
            self.discImage?.alpha = newValue
            self.discInitials?.alpha = newValue
            self.name?.alpha = newValue
        }
    }
    
    public override var tag: Int {
        get {
            return super.tag
        }
        set (newValue) {
            super.tag = newValue
            self.contentView?.tag = newValue
            self.discHalo?.tag = newValue
            self.discImage?.tag = newValue
            self.discInitials?.tag = newValue
            self.name?.tag = newValue
        }
    }
    
    public var nameHeight: CGFloat {
        get {
            return self.name?.frame.height ?? 0.0
        }
    }
    
    public var diameter: CGFloat {
        get {
            return self.discHalo.layer.frame.width
        }
    }
    
    public func set(data: Data? = nil, name: String? = nil, initials: String? = nil, nameHeight: CGFloat? = nil, diameter: CGFloat = 0.0, alpha: CGFloat? = nil, placeholder: Bool = false) {
        
        let initials = initials ?? (name ?? "")
        
        Utility.setThumbnail(data: data, imageView: self.discImage, initials: initials, label: self.discInitials, size: diameter, placeholder: placeholder)
        
        if let nameHeight = nameHeight {
            self.nameHeightConstraint.constant = nameHeight
        } else {
            self.nameHeightConstraint.constant = 0.0
        }
        
        if let name = name {
            self.name.text = name
        } else {
            self.name.text = ""
        }
        
        if let alpha = alpha {
            self.alpha = alpha
        }
        
        self.stopWiggle()
    }
    
    public func set(playerMO: PlayerMO, nameHeight: CGFloat? = nil, diameter: CGFloat = 0.0) {
        self.set(data: playerMO.thumbnail, name: playerMO.name, nameHeight: nameHeight ?? 30.0, diameter: diameter)
    }
    
    public func set(imageName: String?) {
        self.set(frame: frame)
        if let imageName = imageName {
            self.additionalImage.isHidden = false
            self.additionalImage.image = UIImage(named: imageName)
        } else {
            self.additionalImage.isHidden = true
        }
    }
    
    public func set(systemImageName: String, tintColor: UIColor? = nil) {
        self.set(frame: frame)
        self.additionalImage.isHidden = false
        self.additionalImage.image = UIImage(systemName: systemImageName)
        if let tintColor = tintColor {
            self.additionalImage.tintColor = tintColor
        }
    }
    
    public func set(frame: CGRect) {
        self.frame = frame
        let allowHaloWidth = max(self.allowHaloWidth, self.haloWidth)
        // Adjust components
        let haloInset = allowHaloWidth - haloWidth
        let haloSize = self.frame.width - (2.0 * haloInset)
        self.discHalo.layer.frame = CGRect(x: haloInset, y: haloInset, width: haloSize , height: haloSize)
        ScorecardUI.veryRoundCorners(self.discHalo, radius: self.discHalo.layer.frame.width / 2.0)
        
        let discSize: CGFloat = frame.width - (2 * allowHaloWidth)
        self.discImage.frame = CGRect(x: haloWidth, y: haloWidth, width: discSize, height: discSize)
        ScorecardUI.veryRoundCorners(self.discImage, radius: discSize / 2.0)
        self.discInitials.frame = self.discImage.frame
        ScorecardUI.veryRoundCorners(self.discInitials, radius: discSize / 2.0)
    }
    
    public func set(textColor: UIColor) {
        self.name.textColor = textColor
    }
    
    public func set(backgroundColor: UIColor) {
        self.discInitials.backgroundColor = backgroundColor
        self.additionalImage.backgroundColor = backgroundColor
    }
    
    public func set(thumbnailAlpha: CGFloat) {
        self.discHalo.alpha = thumbnailAlpha
        self.discImage.alpha = thumbnailAlpha
        self.discInitials.alpha = thumbnailAlpha
    }
    
    public func set(haloWidth: CGFloat, allowHaloWidth: CGFloat = 0.0) {
        self.haloWidth = haloWidth
        self.allowHaloWidth = allowHaloWidth
        self.set(frame: frame)
    }
    
    public func set(haloColor: UIColor) {
        self.discHalo.backgroundColor = haloColor
    }
    
    public func set(font: UIFont) {
        self.name.font = font
    }
    
    public func setShadow(shadowSize: CGSize = CGSize(width: 4.0, height: 4.0), shadowColor: UIColor? = nil, shadowOpacity: CGFloat = 0.2, shadowRadius: CGFloat? = nil) {
        self.contentView.addShadow(shadowSize: shadowSize, shadowColor: shadowColor, shadowOpacity: shadowOpacity, shadowRadius: shadowRadius)
    }
    
    public func startWiggle(addDeleteButton: Bool = true) {
        let animation  = CAKeyframeAnimation(keyPath:"transform")
        animation.values  = [NSValue(caTransform3D: CATransform3DMakeRotation(0.05, 0.0, 0.0, 1.0)),
                             NSValue(caTransform3D: CATransform3DMakeRotation(-0.05 , 0, 0, 1))]
        animation.autoreverses = true
        animation.duration  = 0.1
        animation.repeatCount = Float.infinity
        self.layer.add(animation, forKey: "transform")
        if addDeleteButton {
            self.deleteView = UIImageView(frame: CGRect(x: 0.0, y: 0.0, width: 20.0, height: 20.0))
            let deleteImageView = UIImageView(frame: CGRect(x: 5.0, y: 5.0, width: 10.0, height: 10.0))
            deleteImageView.image = UIImage(named: "cross red")
            deleteView.backgroundColor = Palette.background
            deleteView.addSubview(deleteImageView)
            ScorecardUI.veryRoundCorners(deleteView, radius: 10.0)
            self.addSubview(deleteView)
        }
    }
    
    public func stopWiggle() {
        self.layer.removeAllAnimations()
        self.deleteView?.removeFromSuperview()
        self.deleteView = nil
    }
}
