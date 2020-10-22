//
//  HelpView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 20/10/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class HelpViewElement {
    let text: ()->(NSAttributedString)
    let views: [UIView]?
    let section: Int
    let itemFrom: Int?
    let itemTo: Int?
    let horizontalBorder: CGFloat
    let verticalBorder: CGFloat
    
    init(text: (()->String)? = nil, attributedText: (()->NSAttributedString)? = nil, views: [UIView?]? = nil, section: Int = 0, item: Int? = nil, itemTo: Int? = nil, border: CGFloat = 0, horizontalBorder: CGFloat? = nil, verticalBorder: CGFloat? = nil) {
        
        if let attributedText = attributedText {
            self.text = attributedText
        } else if let text = text {
            self.text = { NSAttributedString(text()) }
        } else {
            self.text = { NSAttributedString() }
        }
        
        if let views = views {
            var liveViews: [UIView] = []
            for view in views {
                if let view = view {
                    liveViews.append(view)
                }
            }
            self.views = liveViews
        } else {
            self.views = nil
        }
        
        self.section = section
        self.itemFrom = item
        self.itemTo = itemTo ?? item
        self.horizontalBorder = horizontalBorder ?? border
        self.verticalBorder = verticalBorder ?? border
        
        assert(self.views?.count ?? 0 == 1 || itemFrom == nil, "items are only relevant for a single view")
        assert(self.views?.count ?? 1 >= 1, "At least one view must be specified")
    }
}

fileprivate struct HelpViewActiveElement {
    let element: HelpViewElement
    let frame: CGRect?
    let views: [UIView]?
    
    init(element: HelpViewElement, frame: CGRect? = nil, views: [UIView]? = nil) {
        self.element = element
        self.frame = frame
        self.views = views
    }
}

class HelpView : UIView, UIGestureRecognizerDelegate {
    
    private var speechBubble: SpeechBubbleView!
    private var focusGradient: FocusGradientView!
    private var nextButton: ShadowButton!
    private var finishButton: ShadowButton!
    private var tapGesture: UITapGestureRecognizer!
    private var parentViewController: ScorecardViewController!
    private var parentView: UIView!
    
    private var elements: [HelpViewElement]!
    private var activeElements: [HelpViewActiveElement]!
    private var currentElement: Int = 0
    
    private var completion: ((Bool)->())?
    private var alwaysNext = false
    
    private let buttonHeight: CGFloat = 30
    private let buttonWidth: CGFloat = 80
    private let buttonSpacing: CGFloat = 10
    private let border: CGFloat = 8
    private let arrowHeight: CGFloat = 40
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        fatalError("Not implemented")
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.speechBubble = SpeechBubbleView(in: self)
        self.focusGradient = FocusGradientView(in: self)
        self.nextButton = self.addButton(title: "Next", target: #selector(HelpView.nextPressed))
        self.finishButton = self.addButton(title: "Exit", target: #selector(HelpView.self.finishPressed))
        self.isHidden = true
    }
    
    convenience init(in parentViewController: ScorecardViewController) {
        self.init(frame: parentViewController.view.frame)
        self.elements = []
        self.parentViewController = parentViewController
        self.parentView = parentViewController.view
        self.tapGesture = UITapGestureRecognizer(target: self, action: #selector(HelpView.nextPressed))
        self.tapGesture.delegate = self
        if !self.parentViewController.rootViewController.containers {
            self.addGestureRecognizer(self.tapGesture)
        }

        parentView.addSubview(self)
    }
    
    internal override func layoutSubviews() {
        super.layoutSubviews()
        self.frame = self.parentView.bounds
    }
    
    public func reset() {
        self.elements = []
    }
    
    public func add(_ text: @escaping @autoclosure ()->String, views: [UIView?]? = nil, section: Int = 0, item: Int? = nil, itemTo: Int? = nil, border: CGFloat = 0, horizontalBorder: CGFloat? = nil, verticalBorder: CGFloat? = nil) {
        
        self.elements.append(HelpViewElement(text: text, views: views, section: section, item: item, itemTo: itemTo, border: border, horizontalBorder: horizontalBorder, verticalBorder: verticalBorder))
    }
    
    public func add(_ attributedText: @escaping @autoclosure ()->NSAttributedString, views: [UIView?]? = nil, section: Int = 0, item: Int? = nil, itemTo: Int? = nil, border: CGFloat = 0, horizontalBorder: CGFloat? = nil, verticalBorder: CGFloat? = nil) {
        self.elements.append(HelpViewElement(attributedText: attributedText, views: views, section: section, item: item, itemTo: itemTo, border: border, horizontalBorder: horizontalBorder, verticalBorder: verticalBorder))
    }
    
    public func show(alwaysNext: Bool = false, completion: ((Bool)->())? = nil) {
        self.alwaysNext = alwaysNext
        self.completion = completion

        self.isHidden = false

        if self.parentViewController.rootViewController.containers {
            self.parentViewController.rootViewController.view.addGestureRecognizer(self.tapGesture)
        }
        
        // Build a list of currently active elements and calculate their containing frame
        self.activeElements = []
        for element in self.elements {
            var activeFrames: [(frame: CGRect, view: UIView)] = []
            if let views = element.views {
                for view in views {
                    var cell: UIView?
                    if let from = element.itemFrom, let to = element.itemTo {
                        for item in from...to {
                            let indexPath = IndexPath(item: item, section: element.section)
                            if let collectionView = view as? UICollectionView {
                                if item > collectionView.numberOfItems(inSection: indexPath.section) {
                                    break
                                }
                                if let item = collectionView.cellForItem(at: indexPath) {
                                    let flowLayout = collectionView.collectionViewLayout
                                    if let attributes = flowLayout.layoutAttributesForItem(at: indexPath) {
                                        let frame = attributes.frame
                                        if collectionView.bounds.intersects(frame) {
                                            if !item.isHidden {
                                                cell = item
                                            }
                                        }
                                    }
                                }
                            } else if let tableView = view as? UITableView {
                                if indexPath.row < 0 {
                                    let frame = tableView.rectForHeader(inSection: indexPath.section)
                                    if tableView.bounds.intersects(frame) {
                                        if let row = tableView.headerView(forSection: indexPath.section) {
                                            if !row.isHidden {
                                                cell = row
                                            }
                                        }
                                    }
                                } else {
                                    if item > tableView.numberOfRows(inSection: indexPath.section) {
                                        break
                                    }
                                    let frame = tableView.rectForRow(at: indexPath)
                                    if tableView.bounds.intersects(frame) {
                                        if let row = tableView.cellForRow(at: indexPath) {
                                            if !row.isHidden {
                                                cell = row
                                            }
                                        }
                                    }
                                }
                            }
                            if let cell = cell {
                                // Intersect the cell with the original collection / table to allow for partially hidden cells
                                let cellFrame = view.convert(cell.frame, to: view.superview!)
                                activeFrames.append((frame: cellFrame.intersection(view.frame), view: view))
                            }
                        }
                    } else {
                        if !view.isHidden {
                            activeFrames.append((frame: view.frame, view: view))
                        }
                    }
                }
                if !activeFrames.isEmpty {
                    let superFrame = self.superFrame(frames: activeFrames.map{$0.frame})
                    if superFrame.height >= 20 {
                        self.activeElements.append(HelpViewActiveElement(element: element, frame: superFrame, views: activeFrames.map{$0.view}))
                    }
                }
            } else {
                // Text is not related to a control - always include it
                self.activeElements.append(HelpViewActiveElement(element: element))
            }
        }
        
        if self.activeElements.isEmpty {
            self.finished(false)
        } else {
            self.currentElement = 0
            self.showElement()
        }
    }
    
    private func showElement() {
        let activeElement = self.activeElements[self.currentElement]
        let element = activeElement.element
        let frame = activeElement.frame
        let arrowHeight = (frame == nil ? 0 : self.arrowHeight)
        var direction = SpeechBubbleArrowDirection.up
        var point: CGPoint
        
        let requiredHeight = self.speechBubble.height(element.text(), arrowHeight: arrowHeight) + self.buttonHeight + self.buttonSpacing + self.border
        
        if let frame = frame, let superview = activeElement.views?.first?.superview {
            let frame = self.convert(frame.grownBy(dx: element.horizontalBorder, dy: element.verticalBorder), from: superview)
            self.focusGradient.set(around: frame)
                        
            direction = (requiredHeight + frame.maxY > ScorecardUI.screenHeight ? .down : .up)
            point = CGPoint(x: frame.midX, y: (direction == .up ? frame.maxY : frame.minY))
        } else {
            point = self.convert(CGPoint(x: self.parentView.frame.midX, y: (self.parentView.frame.height - requiredHeight) / 2), from: nil)
            self.focusGradient.set(around: CGRect(origin: point, size: CGSize()))
        }
        
        let extremity = (point.y + (requiredHeight * direction.rawValue))
        if extremity < 0 || extremity > self.parentView.frame.height {
            // Doesn't fit - skip it
            self.nextPressed(self.nextButton)
        } else {
            self.speechBubble.show(element.text(), point: point, direction: direction, arrowHeight: arrowHeight, arrowWidth: 0)
            
            let next = (self.alwaysNext || self.currentElement < self.activeElements.count - 1)
            
            let minY = (direction == .up ? self.speechBubble.frame.maxY + self.buttonSpacing: self.speechBubble.frame.minY - self.buttonSpacing - self.buttonHeight)
            
            let offset = (next ? self.buttonWidth + self.buttonSpacing : (self.buttonWidth / 2))
            self.finishButton.frame = CGRect(x: self.speechBubble.frame.midX - offset, y: minY, width: self.buttonWidth, height: self.buttonHeight)
            
            self.nextButton.isHidden = !next
            if next {
                self.nextButton.frame = CGRect(x: self.speechBubble.frame.midX + self.buttonSpacing, y: minY, width: self.buttonWidth, height: self.buttonHeight)
            }
        }
    }
    
    private func superFrame(frames: [CGRect]) -> CGRect {
        var result: CGRect!
        
        for frame in frames {
            if result == nil {
                result = frame
            } else {
                let minX = min(result.minX, frame.minX)
                let minY = min(result.minY, frame.minY)
                result = CGRect(x: minX,
                                y: minY,
                                width: max(result.maxX, frame.maxX) - minX,
                                height: max(result.maxY, frame.maxY) - minY)
            }
        }
        
        return result
    }
    
    private func addButton(title: String, target: Selector) -> ShadowButton {
        let button = ShadowButton(frame: CGRect(x: 0, y: 0, width: self.buttonWidth, height: self.buttonHeight))
        self.addSubview(button)
        button.setTitle(NSAttributedString(title, font: UIFont.systemFont(ofSize: 18, weight: .black)))
        button.setTitleColor(Palette.buttonFace.themeText, for: .normal)
        button.setBackgroundColor(Palette.buttonFace.background)
        button.toCircle()
        button.addTarget(self, action: target, for: .touchUpInside)
        
        return button
    }
    
    @objc private func nextPressed(_ sender: UIButton) {
        self.currentElement += 1
        if self.currentElement >= self.activeElements.count {
            self.finished(false)
        } else {
            self.showElement()
        }
    }
    
    @objc private func finishPressed(_ sender: UIButton) {
        self.finished(true)
    }
    
    public func finished(_ finishPressed: Bool = true) {
        if self.parentViewController.rootViewController.containers {
            self.parentViewController.rootViewController.view.removeGestureRecognizer(self.tapGesture)
        }
        self.isHidden = true
        self.completion?(finishPressed)
    }
    
      // MARK: - Gesture Recognizer Delegates ============================================================ -
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return gestureRecognizer == self.tapGesture
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
