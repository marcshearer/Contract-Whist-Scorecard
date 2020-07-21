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
    
    public func bind(award: Award, backgroundColor: UIColor = Palette.buttonFace, textColor: UIColor = Palette.buttonFaceText, alpha: CGFloat = 1.0) {
        self.nameLabel?.textColor = textColor
        self.titleLabel?.textColor = textColor
        self.view?.backgroundColor = award.backgroundColor.withAlphaComponent(alpha)
        self.imageView?.image = UIImage(named: award.imageName)
        self.nameLabel?.text = award.name
        self.shortNameLabel?.text = award.shortName
        self.titleLabel?.text = award.title
        self.view?.layoutIfNeeded()
        self.view?.roundCorners(cornerRadius: 8.0)
    }
    
    public class func sizeForCell(_ collectionView: UICollectionView, mode: AwardCellMode, across: CGFloat = 5.0, spacing: CGFloat = 10.0, labelHeight: CGFloat = 20.0) -> CGSize {
        let height = collectionView.frame.height
        let width = collectionView.frame.width
        let viewSize = min(((width + spacing) / across) - spacing, height - (mode == .list ? 0 : labelHeight))
        if mode == .list {
            return CGSize(width: width, height: min(height < 120 ? viewSize : 60, height))
        } else {
            return CGSize(width: min(viewSize, width), height: viewSize + labelHeight)
        }
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

protocol AwardCollectionDelegate : class {
    
    func changeMode(to mode: AwardCellMode, section: Int)
}

class AwardCollectionHeader: UICollectionReusableView {
    
    private weak var delegate: AwardCollectionDelegate?
    
    @IBOutlet private weak var topConstraint: NSLayoutConstraint!
    @IBOutlet private weak var gridButton: ClearButton!
    @IBOutlet private weak var listButton: ClearButton!
    @IBOutlet private weak var panelView: UIView!
    @IBOutlet private weak var titleLabel: UILabel!
    
    @IBAction func listModePressed(_ button: UIButton) {
        self.delegate?.changeMode(to: .list, section: button.tag)
    }

    @IBAction func gridModePressed(_ button: UIButton) {
        self.delegate?.changeMode(to: .grid, section: button.tag)
    }

    public func bind(title: String, backgroundColor: UIColor = Palette.buttonFace, panelColor: UIColor = Palette.buttonFace /*sectionHeading*/, textColor: UIColor = Palette.buttonFaceText /*sectionHeadingText*/, section: Int) {
        self.topConstraint.constant = (section == 0 ? 0 : 0)
        self.panelView.backgroundColor = panelColor
        self.panelView.layoutIfNeeded()
        self.panelView.roundCorners(cornerRadius: 8, bottomRounded: false)
        self.titleLabel.textColor = textColor
        self.titleLabel.text = title
        self.gridButton.tintColor = textColor
        self.gridButton.tag = section
        self.listButton.tintColor = textColor
        self.listButton.tag = section
    }
    
    public static func sizeForHeader(_ collectionView: UICollectionView, section: Int) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: (section == 0 ? 56 : 56))
    }
    
    public class func register(_ collectionView: UICollectionView) {
        let nib = UINib(nibName: "AwardCollectionHeader", bundle: nil)
        collectionView.register(nib, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "Header")
    }
    
    public class func dequeue(_ collectionView: UICollectionView, for indexPath: IndexPath, delegate: AwardCollectionDelegate? = nil) -> AwardCollectionHeader {
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "Header", for: indexPath) as! AwardCollectionHeader
        view.delegate = delegate
        return view
    }    
}
