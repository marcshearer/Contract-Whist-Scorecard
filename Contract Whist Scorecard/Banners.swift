//
//  Banners.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 15/03/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

// Used as a padding view for devices such as iPhone X where there is some space around the safe area

import UIKit

class InsetPaddingViewNoColor: UIView {

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }
}

class InsetPaddingView: InsetPaddingViewNoColor {
    
    @IBInspectable var bannerColor: UIColor
    
    required init(coder aDecoder: NSCoder) {
        self.bannerColor = ScorecardUI.bannerColor
        super.init(coder: aDecoder)
    }

    override func layoutSubviews() {
        self.backgroundColor = self.bannerColor
        super.layoutSubviews()
    }
    
}

class NavigationBar: UINavigationBar {
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setBackgroundImage(UIImage(), for: .default)
        self.shadowImage = UIImage()
        
        let titleLabel = UILabel(frame: CGRect(x: 0.0, y: 0.0, width: self.frame.width - (max(80.0, self.topItem?.leftBarButtonItem?.width ?? 0.0, (self.topItem?.rightBarButtonItem?.width ?? 0.0)) * 2.0), height: self.frame.height))
        titleLabel.backgroundColor = UIColor.clear
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.5
        titleLabel.textAlignment = .center
        self.topItem!.titleView = titleLabel
    }
    
    override func draw(_ rect: CGRect) {
        if let titleText = self.topItem?.title, let titleLabel = self.topItem?.titleView as! UILabel? {
            Constraint.anchor(view: self, control: titleLabel, attributes: .centerX)
            titleLabel.text = titleText
        }
        super.draw(rect)
    }
    
    override func layoutSubviews() {
        self.isTranslucent = false
        self.barTintColor = UIColor(named: "Banner")
        self.backgroundColor = UIColor(named: "Banner")
        
        var fontSize: CGFloat
        if ScorecardUI.landscapePhone() {
            fontSize = min(28.0, CGFloat(Int(UIScreen.main.bounds.width / 14)))
        } else {
            fontSize = min(28.0, CGFloat(Int(UIScreen.main.bounds.width / 12)))
        }
        if let titleLabel = self.topItem?.titleView as! UILabel? {
            titleLabel.font = UIFont.systemFont(ofSize: fontSize, weight: .thin)
            titleLabel.textColor = UIColor.white
        }
        super.layoutSubviews()
    }
    
}

extension UIImage{
    
    func resizeImageWith(height: CGFloat) -> UIImage {
        
        let verticalRatio = height / size.height
        let imageWidth = size.width * verticalRatio
        let screenWidth = UIScreen.main.bounds.width
        let padWidth = (screenWidth - imageWidth) / 2.0
        let padImage = UIImage(named: "navigationPad")?.resizableImage(withCapInsets: UIEdgeInsets(), resizingMode: .stretch)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: screenWidth, height: height))
        let newImage = renderer.image { _ in
            padImage!.draw(in: CGRect(x: 0.0, y: 0.0, width: padWidth, height: height))
            self.draw(in: CGRect(x: padWidth, y: 0.0, width: imageWidth, height: height))
            padImage!.draw(in: CGRect(x: padWidth + imageWidth, y: 0.0, width: padWidth, height: height))
        }
        return newImage
    }
}
