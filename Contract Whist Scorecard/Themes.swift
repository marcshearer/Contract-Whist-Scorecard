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
                            .alternateBackground         : (#colorLiteral(red: 0.9724639058, green: 0.9726034999, blue: 0.9724336267, alpha: 1), nil) , //w
                            .background                  : (#colorLiteral(red: 0.9724639058, green: 0.9726034999, blue: 0.9724336267, alpha: 1), nil) , //w
                            .banner                      : (#colorLiteral(red: 0.6745098039, green: 0.2196078431, blue: 0.2, alpha: 1), nil) , //1     Banner
                            .bannerShadow                : (#colorLiteral(red: 0.7294117647, green: 0.2392156863, blue: 0.2156862745, alpha: 1), nil) , //2     Info
                            .bannerEmbossed              : (#colorLiteral(red: 0.5058823529, green: 0.1647058824, blue: 0.1490196078, alpha: 1), nil) , //3     WHIST
                            .bannerText                  : (#colorLiteral(red: 0.9724639058, green: 0.9726034999, blue: 0.9724336267, alpha: 1), nil) , //w
                            .bannerTextContrast          : (#colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1), nil) , //g
                            .bidButtonText               : (#colorLiteral(red: 0.9724639058, green: 0.9726034999, blue: 0.9724336267, alpha: 1), nil) , //w
                            .bidButton                   : (#colorLiteral(red: 0.7164452672, green: 0.7218510509, blue: 0.7215295434, alpha: 1), nil) ,
                            .bold                        : (#colorLiteral(red: 0, green: 0.1469757259, blue: 0.6975850463, alpha: 1), nil) ,
                            .boldText                    : (#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), nil) , //w
                            .buttonFace                  : (#colorLiteral(red: 1, green: 1, blue: 1, alpha: 1), nil) , //w
                            .buttonFaceText              : (#colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1), nil) , //g
                            .cardBack                    : (#colorLiteral(red: 0.001431431621, green: 0.06626898795, blue: 0.3973870575, alpha: 1), nil) ,
                            .cardFace                    : (#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), nil) , //w
                            .clear                       : (#colorLiteral(red: 0, green: 0, blue: 0, alpha: 0), nil) ,
                            .continueButton              : (#colorLiteral(red: 0.5215686275, green: 0.6980392157, blue: 0.7058823529, alpha: 1), nil) , //4
                            .continueButtonText          : (#colorLiteral(red: 0.9999429584, green: 0.9998783469, blue: 0.9957619309, alpha: 1), nil) , //w
                            .contractOver                : (#colorLiteral(red: 0.8621624112, green: 0.1350575387, blue: 0.08568952233, alpha: 1), nil) ,
                            .contractUnder               : (#colorLiteral(red: 0.7120214701, green: 0.9846614003, blue: 0.5001918077, alpha: 1), nil) ,
                            .contractUnderLight          : (#colorLiteral(red: 0, green: 0.7940098643, blue: 0, alpha: 1), nil) ,
                            .contractEqual               : (#colorLiteral(red: 0.5031832457, green: 0.497643888, blue: 0.4938061833, alpha: 1), nil) ,
                            .darkHighlight               : (#colorLiteral(red: 0.4783872962, green: 0.4784596562, blue: 0.4783713818, alpha: 1), nil) ,
                            .darkHighlightText           : (#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), nil) ,
                            .darkHighlightTextContrast   : (#colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), nil) ,
                            .disabled                    : (#colorLiteral(red: 0.8509055972, green: 0.851028502, blue: 0.8508786559, alpha: 1), nil) ,
                            .disabledText                : (#colorLiteral(red: 0.7489530444, green: 0.7490623593, blue: 0.7489293218, alpha: 1), nil) ,
                            .emphasis                    : (#colorLiteral(red: 0.6745098039, green: 0.2196078431, blue: 0.2, alpha: 1), nil) , //1   Setting button
                            .emphasisText                : (#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), nil) ,
                            .error                       : (#colorLiteral(red: 0.9166395068, green: 0.1978720129, blue: 0.137429297, alpha: 1), nil) ,
                            .errorText                   : (#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), nil) ,
                            .gameBanner                  : (#colorLiteral(red: 0.5215686275, green: 0.6980392157, blue: 0.7058823529, alpha: 1), nil) , //4
                            .gameBannerShadow            : (#colorLiteral(red: 0.6470588235, green: 0.7960784314, blue: 0.8039215686, alpha: 1), nil) , //5
                            .gameBannerText              : (#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), nil) ,
                            .gameBannerEmbossed          : (#colorLiteral(red: 0.6470588235, green: 0.7960784314, blue: 0.8039215686, alpha: 1), nil) , //5
                            .gameBannerTextContrast      : (#colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), nil) ,
                            .gameSegmentedControls       : (#colorLiteral(red: 0.5215686275, green: 0.6980392157, blue: 0.7058823529, alpha: 1), nil) , //4        Overide
                            .grid                        : (#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), nil) ,
                            .halo                        : (#colorLiteral(red: 0.9724639058, green: 0.9726034999, blue: 0.9724336267, alpha: 1), nil) ,
                            .haloDealer                  : (#colorLiteral(red: 0.7294117647, green: 0.2392156863, blue: 0.2156862745, alpha: 1), nil) , //2
                            .hand                        : (#colorLiteral(red: 0.5215686275, green: 0.6980392157, blue: 0.7058823529, alpha: 1), nil) ,
                            .handText                    : (#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), nil) ,
                            .handTextContrast            : (#colorLiteral(red: 0.1357744634, green: 0.1417982876, blue: 0.1494296193, alpha: 1), nil) ,
                            .highlight                   : (#colorLiteral(red: 0.337254902, green: 0.4509803922, blue: 0.4549019608, alpha: 1), nil) , //1
                            .highlightText               : (#colorLiteral(red: 0.501960814, green: 0.501960814, blue: 0.501960814, alpha: 1), nil) ,
                            .inputControl                : (#colorLiteral(red: 0.9490196078, green: 0.9490196078, blue: 0.9490196078, alpha: 1), nil) , //lg
                            .inputControlText            : (#colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1), nil) , //g
                            .inputControlPlaceholder     : (#colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1), nil) , //g
                            .instruction                 : (#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), nil) ,
                            .instructionText             : (#colorLiteral(red: 0.5000878572, green: 0.4899184704, blue: 0.4941580892, alpha: 1), nil) ,
                            .madeContract                : (#colorLiteral(red: 0.7333333333, green: 0.8470588235, blue: 0.8549019608, alpha: 1), nil) , //7
                            .madeContractText            : (#colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1), nil) , //g
                            .roomInterior                : (#colorLiteral(red: 0.5215686275, green: 0.6980392157, blue: 0.7058823529, alpha: 1), nil) , //4
                            .roomInteriorText            : (#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), nil) ,
                            .roomInteriorTextContrast    : (#colorLiteral(red: 0.5215686275, green: 0.6980392157, blue: 0.7058823529, alpha: 1), nil) , //4    dealer scorecard
                            .sectionHeading              : (#colorLiteral(red: 0.6745098039, green: 0.2196078431, blue: 0.2, alpha: 1), nil) , //4
                            .sectionHeadingText          : (#colorLiteral(red: 0.994867146, green: 1, blue: 0.9999337792, alpha: 1), nil) ,
                            .sectionHeadingTextContrast  : (#colorLiteral(red: 1, green: 0.9960784316, blue: 1, alpha: 1), nil) ,
                            .segmentedControls           : (#colorLiteral(red: 0.5215686275, green: 0.6980392157, blue: 0.7058823529, alpha: 1), nil) , //4
                            .separator                   : (#colorLiteral(red: 0.493078649, green: 0.4981283545, blue: 0.4939036965, alpha: 1), nil) ,
                            .suitDiamondsHearts          : (#colorLiteral(red: 0.8621624112, green: 0.1350575387, blue: 0.08568952233, alpha: 1), nil) ,
                            .suitClubsSpades             : (#colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), nil) ,
                            .suitNoTrumps                : (#colorLiteral(red: 0, green: 0.003977875225, blue: 0, alpha: 1), nil) ,
                            .tableTop                    : (#colorLiteral(red: 0.6470588235, green: 0.7960784314, blue: 0.8039215686, alpha: 1), nil) , //5     Table
                            .tableTopShadow              : (#colorLiteral(red: 0.5215686275, green: 0.6980392157, blue: 0.7058823529, alpha: 1), nil) , //4
                            .tableTopText                : (#colorLiteral(red: 0, green: 0.003977875225, blue: 0, alpha: 1), nil) , //b
                            .tableTopTextContrast        : (#colorLiteral(red: 0.999904573, green: 1, blue: 0.9998808503, alpha: 1), nil) ,
                            .total                       : (#colorLiteral(red: 0.337254902, green: 0.4509803922, blue: 0.4549019608, alpha: 1), nil) , //6
                            .totalText                   : (#colorLiteral(red: 0.9996390939, green: 1, blue: 0.9997561574, alpha: 1), nil) ,
                            .thumbnailDisc               : (#colorLiteral(red: 0.7294117647, green: 0.2392156863, blue: 0.2156862745, alpha: 1), nil) , //2
                            .thumbnailDiscText           : (#colorLiteral(red: 0.942510128, green: 0.9367026687, blue: 0.9288505912, alpha: 1), nil) ,
                            .thumbnailPlaceholder        : (#colorLiteral(red: 0.9724639058, green: 0.9726034999, blue: 0.9724336267, alpha: 1), nil) , //w
                            .thumbnailPlaceholderText    : (#colorLiteral(red: 0.4940722585, green: 0.4941466451, blue: 0.4940558672, alpha: 1), nil) ,
                            .text                        : (#colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1), nil) , //g
                            .textEmphasised              : (#colorLiteral(red: 0.6745098039, green: 0.2196078431, blue: 0.2, alpha: 1), nil) , //1
                            .textTitle                   : (#colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1), nil) , //g
                            .textError                   : (#colorLiteral(red: 0.9210745692, green: 0.1963090301, blue: 0.1316265166, alpha: 1), nil) ,
                            .textMessage                 : (#colorLiteral(red: 0, green: 0.4733380675, blue: 0.9991257787, alpha: 1), nil) ,
                            .history                     : (#colorLiteral(red: 0.4516967535, green: 0.7031331658, blue: 0.4579167962, alpha: 1), nil) , //
                            .stats                       : (#colorLiteral(red: 0.9738044143, green: 0.7667216659, blue: 0.003810848575, alpha: 1), nil) , //
                            .highScores                  : (#colorLiteral(red: 0.1997601986, green: 0.4349380136, blue: 0.5107212663, alpha: 1), nil) , //
                            .otherButton                 : (#colorLiteral(red: 0.7018982768, green: 0.7020009756, blue: 0.7018757463, alpha: 1), nil) ,
                            .otherButtonText             : (#colorLiteral(red: 0.994867146, green: 1, blue: 0.9999337792, alpha: 1), nil) ,
                            .confirmButton               : (#colorLiteral(red: 0.3292011023, green: 0.4971863031, blue: 0.2595342696, alpha: 1), nil) ,
                            .confirmButtonText           : (#colorLiteral(red: 0.994867146, green: 1, blue: 0.9999337792, alpha: 1), nil) ]),

            
        "Alternate"         : Theme(description: "Alternate", color: [
                            .textEmphasised              : (#colorLiteral(red: 0.4549019608, green: 0.5764705882, blue: 0.5921568627, alpha: 1), nil) ,
                            .gameBanner                  : (#colorLiteral(red: 0.4549019608, green: 0.5764705882, blue: 0.5921568627, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,
                            .emphasis                    : (#colorLiteral(red: 0.4549019608, green: 0.5764705882, blue: 0.5921568627, alpha: 1), nil) ,
                            .banner                      : (#colorLiteral(red: 0.4549019608, green: 0.5764705882, blue: 0.5921568627, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,
                            .bannerEmbossed              : (#colorLiteral(red: 0.4078431373, green: 0.5176470588, blue: 0.5294117647, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,//3
                            .bannerShadow                : (#colorLiteral(red: 0.4078431373, green: 0.5176470588, blue: 0.5294117647, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,//3
                            .gameBannerShadow            : (#colorLiteral(red: 0.4078431373, green: 0.5176470588, blue: 0.5294117647, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,//3
                            .sectionHeading              : (#colorLiteral(red: 0.4549019608, green: 0.5764705882, blue: 0.5921568627, alpha: 1), nil) ,
                            .sectionHeadingText          : (#colorLiteral(red: 0.994867146, green: 1, blue: 0.9999337792, alpha: 1), nil) ,
                            .background                  : (#colorLiteral(red: 0.9724639058, green: 0.9726034999, blue: 0.9724336267, alpha: 1), #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1))  ,
                            .roomInterior                : (#colorLiteral(red: 0.4549019608, green: 0.5764705882, blue: 0.5921568627, alpha: 1), #colorLiteral(red: 0.1694289744, green: 0.1694289744, blue: 0.1694289744, alpha: 1))  ,
                            .hand                        : (#colorLiteral(red: 0.4549019608, green: 0.5764705882, blue: 0.5921568627, alpha: 1), #colorLiteral(red: 0.1694289744, green: 0.1694289744, blue: 0.1694289744, alpha: 1))  ,
                            .tableTop                    : (#colorLiteral(red: 0.8235294118, green: 0.7803921569, blue: 0.7333333333, alpha: 1), #colorLiteral(red: 0.2255345461, green: 0.4820669776, blue: 0.2524022623, alpha: 1))  ]),
        
        "Red"               : Theme(description: "Red", color: [
                            .textEmphasised              : (#colorLiteral(red: 0.6699781418, green: 0.2215877175, blue: 0.2024611831, alpha: 1), nil) ,
                            .emphasis                    : (#colorLiteral(red: 0.6699781418, green: 0.2215877175, blue: 0.2024611831, alpha: 1), nil) ,
                            .banner                      : (#colorLiteral(red: 0.6699781418, green: 0.2215877175, blue: 0.2024611831, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,
                            .bannerEmbossed              : (#colorLiteral(red: 0.5529411765, green: 0.1450980392, blue: 0.1254901961, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,
                            .bannerShadow                : (#colorLiteral(red: 0.6901960784, green: 0.2431372549, blue: 0.2235294118, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,
                            .segmentedControls           : (#colorLiteral(red: 0.6699781418, green: 0.2215877175, blue: 0.2024611831, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,
                            .gameBannerShadow            : (#colorLiteral(red: 0.2352941176, green: 0.4784313725, blue: 0.5529411765, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,
                            .gameBanner                  : (#colorLiteral(red: 0.1968964636, green: 0.4390103817, blue: 0.5146722198, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,
                            .gameBannerEmbossed          : (#colorLiteral(red: 0.1176470588, green: 0.3607843137, blue: 0.4352941176, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,
                            .gameSegmentedControls       : (#colorLiteral(red: 0.1968964636, green: 0.4390103817, blue: 0.5146722198, alpha: 1), #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1))  ,
                            .inputControl                : (#colorLiteral(red: 0.948936522, green: 0.9490727782, blue: 0.9489069581, alpha: 1), nil) ,
                            .inputControlText            : (#colorLiteral(red: 0.101947777, green: 0.1019691005, blue: 0.1019431874, alpha: 1), nil) ,
                            .inputControlPlaceholder     : (#colorLiteral(red: 0.325458765, green: 0.325510323, blue: 0.3254473805, alpha: 1), nil) ,
                            .sectionHeading              : (#colorLiteral(red: 0.6699781418, green: 0.2215877175, blue: 0.2024611831, alpha: 1), nil) ,
                            .sectionHeadingText          : (#colorLiteral(red: 0.994867146, green: 1, blue: 0.9999337792, alpha: 1), nil) ]),

        "Blue"              :Theme(description: "Blue", color: [
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
                            .buttonFaceText              : (#colorLiteral(red: 0.1019607843, green: 0.1019607843, blue: 0.1019607843, alpha: 1), nil) ,
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
                            .gameBannerEmbossed          : (#colorLiteral(red: 0.968627451, green: 0.4980392157, blue: 0.4941176471, alpha: 1), nil) ,
                            .gameBannerTextContrast      : (#colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), nil) ,
                            .gameSegmentedControls       : (#colorLiteral(red: 0.9281279445, green: 0.4577305913, blue: 0.4537009001, alpha: 1), nil) ,
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
                            .suitDiamondsHearts          : (#colorLiteral(red: 0.8621624112, green: 0.1350575387, blue: 0.08568952233, alpha: 1), nil) ,
                            .suitClubsSpades             : (#colorLiteral(red: 0, green: 0, blue: 0, alpha: 1), nil) ,
                            .suitNoTrumps                : (#colorLiteral(red: 0, green: 0.003977875225, blue: 0, alpha: 1), nil) ,
                            .tableTop                    : (#colorLiteral(red: 0.5406154394, green: 0.8017265201, blue: 0.5650425553, alpha: 1), nil) ,
                            .tableTopShadow              : (#colorLiteral(red: 0.4518489838, green: 0.7030248046, blue: 0.4536508322, alpha: 1), nil) ,
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
                            .highScores                  : (#colorLiteral(red: 0.1997601986, green: 0.4349380136, blue: 0.5107212663, alpha: 1), nil) ,
                            .otherButton                 : (#colorLiteral(red: 0.7018982768, green: 0.7020009756, blue: 0.7018757463, alpha: 1), nil) ,
                            .otherButtonText             : (#colorLiteral(red: 0.994867146, green: 1, blue: 0.9999337792, alpha: 1), nil) ,
                            .confirmButton               : (#colorLiteral(red: 0.3292011023, green: 0.4971863031, blue: 0.2595342696, alpha: 1), nil) ,
                            .confirmButtonText           : (#colorLiteral(red: 0.994867146, green: 1, blue: 0.9999337792, alpha: 1), nil) ]),
         
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
    
    static func gameColor(_ themeColor: ThemeColor, _ gameThemeColor: ThemeColor, _ traitCollection: UITraitCollection = UITraitCollection.current) -> UIColor {
        let result = self.currentTheme.getColor((Scorecard.shared.gameBanners ? gameThemeColor : themeColor), traitCollection)
        return result
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
    case gameBannerTextContrast = "Game Banner Text Contrast"
    case gameBannerEmbossed = "Game Banner Embossed"
    case gameSegmentedControls = "Game Segmented Controls"
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
    case tableTopShadow = "Table Top Shadow"
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
    case confirmButton = "Confirm Button"
    case confirmButtonText = "Confirm Button Text"
    case otherButton = "Other Button"
    case otherButtonText = "Other Button Text"
}

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
