//
//  Scorecard UI.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 03/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit

class ScorecardUI {
    
    // TODO Should name these from XCAssets colors using UIColor(named:) but this is only available in IOS11
    static let darkHighlightColor = UIColor(red: CGFloat(0.85), green: CGFloat(0.85),
                                 blue: CGFloat(0.85), alpha: CGFloat(1.0))
    static let highlightColor = UIColor(red: CGFloat(0.95), green: CGFloat(0.95),
                                     blue: CGFloat(0.95), alpha: CGFloat(1.0))
    static let emphasisColor = UIColor.darkGray
    static let errorColor = UIColor.red
    static let boldColor = UIColor(red: CGFloat(0.0), green: CGFloat(0.0),
                            blue: CGFloat(0.7), alpha: CGFloat(1.0))
    static let totalColor = UIColor(red: CGFloat(0.0), green: CGFloat(0.5), blue: CGFloat(0.5), alpha: CGFloat(1.0))
    static let sectionHeaderBackgroundColor = darkHighlightColor
    static let sectionHeadingBackgroundColor = totalColor
    static let madeContractBackgroundColor = UIColor(red: CGFloat(1.0), green: CGFloat(0.7),
                                                blue: CGFloat(0.7), alpha: CGFloat(1.0))
    static let bannerColor = emphasisColor
    static let tableTopColor = UIColor(red: 0.0, green: 0.635, blue: 0.0, alpha: 1.0)

    class func roundCorners(_ view: UIView, percent: CGFloat = 0.0) {
        if percent == 0.0 {
            view.layer.cornerRadius = 5
        } else {
            view.layer.cornerRadius = view.layer.bounds.height * (percent/100.0)
        }
        view.layer.masksToBounds = true
    }
    
    class func veryRoundCorners(_ view: UIView, radius: CGFloat = 0.0) {
        ScorecardUI.roundCorners(view, percent: 50.0)
    }
    
    class func sectionHeadingStyle(_ cell: UITableViewCell) {
        cell.backgroundColor = ScorecardUI.sectionHeadingBackgroundColor
    }
    
    class func sectionHeadingStyle(_ label: UILabel, setFont: Bool = true) {
        label.backgroundColor = ScorecardUI.sectionHeadingBackgroundColor
        label.textColor = UIColor.white
        if setFont {
            label.font = UIFont.boldSystemFont(ofSize: 17.0)
        }
    }
    
    class func sectionHeadingStyle(_ cell: UICollectionViewCell) {
        cell.backgroundColor = ScorecardUI.sectionHeadingBackgroundColor
    }
    
    class func sectionHeadingStyleView(_ view: UIView) {
        view.backgroundColor = ScorecardUI.sectionHeadingBackgroundColor
    }
    
   class func sectionHeaderStyleView(_ view: UITableViewHeaderFooterView) {
        view.contentView.backgroundColor = ScorecardUI.sectionHeaderBackgroundColor
        view.detailTextLabel?.textColor = UIColor.white
    }

    class func sectionHeaderStyle(_ label: UILabel, setFont: Bool = true) {
        label.backgroundColor = ScorecardUI.sectionHeaderBackgroundColor
        label.textColor = UIColor.lightGray
        if setFont {
            label.font = UIFont.systemFont(ofSize: 15.0)
        }
    }
    
    class func sectionHeaderStyleView(_ view: UIView) {
        view.backgroundColor = ScorecardUI.sectionHeaderBackgroundColor
    }

    class func highlightStyleView(_ view: UIView) {
        view.backgroundColor = ScorecardUI.highlightColor
    }
    
    class func highlightStyle(_ label: UILabel, lightText: Bool = false) {
        label.backgroundColor = ScorecardUI.highlightColor
        label.textColor = lightText ? UIColor.darkGray : UIColor.black
    }
    
    class func highlightStyle(_ button: UIButton) {
        button.backgroundColor = ScorecardUI.highlightColor
        button.setTitleColor(UIColor.black, for: .normal)
    }
    
    class func darkHighlightStyle(_ label: UILabel, lightText: Bool = false) {
        label.backgroundColor = ScorecardUI.darkHighlightColor
        label.textColor = lightText ? UIColor.darkGray : UIColor.black
    }

    class func darkHighlightStyle(_ button: UIButton) {
        button.backgroundColor = ScorecardUI.darkHighlightColor
        button.setTitleColor(UIColor.black, for: .normal)
    }

    class func darkHighlightStyleView(_ view: UIView) {
        view.backgroundColor = ScorecardUI.darkHighlightColor
    }
   
    class func emphasisStyle(_ label: UILabel) {
        label.backgroundColor = ScorecardUI.emphasisColor
        label.textColor = UIColor.white
    }
    
    class func emphasisStyle(_ textView: UITextView) {
        textView.backgroundColor = ScorecardUI.emphasisColor
        textView.textColor = UIColor.white
    }
       
    class func emphasisStyle(_ button: UIButton, bigFont: Bool = false) {
        button.backgroundColor = ScorecardUI.emphasisColor
        button.setTitleColor(UIColor.white, for: .normal)
        if bigFont {
            button.titleLabel!.font = UIFont.boldSystemFont(ofSize: 24)
        }
    }
    
    class func emphasisStyleView(_ view: UIView) {
        view.backgroundColor = ScorecardUI.emphasisColor
    }
    
    class func bannerStyle(_ cell: UITableViewCell) {
        cell.backgroundColor = ScorecardUI.bannerColor
    }

    class func bannerStyle(_ label: UILabel) {
        label.backgroundColor = ScorecardUI.bannerColor
        label.textColor = UIColor.white
    }

    class func totalStyle(_ label: UILabel) {
        label.backgroundColor = ScorecardUI.totalColor
        label.textColor = UIColor.white
    }
    
    class func totalStyle(_ button: UIButton, bigFont: Bool = false) {
        button.backgroundColor = ScorecardUI.totalColor
        button.setTitleColor(UIColor.white, for: .normal)
        if bigFont {
            button.titleLabel!.font = UIFont.boldSystemFont(ofSize: 24)
        }
    }
    
    class func totalStyleView(_ view: UIView) {
        view.backgroundColor = ScorecardUI.totalColor
    }
    
    class func errorStyle(_ label: UILabel, errorCondtion: Bool = true, inverse: Bool = false) {
        if errorCondtion {
            if inverse {
                label.backgroundColor = ScorecardUI.errorColor
                label.textColor = UIColor.white
            } else {
                label.textColor = ScorecardUI.errorColor
            }
        } else {
            if inverse {
                label.backgroundColor = UIColor.clear
            }
            label.textColor = UIColor.black
        }
    }
    
    class func errorStyle(_ button: UIButton) {
        button.backgroundColor = ScorecardUI.errorColor
        button.setTitleColor(UIColor.black, for: .normal)
    }

    class func normalStyle(_ label: UILabel, setFont: Bool = true) {
        label.backgroundColor = UIColor.clear
        label.textColor = UIColor.black
        if setFont {
            label.font = UIFont.systemFont(ofSize: 17.0)
        }
        label.adjustsFontSizeToFitWidth = true
    }
    
    class func normalStyle(_ cell: UITableViewCell) {
        cell.backgroundColor = UIColor.clear
    }
    
    class func boldHeadingStyle(_ cell: UITableViewCell) {
        cell.backgroundColor = ScorecardUI.darkHighlightColor
    }
    
    class func boldHeadingStyle(_ label: UILabel, setFont: Bool = true) {
        label.textColor=UIColor.black
        if setFont {
            label.font = UIFont.boldSystemFont(ofSize: 17.0)
        }
    }

    class func madeContractStyle(_ label: UILabel, setFont: Bool = true) {
        label.backgroundColor=ScorecardUI.madeContractBackgroundColor
        label.textColor = UIColor.black
        if setFont {
            label.font = UIFont.boldSystemFont(ofSize: 17.0)
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
}
