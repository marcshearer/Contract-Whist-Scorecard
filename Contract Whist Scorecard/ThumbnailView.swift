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
        self.set(frame:frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.loadThumbnailView()
    }
    
    convenience init(frame: CGRect, haloWidth: CGFloat) {
        self.init(frame: frame)
        self.set(haloWidth: haloWidth)
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
            return self.discHalo.frame.width
        }
    }
    
    public func set(data: Data? = nil, name: String? = nil, initials: String? = nil, nameHeight: CGFloat? = nil, diameter: CGFloat = 0, alpha: CGFloat? = nil, placeholder: Bool = false) {
        
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
    }
    
    public func set(playerMO: PlayerMO, nameHeight: CGFloat? = nil) {
        self.set(data: playerMO.thumbnail, name: playerMO.name, nameHeight: nameHeight ?? 30.0)
    }
    
    public func set(imageName: String?) {
        if let imageName = imageName {
            self.additionalImage.isHidden = false
            self.additionalImage.image = UIImage(named: imageName)
        } else {
            self.additionalImage.isHidden = true
        }
    }
    
    public func set(frame: CGRect) {
        self.frame = frame
        
        // Adjust components
        self.discHalo.frame = CGRect(origin: CGPoint(), size: CGSize(width: self.frame.width, height: self.frame.width))
        ScorecardUI.veryRoundCorners(self.discHalo, radius: (self.discHalo.frame.width - 0.0) / 2.0)
        
        let discSize: CGFloat = frame.width - (2 * self.haloWidth)
        self.discImage.frame = CGRect(x: haloWidth, y: haloWidth, width: discSize, height: discSize)
        ScorecardUI.veryRoundCorners(self.discImage, radius: discSize / 2.0)
        self.discInitials.frame = self.discImage.frame
        ScorecardUI.veryRoundCorners(self.discInitials, radius: discSize / 2.0)
        // self.name.frame = (CGRect(x: 0.0, y: frame.height - frame.width, width: frame.width, height: frame.height - frame.width + 5.0))
    }
    
    public func set(textColor: UIColor) {
        self.name.textColor = textColor
    }
    
    public func set(thumbnailAlpha: CGFloat) {
        self.discHalo.alpha = thumbnailAlpha
        self.discImage.alpha = thumbnailAlpha
        self.discInitials.alpha = thumbnailAlpha
    }
    
    public func set(haloWidth: CGFloat) {
        self.haloWidth = haloWidth
        self.set(frame: frame)
    }
    
    public func set(haloColor: UIColor) {
        self.discHalo.backgroundColor = haloColor
    }
    
    public func set(font: UIFont) {
        self.name.font = font
    }
    
}
