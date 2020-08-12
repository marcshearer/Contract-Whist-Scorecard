//
//  AwardDetailView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 18/07/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

enum AwardDetailMode {
    case awarding
    case awarded
    case toBeAwarded
}

class AwardDetailView: UIView {
        
    private var tapGesture: UITapGestureRecognizer!
    
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var exitButton: UIButton!
    @IBOutlet private weak var shadowView: UIView!
    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var awardView: AwardView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var otherLabel: UILabel!
    @IBOutlet private weak var countBadgeLabel: UILabel!
    @IBOutlet private weak var countBadgeImageView: UIImageView!
    @IBOutlet private var labels: [UILabel]!
 
    @objc internal func viewTapped(_ touch: UITapGestureRecognizer) {
        // Ignore tap unless it is outside the popup view or inside the exit button
        if !self.shadowView.frame.contains(touch.location(in: self.contentView)) || self.exitButton.frame.contains(touch.location(in: self.shadowView)) {
            self.hide()
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.loadAwardDetailView()
    }
    
    override init(frame: CGRect) {
        super.init(frame:frame)
        self.loadAwardDetailView()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.shadowView.roundCorners(cornerRadius: 16.0)
        self.contentView.addShadow(shadowSize: CGSize(width: 8.0, height: 8.0), shadowColor: UIColor.black)
    }
    
    public func set(awards: Awards, playerUUID: String, award: Award, mode: AwardDetailMode, backgroundColor: UIColor? = nil, textColor: UIColor? = nil) {
        self.nameLabel.text = award.name
        self.titleLabel.text = award.title
        let alpha: CGFloat = (mode == .toBeAwarded ? 0.5 : 1.0)
        self.awardView.set(award: award, alpha: alpha, showBadge: false)
        if let backgroundColor = backgroundColor {
            self.shadowView.backgroundColor = backgroundColor
        }
        if let textColor = textColor {
            self.labels.forEach{(label) in label.textColor = textColor}
            self.exitButton.tintColor = textColor
        }
        switch mode {
        case .awarding:
            self.otherLabel.text = ""
        case .awarded:
            self.otherLabel.text = Utility.dateString(award.dateAwarded!, style: .full)
        case .toBeAwarded:
            let levels = awards.toAchieve(playerUUID: playerUUID, code: award.code)
            if levels.count > 1 {
                var text = "Award levels: \(levels.first!)"
                for index in 1..<levels.count {
                    text += ", \(levels[index])"
                }
                self.otherLabel.text = text
            }
        }
        
        if award.count <= 1 {
            self.countBadgeLabel.isHidden = true
            self.countBadgeImageView.isHidden = true
        } else {
            self.countBadgeLabel.isHidden = false
            self.countBadgeImageView.isHidden = false
            self.countBadgeLabel.text = "\(award.count <= 9 ? "x" : "")\(award.count)"
            self.countBadgeLabel.textColor = Palette.banner.text
            self.countBadgeImageView.image = UIImage(named: "award")?.asTemplate()
            self.countBadgeImageView.tintColor = Palette.banner.background
        }
        
        self.layoutSubviews()
    }
    
    public func show(from sourceView: UIView, hideBackground: Bool = true) {
        self.contentView.frame = sourceView.frame
        self.setNeedsLayout()
        self.layoutIfNeeded()
        self.layoutSubviews()
        if hideBackground {
            self.contentView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        }
        sourceView.addSubview(self)
        sourceView.bringSubviewToFront(self)
    }
    
    public func hide() {
        self.removeFromSuperview()
    }
    
    private func loadAwardDetailView() {
        Bundle.main.loadNibNamed("AwardDetailView", owner: self, options: nil)
        self.addSubview(contentView)
        self.contentView.frame = self.bounds
        self.contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        self.shadowView.backgroundColor = Palette.buttonFace.background
        self.labels.forEach{(label) in label.textColor = Palette.buttonFace.text}
        self.exitButton.setImage(UIImage(named: "cross white")?.asTemplate(), for: .normal)
        self.exitButton.tintColor = Palette.buttonFace.text
    
        self.tapGesture = UITapGestureRecognizer(target: self, action: #selector(AwardDetailView.viewTapped(_:)))
        self.addGestureRecognizer(self.tapGesture)
        self.isUserInteractionEnabled = true
    }
}
