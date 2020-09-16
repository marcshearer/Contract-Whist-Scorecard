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
    case nonBanner
}

public class BannerButton {
    fileprivate var title: String?
    fileprivate let image: UIImage?
    fileprivate let width: CGFloat?
    fileprivate let action: (()->())?
    fileprivate let type: BannerButtonType
    fileprivate let menuHide: Bool
    fileprivate let menuText: String?
    fileprivate var menuSpaceBefore: CGFloat = 0.0
    fileprivate let backgroundColor: ThemeBackgroundColorName?
    fileprivate let textColorType: ThemeTextType?
    fileprivate let font: UIFont?
    fileprivate let alignment: UIControl.ContentHorizontalAlignment?
    fileprivate let id: AnyHashable
    fileprivate weak var control: UIButton?
    fileprivate weak var viewGroup: ViewGroup?
    fileprivate var isHidden = false
    fileprivate var isEnabled = true
    
    /// Used for genuine banner buttons
    init(title: String? = nil, image: UIImage? = nil, width: CGFloat = 30.0, action: (()->())?, type: BannerButtonType = .clear, menuHide: Bool, menuText: String? = nil, menuSpaceBefore: CGFloat = 0, backgroundColor: ThemeBackgroundColorName? = nil, textColorType: ThemeTextType? = .normal, font: UIFont = UIFont.systemFont(ofSize: 18), alignment: UIControl.ContentHorizontalAlignment? = .none, id: AnyHashable? = nil) {
        self.title = title
        self.image = image
        self.width = width
        self.action = action
        self.type = type
        self.menuHide = menuHide
        self.menuText = menuText
        self.backgroundColor = backgroundColor ?? .bannerShadow
        self.textColorType = textColorType
        self.font = font
        self.alignment = alignment
        self.menuSpaceBefore = menuSpaceBefore
        self.id = id ?? UUID().uuidString as AnyHashable
    }
    
    /// Used for non-banner buttons
    init(control: UIButton?, action: (()->())?, menuHide: Bool, menuText: String? = nil, menuSpaceBefore: CGFloat = 0, id: AnyHashable? = nil) {
        self.title = nil
        self.image = nil
        self.width = nil
        self.control = control
        self.action = action
        self.type = .nonBanner
        self.menuHide = menuHide
        self.menuText = menuText
        self.backgroundColor = nil
        self.textColorType = nil
        self.font = nil
        self.alignment = nil
        self.menuSpaceBefore = menuSpaceBefore
        self.id = id ?? UUID().uuidString as AnyHashable
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
    
    public static let defaultFont = UIFont.systemFont(ofSize: 28, weight: .semibold)
    public static let heavyFont = UIFont(name: "Avenir-Heavy", size: 34)
    public static let panelFont = UIFont.systemFont(ofSize: 33, weight: .semibold)
    public static let finishButton = UUID().uuidString

    private var leftButtons: [BannerButton] = []
    private var rightButtons: [BannerButton] = []
    private var lowerButtons: [BannerButton] = []
    private var nonBannerButtonsBefore: [BannerButton] = []
    private var nonBannerButtonsAfter: [BannerButton] = []
    private var overrideColor: UIColor?
    private var titleFont = Banner.defaultFont
    private var titleColor: UIColor?
    private let buttonHeight: CGFloat = 30.0
    private var buttonIds: [AnyHashable : BannerButton] = [:]
    private var menuOption: MenuOption?
    private lazy var menuController = self.parentViewController?.rootViewController?.menuController
    public var titleWidth: CGFloat {
        return self.titleLabel.frame.width
    }

    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var leftViewGroup: ViewGroup!
    @IBOutlet private weak var rightViewGroup: ViewGroup!
    @IBOutlet private weak var lowerViewGroup: ViewGroup!
    @IBOutlet private var titleLabelInset: [NSLayoutConstraint]!
    @IBOutlet private weak var lowerViewGroupHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var parentViewController: ScorecardViewController!
    @IBOutlet private weak var delegate: BannerDelegate?
    
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
            self.leftButtons = [BannerButton(title: self.finishText, image: self.finishImage, width: (self.finishText == nil ? 30 : 100), action: self.delegate?.finishPressed, menuHide: self.menuHide, menuText: self.menuText, menuSpaceBefore: self.menuSpaceBefore, id: Banner.finishButton)]
            arrange = true
        }
        
        if self.menuController?.isVisible() ?? false {
            self.titleFont = Banner.panelFont
        }
        self.menuController?.set(gamePlayingTitle: self.title)
        
        if arrange {
            self.arrange()
        }
    }
    
    public func restored() {
        self.setupMenuEntries()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()

        self.showHideButtons()
        self.leftViewGroup.layoutIfNeeded()
        self.rightViewGroup.layoutIfNeeded()
        
        // Set title inset based on button groups
        var inset: CGFloat
        if self.titleLabel.textAlignment == .left {
            inset = self.leftViewGroup.frame.width
        } else {
            inset = max(self.leftViewGroup.frame.width, self.rightViewGroup.frame.width)
        }
        self.titleLabelInset.forEach{(constraint) in constraint.constant = inset}
    }
    
    public func set(title: String? = nil, leftButtons: [BannerButton]? = nil, rightButtons: [BannerButton]? = nil, lowerButtons: [BannerButton]? = nil, nonBannerButtonsBefore: [BannerButton]? = nil, nonBannerButtonsAfter: [BannerButton]? = nil, menuOption: MenuOption? = nil, backgroundColor: UIColor? = nil, titleFont: UIFont? = nil, titleColor: UIColor? = nil, disableOptions: Bool? = nil) {
        var arrange = false
        if let title = title { self.title = title
            self.titleLabel.text = title
            self.menuController?.set(gamePlayingTitle: self.title)
        }
        if let leftButtons = leftButtons           { self.leftButtons = leftButtons ; arrange = true }
        if let rightButtons = rightButtons         { self.rightButtons = rightButtons ; arrange = true }
        if let lowerButtons = lowerButtons         { self.lowerButtons = lowerButtons ; arrange = true }
        if let nonBannerButtonsBefore = nonBannerButtonsBefore { self.nonBannerButtonsBefore = nonBannerButtonsBefore ; arrange = true }
        if let nonBannerButtonsAfter = nonBannerButtonsAfter { self.nonBannerButtonsAfter = nonBannerButtonsAfter ; arrange = true }
        if let menuOption = menuOption             { self.menuOption = menuOption ; arrange = true }
        if let backgroundColor = backgroundColor   { self.overrideColor = backgroundColor ; self.backgroundColor = backgroundColor}
        if let titleFont = titleFont               { self.titleFont = titleFont ; self.titleLabel.font = titleFont}
        if let titleColor = titleColor             { self.titleColor = titleColor ; self.titleLabel.textColor = titleColor}
        if let disableOptions = disableOptions     { self.disableOptions = disableOptions }
        if arrange {
            self.arrange()
        }
    }
    
    public func setButton(_ id: AnyHashable = Banner.finishButton, title: String? = nil, isHidden: Bool? = nil, isEnabled: Bool? = nil, disableOptions: Bool? = nil) {
        if let button = buttonIds[id] {
            if let isHidden = isHidden {
                if button.isHidden != isHidden {
                    button.control?.isHidden = (isHidden || (self.menuHideButtons() && button.menuHide))
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
        }
        if let disableOptions = disableOptions   { self.disableOptions = disableOptions }
        self.setupMenuEntries()
    }
    
    public func getButtonFrame(_ id: AnyHashable = Banner.finishButton) -> CGRect? {
        return buttonIds[id]?.control?.frame
    }
    
    public func refresh() {
        self.arrange()
        self.titleLabel.setNeedsDisplay() // Needed to pick up color changes
    }
    
    private func arrange() {
        self.backgroundColor = self.overrideColor ?? self.parentViewController.defaultBannerColor
        self.titleLabel.textColor = self.titleColor ?? self.parentViewController.defaultBannerTextColor
        self.titleLabel.textAlignment = self.parentViewController.defaultBannerAlignment
        self.titleLabel.text = self.title ?? ""
        self.titleLabel.font = self.titleFont
        self.lowerViewGroupHeightConstraint.constant = self.lowerViewHeight
        
        self.buttonIds = [:]
        self.createBannerButtons(buttons: &self.leftButtons, viewGroup: self.leftViewGroup, defaultAlignment: .left)
        self.createBannerButtons(buttons: &self.rightButtons, viewGroup: self.rightViewGroup, defaultAlignment: .right)
        self.createBannerButtons(buttons: &self.lowerButtons, viewGroup: self.lowerViewGroup, defaultAlignment: .center)
        self.createNonBannerButtons(buttons: &self.nonBannerButtonsBefore)
        self.createNonBannerButtons(buttons: &self.nonBannerButtonsAfter)
        self.lowerViewGroupHeightConstraint.constant = (self.lowerViewGroup.count == 0 ? 0 : self.lowerViewHeight)
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
            let color = PaletteColor(button.backgroundColor!)
            
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
                clearButton.backgroundColor = UIColor.clear
                clearButton.setTitleFont(button.font!)
                buttonControl = clearButton
                
            case .shadow:
                let shadowButton = ShadowButton(frame: frame)
                if let title = button.title { shadowButton.setTitle(title, for: .normal) }
                shadowButton.setBackgroundColor(color.background)
                shadowButton.setTitleFont(button.font!)
                buttonControl = shadowButton
                alignment = .center
                
            case .nonBanner:
                fatalError("Shouldn't use non-banner buttons in a banner group")
            }
            
            if let image = button.image { buttonControl.setImage(image, for: .normal)}
            buttonControl.contentHorizontalAlignment = alignment
            let textColor = color.textColor(button.textColorType!)
            buttonControl.setTitleColor(textColor, for: .normal)
            buttonControl.tintColor = textColor
            buttonControl.addTarget(self, action: #selector(Banner.buttonClicked(_:)), for: .touchUpInside)
            views.append(buttonControl)
            buttons[index].control = buttonControl
            buttons[index].viewGroup = viewGroup
            self.buttonIds[button.id] = buttons[index]
        }
        viewGroup.add(views: views)
    }
    
    private func createNonBannerButtons(buttons: inout [BannerButton]) {
        
        for (index, button) in buttons.enumerated() {
            button.control?.addTarget(self, action: #selector(Banner.buttonClicked(_:)), for: .touchUpInside)
            self.buttonIds[button.id] = buttons[index]
        }
    }
    
    private func showHideButtons() {
        var viewGroups: Set<ViewGroup?> = []
        
        let menuHide = self.menuHideButtons()
        for (_, button) in self.buttonIds {
            if button.menuHide {
                button.control?.isHidden = menuHide || button.isHidden
                viewGroups.insert(button.viewGroup)
            }
        }
        for viewGroup in viewGroups {
            viewGroup?.layoutSubviews()
            viewGroup?.setNeedsLayout()
        }
    }
    
    private func menuHideButtons() -> Bool {
        let container = self.parentViewController.container
        return (menuController?.isVisible() ?? false) && (container == .main || container == .mainRight)
    }
    
    private func setupMenuEntries() {
        if let container = self.parentViewController.container {
            if let menuOption = self.menuOption ?? menuController?.currentOption {
                if menuController?.isVisible() ?? false {
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
                if let title = button.menuText, let action = button.action {
                    results.append(Option(title: title, spaceBefore: button.menuSpaceBefore, action: action))
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
    
    private func loadBanner() {
        Bundle.main.loadNibNamed("Banner", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
}
