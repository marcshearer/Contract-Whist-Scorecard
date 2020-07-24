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
    @IBOutlet private weak var roundedView: UIView!
    @IBOutlet private weak var backgroundImageView: UIImageView!
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var countBadgeView: UILabel!
    
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
        self.roundedView.layoutIfNeeded()
        self.roundedView.roundCorners(cornerRadius: 8.0)
        self.countBadgeView.layoutIfNeeded()
        self.countBadgeView.roundCorners(cornerRadius: self.countBadgeView.frame.height / 2)
    }
    
    public func set(award: Award, alpha: CGFloat = 1.0, showBadge: Bool = true) {
        self.roundedView.backgroundColor = award.backgroundColor.withAlphaComponent(alpha)
        self.backgroundImageView?.image = (award.backgroundImageName == nil ? nil : UIImage(named: award.backgroundImageName!))
        self.backgroundImageView?.alpha = alpha
        self.imageView?.image = UIImage(named: award.imageName)
        if award.count <= 1 || !showBadge{
            self.countBadgeView.isHidden = true
        } else {
            self.countBadgeView.isHidden = false
            self.countBadgeView.text = "\(award.count)"
            self.countBadgeView.backgroundColor = Palette.banner
            self.countBadgeView.textColor = Palette.bannerText
        }
    }
    
    private func loadAwardView() {
        Bundle.main.loadNibNamed("AwardView", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    
}
