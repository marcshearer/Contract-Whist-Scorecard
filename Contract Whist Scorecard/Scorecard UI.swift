//
//  Scorecard UI.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 03/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit

class ScorecardUI {
    
    class func roundCorners(_ view: UIView, percent: CGFloat = 0.0) {
        if percent == 0.0 {
            view.layer.cornerRadius = 5
        } else {
            view.layer.cornerRadius = view.layer.bounds.height * (percent/100.0)
        }
        view.layer.masksToBounds = true
    }
    
    class func veryRoundCorners(_ view: UIView, radius: CGFloat = 0.0) {
        var percent: CGFloat
        if radius == 0.0 {
            percent = 50.0
        } else if view.layer.bounds.width == 0 {
            percent = 0.0
        } else {
            percent = radius / view.layer.bounds.width * 100.0
        }
        ScorecardUI.roundCorners(view, percent: percent)
    }
    
    class func largeBoldStyle(_ label: UILabel) {
        label.font = UIFont.boldSystemFont(ofSize: 20.0)
    }

    class func largeBoldStyle(_ textView: UITextView) {
        textView.font = UIFont.boldSystemFont(ofSize: 20.0)
    }

    class func swipeBackground1Style(_ rowAction: UITableViewRowAction) {
        rowAction.backgroundColor = UIColor(red: 48.0/255.0, green: 173.0/255.0, blue: 99.0/255.0, alpha: 1.0)
    }
    
    class func swipeBackground2Style(_ rowAction: UITableViewRowAction) {
        rowAction.backgroundColor = UIColor(red: 202.0/255.0, green: 202.0/255.0, blue: 203.0/255.0, alpha: 1.0)
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
    
    class func landscapePhone() -> Bool {
        return UIScreen.main.traitCollection.verticalSizeClass == .compact && UIScreen.main.traitCollection.horizontalSizeClass == .compact
    }
    
    class func portraitPhone() -> Bool {
        return UIScreen.main.traitCollection.verticalSizeClass == .regular && UIScreen.main.traitCollection.horizontalSizeClass == .compact
    }
    
    class func phoneSize() -> Bool {
        return UIScreen.main.traitCollection.verticalSizeClass == .compact || UIScreen.main.traitCollection.horizontalSizeClass == .compact
    }
    
    class func landscape() -> Bool {
        return UIScreen.main.bounds.height < UIScreen.main.bounds.width
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
