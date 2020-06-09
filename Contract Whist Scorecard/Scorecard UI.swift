//
//  Scorecard UI.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 03/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit

class ScorecardUI {
    
    class func gradient(_ view: UIView, color: UIColor, gradients: [(alpha: CGFloat, location: CGFloat)], overrideWidth: CGFloat? = nil, overrideHeight: CGFloat? = nil) -> CAGradientLayer {
        let gradient = CAGradientLayer()
        gradient.frame = CGRect(x: view.bounds.minX, y: view.bounds.minY, width: overrideWidth ?? view.bounds.width, height: overrideHeight ?? view.bounds.height)
        gradient.colors = gradients.map { color.withAlphaComponent($0.alpha).cgColor }
        gradient.locations = gradients.map { $0.location as NSNumber }
        view.layer.sublayers?.forEach {
            if let layer = $0 as? CAGradientLayer {
                layer.removeFromSuperlayer()
            }
        }
        
        view.layer.insertSublayer(gradient, at: 0)
        return gradient
    }
    
    class func roundCorners(_ view: UIView, percent: CGFloat = 0.0, radius: CGFloat? = nil) {
        if radius != nil {
            view.layer.cornerRadius = radius!
        } else if percent == 0.0 {
            view.layer.cornerRadius = 5
        } else {
            view.layer.cornerRadius = view.layer.bounds.width * (percent/100.0)
        }
        view.layer.masksToBounds = true
    }
    
    class func veryRoundCorners(_ view: UIView, radius: CGFloat? = nil) {
        ScorecardUI.roundCorners(view, percent: ((radius ?? 0.0) == 0.0 ? 50.0 : 0.0), radius: (radius == 0.0 ? nil : radius))
    }
    
    class func largeBoldStyle(_ label: UILabel) {
        label.font = UIFont.boldSystemFont(ofSize: 20.0)
    }

    class func largeBoldStyle(_ textView: UITextView) {
        textView.font = UIFont.boldSystemFont(ofSize: 20.0)
    }

    class func showSegmented(segmented: UISegmentedControl?, isEnabled: Bool) {
        
        if segmented != nil {
            segmented?.isEnabled = isEnabled
            segmented?.alpha = isEnabled ? 1.0 : 0.3
        }
    }
    
    class func keepPopupPosition(viewController: UIViewController) -> CGRect {
        return (viewController.popoverPresentationController?.sourceRect)!
    }
    
    class func selectBackground(size: CGSize, backgroundImage: UIImageView) {
        if size.height > size.width {
            backgroundImage.image = UIImage(named: "background portrait")
        } else {
            backgroundImage.image = UIImage(named: "background landscape")
        }
    }
    
    class func setToolbarClear(toolbar: UIToolbar) {
        toolbar.setBackgroundImage(UIImage(),
                                        forToolbarPosition: .any,
                                        barMetrics: .default)
        toolbar.setShadowImage(UIImage(), forToolbarPosition: .any)
        toolbar.backgroundColor = UIColor.clear
        toolbar.tintColor = UIColor.clear
    }
    
    class func landscapePhone() -> Bool {
        return UIScreen.main.traitCollection.verticalSizeClass == .compact
    }
    
    class func portraitPhone() -> Bool {
        return UIScreen.main.traitCollection.verticalSizeClass == .regular && UIScreen.main.traitCollection.horizontalSizeClass == .compact
    }
    
    class func phoneSize() -> Bool {
        return UIScreen.main.traitCollection.verticalSizeClass == .compact || UIScreen.main.traitCollection.horizontalSizeClass == .compact
    }
    
    class func smallPhoneSize() -> Bool {
        return (UIScreen.main.traitCollection.verticalSizeClass == .compact || UIScreen.main.traitCollection.horizontalSizeClass == .compact) && min(UIScreen.main.bounds.width, UIScreen.main.bounds.height) <= 320
    }
    
    class func landscape() -> Bool {
        return UIScreen.main.bounds.height < UIScreen.main.bounds.width
    }
    
    class var navigationBarHeight: CGFloat {
        if  UIScreen.main.traitCollection.verticalSizeClass == .compact &&  UIScreen.main.traitCollection.horizontalSizeClass == .compact {
            return 32
        } else {
            return 44
        }
    }
    
    static var screenWidth: CGFloat {
        get {
            return UIScreen.main.bounds.width
        }
    }
    
    static var screenHeight: CGFloat {
        get {
            return UIScreen.main.bounds.height
        }
    }

    static var screenSize: CGSize {
        get {
            return UIScreen.main.bounds.size
        }
    }

}
