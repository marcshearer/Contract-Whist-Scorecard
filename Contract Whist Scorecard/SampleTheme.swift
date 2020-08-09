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
    @IBOutlet private weak var contentView: UIView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.loadSampleThemeView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.loadSampleThemeView()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.contentView.roundCorners(cornerRadius: 5.0)
    }
    
    private func loadSampleThemeView() {
        Bundle.main.loadNibNamed("SampleTheme", owner: self, options: nil)
        self.addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.layoutSubviews()
    }
    
    public func setColors(theme: Theme? = nil) {
        
        let theme = theme ?? Themes.currentTheme!
        
        self.banner?.backgroundColor = theme.background(.banner)
        self.bannerLabel?.textColor = theme.text(.banner)
        self.contentView?.backgroundColor = theme.background(.background)
    }
}
