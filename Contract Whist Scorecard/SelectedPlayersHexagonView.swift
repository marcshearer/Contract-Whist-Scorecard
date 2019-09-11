//
//  SelectedPlayersSectionView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 10/09/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit

public class SelectedPlayersHexagonView: UIView {
    
    @IBInspectable var titleText: String = ""
    @IBInspectable var detailText: String = ""
    @IBInspectable var buttonText: String = ""
    @IBInspectable var separator: Bool = false
    @IBInspectable var bannerColor: UIColor = Palette.banner
    @IBInspectable var fillColor: UIColor = Palette.background
    @IBInspectable var strokeColor: UIColor = Palette.bannerText
    @IBInspectable var textColor: UIColor = Palette.text
    
    private var bannerColorView: UIView!
    private var separatorView: UIView!
    private var hexagonView: UIView!
    private var hexagonShape: CAShapeLayer!
    private var titleLabel: UILabel!
    private var detailLabel: UILabel!
    private var button: AngledButton!
    private var buttonIsHidden = true
    private var viewsCreated = false
    private var buttonAction: (()->())?

    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    init(frame: CGRect, titleText: String, detailText: String, buttonText: String = "", buttonIsHidden: Bool = false, separator: Bool = false, bannerColor: UIColor = Palette.banner, fillColor: UIColor = Palette.background, strokeColor: UIColor = Palette.bannerText, textColor: UIColor = Palette.text, buttonAction: (()->())? = nil) {
        super.init(frame: frame)
        
        // Save properties
        self.titleText = titleText
        self.detailText = detailText
        self.buttonText = buttonText
        self.buttonIsHidden = buttonIsHidden
        self.separator = separator
        self.bannerColor = bannerColor
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.textColor = textColor
        self.buttonAction = buttonAction
    }
    
    override open func layoutSubviews() {
        if !self.viewsCreated {
            self.createView(titleText: self.titleText, detailText: self.detailText, buttonText: self.buttonText, buttonIsHidden: self.buttonIsHidden, separator: self.separator, bannerColor: self.bannerColor, fillColor: self.fillColor, strokeColor: self.strokeColor, textColor: self.textColor)
        }
        self.viewsCreated = true
    }
    
    private func createView(titleText: String, detailText: String, buttonText: String, buttonIsHidden: Bool, separator: Bool, bannerColor: UIColor, fillColor: UIColor, strokeColor: UIColor, textColor: UIColor) {
        let buttonHeightUnits: CGFloat = (buttonText == "" ? 0.0 : 30.0)
        let heightUnits: CGFloat = 86.0 + (buttonHeightUnits * 0.5)
        let hexagonHeightUnits = heightUnits - 8.0 - (buttonHeightUnits * 0.5)
        let scale: CGFloat = frame.height / heightUnits
        let width = self.frame.width
        
        // Create banner-colored view
        let bannerHeightUnits = (separator ? 2.0 + (hexagonHeightUnits / 2.0) : heightUnits)
        self.bannerColorView = UIView(frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: bannerHeightUnits * scale)))
        self.bannerColorView.backgroundColor = bannerColor
        self.addSubview(self.bannerColorView)
        Constraint.anchor(view: self, control: self.bannerColorView, attributes: .top, .leading, .trailing)
        if separator {
            Constraint.proportionalHeight(view: self, control: self.bannerColorView, multiplier: bannerHeightUnits / heightUnits)
        } else {
            Constraint.anchor(view: self, control: self.bannerColorView, attributes: .bottom)
        }
        
        // Create separator
        if separator {
            self.separatorView = UIView(frame: CGRect(x: 0.0, y: bannerHeightUnits * scale, width: width, height: 2.0 * scale))
            self.separatorView.backgroundColor = strokeColor
            self.addSubview(self.separatorView)
            Constraint.anchor(view: self, control: self.separatorView, attributes: .left, .right)
            Constraint.anchor(view: self, control: self.separatorView, to: self.bannerColorView, toAttribute: .bottom, attributes: .top)
            _ = Constraint.setHeight(control: self.separatorView, height: 2.0 * scale)
        }
        
        // Create hexagon
        self.hexagonView = UIView(frame: CGRect(x: 20.0, y: 4.0 * scale, width: width - 40.0, height: hexagonHeightUnits * scale))
        self.hexagonView.backgroundColor = UIColor.clear
        self.hexagonShape = Polygon.hexagonFrame(in: self.hexagonView, strokeColor: strokeColor, fillColor: fillColor, lineWidth: 2.0 * scale, radius: 10.0 * scale)
        self.addSubview(self.hexagonView)
        Constraint.anchor(view: self, control: self.hexagonView, constant: 4.0 * scale, attributes: .top)
        Constraint.proportionalHeight(view: self, control: self.hexagonView, multiplier: hexagonHeightUnits / heightUnits)
        Constraint.anchor(view: self, control: self.hexagonView, constant: 20.0, attributes: .leading, .trailing)
        
        // Create title label
        self.titleLabel = UILabel(frame: CGRect(x: 40.0, y: 12.0 * scale, width: width - 80.0, height: 36.0 * scale))
        self.titleLabel.backgroundColor = UIColor.clear
        self.titleLabel.text = titleText
        self.titleLabel.font = UIFont.systemFont(ofSize: 24.0)
        self.titleLabel.textColor = textColor
        self.titleLabel.textAlignment = .center
        self.addSubview(self.titleLabel)
        Constraint.anchor(view: self, control: self.titleLabel, constant: 12.0 * scale, attributes: .top)
        Constraint.proportionalHeight(view: self, control: self.titleLabel, multiplier: 36.0 / heightUnits)
        Constraint.anchor(view: self, control: self.titleLabel, constant: 40.0, attributes: .leading, .trailing)

        // Create detail label
        self.detailLabel = UILabel(frame: CGRect(x: 40.0, y: 48.0 * scale, width: width - 80.0, height: 16.0 * scale))
        self.detailLabel.backgroundColor = UIColor.clear
        self.detailLabel.text = detailText
        self.detailLabel.font = UIFont.italicSystemFont(ofSize: 12.0)
        self.detailLabel.textColor = textColor
        self.detailLabel.textAlignment = .center
        self.addSubview(self.detailLabel)
        Constraint.anchor(view: self, control: self.detailLabel, constant: 48.0 * scale, attributes: .top)
        Constraint.proportionalHeight(view: self, control: self.detailLabel, multiplier: 16.0 / heightUnits)
        Constraint.anchor(view: self, control: self.detailLabel, constant: 40.0, attributes: .leading, .trailing)

        // Create button
        if buttonText != "" {
            let buttonTopUnits = 4.0 + hexagonHeightUnits - (buttonHeightUnits / 2.0)
            self.button = AngledButton(frame: CGRect(x: (width - 100.0) / 2.0, y: buttonTopUnits * scale, width: 100.0, height: buttonHeightUnits * scale))
            self.button.fillColor = strokeColor
            self.button.strokeColor = strokeColor
            self.button.backgroundColor = UIColor.clear
            self.button.setTitle(buttonText)
            self.button.titleLabel?.font = UIFont.systemFont(ofSize: 16.0)
            self.button.normalTextColor = bannerColor
            self.button.disabledTextColor = bannerColor.withAlphaComponent(0.3)
            self.button.isHidden = buttonIsHidden
            self.button.isEnabled(true)
            self.button.addTarget(self, action: #selector(SelectedPlayersHexagonView.buttonPressed(_:)), for: .touchUpInside)
            self.addSubview(self.button)
            Constraint.anchor(view: self, control: self.button, constant: buttonTopUnits * scale, attributes: .top)
            Constraint.proportionalHeight(view: self, control: self.button, multiplier: buttonHeightUnits / heightUnits)
            Constraint.anchor(view: self, control: self.button, attributes: .centerX)
            _ = Constraint.setWidth(control: self.button, width: 100.0)
        }
    }
    
    @objc internal func buttonPressed(_ sender: UIButton) {
        self.buttonAction?()
    }
    
    public func setText(titleText: String, detailText: String) {
        self.titleText = titleText
        self.detailText = detailText
        self.titleLabel?.text = titleText
        self.detailLabel?.text = detailText
    }
    
    public func setButton(isHidden: Bool, buttonText: String? = nil) {
        self.buttonIsHidden = isHidden
        self.button?.isHidden = isHidden
        if let buttonText = buttonText {
            self.buttonText = buttonText
            self.button?.setTitle(buttonText)
        }
        
    }
    
}
