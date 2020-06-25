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
            self.selectedSegmentTintColor = Palette.emphasis
            let selectedImage = UIImage(color: Palette.emphasis, size: CGSize(width: 1, height: 32))
            self.setBackgroundImage(selectedImage, for: .selected, barMetrics: .default)
            let unselectedImage = UIImage(color: UIColor.white, size: CGSize(width: 1, height: 32))
            self.setBackgroundImage(unselectedImage, for: .normal, barMetrics: .default)
            self.backgroundColor = UIColor.white
        } else {
            self.tintColor = Palette.emphasis
            self.backgroundColor = UIColor.white
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
