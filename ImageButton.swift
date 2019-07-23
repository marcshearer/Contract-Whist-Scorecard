//
//  ImageButtonView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 22/07/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit

@objc protocol ImageButtonDelegate {
    func imageButtonPressed(_ sender: ImageButton)
}

class ImageButton: UIView {
    
    @IBInspectable var image: UIImage!
    @IBInspectable var title: String!
    @IBInspectable var textColor: UIColor!
    @IBOutlet var delegate: ImageButtonDelegate?
    
    @IBOutlet var contentView: UIView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBAction private func tapGesture(recognizer: UITapGestureRecognizer) {
        self.delegate?.imageButtonPressed(self)
    }
    
    public var isEnabled: Bool {
        get {
            return self.contentView.isUserInteractionEnabled
        }
        set(newValue) {
            self.contentView.isUserInteractionEnabled = newValue
        }
    }
    
    override var alpha: CGFloat {
        get {
            return self.contentView.alpha
        }
        set(newValue) {
            self.imageView?.alpha = newValue
            self.titleLabel?.alpha = newValue
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.loadImageButtonView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.loadImageButtonView()
    }
    
    private func loadImageButtonView() {
        Bundle.main.loadNibNamed("ImageButton", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    
    override func layoutSubviews() {
        self.titleLabel.text = self.title
        self.imageView.image = self.image
        self.contentView.backgroundColor = self.backgroundColor
        self.titleLabel.textColor = self.textColor
    }
    
}
