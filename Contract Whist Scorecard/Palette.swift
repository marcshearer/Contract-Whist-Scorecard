//
//  Palette.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 04/07/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit

class Palette {
    
    static let background = UIColor(named: "Background")!
    static let banner = UIColor(named: "Banner")!
    static let bannerText = UIColor(named: "Banner Text")!
    static let bold = UIColor(named: "Bold")!
    static let boldText = UIColor(named: "Bold Text")!
    static let darkHighlight = UIColor(named: "Dark Highlight")!
    static let darkHighlightText = UIColor(named: "Dark Highlight Text")!
    static let darkHighlightTextContrast = UIColor(named: "Dark Highlight Text Contrast")!
    static let disabledText = UIColor(named: "Disabled Text")
    static let disabled = UIColor(named: "Disabled")!
    static let emphasis = UIColor(named: "Emphasis")!
    static let emphasisText = UIColor(named: "Emphasis Text")!
    static let error = UIColor(named: "Error")!
    static let errorText = UIColor(named: "Error Text")!
    static let gameBanner = UIColor(named: "Game Banner")!
    static let gameBannerText = UIColor(named: "Game Banner Text")!
    static let halo = UIColor(named: "Halo")!
    static let haloDealer = UIColor(named: "Halo Dealer")!
    static let hand = UIColor(named: "Hand")!
    static let handText = UIColor(named: "Hand Text")!
    static let handTextContrast = UIColor(named: "Hand Text Contrast")!
    static let highlight = UIColor(named: "Highlight")!
    static let highlightText = UIColor(named: "Highlight Text")!
    static let inputControl = UIColor(named: "Input Control")!
    static let inputControlText = UIColor(named: "Input Control Text")!
    static let inputControlPlaceholder = UIColor(named: "Input Control Placeholder")!
    static let madeContract = UIColor(named: "Made Contract")!
    static let madeContractText = UIColor(named: "Made Contract Text")!
    static let sectionHeading = UIColor(named: "Section Heading")!
    static let sectionHeadingText = UIColor(named: "Section Heading Text")!
    static let sectionHeadingTextContrast = UIColor(named: "Section Heading Text Contrast")!
    static let tableTop = UIColor(named: "Table Top")!
    static let tableTopText = UIColor(named: "Table Top Text")!
    static let tableTopTextContrast = UIColor(named: "Table Top Text Contrast")
    static let total = UIColor(named: "Total")!
    static let totalText = UIColor(named: "Total Text")!
    static let thumbnailDisc = UIColor(named: "Thumbnail Disc")!
    static let thumbnailDiscText = UIColor(named: "Thumbnail Disc Text")!
    static let thumbnailPlaceholder = UIColor(named: "Thumbnail Placeholder")!
    static let thumbnailPlaceholderText = UIColor(named: "Thumbnail Placeholder Text")!
    static let separator = UIColor(named: "Separator")
    static let grid = UIColor(named: "Grid")
    static let text = UIColor(named: "Text")!
    static let textEmphasised = UIColor(named: "Text Emphasised")!
    static let textError = UIColor(named: "Text Error")!
    static let textMessage = UIColor(named: "Text Message")!
    static let shapeStrokeText = UIColor(named: "Shape Stroke Text")!
    static let shapeStroke = UIColor(named: "Shape Stroke")!
    static let shapeFillText = UIColor(named: "Shape Fill Text")!
    static let shapeFill = UIColor(named: "Shape Fill")!
    static let shapeAdminStroke = UIColor(named: "Shape Admin Stroke")!
    static let shapeAdminText = UIColor(named: "Shape Admin Text")!
    static let shapeAdminFill = UIColor(named: "Shape Admin Fill")!
    static let shapeHighlightStrokeText = UIColor(named: "Shape Highlight Stroke Text")!
    static let shapeHighlightStroke = UIColor(named: "Shape Highlight Stroke")!
    static let shapeHighlightFillText = UIColor(named: "Shape Highlight Fill Text")!
    static let shapeHighlightFill = UIColor(named: "Shape Highlight Fill")!
    static let shapeTableLeg = UIColor(named: "Shape Table Leg")
    static let shapeTableLegShadow = UIColor(named: "Shape Table Leg Shadow")
    static let suitDiamondsHearts = UIColor(named: "Suit Diamonds Hearts")!
    static let suitClubsSpades = UIColor(named: "Suit Clubs Spades")!
    static let suitNoTrumps = UIColor(named: "Suit No Trumps")!
    static let cardBack = UIColor(named: "Card Back")
    static let cardFace = UIColor(named: "Card Face")
    static let contractOver = UIColor(named: "Contract Over")!
    static let contractUnder = UIColor(named: "Contract Under")!
    static let contractEqual = UIColor(named: "Contract Equal")!
    
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
    
    class func bannerStyle(_ cell: UITableViewCell) {
        cell.backgroundColor = Palette.banner
        cell.textLabel?.textColor = Palette.bannerText
    }
    
    class func bannerStyle(_ label: UILabel) {
        label.backgroundColor = Palette.banner
        label.textColor = Palette.bannerText
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
