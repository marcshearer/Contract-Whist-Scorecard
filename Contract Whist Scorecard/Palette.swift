//
//  Palette.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 04/07/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit

class Palette {
    
    static var alternateBackground = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.alternateBackground, traitCollection)})
    static var background = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.background, traitCollection)})
    static var banner = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.gameColor(.banner, .gameBanner, traitCollection)})
    static var bannerEmbossed = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.gameColor(.bannerEmbossed, .gameBannerEmbossed, traitCollection)})
    static var bannerShadow = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.gameColor(.bannerShadow, .gameBannerShadow, traitCollection)})
    static var bannerText = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.gameColor(.bannerText, .gameBannerText, traitCollection)})
    static var bannerTextContrast = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.gameColor(.bannerTextContrast, .gameBannerTextContrast, traitCollection)})
    static var bidButton = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.bidButton, traitCollection)})
    static var bidButtonText = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.bidButtonText, traitCollection)})
    static var bold = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.bold, traitCollection)})
    static var boldText = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.boldText, traitCollection)})
    static var buttonFace = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.buttonFace, traitCollection)})
    static var buttonFaceText = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.buttonFaceText, traitCollection)})
    static var confirmButton = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.confirmButton, traitCollection)})
    static var confirmButtonText = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.confirmButtonText, traitCollection)})
    static var otherButton = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.otherButton, traitCollection)})
    static var otherButtonText = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.otherButtonText, traitCollection)})
    static var continueButton = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.continueButton, traitCollection)})
    static var continueButtonText = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.continueButtonText, traitCollection)})
    static var darkHighlight = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.darkHighlight, traitCollection)})
    static var darkHighlightText = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.darkHighlightText, traitCollection)})
    static var darkHighlightTextContrast = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.darkHighlightTextContrast, traitCollection)})
    static var disabledText = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.disabledText, traitCollection)})
    static var disabled = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.disabled, traitCollection)})
    static var emphasis = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.emphasis, traitCollection)})
    static var emphasisText = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.emphasisText, traitCollection)})
    static var error = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.error, traitCollection)})
    static var errorText = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.errorText, traitCollection)})
    static var halo = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.halo, traitCollection)})
    static var haloDealer = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.haloDealer, traitCollection)})
    static var hand = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.hand, traitCollection)})
    static var handText = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.handText, traitCollection)})
    static var handTextContrast = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.handTextContrast, traitCollection)})
    static var highlight = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.highlight, traitCollection)})
    static var highlightText = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.highlightText, traitCollection)})
    static var inputControl = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.inputControl, traitCollection)})
    static var inputControlText = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.inputControlText, traitCollection)})
    static var inputControlPlaceholder = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.inputControlPlaceholder, traitCollection)})
    static var instruction = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.instruction, traitCollection)})
    static var instructionText = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.instructionText, traitCollection)})
    static var madeContract = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.madeContract, traitCollection)})
    static var madeContractText = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.madeContractText, traitCollection)})
    static var roomInterior = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.roomInterior, traitCollection)})
    static var roomInteriorText = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.roomInteriorText, traitCollection)})
    static var roomInteriorTextContrast = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.roomInteriorTextContrast, traitCollection)})
    static var sectionHeading = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.sectionHeading, traitCollection)})
    static var sectionHeadingText = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.sectionHeadingText, traitCollection)})
    static var sectionHeadingTextContrast = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.sectionHeadingTextContrast, traitCollection)})
    static var tableTop = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.tableTop, traitCollection)})
    static var tableTopShadow = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.tableTopShadow, traitCollection)})
    static var tableTopText = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.tableTopText, traitCollection)})
    static var tableTopTextContrast = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.tableTopTextContrast, traitCollection)})
    static var total = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.total, traitCollection)})
    static var totalText = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.totalText, traitCollection)})
    static var thumbnailDisc = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.thumbnailDisc, traitCollection)})
    static var thumbnailDiscText = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.thumbnailDiscText, traitCollection)})
    static var thumbnailPlaceholder = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.thumbnailPlaceholder, traitCollection)})
    static var thumbnailPlaceholderText = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.thumbnailPlaceholderText, traitCollection)})
    static var separator = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.separator, traitCollection)})
    static var grid = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.grid, traitCollection)})
    static var text = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.text, traitCollection)})
    static var textTitle = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.textTitle, traitCollection)})
    static var textEmphasised = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.textEmphasised, traitCollection)})
    static var textError = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.textError, traitCollection)})
    static var textMessage = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.textMessage, traitCollection)})
    static var suitDiamondsHearts = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.suitDiamondsHearts, traitCollection)})
    static var suitClubsSpades = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.suitClubsSpades, traitCollection)})
    static var suitNoTrumps = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.suitNoTrumps, traitCollection)})
    static var cardBack = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.cardBack, traitCollection)})
    static var cardFace = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.cardFace, traitCollection)})
    static var contractOver = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.contractOver, traitCollection)})
    static var contractUnder = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.contractUnder, traitCollection)})
    static var contractUnderLight = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.contractUnderLight, traitCollection)})
    static var contractEqual = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.contractEqual, traitCollection)})
    static var segmentedControls = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.segmentedControls, traitCollection)})
    static var history = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.history, traitCollection)})
    static var stats = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.stats, traitCollection)})
    static var highScores = UIColor(dynamicProvider:
                        { (traitCollection) in return Themes.color(.highScores, traitCollection)})
    
    class func colorDetail(color: UIColor) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return (red: red, green: green, blue: blue, alpha: alpha)
    }
    
    class func sectionHeadingStyle(_ cell: UITableViewCell) {
        cell.backgroundColor = Palette.sectionHeading
        cell.textLabel?.textColor = Palette.sectionHeadingText
    }
    
    class func sectionHeadingStyle(_ label: UILabel, setFont: Bool = true) {
        label.backgroundColor = Palette.sectionHeading
        label.textColor = Palette.sectionHeadingText
        if setFont {
            label.font = UIFont.systemFont(ofSize: 17.0, weight: .thin)
        }
    }
    
    class func sectionHeadingStyle(_ cell: UICollectionViewCell) {
        cell.backgroundColor = Palette.sectionHeading
    }
    
    class func sectionHeadingStyle(view: UIView) {
        view.backgroundColor = Palette.sectionHeading
    }
    
    class func highlightStyle(_ label: UILabel, setFont: Bool = true) {
        label.backgroundColor = Palette.highlight
        label.textColor = Palette.highlightText
        if setFont {
            label.font = UIFont.systemFont(ofSize: 15.0)
        }
    }
    
    class func highlightStyle(view: UIView) {
        view.backgroundColor = Palette.highlight
    }
    
    class func highlightStyle(view: UITableViewHeaderFooterView) {
        view.contentView.backgroundColor = Palette.highlight
        view.detailTextLabel?.textColor = Palette.highlightText
    }
    
    class func highlightStyle(_ button: UIButton) {
        button.backgroundColor = Palette.highlight
        button.setTitleColor(Palette.highlightText, for: .normal)
    }
    
    class func darkHighlightStyle(_ label: UILabel, lightText: Bool = true) {
        label.backgroundColor = Palette.darkHighlight
        label.textColor = Palette.darkHighlightText
    }
    
    class func darkHighlightStyle(_ button: UIButton) {
        button.backgroundColor = Palette.darkHighlight
        button.setTitleColor(Palette.darkHighlightText, for: .normal)
    }
    
    class func darkHighlightStyle(view: UIView) {
        view.backgroundColor = Palette.darkHighlight
    }
    
    class func emphasisStyle(_ label: UILabel) {
        label.backgroundColor = Palette.emphasis
        label.textColor = Palette.emphasisText
    }
    
    class func emphasisStyle(_ textView: UITextView) {
        textView.backgroundColor = Palette.emphasis
        textView.textColor = Palette.emphasisText
    }
    
    class func emphasisStyle(_ button: UIButton, bigFont: Bool = false) {
        button.backgroundColor = Palette.emphasis
        button.setTitleColor(Palette.emphasisText, for: .normal)
        if bigFont {
            button.titleLabel!.font = UIFont.boldSystemFont(ofSize: 24)
        }
    }
    
    class func emphasisStyle(view: UIView) {
        view.backgroundColor = Palette.emphasis
    }
    
    class func bannerStyle(view: UIView) {
        view.backgroundColor = Palette.banner
    }
    
    class func bannerStyle(_ cell: UITableViewCell) {
        cell.backgroundColor = Palette.banner
        cell.textLabel?.textColor = Palette.bannerText
    }
    
    class func bannerStyle(_ label: UILabel) {
        label.backgroundColor = Palette.banner
        label.textColor = Palette.bannerText
    }
    
    class func tableTopStyle(view: UIView) {
        view.backgroundColor = Palette.tableTop
    }
    
    class func tableTopStyle(_ label: UILabel) {
        label.backgroundColor = Palette.tableTop
        label.textColor = Palette.tableTopTextContrast
    }
    
    class func instructionStyle(_ label: UILabel) {
        label.backgroundColor = Palette.instruction
        label.textColor = Palette.instructionText
    }
    
    class func bidButtonStyle(_ label: UILabel) {
        label.backgroundColor = Palette.bidButton
        label.textColor = Palette.bidButtonText
    }
    
    class func totalStyle(_ label: UILabel) {
        label.backgroundColor = Palette.total
        label.textColor = Palette.totalText
    }
    
    class func totalStyle(_ button: UIButton, bigFont: Bool = false) {
        button.backgroundColor = Palette.total
        button.setTitleColor(Palette.totalText, for: .normal)
        if bigFont {
            button.titleLabel!.font = UIFont.boldSystemFont(ofSize: 24)
        }
    }
    
    class func totalStyle(view: UIView) {
        view.backgroundColor = Palette.total
    }
    
    class func errorStyle(_ label: UILabel, errorCondtion: Bool = true) {
        if errorCondtion {
            label.textColor = Palette.textError
        } else {
            label.textColor = Palette.text
        }
    }
    
    class func inverseErrorStyle(_ label: UILabel, errorCondtion: Bool = true) {
        if errorCondtion {
            label.backgroundColor = Palette.error
            label.textColor = Palette.errorText
        } else {
            label.backgroundColor = UIColor.clear
            label.textColor = Palette.text
        }
    }
    
    class func inverseErrorStyle(_ button: UIButton) {
        button.backgroundColor = Palette.error
        button.setTitleColor(Palette.errorText, for: .normal)
    }
    
    class func normalStyle(_ label: UILabel, setFont: Bool = true) {
        label.backgroundColor = UIColor.clear
        label.textColor = Palette.text
        if setFont {
            label.font = UIFont.systemFont(ofSize: 15.0, weight: .thin)
        }
        label.adjustsFontSizeToFitWidth = true
    }
    
    class func normalStyle(_ cell: UITableViewCell) {
        cell.backgroundColor = UIColor.clear
    }
    
    class func alternateStyle(_ label: UILabel, setFont: Bool = true) {
        label.backgroundColor = Palette.alternateBackground
        label.textColor = Palette.text
        if setFont {
            label.font = UIFont.systemFont(ofSize: 15.0, weight: .thin)
        }
        label.adjustsFontSizeToFitWidth = true
    }
    
    class func madeContractStyle(_ label: UILabel, setFont: Bool = true) {
        label.backgroundColor=Palette.madeContract
        label.textColor = Palette.madeContractText
        if setFont {
            label.font = UIFont.boldSystemFont(ofSize: 17.0)
        }
    }
    
    class func thumbnailDiscStyle(_ label: UILabel, setFont: Bool = true) {
        label.backgroundColor=Palette.thumbnailDisc
        label.textColor = Palette.thumbnailDiscText
        if setFont {
            label.font = UIFont.boldSystemFont(ofSize: 20.0)
        }
    }
    
    class func thumbnailPlaceholderStyle(_ label: UILabel, setFont: Bool = true) {
        label.backgroundColor=Palette.thumbnailPlaceholder
        label.textColor = Palette.thumbnailPlaceholderText
        if setFont {
            label.font = UIFont.boldSystemFont(ofSize: 20.0)
        }
    }
}
