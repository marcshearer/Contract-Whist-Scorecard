//
//  ThumbnailView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 12/07/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit

public class ThumbnailView: UIView {

    @IBOutlet private weak var contentView: UIView!
    @IBOutlet public weak var discImage: UIImageView!
    @IBOutlet public weak var discInitials: UILabel!
    @IBOutlet public weak var discContainer: UIView!
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
            self.discContainer?.tag = newValue
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
            return self.discContainer.frame.width
        }
    }
    
    public func set(data: Data? = nil, name: String? = nil, initials: String? = nil, nameHeight: CGFloat? = nil, diameter: CGFloat = 0, alpha: CGFloat? = nil) {
        
        let initials = initials ?? (name ?? "")
        
        Utility.setThumbnail(data: data, imageView: self.discImage, initials: initials, label: self.discInitials, size: diameter)
        
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
        self.discContainer.frame = CGRect(origin: CGPoint(), size: CGSize(width: frame.width, height: frame.width))
        self.discImage.frame = self.discContainer.frame
        ScorecardUI.veryRoundCorners(self.discImage, radius: frame.width/2.0)
        self.discInitials.frame = self.discContainer.frame
        ScorecardUI.veryRoundCorners(self.discContainer, radius: frame.width/2.0)
        self.name.frame = (CGRect(x: 0.0, y: frame.width - 5.0, width: frame.width, height: frame.height - frame.width + 5.0))
    }
    
    public func set(textColor: UIColor) {
        self.name.textColor = textColor
    }
    
}
