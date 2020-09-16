//
//  Palette.swift.background
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 04/07/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit

class Palette {
    
    // Background colors that vary in/out of games
    @BackgroundColor(.banner, game: .gameBanner) static var banner
    @BackgroundColor(.segmentedControls, game: .gameSegmentedControls) static var segmentedControls
    @BackgroundColor(.bannerShadow, game: .gameBannerShadow) static var bannerShadow
    
    // Other background colors
    @BackgroundColor(.alternate) static var alternate
    @BackgroundColor(.background) static var normal
    @BackgroundColor(.dark) static var dark
    @BackgroundColor(.mid) static var mid
    @BackgroundColor(.bidButton) static var bidButton
    @BackgroundColor(.bold) static var bold
    @BackgroundColor(.buttonFace) static var buttonFace
    @BackgroundColor(.confirmButton) static var confirmButton
    @BackgroundColor(.otherButton) static var otherButton
    @BackgroundColor(.continueButton) static var continueButton
    @BackgroundColor(.darkHighlight) static var darkHighlight
    @BackgroundColor(.disabled) static var disabled
    @BackgroundColor(.emphasis) static var emphasis
    @BackgroundColor(.error) static var error
    @BackgroundColor(.halo) static var halo
    @BackgroundColor(.haloDealer) static var haloDealer
    @BackgroundColor(.hand) static var hand
    @BackgroundColor(.highlight) static var highlight
    @BackgroundColor(.inputControl) static var inputControl
    @BackgroundColor(.instruction) static var instruction
    @BackgroundColor(.madeContract) static var madeContract
    @BackgroundColor(.roomInterior) static var roomInterior
    @BackgroundColor(.sectionHeading) static var sectionHeading
    @BackgroundColor(.tableTop) static var tableTop
    @BackgroundColor(.tableTopShadow) static var tableTopShadow
    @BackgroundColor(.total) static var total
    @BackgroundColor(.whisper) static var whisper
    @BackgroundColor(.thumbnailDisc) static var thumbnailDisc
    @BackgroundColor(.thumbnailPlaceholder) static var thumbnailPlaceholder
    @BackgroundColor(.separator) static var separator
    @BackgroundColor(.grid) static var grid
    @BackgroundColor(.cardFace) static var cardFace
    @BackgroundColor(.carouselSelected) static var carouselSelected
    @BackgroundColor(.carouselUnselected) static var carouselUnselected
    @BackgroundColor(.alwaysTheme) static var alwaysTheme
    @BackgroundColor(.watermark) static var watermark
    @BackgroundColor(.leftSidePanel) static var leftSidePanel
    @BackgroundColor(.leftSidePanelBorder) static var leftSidePanelBorder
    @BackgroundColor(.rightGameDetailPanel) static var rightGameDetailPanel

    // Specific colors
    @SpecificColor(.suitDiamondsHearts) static var suitDiamondsHearts
    @SpecificColor(.suitClubsSpades) static var suitClubsSpades
    @SpecificColor(.suitNoTrumps) static var suitNoTrumps
    @SpecificColor(.contractOver) static var contractOver
    @SpecificColor(.contractUnder) static var contractUnder
    @SpecificColor(.contractUnderLight) static var contractUnderLight
    @SpecificColor(.contractEqual) static var contractEqual
    @SpecificColor(.history) static var history
    @SpecificColor(.stats) static var stats
    @SpecificColor(.highScores) static var highScores
    @SpecificColor(.error) static var errorCondition
    @SpecificColor(.confetti) static var confetti
    
    public static func ignoringGameBanners(actions: ()->()) {
        let gameBanners = Scorecard.shared.useGameColor
        Scorecard.shared.useGameColor = false
        actions()
        Scorecard.shared.useGameColor = gameBanners
    }

    public static func forcingGameBanners(actions: ()->()) {
        let gameBanners = Scorecard.shared.useGameColor
        Scorecard.shared.useGameColor = true
        actions()
        Scorecard.shared.useGameColor = gameBanners
    }
    
    class func colorDetail(color: UIColor) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return (red: red, green: green, blue: blue, alpha: alpha)
    }
    
    class func colorMatch(color: UIColor) -> String {
        var matches = ""
        
        func addColor(_ color: String) {
            if matches == "" {
                matches = color
            } else {
                matches = matches + ", " + color
            }
        }
        
        for colorName in ThemeBackgroundColorName.allCases {
            if color.cgColor == Themes.currentTheme.background(colorName).cgColor {
                addColor("\(colorName)")
            }
        }
        
        for colorName in ThemeTextColorSetName.allCases {
            for colorType in ThemeTextType.allCases {
                if color.cgColor == Themes.currentTheme.textColor(textColorSetName: colorName, textType: colorType)?.cgColor {
                    addColor("\(colorName)-\(colorType)")
                }
            }
        }
        
        for colorName in ThemeSpecificColorName.allCases {
            if color.cgColor == Themes.currentTheme.specific(colorName).cgColor {
                addColor("\(colorName)")
            }
        }
        
        return matches
    }
    
    class func sectionHeadingStyle(_ cell: UITableViewCell) {
        cell.backgroundColor = Palette.sectionHeading.background
        cell.textLabel?.textColor = Palette.sectionHeading.text
    }
    
    class func sectionHeadingStyle(_ label: UILabel, setFont: Bool = true) {
        label.backgroundColor = Palette.sectionHeading.background
        label.textColor = Palette.sectionHeading.text
        if setFont {
            label.font = UIFont.systemFont(ofSize: 17.0, weight: .thin)
        }
    }
    
    class func sectionHeadingStyle(_ cell: UICollectionViewCell) {
        cell.backgroundColor = Palette.sectionHeading.background
    }
    
    class func sectionHeadingStyle(view: UIView) {
        view.backgroundColor = Palette.sectionHeading.background
    }
    
    class func highlightStyle(_ label: UILabel, setFont: Bool = true) {
        label.backgroundColor = Palette.highlight.background
        label.textColor = Palette.highlight.text
        if setFont {
            label.font = UIFont.systemFont(ofSize: 15.0)
        }
    }
    
    class func highlightStyle(view: UIView) {
        view.backgroundColor = Palette.highlight.background
    }
    
    class func highlightStyle(view: UITableViewHeaderFooterView) {
        view.contentView.backgroundColor = Palette.highlight.background
        view.detailTextLabel?.textColor = Palette.highlight.text
    }
    
    class func highlightStyle(_ button: UIButton) {
        button.backgroundColor = Palette.highlight.background
        button.setTitleColor(Palette.highlight.text, for: .normal)
    }
    
    class func darkHighlightStyle(_ label: UILabel, lightText: Bool = true) {
        label.backgroundColor = Palette.darkHighlight.background
        label.textColor = Palette.darkHighlight.text
    }
    
    class func darkHighlightStyle(_ button: UIButton) {
        button.backgroundColor = Palette.darkHighlight.background
        button.setTitleColor(Palette.darkHighlight.text, for: .normal)
    }
    
    class func darkHighlightStyle(view: UIView) {
        view.backgroundColor = Palette.darkHighlight.background
    }
    
    class func emphasisStyle(_ label: UILabel) {
        label.backgroundColor = Palette.emphasis.background
        label.textColor = Palette.emphasis.text
    }
    
    class func emphasisStyle(_ textView: UITextView) {
        textView.backgroundColor = Palette.emphasis.background
        textView.textColor = Palette.emphasis.text
    }
    
    class func emphasisStyle(_ button: UIButton, bigFont: Bool = false) {
        button.backgroundColor = Palette.emphasis.background
        button.setTitleColor(Palette.emphasis.text, for: .normal)
        if bigFont {
            button.titleLabel!.font = UIFont.boldSystemFont(ofSize: 24)
        }
    }
    
    class func emphasisStyle(view: UIView) {
        view.backgroundColor = Palette.emphasis.background
    }
    
    class func bannerStyle(view: UIView) {
        view.backgroundColor = Palette.banner.background
    }
    
    class func bannerStyle(_ cell: UITableViewCell) {
        cell.backgroundColor = Palette.banner.background
        cell.textLabel?.textColor = Palette.banner.text
    }
    
    class func bannerStyle(_ label: UILabel) {
        label.backgroundColor = Palette.banner.background
        label.textColor = Palette.banner.text
    }
    
    class func tableTopStyle(view: UIView) {
        view.backgroundColor = Palette.tableTop.background
    }
    
    class func tableTopStyle(_ label: UILabel) {
        label.backgroundColor = Palette.tableTop.background
        label.textColor = Palette.tableTop.text
    }
    
    class func instructionStyle(_ label: UILabel) {
        label.backgroundColor = Palette.instruction.background
        label.textColor = Palette.instruction.text
    }
    
    class func bidButtonStyle(_ label: UILabel) {
        label.backgroundColor = Palette.bidButton.background
        label.textColor = Palette.bidButton.text
    }
    
    class func totalStyle(_ label: UILabel) {
        label.backgroundColor = Palette.total.background
        label.textColor = Palette.total.text
    }
    
    class func totalStyle(_ button: UIButton, bigFont: Bool = false) {
        button.backgroundColor = Palette.total.background
        button.setTitleColor(Palette.total.text, for: .normal)
        if bigFont {
            button.titleLabel!.font = UIFont.boldSystemFont(ofSize: 24)
        }
    }
    
    class func totalStyle(view: UIView) {
        view.backgroundColor = Palette.total.background
    }
    
    class func errorStyle(_ label: UILabel, errorCondtion: Bool = true) {
        if errorCondtion {
            label.textColor = Palette.errorCondition
        } else {
            label.textColor = Palette.normal.text
        }
    }
    
    class func inverseErrorStyle(_ label: UILabel, errorCondtion: Bool = true) {
        if errorCondtion {
            label.backgroundColor = Palette.error.background
            label.textColor = Palette.error.text
        } else {
            label.backgroundColor = UIColor.clear
            label.textColor = Palette.normal.text
        }
    }
    
    class func inverseErrorStyle(_ button: UIButton) {
        button.backgroundColor = Palette.error.background
        button.setTitleColor(Palette.error.text, for: .normal)
    }
    
    class func normalStyle(_ label: UILabel, setFont: Bool = true) {
        label.backgroundColor = UIColor.clear
        label.textColor = Palette.normal.text
        if setFont {
            label.font = UIFont.systemFont(ofSize: 15.0, weight: .thin)
        }
        label.adjustsFontSizeToFitWidth = true
    }
    
    class func normalStyle(_ cell: UITableViewCell) {
        cell.backgroundColor = UIColor.clear
    }
    
    class func alternateStyle(_ label: UILabel, setFont: Bool = true) {
        label.backgroundColor = Palette.alternate.background
        label.textColor = Palette.normal.text
        if setFont {
            label.font = UIFont.systemFont(ofSize: 15.0, weight: .thin)
        }
        label.adjustsFontSizeToFitWidth = true
    }
    
    class func madeContractStyle(_ label: UILabel, setFont: Bool = true) {
        label.backgroundColor=Palette.madeContract.background
        label.textColor = Palette.madeContract.text
        if setFont {
            label.font = UIFont.boldSystemFont(ofSize: 17.0)
        }
    }
    
    class func thumbnailDiscStyle(_ label: UILabel, setFont: Bool = true) {
        label.backgroundColor=Palette.thumbnailDisc.background
        label.textColor = Palette.thumbnailDisc.text
        if setFont {
            label.font = UIFont.boldSystemFont(ofSize: 20.0)
        }
    }
    
    class func thumbnailPlaceholderStyle(_ label: UILabel, setFont: Bool = true) {
        label.backgroundColor=Palette.thumbnailPlaceholder.background
        label.textColor = Palette.thumbnailPlaceholder.text
        if setFont {
            label.font = UIFont.boldSystemFont(ofSize: 20.0)
        }
    }
}

@propertyWrapper fileprivate final class BackgroundColor {
    var wrappedValue: PaletteColor
    
    fileprivate init(_ colorName: ThemeBackgroundColorName, game gameColorName: ThemeBackgroundColorName? = nil) {
        wrappedValue = PaletteColor(colorName, game: gameColorName)
    }
}

@propertyWrapper fileprivate final class SpecificColor {
    var wrappedValue: UIColor
    
    fileprivate init(_ colorName: ThemeSpecificColorName) {
        wrappedValue = UIColor(dynamicProvider: { (_) in Themes.currentTheme.specific(colorName)})
    }
}

class PaletteColor {
    let background: UIColor
    let text: UIColor
    let contrastText: UIColor
    let strongText: UIColor
    let faintText: UIColor
    let themeText: UIColor
    
    init(_ colorName: ThemeBackgroundColorName, game gameColorName: ThemeBackgroundColorName? = nil) {
        self.background = UIColor(dynamicProvider: { (_) in Themes.currentTheme.background(colorName, game: gameColorName)})
        self.text = UIColor(dynamicProvider: { (_) in Themes.currentTheme.text(colorName, game: gameColorName)})
        self.contrastText = UIColor(dynamicProvider: { (_) in Themes.currentTheme.contrastText(colorName, game: gameColorName)})
        self.strongText = UIColor(dynamicProvider: { (_) in Themes.currentTheme.strongText(colorName, game: gameColorName)})
        self.faintText = UIColor(dynamicProvider: { (_) in Themes.currentTheme.faintText(colorName, game: gameColorName)})
        self.themeText = UIColor(dynamicProvider: { (_) in Themes.currentTheme.themeText(colorName, game: gameColorName)})
    }
    
    public func textColor(_ type: ThemeTextType) -> UIColor {
        switch type {
        case .normal:
            return self.text
        case .contrast:
            return self.contrastText
        case .strong:
            return self.strongText
        case .faint:
            return self.faintText
        case .theme:
            return self.themeText
        }
    }
}
