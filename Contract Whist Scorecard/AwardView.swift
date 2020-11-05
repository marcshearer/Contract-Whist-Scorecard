//
//  AwardView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 24/07/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import Foundation
import UIKit

class AwardView: UIView {
        
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var roundedBackgroundView: UIView!
    @IBOutlet private weak var roundedView: UIView!
    @IBOutlet private weak var backgroundImageView: UIImageView!
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var countBadgeLabel: UILabel!
    @IBOutlet private weak var countBadgeImageView: UIImageView!
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.loadAwardView()
    }
    
    override init(frame: CGRect) {
        super.init(frame:frame)
        self.loadAwardView()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.roundedBackgroundView.layoutIfNeeded()
        self.roundedView.layoutIfNeeded()
        self.roundedBackgroundView.roundCorners(cornerRadius: 12.0)
        self.roundedView.roundCorners(cornerRadius: 12.0)
        self.countBadgeLabel.layoutIfNeeded()
        self.countBadgeLabel.roundCorners(cornerRadius: self.countBadgeLabel.frame.height / 2)
    }
    
    public func set(award: Award, alpha: CGFloat = 1.0, showBadge: Bool = true) {
        self.roundedView.backgroundColor = award.backgroundColor.withAlphaComponent(alpha)
        self.roundedBackgroundView.backgroundColor = UIColor.white // To allow correct alpha on non-white backgrounds
        self.backgroundImageView?.image = (award.backgroundImageName == nil ? nil : UIImage(named: award.backgroundImageName!))
        self.backgroundImageView?.alpha = alpha
        self.imageView?.image = UIImage(named: award.imageName)
        if award.count <= 1 || !showBadge {
            self.countBadgeLabel.isHidden = true
            self.countBadgeImageView.isHidden = true
        } else {
            self.countBadgeLabel.isHidden = false
            self.countBadgeImageView.isHidden = false
            self.countBadgeLabel.text = "\(award.count)"
            self.countBadgeLabel.textColor = Palette.banner.text
            self.countBadgeImageView.image = UIImage(named: "award")?.asTemplate
            self.countBadgeImageView.tintColor = Palette.banner.background
        }
    }
    
    private func loadAwardView() {
        Bundle.main.loadNibNamed("AwardView", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    
}
