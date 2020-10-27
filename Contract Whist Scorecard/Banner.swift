//
//  Banner.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 28/08/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

public enum BannerButtonType {
    case clear
    case shadow
    case rounded
    case nonBanner
}

public class BannerButton: NSObject {
    fileprivate var banner: Banner?
    fileprivate var title: String?
    fileprivate var attributedTitle: NSAttributedString?
    fileprivate var image: UIImage?
    fileprivate let width: CGFloat?
    fileprivate let action: (()->())?
    fileprivate let releaseAction: (()->())?
    fileprivate let type: BannerButtonType
    fileprivate let menuHide: Bool
    fileprivate let menuText: String?
    fileprivate let releaseMenuText: String?
    fileprivate var menuSpaceBefore: CGFloat = 0.0
    fileprivate var menuTextColor: UIColor?
    fileprivate let gameDetailHide: Bool
    fileprivate let backgroundColor: ThemeBackgroundColorName?
    fileprivate let textColorType: ThemeTextType?
    fileprivate var specificTextColor: UIColor?
    fileprivate let font: UIFont?
    fileprivate let alignment: UIControl.ContentHorizontalAlignment?
    fileprivate let id: AnyHashable
    fileprivate weak var control: UIButton?
    fileprivate weak var viewGroup: ViewGroup?
    fileprivate var isHidden = false
    fileprivate var isEnabled = true
    fileprivate var _isPressed = true
    fileprivate let nonBanner: Bool
    public var isPressed: Bool { _isPressed }
    public static var defaultFont = UIFont.systemFont(ofSize: 18)
    
    /// Used for genuine banner buttons
    init(title: String? = nil, attributedTitle: NSAttributedString? = nil, image: UIImage? = nil, asTemplate: Bool = true, width: CGFloat = 30.0, action: (()->())?, releaseAction: (()->())? = nil, type: BannerButtonType = .clear, menuHide: Bool = false, menuText: String? = nil, releaseMenuText: String? = nil, menuSpaceBefore: CGFloat = 0, menuTextColor: UIColor? = nil, gameDetailHide: Bool = false, backgroundColor: ThemeBackgroundColorName? = nil, textColorType: ThemeTextType? = .normal, specificTextColor: UIColor? = nil, font: UIFont = BannerButton.defaultFont, alignment: UIControl.ContentHorizontalAlignment? = .none, id: AnyHashable? = nil) {
        self.title = title
        self.attributedTitle = attributedTitle
        self.image = (asTemplate ? image?.asTemplate() : image)
        self.width = width
        self.action = action
        self.releaseAction = releaseAction
        self.type = type
        self.menuHide = menuHide
        self.menuText = menuText
        self.releaseMenuText = releaseMenuText
        self.menuTextColor = menuTextColor
        self.gameDetailHide = gameDetailHide
        self.backgroundColor = backgroundColor ?? (Scorecard.shared.useGameColor ? .gameBannerShadow : .bannerShadow)
        self.textColorType = textColorType
        self.specificTextColor = specificTextColor
        self.font = font
        self.alignment = alignment
        self.menuSpaceBefore = menuSpaceBefore
        self.id = id ?? UUID().uuidString as AnyHashable
        self.nonBanner = false
    }
    
    /// Used for non-banner buttons
    init(control: UIButton? = nil, action: (()->())?, releaseAction: (()->())? = nil, menuHide: Bool = false, menuText: String? = nil, releaseMenuText: String? = nil, menuSpaceBefore: CGFloat = 0, menuTextColor: UIColor? = nil, id: AnyHashable? = nil) {
        self.title = nil
        self.attributedTitle = nil
        self.image = nil
        self.width = nil
        self.control = control
        self.action = action
        self.releaseAction = releaseAction
        self.type = .nonBanner
        self.menuHide = menuHide
        self.menuText = menuText
        self.releaseMenuText = releaseMenuText
        self.menuTextColor = menuTextColor
        self.gameDetailHide = false
        self.backgroundColor = nil
        self.textColorType = nil
        self.specificTextColor = nil
        self.font = nil
        self.alignment = nil
        self.menuSpaceBefore = menuSpaceBefore
        self.id = id ?? UUID().uuidString as AnyHashable
        self.nonBanner = true
    }
}

@objc protocol BannerDelegate : class {
    func finishPressed()
}

class Banner : UIView {
    
    @IBInspectable var title: String?
    @IBInspectable var finishText: String?
    @IBInspectable var finishImage: UIImage?
    @IBInspectable var menuHide: Bool = true
    @IBInspectable var menuText: String?
    @IBInspectable var menuSpaceBefore: CGFloat = 0.0
    @IBInspectable var disableOptions: Bool = false
    @IBInspectable var lowerViewHeight: CGFloat = 0
    @IBInspectable var bottomAlignTitle: Bool = false

    public static let defaultFont = UIFont.systemFont(ofSize: 28, weight: .semibold)
    public static let heavyFont = UIFont(name: "Avenir-Heavy", size: 34)
    public static let panelFont = UIFont.systemFont(ofSize: 33, weight: .semibold)
    public static let finishButton = UUID().uuidString
    public static let containerHeight: CGFloat = 150
    public static let normalHeight: CGFloat = 44

    private var leftButtons: [BannerButton] = []
    private var rightButtons: [BannerButton] = []
    private var lowerButtons: [BannerButton] = []
    private var nonBannerButtonsBefore: [BannerButton] = []
    private var nonBannerButtonsAfter: [BannerButton] = []
    private var overrideColor: PaletteColor?
    private var titleFont = Banner.defaultFont
    private var titleColor: UIColor?
    private var titleAlignment: NSTextAlignment?
    private let buttonHeight: CGFloat = 30.0
    private var buttonIds: [AnyHashable : BannerButton] = [:]
    private var menuOption: MenuOption?
    private var menuController: MenuController? { self.parentViewController?.menuController }
    private var normalOverrideHeight: CGFloat?
    private var containerOverrideHeight: CGFloat?
    private var attributedTitle: NSAttributedString?
    private var menuTitle: String?
    
    public var height: CGFloat { return self.bannerHeightConstraint?.constant ?? self.frame.height }
    public var titleWidth: CGFloat { self.titleLabel.frame.width }
    
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var leftViewGroup: ViewGroup!
    @IBOutlet private weak var rightViewGroup: ViewGroup!
    @IBOutlet private weak var lowerViewGroup: ViewGroup!
    @IBOutlet private var titleLabelInset: [NSLayoutConstraint]!
    @IBOutlet private weak var lowerViewGroupHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var parentViewController: ScorecardViewController!
    @IBOutlet private weak var delegate: BannerDelegate?
    @IBOutlet private var bannerHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var bannerTopConstraint: NSLayoutConstraint!
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.loadBanner()
    }
    
    override init(frame: CGRect) {
        super.init(frame:frame)
        self.loadBanner()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.parentViewController?.bannerClass = self
        
        var arrange = false
        
        if self.title != nil {
            arrange = true
        }
        
        if finishText != nil || finishImage != nil {
            self.leftButtons = [BannerButton(title: self.finishText, image: self.finishImage?.asTemplate(), width: (self.finishText == nil ? 22 : 100), action: self.delegate?.finishPressed, menuHide: self.menuHide, menuText: self.menuText, menuSpaceBefore: self.menuSpaceBefore, id: Banner.finishButton)]
            arrange = true
        }
        
        if self.menuController?.isVisible ?? false {
            self.titleFont = Banner.panelFont
        }
        self.menuController?.set(gamePlayingTitle: self.title)
        
        if arrange {
            self.arrange()
        }
    }
    
    public func restored() {
        if let menuTitle = menuTitle ?? attributedTitle?.string ?? title {
            self.menuController?.set(gamePlayingTitle: menuTitle)
        }
        self.setupMenuEntries()
    }
        
    override func layoutSubviews() {
        super.layoutSubviews()

        // Resize lower container
        self.lowerViewGroupHeightConstraint.constant = (self.lowerViewGroup.visibleCount == 0 ? 0 : self.lowerViewHeight)
        self.lowerViewGroup.layoutIfNeeded()
        
        // Adjust height
        if !self.parentViewController.containerBanner {
            self.bannerHeightConstraint?.constant = self.normalOverrideHeight ?? self.parentViewController!.defaultBannerHeight
        } else {
            self.bannerHeightConstraint?.constant = self.containerOverrideHeight ?? self.parentViewController!.defaultBannerHeight
        }
        
        // Position relative to top
        self.bannerTopConstraint.constant = 0
        if self.parentViewController?.containerBanner ?? false  || self.bottomAlignTitle {
            if let height = self.bannerHeightConstraint?.constant {
                self.bannerTopConstraint.constant = height - self.titleLabel.frame.height - self.lowerViewGroupHeightConstraint.constant
            }
        }
        
        self.showHideButtons()
        self.leftViewGroup.layoutIfNeeded()
        self.rightViewGroup.layoutIfNeeded()
        
        // Set title inset based on button groups
        var inset: CGFloat
        self.titleLabel.textAlignment = self.titleAlignment ?? self.parentViewController.defaultBannerAlignment
        if self.titleLabel.textAlignment == .left {
            inset = self.leftViewGroup.frame.width
        } else {
            inset = max(self.leftViewGroup.frame.width, self.rightViewGroup.frame.width)
        }
        self.titleLabelInset.forEach{(constraint) in constraint.constant = inset}
    }
    
    public func set(title: String? = nil, attributedTitle: NSAttributedString? = nil, menuTitle: String? = nil, leftButtons: [BannerButton]? = nil, rightButtons: [BannerButton]? = nil, lowerButtons: [BannerButton]? = nil, nonBannerButtonsBefore: [BannerButton]? = nil, nonBannerButtonsAfter: [BannerButton]? = nil, menuOption: MenuOption? = nil, backgroundColor: PaletteColor? = nil, titleFont: UIFont? = nil, titleColor: UIColor? = nil, titleAlignment: NSTextAlignment? = nil, disableOptions: Bool? = nil, updateMenuTitle: Bool = true, normalOverrideHeight: CGFloat? = nil, containerOverrideHeight: CGFloat? = nil, forceArrange: Bool = false) {
        var arrange = forceArrange
        var layout = false
        if let title = title {
            self.title = title
            self.titleLabel.text = title
        }
        if let attributedTitle = attributedTitle {
            self.attributedTitle = attributedTitle
            self.titleLabel.attributedText = attributedTitle
        }
        if let menuTitle = menuTitle { self.menuTitle = menuTitle }
        if updateMenuTitle {
            if let menuTitle = menuTitle ?? attributedTitle?.string ?? title {
                self.menuController?.set(gamePlayingTitle: menuTitle)
            }
        }
        if let leftButtons = leftButtons           { self.leftButtons = leftButtons ; arrange = true }
        if let rightButtons = rightButtons         { self.rightButtons = rightButtons ; arrange = true }
        if let lowerButtons = lowerButtons         { self.lowerButtons = lowerButtons ; arrange = true }
        if let nonBannerButtonsBefore = nonBannerButtonsBefore { self.nonBannerButtonsBefore = nonBannerButtonsBefore ; arrange = true }
        if let nonBannerButtonsAfter = nonBannerButtonsAfter { self.nonBannerButtonsAfter = nonBannerButtonsAfter ; arrange = true }
        if let menuOption = menuOption             { self.menuOption = menuOption ; arrange = true }
        if let backgroundColor = backgroundColor   { self.overrideColor = backgroundColor ; self.updateBackgroundColor() }
        if let titleFont = titleFont               { self.titleFont = titleFont ; self.titleLabel.font = titleFont}
        if let titleColor = titleColor             { self.titleColor = titleColor ; self.titleLabel.textColor = titleColor}
        if let titleAlignment = titleAlignment     { self.titleAlignment = titleAlignment ; self.titleLabel.textAlignment = titleAlignment}
        if let disableOptions = disableOptions     { self.disableOptions = disableOptions }
        if let normalOverrideHeight = normalOverrideHeight       { self.normalOverrideHeight = normalOverrideHeight ; layout = true}
        if let containerOverrideHeight = containerOverrideHeight { self.containerOverrideHeight = containerOverrideHeight ; layout = true}
        if arrange {
            self.arrange()
        } else if layout {
            self.layoutSubviews()
        }
    }
    
    public func setButton(_ id: AnyHashable = Banner.finishButton, title: String? = nil, attributedTitle: NSAttributedString? = nil,  titleColor: UIColor? = nil, image: UIImage? = nil, isHidden: Bool? = nil, isEnabled: Bool? = nil, disableOptions: Bool? = nil) {
        if let button = buttonIds[id] {
            if let isHidden = isHidden {
                if button.isHidden != isHidden {
                    self.showHide(button: button)
                    buttonIds[id]?.isHidden = isHidden
                    button.viewGroup?.layoutSubviews()
                    button.viewGroup?.setNeedsLayout()
                    self.layoutSubviews()
                }
            }
            if let isEnabled = isEnabled {
                if button.isEnabled != isEnabled {
                    button.control?.isEnabled = isEnabled
                    buttonIds[id]?.isEnabled = isEnabled
                }
            }
            if let title = title {
                button.title = title
                button.control?.setTitle(title, for: .normal)
            }
            if let attributedTitle = attributedTitle {
                button.attributedTitle = attributedTitle
                button.control?.setAttributedTitle(attributedTitle, for: .normal)
            }
            if let image = image {
                button.image = image
                button.control?.setImage(image, for: .normal)
            }
            if let specificTextColor = titleColor {
                button.specificTextColor = specificTextColor
                button.control?.setTitleColor(specificTextColor, for: .normal)
            }
        }
        if let disableOptions = disableOptions   { self.disableOptions = disableOptions }
        self.setupMenuEntries()
    }
    
    public func getButton(id: AnyHashable) -> (control: UIButton, title: NSAttributedString)? {
        var menuTitle = NSAttributedString()
        if let button = buttonIds[id], let control = button.control {
            if button.nonBanner {
                return nil
            } else {
                if let attributedTitle = button.attributedTitle {
                    menuTitle = NSAttributedString(attributedTitle.string, color: Palette.normal.themeText)
                } else if let title = button.title {
                    menuTitle = NSAttributedString(title, color: Palette.normal.themeText)
                } else if let image = button.image {
                    let image = NSMutableAttributedString(attachment: NSTextAttachment(image: image.asTemplate()))
                    image.addAttribute(NSAttributedString.Key.foregroundColor, value: Palette.normal.themeText, range: NSRange(0...image.length - 1))
                    menuTitle = image
                }
                return (control, " " + menuTitle + "  button")
            }
        } else {
            return nil
        }
    }
    
    public func alertFlash(_ id: AnyHashable = Banner.finishButton, duration: TimeInterval = 0.2, after: Double = 0.0, repeatCount: Int = 1, backgroundColor: UIColor? = nil) {
        if let button = buttonIds[id] {
            button.control?.alertFlash(duration: duration, after: after, repeatCount: repeatCount, backgroundColor: backgroundColor)
        }
    }
    
    public func getButtonIsHidden(_ id: AnyHashable = Banner.finishButton) -> Bool {
        return buttonIds[id]?.isHidden ?? true
    }
    
    public func getButtonIsEnabled(_ id: AnyHashable = Banner.finishButton) -> Bool {
        return buttonIds[id]?.isEnabled ?? false
    }
    public func getButtonFrame(_ id: AnyHashable = Banner.finishButton) -> CGRect? {
        return buttonIds[id]?.control?.frame
    }
    
    public func refresh() {
        self.arrange()
        self.titleLabel.setNeedsDisplay() // Needed to pick up color changes
    }
    
    private func arrange() {
        self.updateTitleColors()
        self.titleLabel.text = self.title
        if let attributedTitle = self.attributedTitle {
            self.titleLabel.attributedText = attributedTitle
        }
        self.titleLabel.font = self.titleFont
        
        self.buttonIds = [:]
        self.createBannerButtons(buttons: &self.leftButtons, viewGroup: self.leftViewGroup, defaultAlignment: .left)
        self.createBannerButtons(buttons: &self.rightButtons, viewGroup: self.rightViewGroup, defaultAlignment: .right)
        self.createBannerButtons(buttons: &self.lowerButtons, viewGroup: self.lowerViewGroup, defaultAlignment: .center)
        self.createNonBannerButtons(buttons: &self.nonBannerButtonsBefore)
        self.createNonBannerButtons(buttons: &self.nonBannerButtonsAfter)
        self.setupMenuEntries()
        self.layoutSubviews()
    }
    
    private func createBannerButtons(buttons: inout [BannerButton], viewGroup: ViewGroup, defaultAlignment: UIControl.ContentHorizontalAlignment) {
        
        viewGroup.clear()
        var views: [UIView] = []
        
        for (index, button) in buttons.enumerated() {
            var buttonControl: UIButton
            var alignment: UIControl.ContentHorizontalAlignment
            
            let frame = CGRect(x: 0, y: 0, width: button.width!, height: self.buttonHeight)
            
            switch button.type {
            case .clear:
                var clearButton: ClearButton
                alignment = button.alignment ?? defaultAlignment
                if alignment == .right {
                    clearButton = RightClearButton(frame: frame)
                    alignment = .left
                } else {
                    clearButton = ClearButton(frame: frame)
                }
                if let title = button.title { clearButton.setTitle(title) }
                clearButton.setTitleFont(button.font!)
                clearButton.setContentHuggingPriority(UILayoutPriority(rawValue: 1), for: .horizontal)
                buttonControl = clearButton
                
            case .rounded, .shadow:
                let shadowButton = ShadowButton(frame: frame)
                if let title = button.title { shadowButton.setTitle(title, for: .normal) }
                shadowButton.setTitleFont(button.font!)
                buttonControl = shadowButton
                alignment = .center
                if button.type == .rounded {
                    shadowButton.toCircle()
                }
                
            case .nonBanner:
                fatalError("Shouldn't use non-banner buttons in a banner group")
            }
            
            if let image = button.image { buttonControl.setImage(image, for: .normal)}
            if let attributedTitle = button.attributedTitle { buttonControl.setAttributedTitle(attributedTitle, for: .normal)}
            buttonControl.contentHorizontalAlignment = alignment
            if button.releaseAction != nil {
                buttonControl.addTarget(self, action: #selector(Banner.buttonPressed(_:)), for: .touchDown)
                buttonControl.addTarget(self, action: #selector(Banner.buttonReleased(_:)), for: .touchUpInside)
            } else {
                buttonControl.addTarget(self, action: #selector(Banner.buttonClicked(_:)), for: .touchUpInside)
            }
            views.append(buttonControl)
            buttons[index].control = buttonControl
            self.updateButtonControlColors(button: buttons[index])
            buttons[index].viewGroup = viewGroup
            buttons[index].banner = self
            self.buttonIds[button.id] = buttons[index]
        }
        viewGroup.add(views: views)
    }
        
    private func createNonBannerButtons(buttons: inout [BannerButton]) {
        
        for (index, button) in buttons.enumerated() {
            button.control?.addTarget(self, action: #selector(Banner.buttonClicked(_:)), for: .touchUpInside)
            buttons[index].banner = self
            self.buttonIds[button.id] = buttons[index]
        }
    }
    
    /// Update background, title and clear button titles / tints
    private func updateBackgroundColor() {
        self.updateTitleColors()
        for (_, button) in self.buttonIds {
            if button.type == .clear {
                self.updateButtonControlColors(button: button)
            }
        }
    }
    
    private func updateTitleColors() {
        self.backgroundColor = self.overrideColor?.background ?? self.parentViewController.defaultBannerColor.background
        self.titleLabel.textColor = self.titleColor ?? self.overrideColor?.text ?? self.parentViewController.defaultBannerTextColor()
    }
    
    private func updateButtonControlColors(button: BannerButton) {
        var textColor: UIColor?
        switch button.type {
        case .clear:
            button.control?.backgroundColor = UIColor.clear
            textColor = button.specificTextColor ?? self.overrideColor?.text ?? self.parentViewController.defaultBannerTextColor()
            
        case .rounded, .shadow:
            if let shadowButton = button.control as? ShadowButton {
                let color = PaletteColor(button.backgroundColor!)
                shadowButton.setBackgroundColor(color.background)
                textColor = button.specificTextColor ?? color.textColor(button.textColorType!)
            }
                        
        default:
            break
        }

        if let textColor = textColor {
            button.control?.setTitleColor(textColor, for: .normal)
            button.control?.tintColor = textColor
        }
    }
    
    private func showHideButtons() {
        var viewGroups: Set<ViewGroup?> = []
        
        for (_, button) in self.buttonIds {
            if self.showHide(button: button) {
                viewGroups.insert(button.viewGroup)
            }
        }
        for viewGroup in viewGroups {
            viewGroup?.layoutSubviews()
            viewGroup?.setNeedsLayout()
        }
    }
    
    /// Show/hide buttons depenedent on whether the menu panel or game detail panner are visible
    /// - Parameter button: Button to hide/show
    /// - Returns: true if visibility changes
    @discardableResult private func showHide(button: BannerButton) -> Bool {
        
        var changed = false
        var isHidden = button.isHidden
             
        if !isHidden {
            let container = self.parentViewController.container
            var menuHideButtons = false
            var gameDetailHideButtons = false
            if (container == .main || container == .mainRight) {
                menuHideButtons = button.menuHide && (self.menuController?.isVisible ?? false)
                gameDetailHideButtons = button.gameDetailHide && (self.parentViewController.gameDetailDelegate?.isVisible ?? false)
            }
            isHidden = menuHideButtons || gameDetailHideButtons
        }
        if isHidden != button.control?.isHidden {
            button.control?.isHidden = isHidden
            changed = true
        }
        
        return changed
    }
    
    private func setupMenuEntries() {
        if let container = self.parentViewController.container {
            if let menuOption = self.menuOption ?? menuController?.currentOption {
                if menuController?.isVisible ?? false {
                    // A menu panel exists - update it
                    var menuSuboptions: [Option] = []
                    menuSuboptions.append(contentsOf: self.setupMenuEntries(buttons: rightButtons))
                    menuSuboptions.append(contentsOf: self.setupMenuEntries(buttons: lowerButtons))
                    menuSuboptions.append(contentsOf: self.setupMenuEntries(buttons: nonBannerButtonsBefore))
                    menuSuboptions.append(contentsOf: self.setupMenuEntries(buttons: leftButtons))
                    menuSuboptions.append(contentsOf: self.setupMenuEntries(buttons: nonBannerButtonsAfter))
                    
                    menuController?.add(suboptions: menuSuboptions, to: menuOption, on: container, highlight: nil, disableOptions: self.disableOptions)
                }
            }
        }
    }
    
    private func setupMenuEntries(buttons: [BannerButton]) -> [Option] {
        var results: [Option] = []
        for button in buttons {
            if !button.isHidden && button.isEnabled {
                if let title = button.menuText {
                    results.append(Option(title: title, releaseTitle: button.releaseMenuText, titleColor: button.menuTextColor, spaceBefore: button.menuSpaceBefore, id: button.id, action: button.action, releaseAction: button.releaseAction))
                }
            }
        }
        return results
    }
    
    @objc private func buttonClicked(_ buttonControl: UIButton) {
        if let button = buttonIds.first(where: {$0.value.control == buttonControl})?.value {
            button.action?()
        }
    }
    
    @objc private func buttonPressed(_ buttonControl: UIButton) {
        if let button = buttonIds.first(where: {$0.value.control == buttonControl})?.value {
            button.action?()
        }
    }
    
    @objc private func buttonReleased(_ buttonControl: UIButton) {
        if let button = buttonIds.first(where: {$0.value.control == buttonControl})?.value {
            button.releaseAction?()
        }
    }
    
    private func loadBanner() {
        Bundle.main.loadNibNamed("Banner", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
}
