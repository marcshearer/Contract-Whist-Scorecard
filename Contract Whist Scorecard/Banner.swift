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
}

public class BannerButton {
    fileprivate let title: String?
    fileprivate let image: UIImage?
    fileprivate let width: CGFloat
    fileprivate let action: (()->())?
    fileprivate let type: BannerButtonType
    fileprivate let containerHide: Bool
    fileprivate let containerMenuText: String?
    fileprivate let backgroundColor: ThemeBackgroundColorName
    fileprivate let textColorType: ThemeTextType
    fileprivate let font: UIFont
    fileprivate let alignment: UIControl.ContentHorizontalAlignment?
    fileprivate let id: AnyHashable
    fileprivate weak var control: UIButton?
    fileprivate weak var viewGroup: ViewGroup?
    fileprivate var isHidden = false
    fileprivate var isEnabled = true
    
    init(title: String? = nil, image: UIImage? = nil, width: CGFloat = 30.0, action: (()->())?, type: BannerButtonType = .clear, containerHide: Bool, containerMenuText: String? = nil, backgroundColor: ThemeBackgroundColorName? = nil, textColorType: ThemeTextType = .normal, font: UIFont = UIFont.systemFont(ofSize: 18), alignment: UIControl.ContentHorizontalAlignment? = .none, id: AnyHashable? = nil) {
        self.title = title
        self.image = image
        self.width = width
        self.action = action
        self.type = type
        self.containerHide = containerHide
        self.containerMenuText = containerMenuText
        self.backgroundColor = backgroundColor ?? (type == .clear ? .clear : .bannerShadow)
        self.textColorType = textColorType
        self.font = font
        self.alignment = alignment
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
    @IBInspectable var containerHide: Bool = true
    @IBInspectable var containerMenuText: String?
    @IBInspectable var disableOptions: Bool = false
    @IBInspectable var lowerViewHeight: CGFloat = 0
    
    private var leftButtons: [BannerButton] = []
    private var rightButtons: [BannerButton] = []
    private var lowerButtons: [BannerButton] = []
    private var titleFont = UIFont.systemFont(ofSize: 28, weight: .semibold)
    private let buttonHeight: CGFloat = 30.0
    private var buttonIds: [AnyHashable : BannerButton] = [:]
    private var containerMenuOption: MenuOption?
    private lazy var menuController = self.parentViewController?.rootViewController?.menuController
    public var titleWidth: CGFloat {
        return self.titleWidthConstraint.constant
    }

    @IBOutlet private weak var contentView: UIView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var leftViewGroup: ViewGroup!
    @IBOutlet private weak var rightViewGroup: ViewGroup!
    @IBOutlet private weak var lowerViewGroup: ViewGroup!
    @IBOutlet private weak var titleWidthConstraint: NSLayoutConstraint!
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
            self.leftButtons = [BannerButton(title: self.finishText, image: self.finishImage, action: self.delegate?.finishPressed, containerHide: self.containerHide, containerMenuText: self.containerMenuText, id: 0)]
            arrange = true
        }
        
        if menuController?.isVisible() ?? false {
            self.titleFont = UIFont.systemFont(ofSize: 33, weight: .semibold)
        }
        
        if arrange {
            self.arrange()
        }
    }
    
    public func restored() {
        self.setupMenuEntries()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()

        self.leftViewGroup.layoutIfNeeded()
        self.rightViewGroup.layoutIfNeeded()
        if self.titleLabel.textAlignment == .left {
            self.titleWidthConstraint.constant = self.contentView.frame.width - (self.leftViewGroup.frame.maxX * 2)
        } else {
            let midX = self.titleLabel.frame.midX
            self.titleWidthConstraint.constant = min(midX - self.leftViewGroup.frame.maxX, self.rightViewGroup.frame.minX - midX) * 2.0
        }
    }
    
    public func set(title: String? = nil, leftButtons: [BannerButton]? = nil, rightButtons: [BannerButton]? = nil, lowerButtons: [BannerButton]? = nil, menuOption: MenuOption? = nil, titleFont: UIFont? = nil, disableOptions: Bool = false) {
        var arrange = false
        if let title = title                { self.title = title ; self.titleLabel.text = title}
        if let leftButtons = leftButtons    { self.leftButtons = leftButtons ; arrange = true }
        if let rightButtons = rightButtons  { self.rightButtons = rightButtons ; arrange = true }
        if let lowerButtons = lowerButtons  { self.lowerButtons = lowerButtons ; arrange = true }
        if let menuOption = menuOption      { self.containerMenuOption = menuOption ; arrange = true }
        if let titleFont = titleFont        { self.titleFont = titleFont ; self.titleLabel.font = self.titleFont}
        self.disableOptions = disableOptions
        if arrange {
            self.arrange()
        }
    }
    
    public func setButton(_ id: AnyHashable = 0, isHidden: Bool? = nil, isEnabled: Bool? = nil, disableOptions: Bool = false) {
        if let button = buttonIds[id] {
            if let isHidden = isHidden {
                if button.isHidden != isHidden {
                    button.control?.isHidden = isHidden
                    buttonIds[id]?.isHidden = isHidden
                    button.viewGroup?.setNeedsLayout()
                }
            }
            if let isEnabled = isEnabled {
                if button.isEnabled != isEnabled {
                    button.control?.isEnabled = isEnabled
                    buttonIds[id]?.isEnabled = isEnabled
                }
            }
        }
        self.disableOptions = disableOptions
        self.setupMenuEntries()
    }
    
    public func refresh() {
        self.arrange()
        self.titleLabel.setNeedsDisplay() // Needed to pick up color changes
    }
    
    private func arrange() {
        self.backgroundColor = self.parentViewController.defaultBannerColor
        self.titleLabel.textColor = self.parentViewController.defaultBannerTextColor
        self.titleLabel.textAlignment = self.parentViewController.defaultBannerAlignment
        self.titleLabel.text = self.title ?? ""
        self.titleLabel.font = self.titleFont
        self.lowerViewGroupHeightConstraint.constant = self.lowerViewHeight
        
        self.buttonIds = [:]
        self.createButtons(buttons: &self.leftButtons, viewGroup: self.leftViewGroup, defaultAlignment: .left, tagOffset: 0)
        self.createButtons(buttons: &self.rightButtons, viewGroup: self.rightViewGroup, defaultAlignment: .right, tagOffset: leftButtons.count)
        self.createButtons(buttons: &self.lowerButtons, viewGroup: self.lowerViewGroup, defaultAlignment: .center, tagOffset: leftButtons.count + rightButtons.count)
        self.lowerViewGroupHeightConstraint.constant = (self.lowerViewGroup.count == 0 ? 0 : self.lowerViewHeight)
        self.setupMenuEntries()
        self.layoutSubviews()
    }
    
    private func createButtons(buttons: inout [BannerButton], viewGroup: ViewGroup, defaultAlignment: UIControl.ContentHorizontalAlignment, tagOffset: Int) {
        
        viewGroup.clear()
        var views: [UIView] = []
        
        for (index, button) in buttons.enumerated() {
            let container = self.parentViewController.container
            if !(menuController?.isVisible() ?? false) || (container != .main && container != .mainRight) || !button.containerHide {
                var buttonView: UIButton
                var alignment: UIControl.ContentHorizontalAlignment
                let frame = CGRect(x: 0, y: 0, width: button.width, height: self.buttonHeight)
                let color = PaletteColor(button.backgroundColor)
                
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
                    clearButton.backgroundColor = color.background
                    clearButton.setTitleFont(button.font)
                    buttonView = clearButton
                    
                case .shadow:
                    let shadowButton = ShadowButton(frame: frame)
                    if let title = button.title { shadowButton.setTitle(title, for: .normal) }
                    shadowButton.setBackgroundColor(color.background)
                    shadowButton.setTitleFont(button.font)
                    buttonView = shadowButton
                    alignment = .center
                }
                
                if let image = button.image { buttonView.setImage(image, for: .normal)}
                buttonView.contentHorizontalAlignment = alignment
                let textColor = color.textColor(button.textColorType)
                buttonView.setTitleColor(textColor, for: .normal)
                buttonView.tintColor = textColor
                buttonView.tag = tagOffset + index
                buttonView.addTarget(self, action: #selector(Banner.buttonClicked(_:)), for: .touchUpInside)
                views.append(buttonView)
                buttons[index].control = buttonView
                buttons[index].viewGroup = viewGroup
            }
            self.buttonIds[button.id] = buttons[index]
        }
        viewGroup.add(views: views)
    }
    
    private func setupMenuEntries() {
        if let container = self.parentViewController.container {
            if let menuOption = self.containerMenuOption ?? menuController?.currentOption {
                if menuController?.isVisible() ?? false {
                    // A menu panel exists - update it
                    var menuSuboptions: [Option] = []
                    menuSuboptions.append(contentsOf: self.setupMenuEntries(buttons: leftButtons, viewGroup: leftViewGroup))
                    menuSuboptions.append(contentsOf: self.setupMenuEntries(buttons: rightButtons, viewGroup: rightViewGroup))
                    menuSuboptions.append(contentsOf: self.setupMenuEntries(buttons: lowerButtons, viewGroup: lowerViewGroup))
                    menuController?.add(suboptions: menuSuboptions, to: menuOption, on: container, highlight: nil, disableOptions: self.disableOptions)
                }
            }
        }
    }
    
    private func setupMenuEntries(buttons: [BannerButton], viewGroup: ViewGroup) -> [Option] {
        var results: [Option] = []
        for button in buttons {
            if !button.isHidden && button.isEnabled {
                if let title = button.containerMenuText, let action = button.action {
                    results.append(Option(title: title, action: action))
                }
            }
        }
        return results
    }
    
    @objc private func buttonClicked(_ button: UIButton) {
        if button.tag < self.leftButtons.count {
            self.leftButtons[button.tag].action?()
        } else if button.tag < self.leftButtons.count + self.rightButtons.count {
            self.rightButtons[button.tag - self.leftButtons.count].action?()
        } else {
            self.lowerButtons[button.tag - self.leftButtons.count - self.rightButtons.count].action?()
        }
    }
    
    private func loadBanner() {
        Bundle.main.loadNibNamed("Banner", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
}
