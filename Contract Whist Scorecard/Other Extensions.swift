//
//  Other Extensions.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 11/11/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import UIKit

class SearchBar : UISearchBar {
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        self.layer.borderWidth = 1
        self.layer.borderColor = self.barTintColor?.cgColor
    }
}

class Stepper: UIStepper {
    private let _textField: UITextField!
    public var textField: UITextField {
        get {
            return _textField
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        _textField = nil
        super.init(coder: aDecoder)!
    }
    
    init(frame: CGRect, textField: UITextField) {
        self._textField = textField
        super.init(frame: frame)
    }
}

extension ScorecardViewController {
    
    func hideNavigationBar() {
        self.navigationController?.isNavigationBarHidden = true
    }
    
    public func showNavigationBar() {
        self.navigationController?.isNavigationBarHidden = false
    }
    
}

extension UIView {
    
    func absoluteFrame() -> CGRect {
        if let superview = self.superview {
            return superview.convert(self.frame, to: nil)
        } else {
            return CGRect()
        }
    }
    
    func addSubview(_ parent: UIView, constant: CGFloat = 0, anchored attributes: ConstraintAnchor...) {
        self.addSubview(parent)
        Constraint.anchor(view: self, control: parent, constant: constant, attributes: attributes)
    }
    
    func addSubview(_ parent: UIView, constant: CGFloat = 0, anchored attributes: [ConstraintAnchor]?) {
        self.addSubview(parent)
        if let attributes = attributes {
            Constraint.anchor(view: self, control: parent, constant: constant, attributes: attributes)
        }
    }
    
    func addSubview(_ parent: UIView, leading: CGFloat? = nil, trailing: CGFloat? = nil, top: CGFloat? = nil, bottom: CGFloat? = nil) {
        self.addSubview(parent)
        if let leading = leading {
            Constraint.anchor(view: self, control: parent, constant: leading, attributes: .leading)
        }
        if let trailing = trailing {
            Constraint.anchor(view: self, control: parent, constant: trailing, attributes: .trailing)
        }
        if let top = top {
            Constraint.anchor(view: self, control: parent, constant: top, attributes: .top)
        }
        if let bottom = bottom {
            Constraint.anchor(view: self, control: parent, constant: bottom, attributes: .bottom)
        }
    }
}

extension CGPoint {
    
    func distance(to point: CGPoint) -> CGFloat {
        return sqrt(pow((self.x - point.x), 2) + pow((self.y - point.y), 2))
    }
    
    func offsetBy(dx: CGFloat = 0.0, dy: CGFloat = 0.0) -> CGPoint {
        return CGPoint(x: self.x + dx, y: self.y + dy)
    }
}

extension CGRect {
    
    var center: CGPoint {
        get {
            return CGPoint(x: self.midX, y: self.midY)
        }
    }

    func offsetBy(dx: CGFloat = 0.0, dy: CGFloat = 0.0) -> CGRect {
        return CGRect(x: self.minX + dx, y: self.minY + dy, width: self.width, height: self.height)
    }
    
    func offsetBy(offset: CGPoint) -> CGRect {
        return CGRect(x: self.minX + offset.x, y: self.minY + offset.y, width: self.width, height: self.height)
    }
    
    func grownBy(dx: CGFloat = 0.0, dy: CGFloat = 0.0) -> CGRect {
        return CGRect(x: self.minX - dx, y: self.minY - dy, width: self.width + (2 * dx), height: self.height + (2 * dy))
    }
}

extension CGPoint {
    
    static prefix func - (point: CGPoint) -> CGPoint {
        return CGPoint(x: -point.x, y: -point.y)
    }
}

class SegmentedControl: UISegmentedControl {
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.set()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.set()
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        self.set()
    }
    
    private func set() {
        if #available(iOS 13.0, *) {
            self.selectedSegmentTintColor = Palette.segmentedControls.background
            let selectedImage = UIImage(color: Palette.segmentedControls.background, size: CGSize(width: 1, height: 32))
            self.setBackgroundImage(selectedImage, for: .selected, barMetrics: .default)
            let unselectedImage = UIImage(color: Palette.buttonFace.background, size: CGSize(width: 1, height: 32))
            self.setBackgroundImage(unselectedImage, for: .normal, barMetrics: .default)
            self.backgroundColor = Palette.buttonFace.background
            self.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: Palette.banner.text], for: .selected)
            self.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: Palette.buttonFace.text], for: .normal)
        } else {
            self.tintColor = Palette.segmentedControls.background
            self.backgroundColor = Palette.buttonFace.background
            self.layer.cornerRadius = 5.0
        }
        self.layer.masksToBounds = true
    }
}

extension UIImage {
    convenience init(color: UIColor, size: CGSize) {
        UIGraphicsBeginImageContextWithOptions(size, false, 1)
        color.set()
        let ctx = UIGraphicsGetCurrentContext()!
        ctx.fill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        self.init(data: image.pngData()!)!
    }
    
    convenience init?(prefixed name: String) {
        if name.left(7) == "system." {
            self.init(systemName: name.right(name.length-7))
        } else {
            self.init(named: name)
        }
    }
    
    public var asTemplate: UIImage {
        return self.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
    }
    
    public func crop(to frame: CGRect) -> UIImage? {
        let scaledFrame = CGRect(x: frame.origin.x * self.scale, y: frame.origin.y * self.scale, width: frame.size.width * self.scale, height: frame.size.height * self.scale)
        
        if let coreImage = self.cgImage?.cropping(to: scaledFrame) {
            let croppedImage = UIImage(cgImage: coreImage, scale: self.scale, orientation: self.imageOrientation)
            return croppedImage
        } else {
            return nil
        }
    }
}

extension Array {
    
    mutating func rotate(by rotations: Int) {
        if rotations == 0 || self.count <= 1 {
            return
        }

       let length = self.count
       let rotations = (length + rotations % length) % length

       let reversed: Array = self.reversed()
       let leftPart: Array = reversed[0..<rotations].reversed()
       let rightPart: Array = reversed[rotations..<length].reversed()
       self = leftPart + rightPart
    }
}

class TextField : UITextField {
    
    // Sets up default colors and moves placeholder to attributed placeholder
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupTextField()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupTextField()
    }
    
    override var placeholder: String? {
        didSet {
            self.setupPlaceholder()
        }
    }
    
    private func setupTextField() {
        self.setupPlaceholder()
        self.backgroundColor = Palette.inputControl.background
        self.textColor = Palette.inputControl.text
    }
    
    private func setupPlaceholder() {
        if let placeholder = self.placeholder {
            self.attributedPlaceholder = NSAttributedString(string: placeholder, attributes:[NSAttributedString.Key.foregroundColor: Palette.inputControl.faintText])
        }
    }
}

class HiddenTextField : UITextField {
    
    // Only shows background when enabled
    
    override var isEnabled: Bool {
        didSet {
            self.backgroundColor = (self.isEnabled ? Palette.inputControl.background : Palette.normal.background)
        }
    }
}

extension NSAttributedString {
    
    convenience init(_ string: String, color: UIColor? = nil, font: UIFont? = nil) {
        var attributes: [NSAttributedString.Key : Any] = [:]
        
        if let color = color {
            attributes[NSAttributedString.Key.foregroundColor] = color
        }
        if let font = font {
            attributes[NSAttributedString.Key.font] = font
        }
        
        self.init(string: string, attributes: attributes)
    }
    
    convenience init(markdown string: String, font: UIFont? = nil) {
        let font = font ?? UIFont.systemFont(ofSize: 17)
        let tokens = ["@*/",
                      "**",
                      "//",
                      "@@",
                      "*/",
                      "@/",
                      "@*",
                      "^^"
                      ]
        let pointSize = font.fontDescriptor.pointSize
        let boldItalicFont = UIFont(descriptor: font.fontDescriptor.withSymbolicTraits([.traitItalic, .traitBold])! , size: pointSize)
        let attributes: [[NSAttributedString.Key : Any]] = [
            [NSAttributedString.Key.foregroundColor: Palette.normal.themeText,
             NSAttributedString.Key.font: boldItalicFont],
            
            [NSAttributedString.Key.font : UIFont.systemFont(ofSize: pointSize, weight: .bold)],
            
            [NSAttributedString.Key.font: UIFont.italicSystemFont(ofSize: pointSize)],
            
            [NSAttributedString.Key.foregroundColor: Palette.normal.themeText],
            
            [NSAttributedString.Key.font : boldItalicFont],
            
            [NSAttributedString.Key.foregroundColor: Palette.normal.themeText,
             NSAttributedString.Key.font: UIFont.italicSystemFont(ofSize: pointSize)],
            
            [NSAttributedString.Key.foregroundColor: Palette.normal.themeText,
             NSAttributedString.Key.font: UIFont.systemFont(ofSize: pointSize, weight: .bold)],
            
            [NSAttributedString.Key.foregroundColor: Palette.normal.themeText,
             NSAttributedString.Key.font: UIFont.systemFont(ofSize: 24, weight: .bold)]
        ]
        self.init(attributedString: NSAttributedString.replace(in: string, tokens: tokens, with: attributes))
    }
    
    convenience init(imageName: String, color: UIColor? = nil) {
        let image = UIImage(prefixed: imageName)!
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = (color == nil ? image : image.asTemplate)
        let imageString = NSMutableAttributedString(attachment: imageAttachment)
        if let color = color {
            imageString.addAttribute(NSAttributedString.Key.foregroundColor, value: color, range: NSRange(0...imageString.length - 1))
        }
        self.init(attributedString: imageString)
    }
    
    private static func replace(in string: String, tokens: [String], with attributes: [[NSAttributedString.Key : Any]], level: Int = 0) -> NSAttributedString {
        var result = NSAttributedString()
        let part = string.components(separatedBy: tokens[level])
        for (index, substring) in part.enumerated() {
            if index % 2 == 0 {
                if level == tokens.count - 1 {
                    result = result + NSAttributedString(substring)
                } else {
                    result = result + replace(in: substring, tokens: tokens, with: attributes, level: level + 1)
                }
            } else {
                result = result + NSAttributedString(string: substring, attributes: attributes[level])
            }
        }
        return result
    }
    
    static func ~= (left: inout NSAttributedString, right: String) {
        left = NSAttributedString(markdown: right)
    }
    
    static func + (left: NSAttributedString, right: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString()
        result.append(left)
        result.append(right)
        return result
    }
    
    static func + (left: NSAttributedString, right: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        result.append(left)
        result.append(NSAttributedString(markdown: right))
        return result
    }
    
    static func + (left: String, right: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString()
        result.append(NSAttributedString(markdown: left))
        result.append(right)
        return result
    }
    
    func labelHeight(width: CGFloat? = nil, font: UIFont? = nil) -> CGFloat {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: width ?? CGFloat.greatestFiniteMagnitude, height: ScorecardUI.screenHeight))
        label.numberOfLines = (width == nil ? 1 : 0)
        if let font = font {
            label.font = font
        }
        label.lineBreakMode = .byWordWrapping
        label.attributedText = self
        label.sizeToFit()
        return label.frame.height
    }

    func labelWidth(height: CGFloat? = nil, font: UIFont? = nil) -> CGFloat {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: CGFloat.greatestFiniteMagnitude, height: height ?? 30))
        label.numberOfLines = (height == nil ? 1 : 0)
        if let font = font {
            label.font = font
        }
        label.attributedText = self
        label.sizeToFit()
        return label.frame.width
    }
}

extension NSMutableAttributedString {
    
    static func + (left: NSMutableAttributedString, right: NSMutableAttributedString) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        result.append(left)
        result.append(right)
        return result
    }
}

