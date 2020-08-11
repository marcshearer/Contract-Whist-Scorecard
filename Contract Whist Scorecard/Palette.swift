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
    @PaletteBackground(.banner, game: .gameBanner) static var banner
    @PaletteBackground(.segmentedControls, game: .gameSegmentedControls) static var segmentedControls
    @PaletteBackground(.bannerShadow, game: .gameBannerShadow) static var bannerShadow
    
    // Other background colors
    @PaletteBackground(.alternateBackground) static var alternateBackground
    @PaletteBackground(.background) static var background
    @PaletteBackground(.bidButton) static var bidButton
    @PaletteBackground(.bold) static var bold
    @PaletteBackground(.buttonFace) static var buttonFace
    @PaletteBackground(.confirmButton) static var confirmButton
    @PaletteBackground(.otherButton) static var otherButton
    @PaletteBackground(.continueButton) static var continueButton
    @PaletteBackground(.darkHighlight) static var darkHighlight
    @PaletteBackground(.disabled) static var disabled
    @PaletteBackground(.emphasis) static var emphasis
    @PaletteBackground(.error) static var error
    @PaletteBackground(.halo) static var halo
    @PaletteBackground(.haloDealer) static var haloDealer
    @PaletteBackground(.hand) static var hand
    @PaletteBackground(.highlight) static var highlight
    @PaletteBackground(.inputControl) static var inputControl
    @PaletteBackground(.instruction) static var instruction
    @PaletteBackground(.madeContract) static var madeContract
    @PaletteBackground(.roomInterior) static var roomInterior
    @PaletteBackground(.sectionHeading) static var sectionHeading
    @PaletteBackground(.tableTop) static var tableTop
    @PaletteBackground(.tableTopShadow) static var tableTopShadow
    @PaletteBackground(.total) static var total
    @PaletteBackground(.whisper) static var whisper
    @PaletteBackground(.thumbnailDisc) static var thumbnailDisc
    @PaletteBackground(.thumbnailPlaceholder) static var thumbnailPlaceholder
    @PaletteBackground(.separator) static var separator
    @PaletteBackground(.grid) static var grid
    @PaletteBackground(.cardFace) static var cardFace
    @PaletteBackground(.carouselSelected) static var carouselSelected
    @PaletteBackground(.carouselUnselected) static var carouselUnselected
    @PaletteBackground(.darkBackground) static var darkBackground
    @PaletteBackground(.syncButton) static var syncButton

    // Text colors that vary in/out of games
    @PaletteText(.banner, game: .gameBanner) static var bannerText
    @PaletteText(.banner, game: .gameBanner, .theme) static var bannerEmbossed
    @PaletteText(.banner, game: .gameBanner, .contrast) static var bannerTextContrast
    
    // Other text colors
    @PaletteText(.bidButton) static var bidButtonText
    @PaletteText(.buttonFace) static var buttonFaceText
    @PaletteText(.buttonFace, .theme) static var buttonFaceThemeText
    @PaletteText(.confirmButton) static var confirmButtonText
    @PaletteText(.otherButton) static var otherButtonText
    @PaletteText(.continueButton) static var continueButtonText
    @PaletteText(.darkHighlight) static var darkHighlightText
    @PaletteText(.darkHighlight, .contrast) static var darkHighlightTextContrast
    @PaletteText(.disabled) static var disabledText
    @PaletteText(.emphasis) static var emphasisText
    @PaletteText(.error) static var errorText
    @PaletteText(.hand) static var handText
    @PaletteText(.hand, .contrast) static var handTextContrast
    @PaletteText(.highlight) static var highlightText
    @PaletteText(.inputControl) static var inputControlText
    @PaletteText(.inputControl, .faint) static var inputControlPlaceholder
    @PaletteText(.instruction) static var instructionText
    @PaletteText(.madeContract) static var madeContractText
    @PaletteText(.roomInterior) static var roomInteriorText
    @PaletteText(.roomInterior, .contrast) static var roomInteriorTextContrast
    @PaletteText(.sectionHeading) static var sectionHeadingText
    @PaletteText(.sectionHeading, .contrast) static var sectionHeadingTextContrast
    @PaletteText(.tableTop) static var tableTopText
    @PaletteText(.tableTop, .contrast) static var tableTopTextContrast
    @PaletteText(.total) static var totalText
    @PaletteText(.whisper) static var whisperText
    @PaletteText(.syncButton) static var syncButtonText
    @PaletteText(.thumbnailDisc) static var thumbnailDiscText
    @PaletteText(.thumbnailPlaceholder) static var thumbnailPlaceholderText
    @PaletteText(.background) static var text
    @PaletteText(.background, .strong) static var textTitle
    @PaletteText(.background, .strong) static var textEmphasised
    @PaletteText(.carouselSelected) static var carouselSelectedText
    @PaletteText(.carouselSelected, .contrast) static var carouselSelectedTextContrast
    @PaletteText(.carouselUnselected) static var carouselUnselectedText
    @PaletteText(.carouselUnselected, .contrast) static var carouselUnselectedTextContrast

    // Specific colors
    @PaletteSpecific(.suitDiamondsHearts) static var suitDiamondsHearts
    @PaletteSpecific(.suitClubsSpades) static var suitClubsSpades
    @PaletteSpecific(.suitNoTrumps) static var suitNoTrumps
    @PaletteSpecific(.contractOver) static var contractOver
    @PaletteSpecific(.contractUnder) static var contractUnder
    @PaletteSpecific(.contractUnderLight) static var contractUnderLight
    @PaletteSpecific(.contractEqual) static var contractEqual
    @PaletteSpecific(.history) static var history
    @PaletteSpecific(.stats) static var stats
    @PaletteSpecific(.highScores) static var highScores
    @PaletteSpecific(.error) static var errorCondition
    
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

@propertyWrapper fileprivate final class PaletteBackground {
    var wrappedValue: UIColor
    
    fileprivate init(_ colorName: ThemeBackgroundColorName, game gameColorName: ThemeBackgroundColorName? = nil) {
        wrappedValue = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(colorName, game: gameColorName)})
    }
}

@propertyWrapper fileprivate final class PaletteText {
    var wrappedValue: UIColor
    
    fileprivate init(_ colorName: ThemeBackgroundColorName, game gameColorName: ThemeBackgroundColorName? = nil, _ type: ThemeTextType = .normal) {
        switch type {
        case .normal:
            wrappedValue = UIColor(dynamicProvider: { (_) in Themes.currentTheme.text(colorName, game: gameColorName)})
        case .contrast:
            wrappedValue = UIColor(dynamicProvider: { (_) in Themes.currentTheme.contrastText(colorName, game: gameColorName)})
        case .strong:
            wrappedValue = UIColor(dynamicProvider: { (_) in Themes.currentTheme.strongText(colorName, game: gameColorName)})
        case .faint:
            wrappedValue = UIColor(dynamicProvider: { (_) in Themes.currentTheme.faintText(colorName, game: gameColorName)})
        case .theme:
            wrappedValue = UIColor(dynamicProvider: { (_) in Themes.currentTheme.themeText(colorName, game: gameColorName)})
        }
    }
}

@propertyWrapper fileprivate final class PaletteSpecific {
    var wrappedValue: UIColor
    
    fileprivate init(_ colorName: ThemeSpecificColorName) {
        wrappedValue = UIColor(dynamicProvider: { (_) in Themes.currentTheme.specific(colorName)})
    }
}
