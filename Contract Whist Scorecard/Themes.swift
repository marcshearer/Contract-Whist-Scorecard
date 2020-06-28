//
//  Themes.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 28/05/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class Themes {
    
    static let themes: [String : Theme] = [
        "Default"         : Theme(description: "Default", color: [
                            .alternateBackground         : (#colorLiteral(red: 0.9724639058, green: 0.9726034999, blue: 0.9724336267, alpha: 1), nil) ,
                            .background                  : (#colorLiteral(red: 0.9724639058, green: 0.9726034999, blue: 0.9724336267, alpha: 1), nil) ,
                            .banner                      : (#colorLiteral(red: 0.8961163759, green: 0.7460593581, blue: 0.3743121624, alpha: 1), nil) ,
                            .bannerShadow                : (#colorLiteral(red: 0.9176470588, green: 0.7647058824, blue: 0.3882352941, alpha: 1), nil) ,
                            .bannerEmbossed              : (#colorLiteral(red: 0.8196078431, green: 0.6666666667, blue: 0.2941176471, alpha: 1), nil) ,
                            .bannerText                  : (#colorLiteral(red: 0.9724639058, green: 0.9726034999, blue: 0.9724336267, alpha: 1), nil) ,
                            .bannerTextContrast          : (#colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), nil) ,
                            .bidButtonText               : (#colorLiteral(red: 0.9724639058, green: 0.9726034999, blue: 0.9724336267, alpha: 1), nil) ,
                            .bidButton                   : (#colorLiteral(red: 0.7164452672, green: 0.7218510509, blue: 0.7215295434, alpha: 1), nil) ,
                            .bold                        : (#colorLiteral(red: 0, green: 0.1469757259, blue: 0.6975850463, alpha: 1), nil) ,
                            .boldText                    : (#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), nil) ,
                            .buttonFace                  : (#colorLiteral(red: 1, green: 1, blue: 1, alpha: 1), nil) ,
                            .buttonFaceText              : (#colorLiteral(red: 0.4989748001, green: 0.494086206, blue: 0.4981276989, alpha: 1), nil) ,
                            .cardBack                    : (#colorLiteral(red: 0.001431431621, green: 0.06626898795, blue: 0.3973870575, alpha: 1), nil) ,
                            .cardFace                    : (#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), nil) ,
                            .clear                       : (#colorLiteral(red: 0, green: 0, blue: 0, alpha: 0), nil) ,
                            .continueButton              : (#colorLiteral(red: 0.4501074553, green: 0.7069990635, blue: 0.4533855319, alpha: 1), nil) ,
                            .continueButtonText          : (#colorLiteral(red: 0.9999429584, green: 0.9998783469, blue: 0.9957619309, alpha: 1), nil) ,
                            .contractOver                : (#colorLiteral(red: 0.8621624112, green: 0.1350575387, blue: 0.08568952233, alpha: 1), nil) ,
                            .contractUnder               : (#colorLiteral(red: 0.7120214701, green: 0.9846614003, blue: 0.5001918077, alpha: 1), nil) ,
                            .contractUnderLight          : (#colorLiteral(red: 0, green: 0.7940098643, blue: 0, alpha: 1), nil) ,
                            .contractEqual               : (#colorLiteral(red: 0.5031832457, green: 0.497643888, blue: 0.4938061833, alpha: 1), nil) ,
                            .darkHighlight               : (#colorLiteral(red: 0.4783872962, green: 0.4784596562, blue: 0.4783713818, alpha: 1), nil) ,
                            .darkHighlightText           : (#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), nil) ,
                            .darkHighlightTextContrast   : (#colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), nil) ,
                            .disabled                    : (#colorLiteral(red: 0.8509055972, green: 0.851028502, blue: 0.8508786559, alpha: 1), nil) ,
                            .disabledText                : (#colorLiteral(red: 0.7489530444, green: 0.7490623593, blue: 0.7489293218, alpha: 1), nil) ,
                            .emphasis                    : (#colorLiteral(red: 0.8961163759, green: 0.7460593581, blue: 0.3743121624, alpha: 1), nil) ,
                            .emphasisText                : (#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), nil) ,
                            .error                       : (#colorLiteral(red: 0.9166395068, green: 0.1978720129, blue: 0.137429297, alpha: 1), nil) ,
                            .errorText                   : (#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), nil) ,
                            .gameBanner                  : (#colorLiteral(red: 0.9281279445, green: 0.4577305913, blue: 0.4537009001, alpha: 1), nil) ,
                            .gameBannerShadow            : (#colorLiteral(red: 0.968627451, green: 0.4980392157, blue: 0.4941176471, alpha: 1), nil) ,
                            .gameBannerText              : (#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), nil) ,
                            .grid                        : (#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), nil) ,
                            .halo                        : (#colorLiteral(red: 0.9724639058, green: 0.9726034999, blue: 0.9724336267, alpha: 1), nil) ,
                            .haloDealer                  : (#colorLiteral(red: 0.9281869531, green: 0.457547009, blue: 0.449475646, alpha: 1), nil) ,
                            .hand                        : (#colorLiteral(red: 0.2931554019, green: 0.6582073569, blue: 0.6451457739, alpha: 1), nil) ,
                            .handText                    : (#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), nil) ,
                            .handTextContrast            : (#colorLiteral(red: 0.1357744634, green: 0.1417982876, blue: 0.1494296193, alpha: 1), nil) ,
                            .highlight                   : (#colorLiteral(red: 0.8961690068, green: 0.7459753156, blue: 0.3697274327, alpha: 1), nil) ,
                            .highlightText               : (#colorLiteral(red: 0.4940722585, green: 0.4941466451, blue: 0.4940558672, alpha: 1), nil) ,
                            .inputControl                : (#colorLiteral(red: 0.9364626408, green: 0.8919522166, blue: 0.7899157405, alpha: 1), nil) ,
                            .inputControlText            : (#colorLiteral(red: 0.496999979, green: 0.502050221, blue: 0.4978249073, alpha: 1), nil) ,
                            .inputControlPlaceholder     : (#colorLiteral(red: 0.8961163759, green: 0.7460593581, blue: 0.3743121624, alpha: 1), nil) ,
                            .instruction                 : (#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), nil) ,
                            .instructionText             : (#colorLiteral(red: 0.5000878572, green: 0.4899184704, blue: 0.4941580892, alpha: 1), nil) ,
                            .madeContract                : (#colorLiteral(red: 0.5729857087, green: 0.8469169736, blue: 0.7794112563, alpha: 1), nil) ,
                            .madeContractText            : (#colorLiteral(red: 0.4968533516, green: 0.5022311211, blue: 0.5019462109, alpha: 1), nil) ,
                            .roomInterior                : (#colorLiteral(red: 0.3027802706, green: 0.6543570161, blue: 0.6493718624, alpha: 1), nil) ,
                            .roomInteriorText            : (#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), nil) ,
                            .roomInteriorTextContrast    : (#colorLiteral(red: 0.2180397511, green: 0.4786666632, blue: 0.4680786133, alpha: 1), nil) ,
                            .sectionHeading              : (#colorLiteral(red: 0.8953641653, green: 0.7500876784, blue: 0.3693457842, alpha: 1), nil) ,
                            .sectionHeadingText          : (#colorLiteral(red: 0.994867146, green: 1, blue: 0.9999337792, alpha: 1), nil) ,
                            .sectionHeadingTextContrast  : (#colorLiteral(red: 1, green: 0.9960784316, blue: 1, alpha: 1), nil) ,
                            .segmentedControls           : (#colorLiteral(red: 0.8991343379, green: 0.7457622886, blue: 0.3696769476, alpha: 1), nil) ,
                            .separator                   : (#colorLiteral(red: 0.493078649, green: 0.4981283545, blue: 0.4939036965, alpha: 1), nil) ,
                            .shapeAdminStroke            : (#colorLiteral(red: 0.6233272552, green: 0.6237481236, blue: 0.6275730729, alpha: 1), nil) ,
                            .shapeAdminText              : (#colorLiteral(red: 0.2823249698, green: 0.2823707461, blue: 0.2823149562, alpha: 1), nil) ,
                            .shapeAdminFill              : (#colorLiteral(red: 0.7736085057, green: 0.7684281468, blue: 0.7684865594, alpha: 1), nil) ,
                            .shapeFillText               : (#colorLiteral(red: 0.9423670173, green: 0.9368831515, blue: 0.9329733849, alpha: 1), nil) ,
                            .shapeFill                   : (#colorLiteral(red: 0.4834339023, green: 0.4782161713, blue: 0.4783229828, alpha: 1), nil) ,
                            .shapeHighlightStrokeText    : (#colorLiteral(red: 0.942510128, green: 0.9367026687, blue: 0.9288505912, alpha: 1), nil) ,
                            .shapeHighlightStroke        : (#colorLiteral(red: 0.8072894216, green: 0.4530420899, blue: 0.436080873, alpha: 1), nil) ,
                            .shapeHighlightFillText      : (#colorLiteral(red: 0.9423670173, green: 0.9368831515, blue: 0.9329733849, alpha: 1), nil) ,
                            .shapeHighlightFill          : (#colorLiteral(red: 0.9231505394, green: 0.4626418352, blue: 0.4536400437, alpha: 1), nil) ,
                            .shapeStrokeText             : (#colorLiteral(red: 0.9374619126, green: 0.9369455576, blue: 0.9288995266, alpha: 1), nil) ,
                            .shapeStroke                 : (#colorLiteral(red: 0.440299511, green: 0.4350764751, blue: 0.4351904988, alpha: 1), nil) ,
                            .shapeTableLeg               : (#colorLiteral(red: 0.568741858, green: 0.8431518674, blue: 0.779614985, alpha: 1), nil) ,
                            .shapeTableLegShadow         : (#colorLiteral(red: 0.4544042945, green: 0.8055810332, blue: 0.736684382, alpha: 1), nil) ,
                            .suitDiamondsHearts          : (#colorLiteral(red: 0.8621624112, green: 0.1350575387, blue: 0.08568952233, alpha: 1), nil) ,
                            .suitClubsSpades             : (#colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), nil) ,
                            .suitNoTrumps                : (#colorLiteral(red: 0, green: 0.003977875225, blue: 0, alpha: 1), nil) ,
                            .tableTop                    : (#colorLiteral(red: 0.5406154394, green: 0.8017265201, blue: 0.5650425553, alpha: 1), nil) ,
                            .tableTopText                : (#colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), nil) ,
                            .tableTopTextContrast        : (#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), nil) ,
                            .total                       : (#colorLiteral(red: 0.3033464551, green: 0.6547588706, blue: 0.6510065198, alpha: 1), nil) ,
                            .totalText                   : (#colorLiteral(red: 0.9996390939, green: 1, blue: 0.9997561574, alpha: 1), nil) ,
                            .thumbnailDisc               : (#colorLiteral(red: 0.9065005183, green: 0.7187946439, blue: 0.7108055949, alpha: 1), nil) ,
                            .thumbnailDiscText           : (#colorLiteral(red: 0.942510128, green: 0.9367026687, blue: 0.9288505912, alpha: 1), nil) ,
                            .thumbnailPlaceholder        : (#colorLiteral(red: 0.8633580804, green: 0.9319525361, blue: 0.917548418, alpha: 1), nil) ,
                            .thumbnailPlaceholderText    : (#colorLiteral(red: 0.4940722585, green: 0.4941466451, blue: 0.4940558672, alpha: 1), nil) ,
                            .text                        : (#colorLiteral(red: 0.1019607843, green: 0.1019607843, blue: 0.1019607843, alpha: 1), nil) ,
                            .textEmphasised              : (#colorLiteral(red: 0.9009206891, green: 0.745765388, blue: 0.3741720319, alpha: 1), nil) ,
                            .textTitle                   : (#colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1), nil) ,
                            .textError                   : (#colorLiteral(red: 0.9210745692, green: 0.1963090301, blue: 0.1316265166, alpha: 1), nil) ,
                            .textMessage                 : (#colorLiteral(red: 0, green: 0.4733380675, blue: 0.9991257787, alpha: 1), nil) ,
                            .history                     : (#colorLiteral(red: 0.4516967535, green: 0.7031331658, blue: 0.4579167962, alpha: 1), nil) ,
                            .stats                       : (#colorLiteral(red: 0.9738044143, green: 0.7667216659, blue: 0.003810848575, alpha: 1), nil) ,
                            .highScores                  : (#colorLiteral(red: 0.1997601986, green: 0.4349380136, blue: 0.5107212663, alpha: 1), nil) ]),

            
        "Alternate"         : Theme(description: "Alternate", color: [
                            .textEmphasised             : (#colorLiteral(red: 0.03921568627, green: 0.5529411765, blue: 1, alpha: 1), nil) ,
                            .gameBanner                 : (#colorLiteral(red: 0, green: 0.4733380675, blue: 0.9991257787, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,
                            .emphasis                   : (#colorLiteral(red: 0, green: 0.4733380675, blue: 0.9991257787, alpha: 1), nil) ,
                            .banner                     : (#colorLiteral(red: 0, green: 0.4733380675, blue: 0.9991257787, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,
                            .bannerEmbossed             : (#colorLiteral(red: 0, green: 0.3960784314, blue: 0.9215686275, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,
                            .bannerShadow               : (#colorLiteral(red: 0.03921568627, green: 0.5529411765, blue: 1, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,
                            .gameBannerShadow           : (#colorLiteral(red: 0.03921568627, green: 0.5529411765, blue: 1, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,
                            .sectionHeading             : (#colorLiteral(red: 0, green: 0.4733380675, blue: 0.9991257787, alpha: 1), nil) ,
                            .sectionHeadingText         : (#colorLiteral(red: 0.994867146, green: 1, blue: 0.9999337792, alpha: 1), nil) ,
                            .background                 : (#colorLiteral(red: 0.9724639058, green: 0.9726034999, blue: 0.9724336267, alpha: 1), #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1))  ,
                            .roomInterior               : (#colorLiteral(red: 1, green: 1, blue: 1, alpha: 1), #colorLiteral(red: 0.1694289744, green: 0.1694289744, blue: 0.1694289744, alpha: 1))  ,
                            .hand                       : (#colorLiteral(red: 0.2931554019, green: 0.6582073569, blue: 0.6451457739, alpha: 1), #colorLiteral(red: 0.1694289744, green: 0.1694289744, blue: 0.1694289744, alpha: 1))  ,
                            .tableTop                   : (#colorLiteral(red: 0.5406154394, green: 0.8017265201, blue: 0.5650425553, alpha: 1), #colorLiteral(red: 0.2255345461, green: 0.4820669776, blue: 0.2524022623, alpha: 1))  ]),
        
        "Red"               : Theme(description: "Red", color: [
                            .textEmphasised             : (#colorLiteral(red: 0.6699781418, green: 0.2215877175, blue: 0.2024611831, alpha: 1), nil) ,
                            .emphasis                   : (#colorLiteral(red: 0.6699781418, green: 0.2215877175, blue: 0.2024611831, alpha: 1), nil) ,
                            .banner                     : (#colorLiteral(red: 0.6699781418, green: 0.2215877175, blue: 0.2024611831, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,
                            .bannerEmbossed             : (#colorLiteral(red: 0.5529411765, green: 0.1450980392, blue: 0.1254901961, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,
                            .bannerShadow               : (#colorLiteral(red: 0.6901960784, green: 0.2431372549, blue: 0.2235294118, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,
                            .gameBannerShadow           : (#colorLiteral(red: 0.6901960784, green: 0.2431372549, blue: 0.2235294118, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,
                            .gameBanner                 : (#colorLiteral(red: 0.6699781418, green: 0.2215877175, blue: 0.2024611831, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,
                            .sectionHeading             : (#colorLiteral(red: 0.6699781418, green: 0.2215877175, blue: 0.2024611831, alpha: 1), nil) ,
                            .sectionHeadingText         : (#colorLiteral(red: 0.994867146, green: 1, blue: 0.9999337792, alpha: 1), nil) ]),

        "Blue"              : Theme(description: "Blue", color: [
                            .textEmphasised             : (#colorLiteral(red: 0, green: 0.4733380675, blue: 0.9991257787, alpha: 1), nil) ,
                            .emphasis                   : (#colorLiteral(red: 0, green: 0.4733380675, blue: 0.9991257787, alpha: 1), nil) ,
                            .banner                     : (#colorLiteral(red: 0, green: 0.4733380675, blue: 0.9991257787, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,
                            .bannerEmbossed             : (#colorLiteral(red: 0, green: 0.3960784314, blue: 0.9215686275, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,
                            .bannerShadow               : (#colorLiteral(red: 0.03921568627, green: 0.5529411765, blue: 1, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,
                            .gameBannerShadow           : (#colorLiteral(red: 0.03921568627, green: 0.5529411765, blue: 1, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,
                            .gameBanner                 : (#colorLiteral(red: 0, green: 0.4733380675, blue: 0.9991257787, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,
                            .sectionHeading             : (#colorLiteral(red: 0, green: 0.4733380675, blue: 0.9991257787, alpha: 1), nil) ,
                            .sectionHeadingText         : (#colorLiteral(red: 0.994867146, green: 1, blue: 0.9999337792, alpha: 1), nil) ]),
        
        "Green"             : Theme(description: "Green", color: [
                            .textEmphasised             : (#colorLiteral(red: 0.3921568627, green: 0.6509803922, blue: 0.6431372549, alpha: 1), nil) ,
                            .emphasis                   : (#colorLiteral(red: 0.3921568627, green: 0.6509803922, blue: 0.6431372549, alpha: 1), nil) ,
                            .banner                     : (#colorLiteral(red: 0.3921568627, green: 0.6509803922, blue: 0.6431372549, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,
                            .gameBannerShadow           : (#colorLiteral(red: 0.431372549, green: 0.6901960784, blue: 0.6823529412, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,
                            .gameBanner                 : (#colorLiteral(red: 0.3921568627, green: 0.6509803922, blue: 0.6431372549, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,
                            .sectionHeading             : (#colorLiteral(red: 0.3921568627, green: 0.6509803922, blue: 0.6431372549, alpha: 1), nil) ,
                            .sectionHeadingText         : (#colorLiteral(red: 0.994867146, green: 1, blue: 0.9999337792, alpha: 1), nil) ])]

    
    static var currentTheme: Theme!
    static var defaultName = "Default"
    
    static func selectTheme(name: String) {
        self.currentTheme = Themes.themes[name]
        if let basedOn = self.currentTheme.basedOn,
            let basedOnTheme = self.themes[basedOn] {
            self.defaultTheme(to: self.currentTheme, from: basedOnTheme)
        }
        if self.currentTheme.basedOn != self.defaultName {
            if let defaultTheme = self.themes[self.defaultName] {
                self.defaultTheme(to: self.currentTheme, from: defaultTheme)
            }
        }
    }
    
    static func defaultTheme(to: Theme, from: Theme) {
        for (name, value) in from.color {
            if to.color[name] == nil {
                to.color[name] = value
            }
        }
    }
    
    static func color(_ themeColor: ThemeColor, _ traitCollection: UITraitCollection = UITraitCollection.current) -> UIColor {
        return self.currentTheme.getColor(themeColor, traitCollection)
    }
}

class Theme {
    
    let description: String
    let basedOn: String?
    var color: [ThemeColor : (any: UIColor , dark: UIColor?)]
    
    init(description: String, basedOn: String? = nil, color: [ThemeColor : (any: UIColor, dark: UIColor?)]) {
        self.description = description
        self.basedOn = basedOn
        self.color = color
    }
    
    public func color(_ themeColor: ThemeColor, _ traitCollection: UITraitCollection = UITraitCollection.current) -> UIColor {
        return UIColor(dynamicProvider: { (traitCollection) in return self.getColor(themeColor, traitCollection) })
    }
    
    fileprivate func getColor(_ themeColor: ThemeColor, _ traitCollection: UITraitCollection) -> UIColor {
        var color: UIColor
        
        if self.color[themeColor]?.any == nil {
            if let basedOn = self.basedOn, let basedOnTheme = Themes.themes[basedOn] {
                color = basedOnTheme.getColor(themeColor, traitCollection)
            } else {
                color = Themes.themes[Themes.defaultName]?.getColor(themeColor, traitCollection) ?? UIColor.clear
            }
        } else {
            if UITraitCollection.current.userInterfaceStyle == .dark && self.color[themeColor]?.dark != nil {
                color = self.color[themeColor]?.dark ?? UIColor.clear
            } else {
                color = self.color[themeColor]?.any ?? UIColor.clear
            }
        }
        return color
    }

}

enum ThemeColor: String {
    case alternateBackground = "Alternate Background"
    case background = "Background"
    case banner = "Banner"
    case bannerShadow = "Banner Shadow"
    case bannerText = "Banner Text"
    case bannerTextContrast = "Banner Text Contrast"
    case bannerEmbossed = "Banner Embossed"
    case bidButton = "Bid Button"
    case bidButtonText = "Bid Button Text"
    case bold = "Bold"
    case boldText = "Bold Text"
    case buttonFace = "Button Face"
    case buttonFaceText = "Button Face Text"
    case clear = "Clear"
    case continueButton = "Continue Button"
    case continueButtonText = "Continue Button Text"
    case darkHighlight = "Dark Highlight"
    case darkHighlightText = "Dark Highlight Text"
    case darkHighlightTextContrast = "Dark Highlight Text Contrast"
    case disabledText = "Disabled Text"
    case disabled = "Disabled"
    case emphasis = "Emphasis"
    case emphasisText = "Emphasis Text"
    case error = "Error"
    case errorText = "Error Text"
    case gameBanner = "Game Banner"
    case gameBannerShadow = "Game Banner Shadow"
    case gameBannerText = "Game Banner Text"
    case halo = "Halo"
    case haloDealer = "Halo Dealer"
    case hand = "Hand"
    case handText = "Hand Text"
    case handTextContrast = "Hand Text Contrast"
    case highlight = "Highlight"
    case highlightText = "Highlight Text"
    case inputControl = "Input Control"
    case inputControlText = "Input Control Text"
    case inputControlPlaceholder = "Input Control Placeholder"
    case instruction = "Instruction"
    case instructionText = "Instruction Text"
    case madeContract = "Made Contract"
    case madeContractText = "Made Contract Text"
    case roomInterior = "Room Interior"
    case roomInteriorText = "Room Interior Text"
    case roomInteriorTextContrast = "Room Interior Text Contrast"
    case sectionHeading = "Section Heading"
    case sectionHeadingText = "Section Heading Text"
    case sectionHeadingTextContrast = "Section Heading Text Contrast"
    case tableTop = "Table Top"
    case tableTopText = "Table Top Text"
    case tableTopTextContrast = "Table Top Text Contrast"
    case total = "Total"
    case totalText = "Total Text"
    case thumbnailDisc = "Thumbnail Disc"
    case thumbnailDiscText = "Thumbnail Disc Text"
    case thumbnailPlaceholder = "Thumbnail Placeholder"
    case thumbnailPlaceholderText = "Thumbnail Placeholder Text"
    case separator = "Separator"
    case grid = "Grid"
    case text = "Text"
    case textEmphasised = "Text Emphasised"
    case textTitle = "Text Title"
    case textError = "Text Error"
    case textMessage = "Text Message"
    case shapeStrokeText = "Shape Stroke Text"
    case shapeStroke = "Shape Stroke"
    case shapeFillText = "Shape Fill Text"
    case shapeFill = "Shape Fill"
    case shapeAdminStroke = "Shape Admin Stroke"
    case shapeAdminText = "Shape Admin Text"
    case shapeAdminFill = "Shape Admin Fill"
    case shapeHighlightStrokeText = "Shape Highlight Stroke Text"
    case shapeHighlightStroke = "Shape Highlight Stroke"
    case shapeHighlightFillText = "Shape Highlight Fill Text"
    case shapeHighlightFill = "Shape Highlight Fill"
    case shapeTableLeg = "Shape Table Leg"
    case shapeTableLegShadow = "Shape Table Leg Shadow"
    case suitDiamondsHearts = "Suit Diamonds Hearts"
    case suitClubsSpades = "Suit Clubs Spades"
    case suitNoTrumps = "Suit No Trumps"
    case cardBack = "Card Back"
    case cardFace = "Card Face"
    case contractOver = "Contract Over"
    case contractUnder = "Contract Under"
    case contractUnderLight = "Contract Under Light"
    case contractEqual = "Contract Equal"
    case segmentedControls = "Segmented Controls"
    case history = "History"
    case stats = "Stats"
    case highScores = "High Scores"
}
