//
//  Palette.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 04/07/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit

class Palette {
    
    // Background colors that vary in/out of games
    static var banner = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.banner, game: .gameBanner) })
    static var segmentedControls = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.segmentedControls, game: .gameSegmentedControls) })
    static var bannerShadow = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.bannerShadow, game: .gameBannerShadow) })
    
    // Other background colors
    static var alternateBackground = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.alternateBackground) })
    static var background = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.background) })
    static var bidButton = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.bidButton) })
    static var bold = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.bold) })
    static var buttonFace = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.buttonFace) })
    static var confirmButton = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.confirmButton) })
    static var otherButton = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.otherButton) })
    static var continueButton = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.continueButton) })
    static var darkHighlight = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.darkHighlight) })
    static var disabled = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.disabled) })
    static var emphasis = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.emphasis) })
    static var error = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.error) })
    static var halo = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.halo) })
    static var haloDealer = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.haloDealer) })
    static var hand = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.hand) })
    static var highlight = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.highlight) })
    static var inputControl = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.inputControl) })
    static var instruction = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.instruction) })
    static var madeContract = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.madeContract) })
    static var roomInterior = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.roomInterior) })
    static var sectionHeading = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.sectionHeading) })
    static var tableTop = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.tableTop) })
    static var tableTopShadow = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.tableTopShadow) })
    static var total = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.total) })
    static var whisper = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.whisper) })
    static var thumbnailDisc = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.thumbnailDisc) })
    static var thumbnailPlaceholder = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.thumbnailPlaceholder) })
    static var thumbnailPlaceholderText = UIColor(dynamicProvider: { (_) in Themes.currentTheme.text(.thumbnailPlaceholder) })
    static var separator = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.separator) })
    static var grid = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.grid) })
    static var cardBack = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.cardBack) })
    static var cardFace = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(.cardFace) })

    // Text colors that vary in/out of games
    static var bannerText = UIColor(dynamicProvider: { (_) in Themes.currentTheme.text(.banner, game: .gameBanner) })
    static var bannerEmbossed = UIColor(dynamicProvider: { (_) in Themes.currentTheme.themeText(.banner, game: .gameBanner) })
    static var bannerTextContrast = UIColor(dynamicProvider: { (_) in Themes.currentTheme.contrastText(.banner, game: .gameBanner) })
    
    // Other text colors
    static var bidButtonText = UIColor(dynamicProvider: { (_) in Themes.currentTheme.text(.bidButton) })
    static var boldText = UIColor(dynamicProvider: { (_) in Themes.currentTheme.text(.bold) })
    static var buttonFaceText = UIColor(dynamicProvider: { (_) in Themes.currentTheme.text(.buttonFace) })
    static var buttonFaceThemeText = UIColor(dynamicProvider: { (_) in Themes.currentTheme.themeText(.buttonFace) })
    static var confirmButtonText = UIColor(dynamicProvider: { (_) in Themes.currentTheme.text(.confirmButton) })
    static var otherButtonText = UIColor(dynamicProvider: { (_) in Themes.currentTheme.text(.otherButton) })
    static var continueButtonText = UIColor(dynamicProvider: { (_) in Themes.currentTheme.text(.continueButton) })
    static var darkHighlightText = UIColor(dynamicProvider: { (_) in Themes.currentTheme.text(.darkHighlight) })
    static var darkHighlightTextContrast = UIColor(dynamicProvider: { (_) in Themes.currentTheme.contrastText(.darkHighlight) })
    static var disabledText = UIColor(dynamicProvider: { (_) in Themes.currentTheme.text(.disabled) })
    static var emphasisText = UIColor(dynamicProvider: { (_) in Themes.currentTheme.text(.emphasis) })
    static var errorText = UIColor(dynamicProvider: { (_) in Themes.currentTheme.text(.error) })
    static var handText = UIColor(dynamicProvider: { (_) in Themes.currentTheme.text(.hand) })
    static var handTextContrast = UIColor(dynamicProvider: { (_) in Themes.currentTheme.contrastText(.hand) })
    static var highlightText = UIColor(dynamicProvider: { (_) in Themes.currentTheme.text(.highlight) })
    static var inputControlText = UIColor(dynamicProvider: { (_) in Themes.currentTheme.text(.inputControl) })
    static var inputControlPlaceholder = UIColor(dynamicProvider: { (_) in Themes.currentTheme.faintText(.inputControl) })
    static var instructionText = UIColor(dynamicProvider: { (_) in Themes.currentTheme.text(.instruction) })
    static var madeContractText = UIColor(dynamicProvider: { (_) in Themes.currentTheme.text(.madeContract) })
    static var roomInteriorText = UIColor(dynamicProvider: { (_) in Themes.currentTheme.text(.roomInterior) })
    static var roomInteriorTextContrast = UIColor(dynamicProvider: { (_) in Themes.currentTheme.contrastText(.roomInterior) })
    static var sectionHeadingText = UIColor(dynamicProvider: { (_) in Themes.currentTheme.text(.sectionHeading) })
    static var sectionHeadingTextContrast = UIColor(dynamicProvider: { (_) in Themes.currentTheme.contrastText(.sectionHeading) })
    static var tableTopText = UIColor(dynamicProvider: { (_) in Themes.currentTheme.text(.tableTop) })
    static var tableTopTextContrast = UIColor(dynamicProvider: { (_) in Themes.currentTheme.contrastText(.tableTop) })
    static var totalText = UIColor(dynamicProvider: { (_) in Themes.currentTheme.text(.total) })
    static var whisperText = UIColor(dynamicProvider: { (_) in Themes.currentTheme.text(.whisper) })
    static var thumbnailDiscText = UIColor(dynamicProvider: { (_) in Themes.currentTheme.text(.thumbnailDisc) })
    static var text = UIColor(dynamicProvider: { (_) in Themes.currentTheme.text(.background) })
    static var textTitle = UIColor(dynamicProvider: { (_) in Themes.currentTheme.strongText(.background) })
    static var textEmphasised = UIColor(dynamicProvider: { (_) in Themes.currentTheme.strongText(.background) })
 
    // Specific colors
    static var suitDiamondsHearts = UIColor(dynamicProvider: { (_) in Themes.currentTheme.specific(.suitDiamondsHearts) })
    static var suitClubsSpades = UIColor(dynamicProvider: { (_) in Themes.currentTheme.specific(.suitClubsSpades) })
    static var suitNoTrumps = UIColor(dynamicProvider: { (_) in Themes.currentTheme.specific(.suitNoTrumps) })
    static var contractOver = UIColor(dynamicProvider: { (_) in Themes.currentTheme.specific(.contractOver) })
    static var contractUnder = UIColor(dynamicProvider: { (_) in Themes.currentTheme.specific(.contractUnder) })
    static var contractUnderLight = UIColor(dynamicProvider: { (_) in Themes.currentTheme.specific(.contractUnderLight) })
    static var contractEqual = UIColor(dynamicProvider: { (_) in Themes.currentTheme.specific(.contractEqual) })
    static var history = UIColor(dynamicProvider: { (_) in Themes.currentTheme.specific(.history) })
    static var stats = UIColor(dynamicProvider: { (_) in Themes.currentTheme.specific(.stats) })
    static var highScores = UIColor(dynamicProvider: { (_) in Themes.currentTheme.specific(.highScores) })
    static var errorCondition = UIColor(dynamicProvider: { (_) in Themes.currentTheme.specific(.error) })
    
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
        label.textColor = Palette.tableTopText
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
            label.textColor = Palette.errorCondition
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
