//
//  HelpView.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 20/10/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class HelpViewElement {
    fileprivate let text: ()->NSAttributedString
    fileprivate let descriptor: NSAttributedString?
    fileprivate let views: [UIView]?
    fileprivate let callback: ((Int, UIView)->CGRect?)?
    fileprivate let condition: (()->Bool)?
    fileprivate let section: Int
    fileprivate let itemFrom: Int?
    fileprivate let itemTo: Int?
    fileprivate let bannerId: AnyHashable?
    fileprivate let horizontalBorder: CGFloat
    fileprivate let verticalBorder: CGFloat
    fileprivate let radius: CGFloat
    fileprivate let shrink: Bool
    fileprivate let direction: SpeechBubbleArrowDirection?
    
    init(text: (()->String)? = nil, attributedText: (()->NSAttributedString)? = nil, descriptor: NSAttributedString? = nil, views: [UIView?]? = nil, callback: ((Int, UIView)->CGRect?)? = nil, condition: (()->Bool)? = nil, section: Int = 0, item: Int? = nil, itemTo: Int? = nil, bannerId: AnyHashable? = nil, border: CGFloat = 0, horizontalBorder: CGFloat? = nil, verticalBorder: CGFloat? = nil, radius: CGFloat = 8.0, shrink: Bool = false, direction: SpeechBubbleArrowDirection? = nil) {
        
        if let attributedText = attributedText {
            self.text = attributedText
        } else if let text = text {
            self.text = { NSAttributedString(markdown: text()) }
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
        
        self.callback = callback
        self.descriptor = descriptor
        self.condition = condition
        self.section = section
        self.itemFrom = item
        self.itemTo = itemTo ?? item
        self.bannerId = bannerId
        self.horizontalBorder = horizontalBorder ?? border
        self.verticalBorder = verticalBorder ?? border
        self.radius = radius
        self.shrink = shrink
        self.direction = direction
        
        assert(self.views?.count ?? 0 == 1 || itemFrom == nil, "items are only relevant for a single view")
    }
}

fileprivate enum HelpViewSource {
    case message
    case view
    case menu
    case banner
    
    var sort: Int {
        switch self {
        case .message:
            return 0
        case .menu:
            return 1
        case .banner:
            return 2
        case .view:
            return 3
        }
    }
}

fileprivate struct HelpViewActiveElement: Comparable {
    
    let element: HelpViewElement
    let frame: CGRect?
    let views: [UIView]?
    let source: HelpViewSource
    let descriptor: NSAttributedString?
    let sequence: Int
    let radius: CGFloat
    let positionSort: CGFloat
    
    static var nextSequence = 0
    
    init(element: HelpViewElement, frame: CGRect? = nil, views: [UIView]? = nil, source: HelpViewSource = .view, descriptor: NSAttributedString? = nil, radius: CGFloat? = nil, positionSort: CGFloat = 0) {
        self.element = element
        self.frame = frame
        self.views = views
        self.source = source
        self.descriptor = descriptor
        self.radius = radius ?? (source == .view ? element.radius : (source == .message ? 0 : 8))
        self.positionSort = positionSort
        self.sequence = HelpViewActiveElement.nextSequence
        HelpViewActiveElement.nextSequence += 1
    }
    
    static func < (lhs: HelpViewActiveElement, rhs: HelpViewActiveElement) -> Bool {
        return (lhs.source.sort, lhs.positionSort, lhs.sequence) < (rhs.source.sort, rhs.positionSort, rhs.sequence)
    }
        
    static func == (lhs: HelpViewActiveElement, rhs: HelpViewActiveElement) -> Bool {
        return (lhs.source.sort, lhs.positionSort, lhs.sequence) == (rhs.source.sort, rhs.positionSort, rhs.sequence)
    }
}

class HelpView : UIView, UIGestureRecognizerDelegate {
    
    private var speechBubble: SpeechBubbleView!
    private var focus: FocusView!
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
    private let minVisibleHeight: CGFloat = 20
    
    private static var _helpContext: String?
    public static var helpContext: String? { _helpContext }
    
    public var isEmpty: Bool { return self.elements.isEmpty }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        fatalError("Not implemented")
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    convenience init(in parentViewController: ScorecardViewController) {
        self.init(frame: parentViewController.view.convert(parentViewController.screenBounds, from: nil))
        self.parentViewController = parentViewController
        self.speechBubble = SpeechBubbleView(from: parentViewController, in: self)
        self.focus = FocusView(from: parentViewController, in: self)
        self.nextButton = self.addButton(title: "Next", target: #selector(HelpView.nextPressed))
        self.finishButton = self.addButton(title: "Exit", target: #selector(HelpView.self.finishPressed))
        self.accessibilityIdentifier = "helpView"
        self.isHidden = true
        self.elements = []
        self.parentView = parentViewController.view
        self.tapGesture = UITapGestureRecognizer(target: self, action: #selector(HelpView.wasTapped))
        self.tapGesture.delegate = self
        parentView.addSubview(self)
        parentViewController.rootViewController?.view.bringSubviewToFront(self)
    }
    
    internal override func layoutSubviews() {
        super.layoutSubviews()
        
        if self.parentViewController.container == .none {
            self.frame = self.parentView.bounds
        } else {
            self.frame = self.parentView.convert(self.parentViewController.screenBounds, from: nil)
        }
        self.parentView.bringSubviewToFront(self)
    }
    
    public func reset() {
        self.elements = []
    }
    
    public func add(_ text: @escaping @autoclosure ()->String, descriptor: String? = nil, views: [UIView?]? = nil, callback: ((Int, UIView)->CGRect?)? = nil, condition: (()->Bool)? = nil, section: Int = 0, item: Int? = nil, itemTo: Int? = nil, bannerId: AnyHashable? = nil, border: CGFloat = 0, horizontalBorder: CGFloat? = nil, verticalBorder: CGFloat? = nil, radius: CGFloat = 8.0, shrink: Bool = false, direction: SpeechBubbleArrowDirection? = nil) {
        
        self.add(HelpViewElement(text: text, descriptor: (descriptor != nil ? NSAttributedString(markdown: descriptor!) : nil), views: views, callback: callback, condition: condition, section: section, item: item, itemTo: itemTo, bannerId: bannerId, border: border, horizontalBorder: horizontalBorder, verticalBorder: verticalBorder, radius: radius, shrink: shrink, direction: direction))
    }
    
    public func add(_ attributedText: @escaping @autoclosure ()->NSAttributedString, descriptor: NSAttributedString? = nil, views: [UIView?]? = nil, callback: ((Int, UIView)->CGRect?)? = nil, condition: (()->Bool)? = nil, section: Int = 0, item: Int? = nil, itemTo: Int? = nil, bannerId: AnyHashable? = nil, border: CGFloat = 0, horizontalBorder: CGFloat? = nil, verticalBorder: CGFloat? = nil, radius: CGFloat = 8, shrink: Bool = false, direction: SpeechBubbleArrowDirection? = nil) {
        
        self.add(HelpViewElement(attributedText: attributedText, descriptor: descriptor, views: views, callback: callback, condition: condition, section: section, item: item, itemTo: itemTo, bannerId: bannerId, border: border, horizontalBorder: horizontalBorder, verticalBorder: verticalBorder, radius: radius, shrink: shrink, direction: direction))
    }
    
    private func add(_ element: HelpViewElement) {
        if !(element.views?.isEmpty ?? false) || element.bannerId != nil {
            self.elements.append(element)
        }
    }
    
    public func show(alwaysNext: Bool = false, completion: ((Bool)->())? = nil) {
        self.alwaysNext = alwaysNext
        self.completion = completion
        
        HelpView._helpContext = UUID().uuidString
        self.layoutSubviews()
        
        self.isHidden = false
        self.isHidden(false)
        self.addTapGesture()
        
        // Build a list of currently active elements and calculate their containing frame
        self.activeElements = []
        for element in self.elements {
            var activeFrames: [(frame: CGRect, view: UIView)] = []
            
            // Check condition
            if element.condition?() ?? true {
                
                // Check views
                if let views = element.views {
                    for view in views {
                        var cell: UIView?
                        var frame: CGRect?
                        if let from = element.itemFrom, let to = element.itemTo {
                            for item in from...to {
                                let indexPath = IndexPath(item: item, section: element.section)
                                if let collectionView = view as? UICollectionView {
                                    if indexPath.section < 0 || item > collectionView.numberOfItems(inSection: indexPath.section) {
                                        break
                                    }
                                    let flowLayout = collectionView.collectionViewLayout
                                    if indexPath.item < 0 {
                                        let kind = UICollectionView.elementKindSectionHeader
                                        let indexPath = IndexPath(item: 0, section: indexPath.section)
                                        if let item = collectionView.supplementaryView(forElementKind: kind, at: indexPath) {
                                            if let attributes = flowLayout.layoutAttributesForSupplementaryView(ofKind: kind, at: indexPath) {
                                                frame = attributes.frame
                                                if collectionView.bounds.intersects(frame!) {
                                                    if !item.isHidden {
                                                        cell = item
                                                    }
                                                }
                                            }
                                        }
                                    } else {
                                        if let item = collectionView.cellForItem(at: indexPath) {
                                            if let attributes = flowLayout.layoutAttributesForItem(at: indexPath) {
                                                frame = attributes.frame
                                                if collectionView.bounds.intersects(frame!) {
                                                    if !item.isHidden {
                                                        cell = item
                                                    }
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
                                        if indexPath.section < 0 || item > tableView.numberOfRows(inSection: indexPath.section) {
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
                                    frame = cell?.frame
                                }
                                if let cell = cell {
                                    // Intersect the cell with the original collection / table to allow for partially hidden cells
                                    if let callback = element.callback {
                                        if let callbackFrame = callback(item, cell) {
                                            frame = cell.superview!.convert(callbackFrame, from: cell)
                                        } else {
                                            frame = nil
                                        }
                                    }
                                    if let frame = frame {
                                        let cellFrame = view.convert(frame, to: view.superview!)
                                        activeFrames.append((frame: cellFrame.intersection(view.frame), view: view))
                                    }
                                }
                            }
                        } else {
                            if !view.isHidden {
                                var frame: CGRect? = view.frame
                                if let callback = element.callback {
                                    if let callbackFrame = callback(0, view) {
                                        frame = view.superview!.convert(callbackFrame, from: view)
                                    } else {
                                        frame = nil
                                    }
                                }
                                if let frame = frame {
                                    activeFrames.append((frame: frame, view: view))
                                }
                            }
                        }
                    }
                    if !activeFrames.isEmpty {
                        let superFrame = self.superFrame(frames: activeFrames.map{$0.frame})
                        if superFrame.height >= self.minVisibleHeight {
                            self.activeElements.append(HelpViewActiveElement(element: element, frame: superFrame, views: activeFrames.map{$0.view}))
                        }
                    }
                }
                
                // Check banner ID
                if let id = element.bannerId {
                    
                    if let banner = self.parentViewController.bannerClass {
                        if (id as? String) == Banner.titleControl {
                            // Get title
                            let bannerTitle = banner.getTitle()
                            let control = bannerTitle.control
                            if !control.isHidden {
                                self.activeElements.append(HelpViewActiveElement(element: element, frame: control.frame, views: [control], source: .banner, descriptor: NSAttributedString(markdown: bannerTitle.title ?? "@*/Title@*/"), positionSort: bannerTitle.positionSort))
                            }
                        } else {
                            // Get banner button
                            if let bannerButton = banner.getButton(id: id) {
                                let control = bannerButton.control
                                if !control.isHidden {
                                    let rounded = (bannerButton.type == .rounded || bannerButton.type == .help)
                                    self.activeElements.append(HelpViewActiveElement(element: element, frame: control.frame, views: [control], source: .banner, descriptor: bannerButton.title, radius: (rounded ? control.frame.height / 2 : nil), positionSort: bannerButton.positionSort))
                                }
                            }
                        }
                    }
                    
                    if let menuController = self.parentViewController.menuController {
                        // And get menu sub-option in container mode
                        if menuController.isVisible {
                            if let menuOption = menuController.getSuboptionView(id: id) {
                                if let cell = menuOption.view.cellForRow(at: IndexPath(row: menuOption.item, section: 0)) {
                                    self.activeElements.append(HelpViewActiveElement(element: element, frame: cell.frame, views: [cell], source: .menu, descriptor: menuOption.title, positionSort: menuOption.positionSort))
                                }
                            }
                        }
                    }
                }
                
                if (element.views?.count ?? 0) == 0 && element.bannerId == nil {
                    // Text is not related to a control - always include it
                    self.activeElements.append(HelpViewActiveElement(element: element, source: .message))
                }
            }
        }
        
        if self.activeElements.isEmpty {
            self.finished(false)
        } else {
            self.activeElements.sort(by: { $0 < $1 })
            self.currentElement = 0
            self.showElement()
        }
    }
    
    private func showElement() {
        let showNext = (self.alwaysNext || self.currentElement < self.activeElements.count - 1)
        let activeElement = self.activeElements[self.currentElement]
        
        if activeElement.source == .menu && self.parentViewController.menuController?.isVisible ?? false {
            // Need to execute remotely in the menu controller
            if self.parentViewController.container != .none && self.parentViewController.menuController?.isVisible ?? false {
                let sourceElement = activeElement.element
                let menuElement = HelpViewElement(attributedText: sourceElement.text, descriptor: activeElement.descriptor, views: activeElement.views, horizontalBorder: sourceElement.horizontalBorder, verticalBorder: sourceElement.verticalBorder)
                
                self.removeTapGesture()
                self.isHidden(true)
                self.parentViewController.menuController?.showHelp(helpElement: menuElement, showNext: showNext, completion: self.menuCompletion)
            } else {
                self.next()
            }
        } else {
            // Show ordinary subview of current view
            self.showActiveElement(activeElement: activeElement, showNext: showNext)
        }
    }
    
    public func showMenuElement(element: HelpViewElement, showNext: Bool, completion: @escaping (Bool)->()) {
        // Used to execute a specific element remotely (in a menu controller)
        self.completion = { (finishPressed) in
            self.removeTapGesture()
            self.isHidden = true
            self.isHidden(true)
            completion(finishPressed)
        }
        self.addTapGesture()
        self.isHidden = false
        self.isHidden(false)
        if let view = element.views?.first {
            self.activeElements = [HelpViewActiveElement(element: element, frame: view.frame, views: [view], source: .menu)]
            self.currentElement = 0
            self.showActiveElement(activeElement: self.activeElements.first!, showNext: showNext)
        }
    }
    
    private func showActiveElement(activeElement: HelpViewActiveElement, showNext: Bool) {
        let element = activeElement.element
        var frame = activeElement.frame
        let arrowHeight = (frame == nil ? 0 : self.arrowHeight)
        var direction = SpeechBubbleArrowDirection.up
        var point: CGPoint
        var focusFrame: CGRect
        
        // Instantiate text and substitute for {} with descriptor
        
        let text = element.text().mutableCopy() as! NSMutableAttributedString
        if let descriptor = activeElement.descriptor ?? element.descriptor {
            while true {
                if let range = text.string.range(of: "{}") {
                    let nsRange = NSRange(range, in: text.string)
                    text.replaceCharacters(in: nsRange, with: descriptor)
                } else {
                    break
                }
            }
        }
        
        // Reposition frame
        let superview = activeElement.views?.first?.superview
        if frame != nil && superview != nil {
            frame = self.convert(frame!.grownBy(dx: element.horizontalBorder, dy: element.verticalBorder), from: superview!)
        }

        // Check if positioning bubble left/right or above/below
        var aboveBelow: Bool
        if let direction = element.direction?.rotated {
            aboveBelow = (direction == .up || direction == .down)
        } else if frame?.width ?? 0 > self.frame.width * 0.7 && !element.shrink {
            aboveBelow = true
        } else {
            aboveBelow = (ScorecardUI.portraitPhone() || (!ScorecardUI.phoneSize() && !(self.parentViewController.menuController?.isVisible ?? false)))
        }
        
        // Get required width of bubble
        let requiredWidth = SpeechBubbleView.width(availableWidth: (frame == nil || aboveBelow ? nil : (max(frame!.minX, self.parentViewController.screenWidth - frame!.maxX))), minWidth: (element.shrink ? 290 : 190))
        
        // Get required height of bubble
        let requiredHeight = self.speechBubble.height(text, arrowHeight: arrowHeight, width: requiredWidth) + self.buttonHeight + self.buttonSpacing + self.border
        
       if activeElement.source != .message {
            // Bubble mode - Work out connection point on frame for arrow
            if aboveBelow {
                direction = element.direction?.rotated ?? (requiredHeight + frame!.maxY > self.frame.height - self.parentView.safeAreaInsets.bottom ? .down : .up)
                point = CGPoint(x: frame!.midX, y: (direction == .up ? frame!.maxY : frame!.minY))
            } else {
                direction = element.direction?.rotated ?? (requiredWidth + frame!.maxX > self.frame.width - self.parentView.safeAreaInsets.right ? .right : .left)
                point = CGPoint(x: (direction == .left ? frame!.maxX : frame!.minX), y: frame!.midY)
                
            }
            focusFrame = frame!
        } else {
            // Just a message (no control) - draw focus shape covering entire screen
            point = self.convert(CGPoint(x: self.parentView.frame.midX, y: (self.parentView.frame.height - requiredHeight) / 2), from: nil)
            focusFrame = CGRect(origin: point, size: CGSize())
        }
        
        // Check if fits (and adjust if shrinking allowed)
        let doesntFit = self.shrinkToFit(activeElement: activeElement, direction: direction, focusFrame: &focusFrame, point: &point, requiredHeight: requiredHeight, requiredWidth: requiredWidth)
            
        if doesntFit {
            // Doesn't fit - skip it
            self.nextPressed(self.nextButton)
        } else {
            // Draw focus frame
            self.focus.set(around: focusFrame, radius: activeElement.radius)
            
            // Show bubble
            self.speechBubble.show(text, point: point, direction: direction, width: requiredWidth, color: Palette.helpBubble, arrowHeight: (activeElement.source == .message ? 0 : arrowHeight), arrowWidth: 0)
            
            // Show Next / Finish buttons
            var buttonsBelow: Bool
            switch direction {
            case .up:
                buttonsBelow = true
            case .down:
                buttonsBelow = false
            default:
                buttonsBelow = (self.speechBubble.frame.maxY + self.buttonHeight + (self.buttonSpacing * 2) < self.frame.height)
            }
            let minY = (buttonsBelow ? self.speechBubble.frame.maxY + self.buttonSpacing : self.speechBubble.frame.minY - self.buttonSpacing - self.buttonHeight)
                
            let offset = (showNext ? self.buttonWidth + self.buttonSpacing : (self.buttonWidth / 2))
            self.finishButton.frame = CGRect(x: self.speechBubble.labelFrame.midX - offset, y: minY, width: self.buttonWidth, height: self.buttonHeight)
            
            self.nextButton.isHidden = !showNext
            if showNext {
                self.nextButton.frame = CGRect(x: self.speechBubble.labelFrame.midX + self.buttonSpacing, y: minY, width: self.buttonWidth, height: self.buttonHeight)
            }
        }
    }

    private func shrinkToFit(activeElement: HelpViewActiveElement, direction: SpeechBubbleArrowDirection, focusFrame: inout CGRect, point: inout CGPoint, requiredHeight: CGFloat, requiredWidth: CGFloat) -> Bool {
        
        var doesntFit = false
        let shrink = activeElement.element.shrink
        
        switch direction {
        case .down:
            let deficit = self.parentView.safeAreaInsets.top + requiredHeight - point.y
            if deficit > 0 {
                if shrink && focusFrame.height - deficit > self.minVisibleHeight {
                    focusFrame = CGRect(x: focusFrame.minX, y: focusFrame.minY + deficit, width: focusFrame.width, height: focusFrame.height - deficit)
                    point = CGPoint(x: focusFrame.midX, y: focusFrame.minY)
                } else {
                    doesntFit = true
                }
            }
            
        case .up:
            let deficit = point.y - (self.frame.height - self.parentView.safeAreaInsets.bottom - requiredHeight)
            if deficit > 0 {
                if shrink && focusFrame.height - deficit > self.minVisibleHeight {
                    focusFrame = CGRect(x: focusFrame.minX, y: focusFrame.minY, width: focusFrame.width, height: focusFrame.height - deficit)
                    point = CGPoint(x: focusFrame.midX, y: focusFrame.maxY)
                } else {
                    doesntFit = true
                }
            }
            
        case .right:
            let deficit = self.parentView.safeAreaInsets.left + requiredWidth - point.x
            if deficit > 0 {
                if shrink && focusFrame.width - deficit > self.minVisibleHeight {
                    focusFrame = CGRect(x: focusFrame.minX + deficit, y: focusFrame.minY, width: focusFrame.width - deficit, height: focusFrame.height)
                    point = CGPoint(x: focusFrame.minX, y: focusFrame.midY)
                } else {
                    doesntFit = true
                }
            }
            
        case .left:
            let deficit = point.x - (self.frame.width - self.parentView.safeAreaInsets.right - requiredWidth)
            if deficit > 0 {
                if shrink && focusFrame.width - deficit > self.minVisibleHeight {
                    focusFrame = CGRect(x: focusFrame.minX, y: focusFrame.minY, width: focusFrame.width - deficit, height: focusFrame.height)
                    point = CGPoint(x: focusFrame.maxX, y: focusFrame.midY)
                } else {
                    doesntFit = true
                }
            }
        }
        
        return doesntFit
    }
    
    private func menuCompletion(finishPressed: Bool) {
        if finishPressed {
            self.finished()
        } else {
            self.addTapGesture()
            self.isHidden(false)

            self.next()
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
        button.setTitleColor(Palette.helpBubble.themeText, for: .normal)
        button.setBackgroundColor(Palette.helpBubble.background)
        button.toCircle()
        button.addTarget(self, action: target, for: .touchUpInside)
        
        return button
    }
    
    private func addTapGesture() {
        if (self.parentViewController.rootViewController?.containers ?? false) && self.parentViewController.container != nil {
            self.parentViewController.rootViewController.view.addGestureRecognizer(self.tapGesture)
        } else {
            self.addGestureRecognizer(self.tapGesture)
        }
    }
    
    private func removeTapGesture() {
        if (self.parentViewController.rootViewController?.containers ?? false) && self.parentViewController.container != nil {
            self.parentViewController.rootViewController.view.removeGestureRecognizer(self.tapGesture)
        } else {
            self.removeGestureRecognizer(self.tapGesture)
        }
    }
    
    @objc private func wasTapped(_ gesture: UIGestureRecognizer) {
        if self.finishButton.frame.contains(gesture.location(in: self)) {
            self.finished()
        } else {
            self.next()
        }
    }
    
    private func next() {
        self.currentElement += 1
        if self.currentElement >= self.activeElements.count {
            self.finished(false)
        } else {
            self.showElement()
        }
    }
    
    @objc private func nextPressed(_ sender: UIButton) {
        self.next()
    }
    
    public func finished(_ finishPressed: Bool = true) {
        self.removeTapGesture()
        self.isHidden = true
        self.isHidden(true)
        self.completion?(finishPressed)
    }
    
    @objc private func finishPressed(_ sender: UIButton) {
        self.finished(true)
    }
    
    private func isHidden(_ isHidden: Bool) {
        self.speechBubble.isHidden = isHidden
        self.focus.isHidden = isHidden
        self.nextButton.isHidden = isHidden
        self.finishButton.isHidden = isHidden
    }
    
    // MARK: - Dashboard Help ===================================================== -
    
    public func add(dashboardView: DashboardView) {
        self.addHelpView(view: dashboardView)
    }
    
    private func addHelpView(view: UIView) {
        if let view = view as? DashboardTileDelegate {
            view.addHelp?(to: self)
        } else {
            for view in view.subviews {
                self.addHelpView(view: view)
            }
        }
    }
    
    // MARK: - Gesture Recognizer Delegates ============================================================ -
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
