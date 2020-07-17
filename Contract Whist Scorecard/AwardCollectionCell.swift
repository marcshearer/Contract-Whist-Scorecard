//
//  AwardView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 15/07/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

public enum AwardCellMode: String {
    case list = "List"
    case grid = "Grid"
}

class AwardCollectionCell: UICollectionViewCell {
    @IBOutlet private weak var view: UIView!
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var shortNameLabel: UILabel!
    @IBOutlet private weak var titleLabel: UILabel!
    
    public func bind(award: Award, backgroundColor: UIColor = Palette.buttonFaceText, textColor: UIColor = Palette.buttonFaceText) {
        self.nameLabel?.textColor = backgroundColor
        self.titleLabel?.textColor = textColor
        self.view?.backgroundColor = award.backgroundColor
        self.imageView?.image = UIImage(named: award.imageName)
        self.nameLabel?.text = award.name
        self.shortNameLabel?.text = award.shortName
        self.titleLabel?.text = award.title
    }
    
    public class func register(_ collectionView: UICollectionView, modes: AwardCellMode...) {
        for mode in modes {
            let nib = UINib(nibName: "Award\(mode.rawValue)CollectionCell", bundle: nil)
            collectionView.register(nib, forCellWithReuseIdentifier: "\(mode.rawValue)")
        }
    }
    
    public class func dequeue(_ collectionView: UICollectionView, for indexPath: IndexPath, mode: AwardCellMode) -> AwardCollectionCell {
        return collectionView.dequeueReusableCell(withReuseIdentifier: "\(mode.rawValue)", for: indexPath) as! AwardCollectionCell
    }
}
