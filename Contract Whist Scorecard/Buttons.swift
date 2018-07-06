//
//  Buttons.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 09/01/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit

class RoundedButton: UIButton {
    
    var normalTextColor = UIColor.black
    var normalBackgroundColor = ScorecardUI.darkHighlightColor
    var normalAlpha: CGFloat = 1.0
    var disabledTextColor = UIColor.black
    var disabledBackgroundColor = ScorecardUI.highlightColor
    var disabledAlpha: CGFloat = 0.3
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        self.toRounded()
        self.titleLabel?.adjustsFontSizeToFitWidth = true
    }
    
    func isEnabled(_ enabled: Bool) {
        if enabled {
            self.setTitleColor(self.normalTextColor, for: .normal)
            self.backgroundColor = self.normalBackgroundColor
            self.alpha = self.normalAlpha
            self.isEnabled = true
        } else {
            self.setTitleColor(self.disabledTextColor, for: .normal)
            self.backgroundColor = self.disabledBackgroundColor
            self.alpha = self.disabledAlpha
            self.isEnabled = false
        }
    }
    
    func toCircle() {
        self.layer.cornerRadius = self.layer.bounds.height / 2
        self.layer.masksToBounds = true
    }
    
    func toRounded() {
        self.layer.cornerRadius = 5
        self.layer.masksToBounds = true
    }
    
    func toUnrounded() {
        self.layer.cornerRadius = 0
        self.layer.masksToBounds = true
    }
    
    func setTitle(_ title: String) {
        // Set title
        super.setTitle(title, for: .normal)
    }
}

class LightRoundedButton: RoundedButton {
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.normalTextColor = UIColor.black
        self.normalBackgroundColor = ScorecardUI.highlightColor
        self.normalAlpha = 1.0
        self.disabledTextColor = self.normalTextColor
        self.disabledBackgroundColor = self.normalBackgroundColor
        self.disabledAlpha = 0.3
        super.isEnabled(true)
    }
}

class DarkRoundedButton: RoundedButton {
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.normalTextColor = UIColor.white
        self.normalBackgroundColor = ScorecardUI.emphasisColor
        self.normalAlpha = 1.0
        self.disabledTextColor = UIColor.white
        self.disabledBackgroundColor = ScorecardUI.darkHighlightColor
        self.disabledAlpha = 1.0
        super.isEnabled(true)
    }
}

class DarkUnroundedButton: DarkRoundedButton {
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.toUnrounded()
        self.disabledBackgroundColor = self.normalBackgroundColor
        self.disabledTextColor = UIColor.lightGray
        self.disabledAlpha = 0.8
    }
}

class BrightRoundedButton: RoundedButton {
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.normalTextColor = UIColor.white
        self.normalBackgroundColor = ScorecardUI.brightColor
        self.normalAlpha = 1.0
        self.disabledTextColor = self.normalTextColor
        self.disabledBackgroundColor = self.normalBackgroundColor
        self.disabledAlpha = 0.5
        super.isEnabled(true)
    }
}

class ErrorRoundedButton: RoundedButton {
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.normalTextColor = UIColor.white
        self.normalBackgroundColor = ScorecardUI.errorColor
        self.normalAlpha = 1.0
        self.disabledTextColor = self.normalTextColor
        self.disabledBackgroundColor = self.normalBackgroundColor
        self.disabledAlpha = 0.0
        super.isEnabled(true)
    }
}

class ClearButton: RoundedButton {
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.normalTextColor = self.titleColor(for: .normal)! // Leave as declared
        self.normalBackgroundColor = UIColor.clear
        self.normalAlpha = 1.0
        self.disabledTextColor = self.normalTextColor
        self.disabledBackgroundColor = self.normalBackgroundColor
        self.disabledAlpha = 0.3
        super.isEnabled(true)
    }
}

class OutlineButton: ClearButton {

    @IBInspectable
    public var outlineColor: UIColor?
    {
        set (color) {
            self.layer.borderColor = color?.cgColor
        }
        
        get {
            if let color = self.layer.borderColor
            {
                return UIColor(cgColor: color)
            } else {
                return nil
            }
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.layer.borderWidth = 1.0
    }
}

class RightClearButton: ClearButton {
    // Moves the image to the right
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
        self.titleLabel?.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
        self.imageView?.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
    }
}

class ImageButton: RoundedButton {
    
    let spacing: CGFloat = 6.0
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        super.isEnabled(true)
    }
    
    override func setTitle(_ title: String) {
        // Set title
        super.setTitle(title)
    
        let imageSize: CGSize = self.imageView!.image!.size
        self.titleEdgeInsets = UIEdgeInsetsMake(0.0, -imageSize.width, -(imageSize.height + self.spacing), 0.0)
        let titleSize = title.size(withAttributes: [NSAttributedStringKey.font: self.titleLabel!.font])
        self.imageEdgeInsets = UIEdgeInsetsMake(-(titleSize.height + self.spacing), 0.0, 0.0, -titleSize.width)
    }
    
    func setImage(_ imageName: String) {
        super.setImage(UIImage(named: imageName), for: .normal)
        var titleSize = CGSize(width: 0, height: 0)
        if self.titleLabel?.text != nil {
            titleSize = self.titleLabel!.text!.size(withAttributes: [NSAttributedStringKey.font: self.titleLabel!.font])
        }
        self.imageEdgeInsets = UIEdgeInsetsMake(-(titleSize.height + self.spacing), 0.0, 0.0, -titleSize.width)
    }
}

class SideImageButton: RoundedButton {
   
    let spacing: CGFloat = 10.0
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        super.isEnabled(true)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if imageView != nil {
            imageEdgeInsets = UIEdgeInsets(top: spacing, left: spacing, bottom: spacing, right: bounds.width - bounds.height + spacing)
            titleEdgeInsets = UIEdgeInsets(top: spacing, left: spacing, bottom: spacing, right: spacing)
        }
    }
    
    func setImage(_ imageName: String) {
        super.setImage(UIImage(named: imageName), for: .normal)
    }
    
}


