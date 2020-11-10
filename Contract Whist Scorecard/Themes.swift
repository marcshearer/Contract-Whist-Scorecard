//
//  Themes.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 28/05/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

enum ThemeAppearance: Int {
    case light = 1
    case dark = 2
    case device = 3
    
    public var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        default:
            return .unspecified
        }
    }
}

enum ThemeName: String, CaseIterable {
    case standard = "Default"
    case alternate = "Alternate"
    case red = "Red"
    case blue = "Blue"
    case green = "Green"
    
    public var description: String {
        switch self {
        case .standard:
            return "Default"
        case .alternate:
            return "Alternate"
        case .red:
            return "Red"
        case .blue:
            return "Blue"
        case .green:
            return "Green"
        }
    }
}

enum ThemeTextType: CaseIterable {
    case normal
    case contrast
    case strong
    case faint
    case theme
}

enum ThemeBackgroundColorName: CaseIterable {
    case alternate
    case background
    case banner
    case bannerShadow
    case bidButton
    case bold
    case buttonFace
    case clear
    case continueButton
    case darkHighlight
    case disabled
    case emphasis
    case error
    case gameBanner
    case gameBannerShadow
    case gameSegmentedControls
    case halo
    case haloDealer
    case hand
    case highlight
    case inputControl
    case instruction
    case madeContract
    case roomInterior
    case sectionHeading
    case tableTop
    case tableTopShadow
    case total
    case thumbnailDisc
    case thumbnailPlaceholder
    case separator
    case grid
    case cardBack
    case cardFace
    case segmentedControls
    case confirmButton
    case otherButton
    case whisper
    case carouselSelected
    case carouselUnselected
    case dark
    case mid
    case alwaysTheme
    case watermark
    case pageIndicator
    case leftSidePanel
    case leftSidePanelBorder
    case rightGameDetailPanel
    case rightGameDetailPanelShadow
    case helpBubble
}

enum ThemeTextColorSetName: CaseIterable {
    case darkBackground
    case midBackground
    case midGameBackground
    case lightBackground
}

enum ThemeSpecificColorName: CaseIterable {
    case suitDiamondsHearts
    case suitClubsSpades
    case suitNoTrumps
    case contractOver
    case contractUnder
    case contractUnderLight
    case contractEqual
    case errorCondition
    case history
    case stats
    case highScores
    case confetti
}

class Theme {
    private var themeName: ThemeName
    private var textColorConfig: [ThemeTextColorSetName: ThemeTextColor] = [:]
    private var backgroundColor: [ThemeBackgroundColorName : UIColor] = [:]
    private var textColor: [ThemeBackgroundColorName : UIColor] = [:]
    private var contrastTextColor: [ThemeBackgroundColorName : UIColor] = [:]
    private var strongTextColor: [ThemeBackgroundColorName : UIColor] = [:]
    private var faintTextColor: [ThemeBackgroundColorName : UIColor] = [:]
    private var themeTextColor: [ThemeBackgroundColorName : UIColor] = [:]
    private var specificColor: [ThemeSpecificColorName : UIColor] = [:]
    private var _icon: String?
    public var icon: String? { self._icon }
    
    init(themeName: ThemeName) {
        self.themeName = themeName
        if let config = Themes.themes[themeName] {
            self._icon = config.icon
            self.defaultTheme(from: config, all: true)
            
            if let basedOn = config.basedOn,
                let basedOnTheme = Themes.themes[basedOn] {
                self.defaultTheme(from: basedOnTheme)
            }
            if config.basedOn != .standard && themeName != .standard {
                if let defaultTheme = Themes.themes[.standard] {
                    self.defaultTheme(from: defaultTheme)
                }
            }
        }
    }
    
    public func background(_ backgroundColorName: ThemeBackgroundColorName, game gameBackgroundColorName: ThemeBackgroundColorName? = nil) -> UIColor {
        if let gameBackgroundColorName = gameBackgroundColorName {
            return self.gameColor(self.backgroundColor[backgroundColorName] ?? UIColor.clear, self.backgroundColor[gameBackgroundColorName])
        } else {
            return self.backgroundColor[backgroundColorName] ?? UIColor.clear
        }
    }
    
    public func text(_ backgroundColorName: ThemeBackgroundColorName, game gameBackgroundColorName: ThemeBackgroundColorName? = nil, textType: ThemeTextType = .normal) -> UIColor {
        switch textType {
        case .contrast:
            return self.contrastText(backgroundColorName, game: gameBackgroundColorName)
        case .strong:
            return self.strongText(backgroundColorName, game: gameBackgroundColorName)
        case .faint:
            return self.faintText(backgroundColorName, game: gameBackgroundColorName)
        case .theme:
            return self.themeText(backgroundColorName, game: gameBackgroundColorName)
        default:
            if let gameBackgroundColorName = gameBackgroundColorName {
                return self.gameColor(self.textColor[backgroundColorName] ?? UIColor.clear, self.textColor[gameBackgroundColorName])
            } else {
                return self.textColor[backgroundColorName] ?? UIColor.clear
            }
        }
    }
    
    public func contrastText(_ backgroundColorName: ThemeBackgroundColorName, game gameBackgroundColorName: ThemeBackgroundColorName? = nil) -> UIColor {
        if let gameBackgroundColorName = gameBackgroundColorName {
            return self.gameColor(self.contrastTextColor[backgroundColorName] ?? UIColor.clear, self.contrastTextColor[gameBackgroundColorName])
        } else {
            return self.contrastTextColor[backgroundColorName] ?? UIColor.clear
        }
    }
    
    public func strongText(_ backgroundColorName: ThemeBackgroundColorName, game gameBackgroundColorName: ThemeBackgroundColorName? = nil) -> UIColor {
        if let gameBackgroundColorName = gameBackgroundColorName {
            return self.gameColor(self.strongTextColor[backgroundColorName] ?? UIColor.clear, self.strongTextColor[gameBackgroundColorName])
        } else {
            return self.strongTextColor[backgroundColorName] ?? UIColor.clear
        }
    }
    
    public func faintText(_ backgroundColorName: ThemeBackgroundColorName, game gameBackgroundColorName: ThemeBackgroundColorName? = nil) -> UIColor {
        if let gameBackgroundColorName = gameBackgroundColorName {
            return self.gameColor(self.faintTextColor[backgroundColorName] ?? UIColor.clear, self.faintTextColor[gameBackgroundColorName])
        } else {
            return self.faintTextColor[backgroundColorName] ?? UIColor.clear
        }
    }
    
    public func themeText(_ backgroundColorName: ThemeBackgroundColorName, game gameBackgroundColorName: ThemeBackgroundColorName? = nil) -> UIColor {
        if let gameBackgroundColorName = gameBackgroundColorName {
            return self.gameColor(self.themeTextColor[backgroundColorName] ?? UIColor.clear, self.themeTextColor[gameBackgroundColorName])
        } else {
            return self.themeTextColor[backgroundColorName] ?? UIColor.clear
        }
    }
    
    public func textColor(textColorSetName: ThemeTextColorSetName, textType: ThemeTextType) -> UIColor? {
        return self.textColorConfig[textColorSetName]?.color(textType)?.uiColor
    }
    
    public func specific(_ specificColorName: ThemeSpecificColorName) -> UIColor {
        return self.specificColor[specificColorName] ?? UIColor.black
    }
    
    private func defaultTheme(from: ThemeConfig, all: Bool = false) {
        // Default in any missing text colors
        for (name, themeTextColor) in from.textColor {
            if all || self.textColorConfig[name] == nil {
                self.textColorConfig[name] = themeTextColor
            }
        }
        
        // Iterate background colors filling in detail
        for (name, themeBackgroundColor) in from.backgroundColor {
            var anyTextColorName: ThemeTextColorSetName
            var darkTextColorName: ThemeTextColorSetName
            if all || self.backgroundColor[name] == nil {
                self.backgroundColor[name] = themeBackgroundColor.backgroundColor.uiColor
            }
            anyTextColorName = themeBackgroundColor.anyTextColorName
            darkTextColorName = themeBackgroundColor.darkTextColorName ?? anyTextColorName
            if let anyTextColor = self.textColorConfig[anyTextColorName] {
                let darkTextColor = self.textColorConfig[darkTextColorName]
                if all || self.textColor[name] == nil {
                    self.textColor[name] = self.color(any: anyTextColor, dark: darkTextColor, .normal)
                }
                if all || self.contrastTextColor[name] == nil {
                    self.contrastTextColor[name] = self.color(any: anyTextColor, dark: darkTextColor, .contrast)
                }
                if all || self.strongTextColor[name] == nil {
                    self.strongTextColor[name] = self.color(any: anyTextColor, dark: darkTextColor, .strong)
                }
                if all || self.faintTextColor[name] == nil {
                    self.faintTextColor[name] = self.color(any: anyTextColor, dark: darkTextColor, .faint)
                }
                if all || self.themeTextColor[name] == nil {
                    self.themeTextColor[name] = self.color(any: anyTextColor, dark: darkTextColor, .theme)
                }
            }
        }
        for (name, themeSpecificColor) in from.specificColor {
            if all || self.specificColor[name] == nil {
                self.specificColor[name] = themeSpecificColor.uiColor
            }
        }
    }
    
    private func color(any anyTextColor: ThemeTextColor, dark darkTextColor: ThemeTextColor?, _ textType: ThemeTextType) -> UIColor {
        let anyTraitColor = anyTextColor.color(textType) ?? anyTextColor.normal!
        
        if let darkTraitColor = darkTextColor?.color(textType) {
            let darkColor = darkTraitColor.darkColor ?? darkTraitColor.anyColor
            return self.traitColor(anyTraitColor.anyColor, darkColor)
        } else {
            return anyTraitColor.uiColor
        }
    }

    private func traitColor(_ anyColor: UIColor, _ darkColor: UIColor?) -> UIColor {
        if let darkColor = darkColor {
            return UIColor(dynamicProvider: { (traitCollection) in
                traitCollection.userInterfaceStyle == .dark ? darkColor : anyColor
                
                })
        } else {
            return anyColor
        }
    }
    
    private func gameColor(_ normalColor: UIColor, _ gameColor: UIColor?) -> UIColor {
        if let gameColor = gameColor {
            return UIColor(dynamicProvider: { (_) in
                Scorecard.shared.useGameColor ? gameColor : normalColor
                
                })
        } else {
            return normalColor
        }
    }
}

class ThemeTraitColor {
    fileprivate let anyColor: UIColor
    fileprivate let darkColor: UIColor?
    
    init(_ anyColor: UIColor, _ darkColor: UIColor? = nil) {
        self.anyColor = anyColor
        self.darkColor = darkColor
    }
    
    public var uiColor: UIColor {
        UIColor(dynamicProvider: { (traitCollection) in
            if traitCollection.userInterfaceStyle == .dark {
                return self.darkColor ?? self.anyColor
            } else {
                return self.anyColor
            }
        })
    }
}

class ThemeColor {
    fileprivate let backgroundColor: ThemeTraitColor
    fileprivate let anyTextColorName: ThemeTextColorSetName
    fileprivate let darkTextColorName: ThemeTextColorSetName?
    
    init(_ anyColor: UIColor, _ darkColor: UIColor? = nil, _ anyTextColorName: ThemeTextColorSetName, _ darkTextColorName: ThemeTextColorSetName? = nil) {
        self.backgroundColor = ThemeTraitColor(anyColor, darkColor)
        self.anyTextColorName = anyTextColorName
        self.darkTextColorName = darkTextColorName
    }
}

class ThemeTextColor {
    fileprivate var normal: ThemeTraitColor?
    fileprivate var contrast: ThemeTraitColor?
    fileprivate var strong: ThemeTraitColor?
    fileprivate var faint: ThemeTraitColor?
    fileprivate var theme: ThemeTraitColor?

    init(normal normalAny: UIColor, _ normalDark: UIColor? = nil, contrast contrastAny: UIColor? = nil, _ contrastDark: UIColor? = nil, strong strongAny: UIColor? = nil, _ strongDark: UIColor? = nil, faint faintAny: UIColor? = nil, _ faintDark: UIColor? = nil, theme themeAny: UIColor? = nil, _ themeDark: UIColor? = nil) {
        self.normal = self.traitColor(normalAny, normalDark)!
        self.contrast = self.traitColor(contrastAny, contrastDark)
        self.strong = self.traitColor(strongAny, strongDark)
        self.faint = self.traitColor(faintAny, faintDark)
        self.theme = self.traitColor(themeAny, themeDark)
    }
    
    fileprivate func color(_ textType: ThemeTextType) -> ThemeTraitColor? {
        switch textType {
        case .normal:
            return self.normal
        case .contrast:
            return self.contrast
        case .strong:
            return self.strong
        case .faint:
            return self.faint
        case .theme:
            return self.theme
        }
    }
    
    private func traitColor(_ anyColor: UIColor?, _ darkColor: UIColor? = nil) -> ThemeTraitColor? {
        if let anyColor = anyColor {
            return ThemeTraitColor(anyColor, darkColor)
        } else {
            return nil
        }
    }
}

class ThemeConfig {
    
    let basedOn: ThemeName?
    let icon: String?
    var backgroundColor: [ThemeBackgroundColorName: ThemeColor]
    var textColor: [ThemeTextColorSetName: ThemeTextColor]
    var specificColor: [ThemeSpecificColorName: ThemeTraitColor]
    
    init(basedOn: ThemeName? = nil, icon: String? = nil, background backgroundColor: [ThemeBackgroundColorName : ThemeColor], text textColor: [ThemeTextColorSetName : ThemeTextColor], specific specificColor: [ThemeSpecificColorName: ThemeTraitColor] = [:]) {
        self.basedOn = basedOn
        self.icon = icon
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.specificColor = specificColor
    }
}


class Themes {
    
    public static var currentTheme: Theme!
    
    fileprivate static let themes: [ThemeName : ThemeConfig] = [
        .standard : ThemeConfig(
            background: [
                .alternate                   : ThemeColor(#colorLiteral(red: 0.9724639058, green: 0.9726034999, blue: 0.9724336267, alpha: 1), nil, .lightBackground), //w
                .background                  : ThemeColor(#colorLiteral(red: 0.9724639058, green: 0.9726034999, blue: 0.9724336267, alpha: 1), #colorLiteral(red: 0.2605174184, green: 0.2605243921, blue: 0.260520637, alpha: 1),  .lightBackground, .darkBackground), //w
                .mid                         : ThemeColor(#colorLiteral(red: 0.9724639058, green: 0.9726034999, blue: 0.9724336267, alpha: 1), #colorLiteral(red: 0.2605174184, green: 0.2605243921, blue: 0.260520637, alpha: 1),  .lightBackground, .darkBackground), //      Home screen No devices... background
                .dark                        : ThemeColor(#colorLiteral(red: 0.9098039216, green: 0.9098039216, blue: 0.9098039216, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1),  .lightBackground, .darkBackground), //      Home screen & Results background
                .banner                      : ThemeColor(#colorLiteral(red: 0.6745098039, green: 0.2196078431, blue: 0.2, alpha: 1), #colorLiteral(red: 0.1298420429, green: 0.1298461258, blue: 0.1298439503, alpha: 1),  .midBackground,   .darkBackground),   //1     Banner
                .bannerShadow                : ThemeColor(#colorLiteral(red: 0.7294117647, green: 0.2392156863, blue: 0.2156862745, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1),  .midBackground,   .darkBackground),
                .carouselSelected            : ThemeColor(#colorLiteral(red: 0.7294117647, green: 0.2392156863, blue: 0.2156862745, alpha: 1), nil, .midBackground),
                .carouselUnselected          : ThemeColor(#colorLiteral(red: 0.9724639058, green: 0.9726034999, blue: 0.9724336267, alpha: 1), nil, .lightBackground),
                .bidButton                   : ThemeColor(#colorLiteral(red: 0.7164452672, green: 0.7218510509, blue: 0.7215295434, alpha: 1), nil, .midBackground),
                .buttonFace                  : ThemeColor(#colorLiteral(red: 1, green: 1, blue: 1, alpha: 1), #colorLiteral(red: 0.2605174184, green: 0.2605243921, blue: 0.260520637, alpha: 1),  .lightBackground, .darkBackground), //w
                .cardFace                    : ThemeColor(#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), nil, .lightBackground), //w
                .clear                       : ThemeColor(#colorLiteral(red: 0, green: 0, blue: 0, alpha: 0), nil, .lightBackground, .darkBackground),
                .continueButton              : ThemeColor(#colorLiteral(red: 0.5215686275, green: 0.6980392157, blue: 0.7058823529, alpha: 1), nil, .midBackground),   //4
                .darkHighlight               : ThemeColor(#colorLiteral(red: 0.4783872962, green: 0.4784596562, blue: 0.4783713818, alpha: 1), nil, .darkBackground),
                .disabled                    : ThemeColor(#colorLiteral(red: 0.8509055972, green: 0.851028502, blue: 0.8508786559, alpha: 1), nil, .lightBackground),
                .emphasis                    : ThemeColor(#colorLiteral(red: 0.6745098039, green: 0.2196078431, blue: 0.2, alpha: 1), nil, .midBackground),   //1   Setting button
                .error                       : ThemeColor(#colorLiteral(red: 0.9166395068, green: 0.1978720129, blue: 0.137429297, alpha: 1), nil, .midBackground),
                .gameBanner                  : ThemeColor(#colorLiteral(red: 0.5215686275, green: 0.6980392157, blue: 0.7058823529, alpha: 1), nil, .midBackground),   //4
                .gameBannerShadow            : ThemeColor(#colorLiteral(red: 0.6470588235, green: 0.7960784314, blue: 0.8039215686, alpha: 1), nil, .midBackground),   //5
                .gameSegmentedControls       : ThemeColor(#colorLiteral(red: 0.5215686275, green: 0.6980392157, blue: 0.7058823529, alpha: 1), nil, .midBackground),   //4        Overide
                .grid                        : ThemeColor(#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), nil, .lightBackground),
                .halo                        : ThemeColor(#colorLiteral(red: 0.9724639058, green: 0.9726034999, blue: 0.9724336267, alpha: 1), nil, .lightBackground),
                .haloDealer                  : ThemeColor(#colorLiteral(red: 0.7294117647, green: 0.2392156863, blue: 0.2156862745, alpha: 1), nil, .midBackground),   //2
                .hand                        : ThemeColor(#colorLiteral(red: 0.5215686275, green: 0.6980392157, blue: 0.7058823529, alpha: 1), nil, .midBackground),
                .highlight                   : ThemeColor(#colorLiteral(red: 0.337254902, green: 0.4509803922, blue: 0.4549019608, alpha: 1), nil, .midBackground),   //1
                .inputControl                : ThemeColor(#colorLiteral(red: 0.9490196078, green: 0.9490196078, blue: 0.9490196078, alpha: 1), nil, .lightBackground), //lg
                .instruction                 : ThemeColor(#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), nil, .lightBackground),
                .madeContract                : ThemeColor(#colorLiteral(red: 0.7333333333, green: 0.8470588235, blue: 0.8549019608, alpha: 1), nil, .midBackground),   //7
                .roomInterior                : ThemeColor(#colorLiteral(red: 0.5215686275, green: 0.6980392157, blue: 0.7058823529, alpha: 1), nil, .midBackground),   //4
                .sectionHeading              : ThemeColor(#colorLiteral(red: 0.6745098039, green: 0.2196078431, blue: 0.2, alpha: 1), #colorLiteral(red: 0.1298420429, green: 0.1298461258, blue: 0.1298439503, alpha: 1),  .midBackground, .darkBackground),   //4
                .segmentedControls           : ThemeColor(#colorLiteral(red: 0.6745098039, green: 0.2196078431, blue: 0.2, alpha: 1), nil, .midBackground),   //4
                .separator                   : ThemeColor(#colorLiteral(red: 0.493078649, green: 0.4981283545, blue: 0.4939036965, alpha: 1), nil, .midBackground),
                .tableTop                    : ThemeColor(#colorLiteral(red: 0.6470588235, green: 0.7960784314, blue: 0.8039215686, alpha: 1), nil, .midBackground),   //5     Table
                .tableTopShadow              : ThemeColor(#colorLiteral(red: 0.5215686275, green: 0.6980392157, blue: 0.7058823529, alpha: 1), nil, .midBackground),   //4
                .total                       : ThemeColor(#colorLiteral(red: 0.337254902, green: 0.4509803922, blue: 0.4549019608, alpha: 1), nil, .midBackground),   //6
                .thumbnailDisc               : ThemeColor(#colorLiteral(red: 0.7294117647, green: 0.2392156863, blue: 0.2156862745, alpha: 1), nil, .midBackground),   //2
                .thumbnailPlaceholder        : ThemeColor(#colorLiteral(red: 0.9724639058, green: 0.9726034999, blue: 0.9724336267, alpha: 1), nil, .lightBackground), //w
                .otherButton                 : ThemeColor(#colorLiteral(red: 0.7018982768, green: 0.7020009756, blue: 0.7018757463, alpha: 1), nil, .midBackground),
                .confirmButton               : ThemeColor(#colorLiteral(red: 0.3292011023, green: 0.4971863031, blue: 0.2595342696, alpha: 1), nil, .midBackground),
                .whisper                     : ThemeColor(#colorLiteral(red: 0.4745098054, green: 0.8392156959, blue: 0.9764705896, alpha: 1), nil, .lightBackground),
                .alwaysTheme                 : ThemeColor(#colorLiteral(red: 0.6745098039, green: 0.2196078431, blue: 0.2, alpha: 1), nil, .midBackground),
                .watermark                   : ThemeColor(#colorLiteral(red: 0.9724639058, green: 0.9726034999, blue: 0.9724336267, alpha: 1), #colorLiteral(red: 0.2195822597, green: 0.2196257114, blue: 0.2195765674, alpha: 1),  .lightBackground, .darkBackground),
                .leftSidePanel               : ThemeColor(#colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1), #colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1),  .darkBackground),
                .leftSidePanelBorder         : ThemeColor(#colorLiteral(red: 0.4509385824, green: 0.4510071278, blue: 0.4509235024, alpha: 1), nil,  .darkBackground),
                .rightGameDetailPanel        : ThemeColor(#colorLiteral(red: 0.7058823529, green: 0.8549019608, blue: 0.862745098, alpha: 1), #colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1),  .midBackground, .darkBackground),
                .rightGameDetailPanelShadow  : ThemeColor(#colorLiteral(red: 0.6274509804, green: 0.7764705882, blue: 0.7843137255, alpha: 1), #colorLiteral(red: 0.2605174184, green: 0.2605243921, blue: 0.260520637, alpha: 1),  .midBackground, .darkBackground),
                .helpBubble                  : ThemeColor(#colorLiteral(red: 0.9215686275, green: 0.9215686275, blue: 1, alpha: 1), nil,  .lightBackground)],

            text: [
                .lightBackground             : ThemeTextColor(normal: #colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1), contrast: #colorLiteral(red: 0.337254902, green: 0.4509803922, blue: 0.4549019608, alpha: 1), strong: #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), faint: #colorLiteral(red: 0.6235294118, green: 0.6235294118, blue: 0.6235294118, alpha: 1), theme: #colorLiteral(red: 0.6745098039, green: 0.2196078431, blue: 0.2, alpha: 1)) ,
                .midBackground               : ThemeTextColor(normal: #colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), contrast: #colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1), strong: #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), theme: #colorLiteral(red: 0.5058823529, green: 0.1647058824, blue: 0.1490196078, alpha: 1), #colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1)) ,
                .midGameBackground           : ThemeTextColor(normal: #colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), contrast: #colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1), strong: #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), theme: #colorLiteral(red: 0.6470588235, green: 0.7960784314, blue: 0.8039215686, alpha: 1))  ,
                .darkBackground              : ThemeTextColor(normal: #colorLiteral(red: 0.9411764706, green: 0.9411764706, blue: 0.9411764706, alpha: 1), contrast: #colorLiteral(red: 0.337254902, green: 0.4509803922, blue: 0.4549019608, alpha: 1), strong: #colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), faint: #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), theme: #colorLiteral(red: 0.6745098039, green: 0.2196078431, blue: 0.2, alpha: 1))] ,
            specific: [
                .contractOver                : ThemeTraitColor(#colorLiteral(red: 0.8621624112, green: 0.1350575387, blue: 0.08568952233, alpha: 1)) ,
                .contractUnder               : ThemeTraitColor(#colorLiteral(red: 0, green: 0.7940098643, blue: 0, alpha: 1)) ,
                .contractUnderLight          : ThemeTraitColor(#colorLiteral(red: 0.7120214701, green: 0.9846614003, blue: 0.5001918077, alpha: 1)) ,
                .contractEqual               : ThemeTraitColor(#colorLiteral(red: 0.5031832457, green: 0.497643888, blue: 0.4938061833, alpha: 1)) ,
                .suitDiamondsHearts          : ThemeTraitColor(#colorLiteral(red: 0.8621624112, green: 0.1350575387, blue: 0.08568952233, alpha: 1)) ,
                .suitClubsSpades             : ThemeTraitColor(#colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)) ,
                .suitNoTrumps                : ThemeTraitColor(#colorLiteral(red: 0, green: 0.003977875225, blue: 0, alpha: 1)) ,
                .errorCondition              : ThemeTraitColor(#colorLiteral(red: 0.9166395068, green: 0.1978720129, blue: 0.137429297, alpha: 1)) ,
                .history                     : ThemeTraitColor(#colorLiteral(red: 0.4516967535, green: 0.7031331658, blue: 0.4579167962, alpha: 1)) ,
                .stats                       : ThemeTraitColor(#colorLiteral(red: 0.9738044143, green: 0.7667216659, blue: 0.003810848575, alpha: 1)) ,
                .highScores                  : ThemeTraitColor(#colorLiteral(red: 0.1997601986, green: 0.4349380136, blue: 0.5107212663, alpha: 1)) ,
                .confetti                    : ThemeTraitColor(#colorLiteral(red: 0.8431372549, green: 0.7176470588, blue: 0.2509803922, alpha: 1))]
            ),
        .alternate: ThemeConfig(
            icon: "AppIcon-Green",
            background: [
                .gameBanner                  : ThemeColor(#colorLiteral(red: 0.4549019608, green: 0.5764705882, blue: 0.5921568627, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1),  .midBackground)   ,
                .emphasis                    : ThemeColor(#colorLiteral(red: 0.4549019608, green: 0.5764705882, blue: 0.5921568627, alpha: 1), nil, .midBackground)   ,
                .banner                      : ThemeColor(#colorLiteral(red: 0.4549019608, green: 0.5764705882, blue: 0.5921568627, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1),  .midBackground)   ,
                .bannerShadow                : ThemeColor(#colorLiteral(red: 0.4078431373, green: 0.5176470588, blue: 0.5294117647, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1),  .midBackground)   ,//3
                .gameBannerShadow            : ThemeColor(#colorLiteral(red: 0.4078431373, green: 0.5176470588, blue: 0.5294117647, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1),  .midBackground)   ,//3
                .sectionHeading              : ThemeColor(#colorLiteral(red: 0.4549019608, green: 0.5764705882, blue: 0.5921568627, alpha: 1), nil, .midBackground)   ,
                .background                  : ThemeColor(#colorLiteral(red: 0.9724639058, green: 0.9726034999, blue: 0.9724336267, alpha: 1), #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1),  .lightBackground) ,
                .roomInterior                : ThemeColor(#colorLiteral(red: 0.4549019608, green: 0.5764705882, blue: 0.5921568627, alpha: 1), #colorLiteral(red: 0.1694289744, green: 0.1694289744, blue: 0.1694289744, alpha: 1),  .midBackground)   ,
                .hand                        : ThemeColor(#colorLiteral(red: 0.4549019608, green: 0.5764705882, blue: 0.5921568627, alpha: 1), #colorLiteral(red: 0.1694289744, green: 0.1694289744, blue: 0.1694289744, alpha: 1),  .midBackground)   ,
                .tableTop                    : ThemeColor(#colorLiteral(red: 0.8235294118, green: 0.7803921569, blue: 0.7333333333, alpha: 1), #colorLiteral(red: 0.2255345461, green: 0.4820669776, blue: 0.2524022623, alpha: 1),  .midBackground)   ],
            text: [
                .lightBackground             : ThemeTextColor(normal: #colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1), contrast: #colorLiteral(red: 0.337254902, green: 0.4509803922, blue: 0.4549019608, alpha: 1), strong: #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), faint: #colorLiteral(red: 0.6235294118, green: 0.6235294118, blue: 0.6235294118, alpha: 1), theme: #colorLiteral(red: 0.4549019608, green: 0.5764705882, blue: 0.5921568627, alpha: 1)) ,
                .midBackground               : ThemeTextColor(normal: #colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), contrast: #colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1), strong: #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), theme: #colorLiteral(red: 0.4078431373, green: 0.5176470588, blue: 0.5294117647, alpha: 1)) ,
                .midGameBackground           : ThemeTextColor(normal: #colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), contrast: #colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1), strong: #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), theme: #colorLiteral(red: 0.4078431373, green: 0.5176470588, blue: 0.5294117647, alpha: 1)) ,
                .darkBackground              : ThemeTextColor(normal: #colorLiteral(red: 0.9411764706, green: 0.9411764706, blue: 0.9411764706, alpha: 1), contrast: #colorLiteral(red: 0.337254902, green: 0.4509803922, blue: 0.4549019608, alpha: 1), strong: #colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), theme: #colorLiteral(red: 0.4549019608, green: 0.5764705882, blue: 0.5921568627, alpha: 1)) ]
            ),
        .red: ThemeConfig(
            background: [
                .emphasis                    : ThemeColor(#colorLiteral(red: 0.6699781418, green: 0.2215877175, blue: 0.2024611831, alpha: 1), nil, .midBackground)   ,
                .banner                      : ThemeColor(#colorLiteral(red: 0.6699781418, green: 0.2215877175, blue: 0.2024611831, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1),  .midBackground)   ,
                .bannerShadow                : ThemeColor(#colorLiteral(red: 0.6901960784, green: 0.2431372549, blue: 0.2235294118, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1),  .midBackground)   ,
                .segmentedControls           : ThemeColor(#colorLiteral(red: 0.6699781418, green: 0.2215877175, blue: 0.2024611831, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1),  .midBackground)   ,
                .gameBannerShadow            : ThemeColor(#colorLiteral(red: 0.2352941176, green: 0.4784313725, blue: 0.5529411765, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1),  .midBackground)   ,
                .gameBanner                  : ThemeColor(#colorLiteral(red: 0.1968964636, green: 0.4390103817, blue: 0.5146722198, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1),  .midBackground)   ,
                .gameSegmentedControls       : ThemeColor(#colorLiteral(red: 0.1968964636, green: 0.4390103817, blue: 0.5146722198, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1),  .midBackground)   ,
                .inputControl                : ThemeColor(#colorLiteral(red: 0.948936522, green: 0.9490727782, blue: 0.9489069581, alpha: 1), nil, .lightBackground) ,
                .sectionHeading              : ThemeColor(#colorLiteral(red: 0.6699781418, green: 0.2215877175, blue: 0.2024611831, alpha: 1), nil, .midBackground)   ],
            text: [
                .lightBackground             : ThemeTextColor(normal: #colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1), contrast: #colorLiteral(red: 0.337254902, green: 0.4509803922, blue: 0.4549019608, alpha: 1), strong: #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), faint: #colorLiteral(red: 0.325458765, green: 0.325510323, blue: 0.3254473805, alpha: 1), theme: #colorLiteral(red: 0.6699781418, green: 0.2215877175, blue: 0.2024611831, alpha: 1)) ,
                .midBackground               : ThemeTextColor(normal: #colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), contrast: #colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1), strong: #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), theme: #colorLiteral(red: 0.5529411765, green: 0.1450980392, blue: 0.1254901961, alpha: 1)) ,
                .midGameBackground           : ThemeTextColor(normal: #colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), contrast: #colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1), strong: #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), theme: #colorLiteral(red: 0.1176470588, green: 0.3607843137, blue: 0.4352941176, alpha: 1)) ,
                .darkBackground              : ThemeTextColor(normal: #colorLiteral(red: 0.9411764706, green: 0.9411764706, blue: 0.9411764706, alpha: 1), contrast: #colorLiteral(red: 0.337254902, green: 0.4509803922, blue: 0.4549019608, alpha: 1), strong: #colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), theme: #colorLiteral(red: 0.6699781418, green: 0.2215877175, blue: 0.2024611831, alpha: 1)) ]
        ),
        .blue: ThemeConfig(
            icon: "AppIcon-Yellow",
            background: [
                .background                  : ThemeColor(#colorLiteral(red: 0.9724639058, green: 0.9726034999, blue: 0.9724336267, alpha: 1), nil, .lightBackground) ,
                .banner                      : ThemeColor(#colorLiteral(red: 0.8961163759, green: 0.7460593581, blue: 0.3743121624, alpha: 1), nil, .midBackground)   ,
                .bannerShadow                : ThemeColor(#colorLiteral(red: 0.9176470588, green: 0.7647058824, blue: 0.3882352941, alpha: 1), nil, .midBackground)   ,
                .bidButton                   : ThemeColor(#colorLiteral(red: 0.7164452672, green: 0.7218510509, blue: 0.7215295434, alpha: 1), nil, .midBackground)   ,
                .bold                        : ThemeColor(#colorLiteral(red: 0, green: 0.1469757259, blue: 0.6975850463, alpha: 1), nil, .darkBackground)  ,
                .buttonFace                  : ThemeColor(#colorLiteral(red: 1, green: 1, blue: 1, alpha: 1), nil, .lightBackground) ,
                .cardBack                    : ThemeColor(#colorLiteral(red: 0.001431431621, green: 0.06626898795, blue: 0.3973870575, alpha: 1), nil, .darkBackground)  ,
                .cardFace                    : ThemeColor(#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), nil, .lightBackground) ,
                .clear                       : ThemeColor(#colorLiteral(red: 0, green: 0, blue: 0, alpha: 0), nil, .midBackground)   ,
                .continueButton              : ThemeColor(#colorLiteral(red: 0.4501074553, green: 0.7069990635, blue: 0.4533855319, alpha: 1), nil, .midBackground)   ,
                .darkHighlight               : ThemeColor(#colorLiteral(red: 0.4783872962, green: 0.4784596562, blue: 0.4783713818, alpha: 1), nil, .darkBackground)  ,
                .disabled                    : ThemeColor(#colorLiteral(red: 0.8509055972, green: 0.851028502, blue: 0.8508786559, alpha: 1), nil, .lightBackground) ,
                .emphasis                    : ThemeColor(#colorLiteral(red: 0.8961163759, green: 0.7460593581, blue: 0.3743121624, alpha: 1), nil, .midBackground)   ,
                .error                       : ThemeColor(#colorLiteral(red: 0.9166395068, green: 0.1978720129, blue: 0.137429297, alpha: 1), nil, .midBackground)   ,
                .gameBanner                  : ThemeColor(#colorLiteral(red: 0.9281279445, green: 0.4577305913, blue: 0.4537009001, alpha: 1), nil, .midBackground)   ,
                .gameBannerShadow            : ThemeColor(#colorLiteral(red: 0.968627451, green: 0.4980392157, blue: 0.4941176471, alpha: 1), nil, .midBackground)   ,
                .gameSegmentedControls       : ThemeColor(#colorLiteral(red: 0.9281279445, green: 0.4577305913, blue: 0.4537009001, alpha: 1), nil, .midBackground)   ,
                .grid                        : ThemeColor(#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), nil, .lightBackground) ,
                .halo                        : ThemeColor(#colorLiteral(red: 0.9724639058, green: 0.9726034999, blue: 0.9724336267, alpha: 1), nil, .lightBackground) ,
                .haloDealer                  : ThemeColor(#colorLiteral(red: 0.9281869531, green: 0.457547009, blue: 0.449475646, alpha: 1), nil, .midBackground)   ,
                .hand                        : ThemeColor(#colorLiteral(red: 0.2931554019, green: 0.6582073569, blue: 0.6451457739, alpha: 1), nil, .midBackground)   ,
                .highlight                   : ThemeColor(#colorLiteral(red: 0.8961690068, green: 0.7459753156, blue: 0.3697274327, alpha: 1), nil, .midBackground)   ,
                .inputControl                : ThemeColor(#colorLiteral(red: 0.9364626408, green: 0.8919522166, blue: 0.7899157405, alpha: 1), nil, .lightBackground) ,
                .instruction                 : ThemeColor(#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), nil, .lightBackground) ,
                .madeContract                : ThemeColor(#colorLiteral(red: 0.5729857087, green: 0.8469169736, blue: 0.7794112563, alpha: 1), nil, .midBackground)   ,
                .roomInterior                : ThemeColor(#colorLiteral(red: 0.3027802706, green: 0.6543570161, blue: 0.6493718624, alpha: 1), nil, .midBackground)   ,
                .sectionHeading              : ThemeColor(#colorLiteral(red: 0.8953641653, green: 0.7500876784, blue: 0.3693457842, alpha: 1), nil, .midBackground)   ,
                .segmentedControls           : ThemeColor(#colorLiteral(red: 0.8991343379, green: 0.7457622886, blue: 0.3696769476, alpha: 1), nil, .midBackground)   ,
                .separator                   : ThemeColor(#colorLiteral(red: 0.493078649, green: 0.4981283545, blue: 0.4939036965, alpha: 1), nil, .midBackground)   ,
                .tableTop                    : ThemeColor(#colorLiteral(red: 0.5406154394, green: 0.8017265201, blue: 0.5650425553, alpha: 1), nil, .midBackground)   ,
                .tableTopShadow              : ThemeColor(#colorLiteral(red: 0.4518489838, green: 0.7030248046, blue: 0.4536508322, alpha: 1), nil, .midBackground)   ,
                .total                       : ThemeColor(#colorLiteral(red: 0.3033464551, green: 0.6547588706, blue: 0.6510065198, alpha: 1), nil, .midBackground)   ,
                .thumbnailDisc               : ThemeColor(#colorLiteral(red: 0.9065005183, green: 0.7187946439, blue: 0.7108055949, alpha: 1), nil, .midBackground)   ,
                .thumbnailPlaceholder        : ThemeColor(#colorLiteral(red: 0.8633580804, green: 0.9319525361, blue: 0.917548418, alpha: 1), nil, .lightBackground) ,
                .otherButton                 : ThemeColor(#colorLiteral(red: 0.7018982768, green: 0.7020009756, blue: 0.7018757463, alpha: 1), nil, .midBackground)   ,
                .confirmButton               : ThemeColor(#colorLiteral(red: 0.3292011023, green: 0.4971863031, blue: 0.2595342696, alpha: 1), nil, .midBackground)   ,
                .leftSidePanel               : ThemeColor(#colorLiteral(red: 0.8196078431, green: 0.6666666667, blue: 0.2941176471, alpha: 1), #colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1),  .lightBackground) ],
            text: [
                .lightBackground             : ThemeTextColor(normal: #colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1), contrast: #colorLiteral(red: 0.337254902, green: 0.4509803922, blue: 0.4549019608, alpha: 1), strong: #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), faint: #colorLiteral(red: 0.8961163759, green: 0.7460593581, blue: 0.3743121624, alpha: 1), theme: #colorLiteral(red: 0.8961163759, green: 0.7460593581, blue: 0.3743121624, alpha: 1)) ,
                .midBackground               : ThemeTextColor(normal: #colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), contrast: #colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1), strong: #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), theme: #colorLiteral(red: 0.8196078431, green: 0.6666666667, blue: 0.2941176471, alpha: 1)) ,
                .midGameBackground           : ThemeTextColor(normal: #colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), contrast: #colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1), strong: #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), theme: #colorLiteral(red: 0.968627451, green: 0.4980392157, blue: 0.4941176471, alpha: 1)) ,
                .darkBackground              : ThemeTextColor(normal: #colorLiteral(red: 0.9411764706, green: 0.9411764706, blue: 0.9411764706, alpha: 1), contrast: #colorLiteral(red: 0.337254902, green: 0.4509803922, blue: 0.4549019608, alpha: 1), strong: #colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), theme: #colorLiteral(red: 0.8961163759, green: 0.7460593581, blue: 0.3743121624, alpha: 1)) ]
        ),
        .green: ThemeConfig(
            icon: "AppIcon-Green",
            background:  [
                .emphasis                    : ThemeColor(#colorLiteral(red: 0.3921568627, green: 0.6509803922, blue: 0.6431372549, alpha: 1), nil, .midBackground) ,
                .banner                      : ThemeColor(#colorLiteral(red: 0.3921568627, green: 0.6509803922, blue: 0.6431372549, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1),  .midBackground) ,
                .gameBannerShadow            : ThemeColor(#colorLiteral(red: 0.431372549, green: 0.6901960784, blue: 0.6823529412, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1),  .midBackground) ,
                .gameBanner                  : ThemeColor(#colorLiteral(red: 0.3921568627, green: 0.6509803922, blue: 0.6431372549, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1),  .midBackground) ,
                .sectionHeading              : ThemeColor(#colorLiteral(red: 0.3921568627, green: 0.6509803922, blue: 0.6431372549, alpha: 1), nil, .midBackground) ],
            text: [
                .lightBackground             : ThemeTextColor(normal: #colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1), contrast: #colorLiteral(red: 0.337254902, green: 0.4509803922, blue: 0.4549019608, alpha: 1), strong: #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), faint: #colorLiteral(red: 0.6235294118, green: 0.6235294118, blue: 0.6235294118, alpha: 1), theme: #colorLiteral(red: 0.3921568627, green: 0.6509803922, blue: 0.6431372549, alpha: 1)) ,
                .midBackground               : ThemeTextColor(normal: #colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), contrast: #colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1), strong: #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), theme: #colorLiteral(red: 0.5058823529, green: 0.1647058824, blue: 0.1490196078, alpha: 1)) ,
                .midGameBackground           : ThemeTextColor(normal: #colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), contrast: #colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1), strong: #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), theme: #colorLiteral(red: 0.3921568627, green: 0.6509803922, blue: 0.6431372549, alpha: 1)) ,
                .darkBackground              : ThemeTextColor(normal: #colorLiteral(red: 0.9411764706, green: 0.9411764706, blue: 0.9411764706, alpha: 1), contrast: #colorLiteral(red: 0.337254902, green: 0.4509803922, blue: 0.4549019608, alpha: 1), strong: #colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), theme: #colorLiteral(red: 0.3921568627, green: 0.6509803922, blue: 0.6431372549, alpha: 1))]
        )
    ]
    
    public static func selectTheme(_ themeName: ThemeName, changeIcon: Bool = false) {
        let oldIcon = Themes.currentTheme?.icon
        Themes.currentTheme = Theme(themeName: themeName)
        let newIcon = Themes.currentTheme.icon
        if UIApplication.shared.supportsAlternateIcons && changeIcon && oldIcon != newIcon {
            Themes.setApplicationIconName(Themes.currentTheme.icon)
        }
    }
    
    private static func setApplicationIconName(_ iconName: String?) {
        if UIApplication.shared.responds(to: #selector(getter: UIApplication.supportsAlternateIcons)) && UIApplication.shared.supportsAlternateIcons {
            
            typealias setAlternateIconName = @convention(c) (NSObject, Selector, NSString?, @escaping (NSError) -> ()) -> ()
            
            let selectorString = "_setAlternateIconName:completionHandler:"
            
            let selector = NSSelectorFromString(selectorString)
            let imp = UIApplication.shared.method(for: selector)
            let method = unsafeBitCast(imp, to: setAlternateIconName.self)
            method(UIApplication.shared, selector, iconName as NSString?, { _ in })
        }
    }
}
