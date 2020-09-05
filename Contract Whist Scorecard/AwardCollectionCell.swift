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
    
    @IBOutlet private weak var awardView: AwardView!
    @IBOutlet private weak var nameLabel: UILabel!
    @IBOutlet private weak var shortNameLabel: UILabel!
    @IBOutlet private weak var titleLabel: UITextView!
    
    public func bind(award: Award, color: PaletteColor = Palette.buttonFace, alpha: CGFloat = 1.0, showBadge: Bool = false) {
        self.nameLabel?.textColor = color.text
        self.titleLabel?.textColor = color.text
        self.awardView.set(award: award, alpha: alpha, showBadge: showBadge)
        self.nameLabel?.text = award.name
        self.shortNameLabel?.text = award.shortName
        self.titleLabel?.text = award.title
        self.titleLabel?.sizeToFit()
    }
    
    public class func sizeForCell(_ collectionView: UICollectionView, mode: AwardCellMode, across: CGFloat = 5.0, spacing: CGFloat = 10.0, labelHeight: CGFloat = 20.0, sectionInsets: UIEdgeInsets = UIEdgeInsets()) -> CGSize {
        let height = collectionView.frame.height
        let width = collectionView.frame.width - sectionInsets.left - sectionInsets.right
        let viewSize = min(((width + spacing) / across) - spacing, height - (mode == .list ? 0 : labelHeight))
        if mode == .list {
            let numberVertically = Utility.roundQuotient(height, 90.0)
            let idealHeight: CGFloat = ((height + spacing) / CGFloat(numberVertically)) - spacing
            return CGSize(width: width, height: min(height < 120 ? viewSize : idealHeight, height))
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
    
    private static let noAwardsHeight: CGFloat = 30.0
    private static let normalHeight: CGFloat = 56.0
    private weak var delegate: AwardCollectionDelegate?
    
    @IBOutlet private weak var gridButton: ClearButton!
    @IBOutlet private weak var listButton: ClearButton!
    @IBOutlet private weak var panelView: UIView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var noAwardsLabel: UILabel!
    @IBOutlet private weak var noAwardsHeightConstraint: NSLayoutConstraint!
    
    @IBAction func listModePressed(_ button: UIButton) {
        self.delegate?.changeMode(to: .list, section: button.tag)
    }

    @IBAction func gridModePressed(_ button: UIButton) {
        self.delegate?.changeMode(to: .grid, section: button.tag)
    }

    public func bind(title: NSAttributedString, color: PaletteColor = Palette.buttonFace, section: Int, mode: AwardCellMode, noAwards: Bool = false) {
        self.panelView.backgroundColor = color.background
        self.panelView.layoutIfNeeded()
        self.panelView.roundCorners(cornerRadius: 8, bottomRounded: false)
        self.titleLabel.textColor = color.text
        self.titleLabel.attributedText = title
        self.gridButton.tintColor = (mode == .grid ? color.themeText : color.text)
        self.gridButton.tag = section
        self.listButton.tintColor = (mode == .list ? color.themeText : color.text)
        self.listButton.tag = section
        if noAwards {
            self.noAwardsHeightConstraint.constant = AwardCollectionHeader.noAwardsHeight
            self.noAwardsLabel.text = "No Awards Found"
            self.noAwardsLabel.textColor = Palette.disabled.text
            self.noAwardsLabel.isHidden = false
        } else {
            self.noAwardsHeightConstraint.constant = 0
            self.noAwardsLabel.isHidden = true
        }
    }
    
    public static func sizeForHeader(_ collectionView: UICollectionView, section: Int, noAwards: Bool) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: AwardCollectionHeader.normalHeight + (noAwards ? AwardCollectionHeader.noAwardsHeight : 0))
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
