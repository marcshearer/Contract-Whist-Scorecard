//
//  Centered Collection View Flow.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 05/09/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class CenteredCollectionViewLayout: UICollectionViewFlowLayout {

    private var cache: [UICollectionViewLayoutAttributes] = []
      
    private var collectionViewWidth: CGFloat = 0.0
    private var collectionViewHeight: CGFloat = 0.0
    
    private var contentHeight: CGFloat {
        return self.itemSize.height
    }
    
    private var cellWidth: CGFloat {
        return self.itemSize.width
    }

    override func prepare() {
        cache = []
        if let collectionView = collectionView {
            let cells = collectionView.numberOfItems(inSection: 0)
            
            let delegate = self.collectionView?.delegate as! UICollectionViewDelegateFlowLayout
            self.itemSize = delegate.collectionView!(collectionView, layout: self, sizeForItemAt: IndexPath(item: 0, section: 0))
            let horizontalSpacing = delegate.collectionView!(collectionView, layout: self, minimumLineSpacingForSectionAt: 0)
            let verticalSpacing = delegate.collectionView!(collectionView, layout: self, minimumInteritemSpacingForSectionAt: 0)
            self.collectionViewWidth = collectionView.bounds.width
            self.collectionViewHeight = collectionView.bounds.height
            let cellsPerRow = max(1,Int(self.collectionViewWidth / self.cellWidth))
            let cellsInLastRow = cells % cellsPerRow
            let rows = Int((cells + cellsPerRow - 1) / cellsPerRow)
            let lastRowIndent = (cellsInLastRow == 0 ? 0 : ((CGFloat(cellsPerRow - cellsInLastRow) * (self.cellWidth + horizontalSpacing)) - horizontalSpacing) / 2.0)

            var column = cellsPerRow - 1    
            var row = -1
            for item in 0..<cells {
                column += 1
                if column + 1 > cellsPerRow {
                    column = 0
                    row += 1
                }
                let frame = CGRect(x: (row == rows - 1 ? lastRowIndent : 0.0) + CGFloat(column) * (self.cellWidth + horizontalSpacing), y: CGFloat(row) * (self.itemSize.height + verticalSpacing), width: self.cellWidth, height: self.itemSize.height)
                let attributes = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: item, section: 0))
                attributes.frame = frame
                cache.append(attributes)
            }
        }
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return cache
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return cache[indexPath.item]
    }
    
    override public func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
}
