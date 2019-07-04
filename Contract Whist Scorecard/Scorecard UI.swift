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
            view.layer.cornerRadius = view.layer.bounds.width * (percent/100.0)
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
    
    class func sectionHeadingStyle(_ cell: UITableViewCell) {
        cell.backgroundColor = ScorecardUI.sectionHeadingColor
        cell.textLabel?.textColor = ScorecardUI.sectionHeadingTextColor
    }
    
    class func sectionHeadingStyle(_ label: UILabel, setFont: Bool = true) {
        label.backgroundColor = ScorecardUI.sectionHeadingColor
        label.textColor = ScorecardUI.sectionHeadingTextColor
        if setFont {
            label.font = UIFont.systemFont(ofSize: 17.0, weight: .thin)
        }
    }
    
    class func sectionHeadingStyle(_ cell: UICollectionViewCell) {
        cell.backgroundColor = ScorecardUI.sectionHeadingColor
    }
    
    class func sectionHeadingStyle(view: UIView) {
        view.backgroundColor = ScorecardUI.sectionHeadingColor
    }
    
    class func highlightStyle(_ label: UILabel, setFont: Bool = true) {
        label.backgroundColor = ScorecardUI.highlightColor
        label.textColor = ScorecardUI.highlightTextColor
        if setFont {
            label.font = UIFont.systemFont(ofSize: 15.0)
        }
    }
    
    class func highlightStyle(view: UIView) {
        view.backgroundColor = ScorecardUI.highlightColor
    }
    
    class func highlightStyle(view: UITableViewHeaderFooterView) {
        view.contentView.backgroundColor = ScorecardUI.highlightColor
        view.detailTextLabel?.textColor = ScorecardUI.highlightTextColor
    }

    class func highlightStyle(_ button: UIButton) {
        button.backgroundColor = ScorecardUI.highlightColor
        button.setTitleColor(ScorecardUI.highlightTextColor, for: .normal)
    }
    
    class func darkHighlightStyle(_ label: UILabel, lightText: Bool = true) {
        label.backgroundColor = ScorecardUI.darkHighlightColor
        label.textColor = ScorecardUI.darkHighlightTextColor
    }

    class func darkHighlightStyle(_ button: UIButton) {
        button.backgroundColor = ScorecardUI.darkHighlightColor
        button.setTitleColor(ScorecardUI.darkHighlightTextColor, for: .normal)
    }

    class func darkHighlightStyle(view: UIView) {
        view.backgroundColor = ScorecardUI.darkHighlightColor
    }
   
    class func emphasisStyle(_ label: UILabel) {
        label.backgroundColor = ScorecardUI.emphasisColor
        label.textColor = ScorecardUI.emphasisTextColor
    }
    
    class func emphasisStyle(_ textView: UITextView) {
        textView.backgroundColor = ScorecardUI.emphasisColor
        textView.textColor = ScorecardUI.emphasisTextColor
    }
       
    class func emphasisStyle(_ button: UIButton, bigFont: Bool = false) {
        button.backgroundColor = ScorecardUI.emphasisColor
        button.setTitleColor(ScorecardUI.emphasisTextColor, for: .normal)
        if bigFont {
            button.titleLabel!.font = UIFont.boldSystemFont(ofSize: 24)
        }
    }
    
    class func emphasisStyle(view: UIView) {
        view.backgroundColor = ScorecardUI.emphasisColor
    }
    
    class func bannerStyle(_ cell: UITableViewCell) {
        cell.backgroundColor = ScorecardUI.bannerColor
        cell.textLabel?.textColor = ScorecardUI.bannerTextColor
    }

    class func bannerStyle(_ label: UILabel) {
        label.backgroundColor = ScorecardUI.bannerColor
        label.textColor = ScorecardUI.bannerTextColor
    }

    class func totalStyle(_ label: UILabel) {
        label.backgroundColor = ScorecardUI.totalColor
        label.textColor = ScorecardUI.totalTextColor
    }
    
    class func totalStyle(_ button: UIButton, bigFont: Bool = false) {
        button.backgroundColor = ScorecardUI.totalColor
        button.setTitleColor(ScorecardUI.totalTextColor, for: .normal)
        if bigFont {
            button.titleLabel!.font = UIFont.boldSystemFont(ofSize: 24)
        }
    }
    
    class func totalStyle(view: UIView) {
        view.backgroundColor = ScorecardUI.totalColor
    }
    
    class func errorStyle(_ label: UILabel, errorCondtion: Bool = true) {
        if errorCondtion {
            label.textColor = ScorecardUI.textErrorColor
        } else {
            label.textColor = ScorecardUI.textColor
        }
    }
    
    class func inverseErrorStyle(_ label: UILabel, errorCondtion: Bool = true) {
        if errorCondtion {
            label.backgroundColor = ScorecardUI.errorColor
            label.textColor = ScorecardUI.errorTextColor
         } else {
            label.backgroundColor = UIColor.clear
            label.textColor = ScorecardUI.textColor
        }
    }
    
    class func inverseErrorStyle(_ button: UIButton) {
        button.backgroundColor = ScorecardUI.errorColor
        button.setTitleColor(ScorecardUI.errorTextColor, for: .normal)
    }

    class func normalStyle(_ label: UILabel, setFont: Bool = true) {
        label.backgroundColor = UIColor.clear
        label.textColor = ScorecardUI.textColor
        if setFont {
            label.font = UIFont.systemFont(ofSize: 15.0, weight: .thin)
        }
        label.adjustsFontSizeToFitWidth = true
    }
    
    class func normalStyle(_ cell: UITableViewCell) {
        cell.backgroundColor = UIColor.clear
    }
    
    class func madeContractStyle(_ label: UILabel, setFont: Bool = true) {
        label.backgroundColor=ScorecardUI.madeContractColor
        label.textColor = ScorecardUI.madeContractTextColor
        if setFont {
            label.font = UIFont.boldSystemFont(ofSize: 17.0)
        }
    }

    class func thumbnailDiscStyle(_ label: UILabel, setFont: Bool = true) {
        label.backgroundColor=ScorecardUI.thumbnailDiscColor
        label.textColor = ScorecardUI.thumbnailDiscTextColor
        if setFont {
            label.font = UIFont.boldSystemFont(ofSize: 20.0)
        }
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
