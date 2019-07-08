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
    var normalBackgroundColor = Palette.darkHighlight
    var normalAlpha: CGFloat = 1.0
    var disabledTextColor = UIColor.black
    var disabledBackgroundColor = Palette.highlight
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
        self.normalBackgroundColor = Palette.highlight
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
        self.normalTextColor = Palette.darkHighlightText
        self.normalBackgroundColor = Palette.darkHighlight
        self.normalAlpha = 1.0
        self.disabledTextColor = Palette.darkHighlight
        self.disabledBackgroundColor = Palette.darkHighlight
        self.disabledAlpha = 0.5
        super.isEnabled(true)
    }
}

class EmphasisRoundedButton: RoundedButton {
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.normalTextColor = Palette.emphasisText
        self.normalBackgroundColor = Palette.emphasis
        self.normalAlpha = 1.0
        self.disabledTextColor = Palette.emphasisText
        self.disabledBackgroundColor = Palette.emphasis
        self.disabledAlpha = 0.5
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

class TotalRoundedButton: RoundedButton {
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.normalTextColor = UIColor.white
        self.normalBackgroundColor = Palette.total
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
        self.normalBackgroundColor = Palette.error
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
        self.titleEdgeInsets = UIEdgeInsets.init(top: 0.0, left: -imageSize.width, bottom: -(imageSize.height + self.spacing), right: 0.0)
        let titleSize = title.size(withAttributes: [NSAttributedString.Key.font: self.titleLabel!.font!])
        self.imageEdgeInsets = UIEdgeInsets.init(top: -(titleSize.height + self.spacing), left: 0.0, bottom: 0.0, right: -titleSize.width)
    }
    
    func setImage(_ imageName: String) {
        super.setImage(UIImage(named: imageName), for: .normal)
        var titleSize = CGSize(width: 0, height: 0)
        if self.titleLabel?.text != nil {
            titleSize = self.titleLabel!.text!.size(withAttributes: [NSAttributedString.Key.font: self.titleLabel!.font!])
        }
        self.imageEdgeInsets = UIEdgeInsets.init(top: -(titleSize.height + self.spacing), left: 0.0, bottom: 0.0, right: -titleSize.width)
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


