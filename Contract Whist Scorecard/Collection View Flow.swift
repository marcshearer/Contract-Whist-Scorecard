//
//  Collection View Flow.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 02/06/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class CustomCollectionViewLayout: UICollectionViewFlowLayout {

    private var cache: [UICollectionViewLayoutAttributes] = []
    
    private var contentWidth: CGFloat = 0
    private var alphaFactor: CGFloat = 1.0
    private var scaleFactor: CGFloat = 0.98
    
    private var contentHeight: CGFloat {
        return collectionView?.bounds.height ?? 0.0
    }

    override internal var collectionViewContentSize: CGSize {
        return CGSize(width: self.contentWidth, height: self.contentHeight)
    }
    
    override func prepare() {
        cache = []
        if let collectionView = collectionView {
            let items = collectionView.numberOfItems(inSection: 0)
            let width = collectionView.bounds.width
            
            self.contentWidth = collectionView.bounds.width * CGFloat(items)
            
            for item in 0..<items {
                let frame = CGRect(x: CGFloat(item) * width, y: 0, width: width, height: self.contentHeight)
                let attributes = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: item, section: 0))
                attributes.frame = frame
                cache.append(attributes)
            }
            
        }
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        if let collectionView = collectionView {
            var layoutAttributes: [UICollectionViewLayoutAttributes] = []
            let items = cache.count
            let minItem = max(0, Utility.round(Double(rect.minX / collectionView.bounds.width)))
            let maxItem = min(Utility.round(Double(rect.maxX / collectionView.bounds.width)), max(0,items - 1))
            
            if minItem < items {
                
                for item in minItem...maxItem {
                    layoutAttributes.append(transformLayoutAttributes(cache[item].copy() as! UICollectionViewLayoutAttributes))
                }
                
                return layoutAttributes
                
            } else {
                return nil
            }
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
        guard let collectionView = self.collectionView else { return attributes }
        
        let collectionCenter = collectionView.frame.size.width/2
        let offset = collectionView.contentOffset.x
        let normalizedCenter = attributes.center.x - offset
        
        let maxDistance = self.itemSize.width + self.minimumLineSpacing
        let distance = min(abs(collectionCenter - normalizedCenter), maxDistance)
        let ratio = (maxDistance - distance)/maxDistance
        
        let alpha = ratio * (1 - alphaFactor) + alphaFactor
        let scale = ratio * (1 - scaleFactor) + scaleFactor
        attributes.alpha = alpha
        attributes.transform3D = CATransform3DScale(CATransform3DIdentity, scale, 1, 1)
        
        return attributes
    }
    
    override open func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        guard let collectionView = collectionView , !collectionView.isPagingEnabled,
            let layoutAttributes = self.layoutAttributesForElements(in: collectionView.bounds)
            else { return super.targetContentOffset(forProposedContentOffset: proposedContentOffset) }
        
        let isHorizontal = (self.scrollDirection == .horizontal)
        
        let midSide = (isHorizontal ? collectionView.bounds.size.width : collectionView.bounds.size.height) / 2
        let proposedContentOffsetCenterOrigin = (isHorizontal ? proposedContentOffset.x : proposedContentOffset.y) + midSide
        
        var targetContentOffset: CGPoint
        if isHorizontal {
            let closest = layoutAttributes.sorted { abs($0.center.x - proposedContentOffsetCenterOrigin) < abs($1.center.x - proposedContentOffsetCenterOrigin) }.first ?? UICollectionViewLayoutAttributes()
            targetContentOffset = CGPoint(x: floor(closest.center.x - midSide), y: proposedContentOffset.y)
        }
        else {
            let closest = layoutAttributes.sorted { abs($0.center.y - proposedContentOffsetCenterOrigin) < abs($1.center.y - proposedContentOffsetCenterOrigin) }.first ?? UICollectionViewLayoutAttributes()
            targetContentOffset = CGPoint(x: proposedContentOffset.x, y: floor(closest.center.y - midSide))
        }
        
        return targetContentOffset
    }
}
