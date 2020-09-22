//
//  String Extensions.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 27/09/2017.
//  Copyright © 2017 Marc Shearer. All rights reserved.
//

import Foundation
import UIKit

extension String {
    
    func left(_ length: Int) -> String {
        return String(self.prefix(length))
    }
    
    func right(_ length: Int) -> String {
        return String(self.suffix(length))
    }
    
    func mid(_ from: Int, _ length: Int) -> String {
        return String(self.prefix(from+length).suffix(length))
    }
    
    func split(at: Character = ",") -> [String] {
        let substrings = self.split(separator: at).map(String.init)
        return substrings
    }
    
    
    var length: Int {
        get {
            return self.count
        }
    }
    
    func contains(_ contains: String, caseless: Bool = false) -> Bool {
        var string = self
        var contains = contains
        if caseless {
            string = string.lowercased()
            contains = contains.lowercased()
        }
        return string.range(of: contains) != nil
    }
    
    func position(_ contains: String, caseless: Bool = false) -> Int? {
        var string = self
        var contains = contains
        if caseless {
            string = string.lowercased()
            contains = contains.lowercased()
        }
        let range = string.range(of: contains)
        if range == nil {
            return nil
        } else {
            return self.distance(from: self.startIndex, to: range!.lowerBound)
        }
    }
    
    
    func trim() -> String {
        return self.trimmingCharacters(in: .whitespaces)
    }
    
    func rtrim() -> String {
        let trailingWhitespace = self.range(of: "\\s*$", options: .regularExpression)
        return self.replacingCharacters(in: trailingWhitespace!, with: "")
    }

    func ltrim() -> String {
        let leadingWhitespace = self.range(of: "^\\s*", options: .regularExpression)
        return self.replacingCharacters(in: leadingWhitespace!, with: "")
    }
    
    func labelHeight(width: CGFloat? = nil, font: UIFont? = nil) -> CGFloat {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: width ?? CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        label.numberOfLines = (width == nil ? 1 : 0)
        if let font = font {
            label.font = font
        }
        label.text = self
        label.sizeToFit()
        return label.frame.height
    }

    func labelWidth(height: CGFloat? = nil, font: UIFont? = nil) -> CGFloat {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: CGFloat.greatestFiniteMagnitude, height: height ?? 30))
        label.numberOfLines = (height == nil ? 1 : 0)
        if let font = font {
            label.font = font
        }
        label.text = self
        label.sizeToFit()
        return label.frame.width
    }

}
