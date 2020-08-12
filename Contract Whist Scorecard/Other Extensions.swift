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

extension UIViewController {
    
    func hideNavigationBar() {
        self.navigationController?.isNavigationBarHidden = true
    }
    
    public func showNavigationBar() {
        self.navigationController?.isNavigationBarHidden = false
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
    
    func asTemplate() -> UIImage {
        return self.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
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

extension NSMutableAttributedString {
    
    static func + (left: NSMutableAttributedString, right: NSMutableAttributedString) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        result.append(left)
        result.append(right)
        return result
    }
    
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
}

