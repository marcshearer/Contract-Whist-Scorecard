//
//  BubbleView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 02/07/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class BubbleView: UIView {
    
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var bubbleView: UIView!
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var label: UILabel!
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.loadBubbleView()
        self.isHidden = true
    }
    
    override init(frame: CGRect) {
        super.init(frame:frame)
        self.loadBubbleView()
        self.isHidden = true
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.toCircle(self.bubbleView)
    }
    
    public func show(from view: UIView, message: String, size: CGFloat = 150, waitFor: TimeInterval = 2.0, completion: (()->())? = nil) {
        
        self.removeFromSuperview()
        view.addSubview(self)
        view.bringSubviewToFront(self)
        
        var y: CGFloat
        if ScorecardUI.landscapePhone() {
            y = view.frame.midY - (size / 2)
        } else {
            y = max(50, view.frame.midY - size)
        }
        
        self.frame = CGRect(x: (view.frame.width - size) / 2, y: y, width: size, height: size)
        self.label.setNeedsLayout()
        self.contentView.layoutIfNeeded()
        self.alpha = 1
        self.label?.text = message
        self.isHidden = false
        self.transform = CGAffineTransform(scaleX: 0, y: 0)

        Utility.animate(duration: 0.25,
            completion: {
                Utility.animate(duration: 0.2, afterDelay: waitFor,
                    completion: {
                        self.transform = CGAffineTransform(scaleX: 1, y: 1)
                        completion?()
                    },
                    animations: {
                        Utility.getActiveViewController()?.alertSound(sound: .lock)
                        self.frame = CGRect(x: view.frame.maxX, y: view.frame.maxY / 8, width: size, height: size)
                        self.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
                        self.alpha = 0
                    })
            },
            animations: {
                self.transform = CGAffineTransform(scaleX: 1, y: 1)
            })
    }
    
    private func loadBubbleView() {
        Bundle.main.loadNibNamed("BubbleView", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        self.bubbleView?.backgroundColor = Palette.banner.background
        
        self.imageView?.image = UIImage(named: "big tick")?.asTemplate
        self.imageView?.tintColor = Palette.banner.text
        
        self.label?.backgroundColor = UIColor.clear
        self.label?.textColor = Palette.banner.text
        
        self.contentView.addShadow(shadowOpacity: 0.5)
    }
    
    private func toCircle(_ view: UIView?) {
        view?.layer.cornerRadius = self.layer.bounds.height / 2
        view?.layer.masksToBounds = true
    }
    
}
