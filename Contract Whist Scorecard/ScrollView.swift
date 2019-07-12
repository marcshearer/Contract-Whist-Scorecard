//
//  ScrollView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 21/06/2019.
//  Copyright © 2019 Marc Shearer. All rights reserved.
//

import UIKit

open class ScrollViewCell : UIView {
    public var indexPath: IndexPath!
}

@objc protocol ScrollViewDataSource {
    
    @objc optional func numberOfSections(in: ScrollView) -> Int
    
    func scrollView(_ scrollView: ScrollView, numberOfItemsIn section: Int) -> Int
    
    func scrollView(_ scrollView: ScrollView, cellForItemAt indexPath: IndexPath) -> ScrollViewCell
    
}

@objc protocol ScrollViewDelegate {
    
    @objc optional func scrollView(_ scrollView: ScrollView, frameForSectionHeader: Int) -> CGRect
    
    @objc optional func scrollView(_ scrollView: ScrollView, viewForSectionHeader: Int) -> UIView
    
    func scrollView(_ scrollView: ScrollView, frameForItemAt indexPath: IndexPath) -> CGRect
    
    @objc optional func scrollView(_ scrollView: ScrollView, shouldSelectItemAt indexPath: IndexPath) -> Bool
    
    @objc optional func scrollView(_ scrollView: ScrollView, didSelectItemAt indexPath: IndexPath, tapPosition: CGPoint)
    
    @objc optional func scrollView(_ scrollView: ScrollView, didSelectCell: ScrollViewCell, tapPosition: CGPoint)
}

class ScrollView : NSObject, UIScrollViewDelegate {
    
    public var delegate: ScrollViewDelegate?
    public var dataSource: ScrollViewDataSource?
    private var scrollView: UIScrollView
    private var sectionHeaderViewList: [Int : UIView]
    private var cellList: [IndexPath : ScrollViewCell]
    private var overlaps = false
    
    init(_ scrollView: UIScrollView) {
        self.scrollView = scrollView
        self.sectionHeaderViewList = [:]
        self.cellList = [:]
        super.init()
        scrollView.delegate = self
        
        // Setup tap gesture recognizer
        let scrollViewTap = UITapGestureRecognizer(target: self, action: #selector(scrollViewTapped(_:)))
        scrollViewTap.numberOfTapsRequired = 1
        self.scrollView.addGestureRecognizer(scrollViewTap)
    }

    @objc private func scrollViewTapped(_ touch: UITouch) {
        let tapPosition = touch.location(in: self.scrollView)
        for (_, cell) in cellList {
            if cell.frame.contains(tapPosition) {
                // Call both delegates - only one will be implemented
                self.delegate?.scrollView?(self, didSelectItemAt: cell.indexPath, tapPosition: tapPosition)
                self.delegate?.scrollView?(self, didSelectCell: cell, tapPosition: tapPosition)
            }
        }
    }
    
    public func reloadData() {
        // Remove any existing headers cells
        Utility.mainThread {
            for (_, sectionHeaderView) in self.sectionHeaderViewList {
                sectionHeaderView.removeFromSuperview()
            }
            self.sectionHeaderViewList.removeAll()
            for (_, cell) in self.cellList {
                cell.removeFromSuperview()
            }
            self.cellList.removeAll()
            self.overlaps = false
            
            self.scrollView.contentSize = self.scrollView.frame.size
            
            self.reloadSections()
        }
    }
    
    public func reloadItems(at indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            if let existingCell = cellList[indexPath] {
                existingCell.removeFromSuperview()
                cellList[indexPath] = nil
            }
            self.reloadCell(at: indexPath)
        }
    }
    
    internal func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.reloadSections()
    }
    
    private func reloadSections() {
        
        // Setup content rectangle
        let contentFrame = CGRect(origin: self.scrollView.contentOffset, size: self.scrollView.frame.size)
        
        // Create sections
        let sections = self.dataSource?.numberOfSections?(in: self) ?? 1
        if sections > 0 {
            for section in 0..<sections {
                
                if sectionHeaderViewList[section] == nil {
                    
                    if let sectionHeaderFrame = self.delegate?.scrollView?(self, frameForSectionHeader: section) {
                        
                        if sectionHeaderFrame.intersects(contentFrame) {
                        
                            if let sectionHeaderView = self.delegate?.scrollView?(self, viewForSectionHeader: section) {
                            
                                sectionHeaderView.frame = sectionHeaderFrame
                                self.sectionHeaderViewList[section] = sectionHeaderView
                                self.scrollView.addSubview(sectionHeaderView)
                            }
                        }
                    }
                }
                
                // Create items for section
                if let itemsInSection = self.dataSource?.scrollView(self, numberOfItemsIn: section) {
                    if itemsInSection > 0 {
                        for item in 0..<itemsInSection {
                            let indexPath = IndexPath(item: item, section: section)
                            
                            if self.cellList[indexPath] == nil {
                                
                                self.reloadCell(at: indexPath)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func reloadCell(at indexPath: IndexPath) {
        if let itemFrame = self.delegate?.scrollView(self, frameForItemAt: indexPath) {
            
            self.scrollView.contentSize = CGSize(width: max(self.scrollView.contentSize.width, itemFrame.maxX),
                                                 height: max(self.scrollView.contentSize.height, itemFrame.maxY))
            
            // Setup content rectangle
            let contentFrame = CGRect(origin: self.scrollView.contentOffset, size: self.scrollView.frame.size)
            
            if itemFrame.intersects(contentFrame) {
                
                if let cell = self.dataSource?.scrollView(self, cellForItemAt: indexPath) {
                    
                    if let _ = cellList.first(where: { $0.value.frame.intersects(cell.frame) }) {
                        overlaps = true
                    }
                    self.cellList[indexPath] = cell
                    cell.frame = itemFrame
                    cell.indexPath = indexPath
                    self.scrollView.addSubview(cell)
                }
            }
        }
    }
}
