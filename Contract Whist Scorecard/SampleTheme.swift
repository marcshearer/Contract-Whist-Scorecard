//
//  SampleTheme.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 04/06/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class SampleTheme: UIView {

    @IBOutlet private weak var banner: UIView!
    @IBOutlet private weak var bannerLabel: UILabel!
    @IBOutlet private weak var titleBar: TitleBar!
    @IBOutlet private weak var leftButton: ImageButton!
    @IBOutlet private weak var rightButton: ImageButton!
    @IBOutlet private weak var contentView: UIView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.loadSampleThemeView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.loadSampleThemeView()
    }
    
    private func loadSampleThemeView() {
        Bundle.main.loadNibNamed("SampleTheme", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.layoutSubviews()
        self.setColors()
    }
    
    public func setColors(theme: Theme? = nil) {
        
        let theme = theme ?? Themes.currentTheme!
        
        self.banner?.backgroundColor = theme.color(.gameBanner, .current)
        self.bannerLabel?.textColor = theme.color(.gameBannerText, .current)
        self.contentView?.backgroundColor = theme.color(.background, .current)
        self.titleBar?.set(faceColor: theme.color(.buttonFace, .current))
        self.titleBar?.set(textColor: theme.color(.buttonFaceText, .current))
        self.titleBar?.set(font: UIFont.systemFont(ofSize: 5, weight: .bold))
        self.leftButton?.set(faceColor: theme.color(.buttonFace, .current))
        self.leftButton?.set(titleColor: theme.color(.buttonFaceText, .current))
        self.leftButton?.set(titleFont: UIFont.systemFont(ofSize: 5))
        self.leftButton?.set(imageTintColor: theme.color(.gameBanner, .current))
        self.leftButton.setProportions(top: 1, image: 2, imageBottom: 1, title: 1, titleBottom: 0, message: 0, bottom: 1)
        self.rightButton?.set(faceColor: theme.color(.buttonFace, .current))
        self.rightButton?.set(titleColor: theme.color(.buttonFaceText, .current))
        self.rightButton?.set(titleFont: UIFont.systemFont(ofSize: 5))
        self.rightButton?.set(imageTintColor: theme.color(.gameBanner, .current))
        self.rightButton.setProportions(top: 1, image: 2, imageBottom: 1, title: 1, titleBottom: 0, message: 0, bottom: 1)
    }
}
