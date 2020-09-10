//
//  Collection View Flow.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 02/06/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

protocol CustomCollectionViewLayoutDelegate : class {
    func changed(_ collectionView: UICollectionView, itemAtCenter: Int, forceScroll: Bool)
}

class CustomCollectionViewLayout: UICollectionViewFlowLayout {

    private var cache: [UICollectionViewLayoutAttributes] = []
    
    @IBInspectable private var fixedFactors: Bool = true
    @IBInspectable private var alphaFactor: CGFloat = 1.0
    @IBInspectable private var scaleFactor: CGFloat = 0.98
    
    public weak var delegate: CustomCollectionViewLayoutDelegate!
    
    private var contentWidth: CGFloat = 0.0
    private var collectionViewWidth: CGFloat = 0.0
    private var collectionViewHeight: CGFloat = 0.0
    
    private var contentHeight: CGFloat {
        return collectionView?.bounds.height ?? 0.0
    }
    
    private var cellWidth: CGFloat {
        return self.itemSize.width
    }

    override internal var collectionViewContentSize: CGSize {
        return CGSize(width: self.contentWidth, height: self.contentHeight)
    }
    
    override func prepare() {
        cache = []
        if let collectionView = collectionView {
            let items = collectionView.numberOfItems(inSection: 0)
            
            let delegate = self.collectionView?.delegate as! UICollectionViewDelegateFlowLayout
            self.itemSize = delegate.collectionView!(collectionView, layout: self, sizeForItemAt: IndexPath(item: 0, section: 0))
            self.collectionViewWidth = collectionView.bounds.width
            self.collectionViewHeight = collectionView.bounds.height
            self.contentWidth = (self.cellWidth * CGFloat(items)) + 20.0
            
            for item in 0..<items {
                let frame = CGRect(x: CGFloat(item) * self.cellWidth, y: 0, width: self.cellWidth, height: self.itemSize.height)
                let attributes = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: item, section: 0))
                attributes.frame = frame
                cache.append(attributes)
            }
        }
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {

        var layoutAttributes: [UICollectionViewLayoutAttributes] = []
        let items = cache.count
        
        let minItem = max(0, Utility.round(Double(rect.minX / self.cellWidth)))
        let maxItem = min(Utility.round(Double(rect.maxX / self.cellWidth)), max(0,items - 1))
        
        if minItem < items {
            
            for item in minItem...maxItem {
                layoutAttributes.append(transformLayoutAttributes(cache[item].copy() as! UICollectionViewLayoutAttributes))
            }
            
            return layoutAttributes
            
        } else {
            return nil
        }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return cache[indexPath.item]
    }
    
    override public func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
    
    fileprivate func transformLayoutAttributes(_ attributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        
        if let collectionView = self.collectionView {
        
            var alpha: CGFloat
            var scale: CGFloat
            
            let offsetCenter = collectionView.contentOffset.x + (self.collectionViewWidth / 2.0)
            let distanceFromOffsetCenter = abs(attributes.center.x - offsetCenter)
            let itemsAcross = self.collectionViewWidth / self.cellWidth
            let itemsFromCenter = (distanceFromOffsetCenter / self.cellWidth)
            
            if self.fixedFactors {
                alpha = (itemsFromCenter == 0 ? 1 : alphaFactor)
                scale = (itemsFromCenter == 0 ? 1 : scaleFactor)
            } else {
                let multiplier = itemsFromCenter / (itemsAcross / 2)
                alpha = 1 - (multiplier * alphaFactor)
                scale = 1 - (multiplier * scaleFactor)
            }
            
            attributes.alpha = alpha
            attributes.transform3D = CATransform3DScale(CATransform3DIdentity, scale, scale, 1)
        }
        
        return attributes
    }
    
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        let proposedCenter = proposedContentOffset.x + (self.collectionViewWidth / 2.0)
        let itemAtCenter = Int(proposedCenter / self.cellWidth)
        if let collectionView = collectionView {
            self.delegate?.changed(collectionView, itemAtCenter: itemAtCenter, forceScroll: false)
        }
        let requiredOffset = ((CGFloat(itemAtCenter) + 0.5) * self.cellWidth) - (self.collectionViewWidth / 2.0)
        return CGPoint(x: requiredOffset, y: proposedContentOffset.y)
    }
}
