//
//  DashboardViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 21/06/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

@objc public enum DashboardDetailType: Int {
    case history = 1
    case statistics = 2
    case highScores = 3
}

public enum Orientation: String, CaseIterable {
    case portrait = "Portrait"
    case landscape = "Landscape"
}

@objc protocol DashboardActionDelegate : class {
    
    func action(view: DashboardDetailType)

}

@objc protocol DashboardTileDelegate : class {
    
    @objc optional func reloadData()
}

class DashboardViewController: ScorecardViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, CustomCollectionViewLayoutDelegate, DashboardActionDelegate {
    
    private enum DashboardCollectionViews: Int {
        case carousel = 1
        case scroll = 2
    }
    
    private let pages = 3
    private let shieldsPage = 0
    private let personalPage = 1
    private let everyonePage = 2
    private var currentPage = -1
    
    private var dashboardViews: [Int:[Orientation:(name: String, view: DashboardView?)]] = [:]
    private var currentOrientation: Orientation!
    
    private var historyViewer: HistoryViewer!
    private var statisticsViewer: StatisticsViewer!
    
    private var firstTime = true
    private var rotated = false
    
    @IBOutlet private weak var bannerPaddingView: InsetPaddingView!
    @IBOutlet private weak var bannerView: UIView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var carouselCollectionView: UICollectionView!
    @IBOutlet private weak var carouselCollectionViewFlowLayout: CustomCollectionViewLayout!
    @IBOutlet private weak var scrollCollectionView: UICollectionView!
    @IBOutlet private weak var finishButton: ClearButton!
    @IBOutlet private weak var dashboardContainerView: UIView!
    @IBOutlet private weak var syncButton: ShadowButton!
    @IBOutlet private weak var smallSyncButton: ClearButton!
    
    @IBAction func finishButtonPressed(_ sender: UIButton) {
        self.dismiss()
    }
    
    @IBAction func syncButtonPressed(_ sender: UIButton) {
        self.showSync()
    }
    
    @IBAction func swipeGestureRecognizer(_ recognizer: UISwipeGestureRecognizer) {
        if recognizer.state == .ended {
            switch recognizer.direction {
            case .left:
                if self.currentPage < pages - 1 {
                    self.changed(self.carouselCollectionView, itemAtCenter: self.currentPage + 1, forceScroll: true)
                }
            case .right:
                if self.currentPage > 0 {
                    self.changed(self.carouselCollectionView, itemAtCenter: self.currentPage - 1, forceScroll: true)
                }
            default:
                self.finishButtonPressed(self.finishButton)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.defaultViewColors()

        // Configure flow and set initial value
        self.carouselCollectionViewFlowLayout.delegate = self
        
        self.carouselCollectionView.decelerationRate = UIScrollView.DecelerationRate.fast
        
        self.currentPage = self.personalPage
        self.addDashboardViews()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.rotated = true
        self.view.setNeedsLayout()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.currentOrientation = ScorecardUI.landscapePhone() ? .landscape : .portrait
        self.carouselCollectionView.layoutIfNeeded()
        let width: CGFloat = self.carouselCollectionView.frame.width / 4
        self.carouselCollectionView.contentInset = UIEdgeInsets(top: 0.0, left: width, bottom: 0.0, right: width)
        self.carouselCollectionView.reloadData()
        self.carouselCollectionView.layoutIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if self.firstTime || self.rotated {
            self.carouselCollectionView.layoutIfNeeded()
            self.carouselCollectionView.contentOffset = CGPoint(x: self.carouselCollectionView.bounds.width / 4.0, y: 0.0)
            let selectedPage = (firstTime ? self.personalPage : self.currentPage)
            self.changed(carouselCollectionView, itemAtCenter: selectedPage, forceScroll: true)
            self.carouselCollectionView.reloadData()
            if self.rotated {
                self.hideOrientationViews(not: self.currentOrientation)
                self.reloadData()
            }
            self.firstTime = false
            self.rotated = false
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.carouselCollectionView.reloadData()
    }
    
    private func reloadData() {
        Utility.mainThread {
            for (_, orientationViews) in self.dashboardViews {
                for (orientation, dashboardView) in orientationViews {
                    if orientation == self.currentOrientation {
                        if let view = dashboardView.view {
                            self.reloadData(for: view)
                        }
                    }
                }
            }
        }
    }
    
    private func reloadData(for view: UIView) {
        if let view = view as? DashboardTileDelegate {
            view.reloadData?()
        } else {
            for view in view.subviews {
                self.reloadData(for: view)
            }
        }
    }

    // MARK: - Dashboard Action Delegate =============================================================== -
    
    func action(view: DashboardDetailType) {
        switch view {
        case .history:
            self.historyViewer = HistoryViewer(from: self) {
                self.historyViewer = nil
                self.reloadData()
            }
        case .statistics:
            self.statisticsViewer = StatisticsViewer(from: self) {
                self.statisticsViewer = nil
                self.reloadData()
            }
        case .highScores:
            self.showHighScores()
        }
        
    }
    
    // MARK: - CollectionView Overrides ================================================================ -
    
    internal func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        switch DashboardCollectionViews(rawValue: collectionView.tag) {
        case .carousel:
            return self.pages
        case .scroll:
            return self.pages
        default:
            return 0
        }
    }
    
    internal func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        switch DashboardCollectionViews(rawValue: collectionView.tag) {
        case .carousel:
            let height: CGFloat = collectionView.bounds.size.height
            let width: CGFloat = collectionView.bounds.size.width / 2.0
            return CGSize(width: width, height: height)
            
        case .scroll:
            return CGSize(width: 10.0, height: 10.0)
            
        default:
            return CGSize()
        }
        
    }
    
    internal func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        switch DashboardCollectionViews(rawValue: collectionView.tag) {
        case .carousel:
            let carouselCell = collectionView.dequeueReusableCell(withReuseIdentifier: "Carousel Cell", for: indexPath) as! DashboardCarouselCell
            self.defaultCellColors(carouselCell)
            carouselCell.containerView.roundCorners(cornerRadius: 8.0)
            carouselCell.addShadow(shadowSize: CGSize(width: 4.0, height: 4.0))
            carouselCell.titleLabel.alpha = (indexPath.row != self.currentPage ? 0.0 : 1.0)
            carouselCell.containerView.backgroundColor = (indexPath.row == self.currentPage ? Palette.bannerShadow : Palette.background)
            carouselCell.backgroundImageView.tintColor = (indexPath.row == self.currentPage ? Palette.textTitle : Palette.disabledText)
            
            switch indexPath.row {
            case shieldsPage:
                carouselCell.titleLabel.text = "Shields"
                carouselCell.backgroundImageView.image = UIImage(systemName: "shield.fill")
            case personalPage:
                carouselCell.titleLabel.text = "Personal"
                carouselCell.backgroundImageView.image = UIImage(systemName: "person.fill")
            case everyonePage:
                carouselCell.titleLabel.text = "Everyone"
                carouselCell.backgroundImageView.image = UIImage(systemName: "person.3.fill")
            default:
                break
            }
            return carouselCell
            
        case .scroll:
            let scrollCell = collectionView.dequeueReusableCell(withReuseIdentifier: "Scroll Cell", for: indexPath) as! DashboardScrollCell
                self.defaultCellColors(scrollCell)
            
            scrollCell.indicator.image = UIImage(systemName: (indexPath.row == self.currentPage ? "circle.fill" : "circle"))
            scrollCell.indicator.tintColor = Palette.banner

            return scrollCell
            
        default:
            return UICollectionViewCell()
        }
    }
        
    internal func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch DashboardCollectionViews(rawValue: collectionView.tag) {
        case .carousel:
            self.changed(collectionView, itemAtCenter: indexPath.item, forceScroll: true)
        default:
            break
        }
    }
        
    internal func changed(_ collectionView: UICollectionView, itemAtCenter: Int, forceScroll: Bool) {
        Utility.mainThread {
            let changed = self.currentPage != itemAtCenter
            if changed || forceScroll == true {
                let oldView = self.getView(page: self.currentPage)
                let newView = self.getView(page: itemAtCenter)
                newView.isHidden = false
                Utility.animate(duration: self.firstTime ? 0.0 : 0.5,
                    completion: {
                        if changed {
                            oldView.isHidden = true
                        }
                    },
                    animations: {
                        // Unhighlight the cell leaving the center
                        if let cell = self.carouselCollectionView.cellForItem(at: IndexPath(item: self.currentPage, section: 0)) as? DashboardCarouselCell {
                            if self.currentPage != itemAtCenter {
                                cell.containerView.backgroundColor = Palette.background
                                cell.backgroundImageView.tintColor = Palette.disabledText
                                cell.titleLabel.alpha = 0.0
                            }
                        }
                        
                        // Select cell
                        self.currentPage = itemAtCenter
                     
                        if forceScroll {
                            collectionView.scrollToItem(at: IndexPath(item: itemAtCenter, section: 0), at: .centeredHorizontally, animated: !self.firstTime)
                        }
                        
                        // Highlight new cell at center
                        if let cell = self.carouselCollectionView.cellForItem(at: IndexPath(item: self.currentPage, section: 0)) as? DashboardCarouselCell {
                            cell.containerView.backgroundColor = Palette.bannerShadow
                            cell.backgroundImageView.tintColor = Palette.textTitle
                            cell.titleLabel.alpha = 1.0
                        }
                        self.scrollCollectionView.reloadData()
                        if changed {
                            oldView.alpha = 0.0
                        }
                        newView.alpha = 1.0
                    })
                        
            }
        }
    }

    // MARK: - Add dashboard views ================================================================== -
    
    private func addDashboardViews() {
        
        for page in 0..<pages {
            self.dashboardViews[page] = [:]
            for orientation in Orientation.allCases {
                var nibName = ""
                switch page {
                case shieldsPage:
                    nibName = "ShieldsDashboard\(orientation.rawValue)View"
                case personalPage:
                    nibName = "PersonalDashboard\(orientation.rawValue)View"
                case everyonePage:
                    nibName = "EveryoneDashboard\(orientation.rawValue)View"
                default:
                    break
                }
                self.dashboardViews[page]![orientation] = (nibName, nil)
            }
        }
    }
    
    private func hideOrientationViews(not notOrientation: Orientation) {
        for (_, orientationViews) in self.dashboardViews {
            for (orientation, viewInfo) in orientationViews {
                if orientation != notOrientation {
                    if let view = viewInfo.view {
                        view.alpha = 0.0
                        view.isHidden = true
                    }
                }
            }
        }
    }
    
    private func getView(page: Int) -> DashboardView {
        var view: DashboardView
        let viewInfo = self.dashboardViews[page]![self.currentOrientation]!
        if viewInfo.view == nil {
            view = DashboardView(withNibName: viewInfo.name, frame: self.dashboardContainerView.frame)
            view.alpha = 0.0
            view.delegate = self
            self.dashboardViews[page]![self.currentOrientation]!.view = view
            self.dashboardContainerView.addSubview(view)
            Constraint.anchor(view: self.dashboardContainerView, control: view, attributes: .leading, .trailing, .top, .bottom)
        } else {
            view = viewInfo.view!
        }
        return view
    }
    
    // MARK: - Functions to present other views ========================================================== -
    
    private func showHighScores() {
        _ = HighScoresViewController.show(from: self, backText: "", backImage: "back")
    }
    
    private func showSync() {
        SyncViewController.show(from: self, completion: {
            // Refresh screen
            self.reloadData()
        })
    }
    
    // MARK: - Function to present and dismiss this view ================================================= -
    
    class public func show(from viewController: ScorecardViewController) {
        
        let storyboard = UIStoryboard(name: "DashboardViewController", bundle: nil)
        let dashboardViewController: DashboardViewController = storyboard.instantiateViewController(withIdentifier: "DashboardViewController") as! DashboardViewController
        
        dashboardViewController.preferredContentSize = CGSize(width: 400, height: 700)
        dashboardViewController.modalPresentationStyle = (ScorecardUI.phoneSize() ? .fullScreen : .automatic)
        
        viewController.present(dashboardViewController, sourceView: viewController.popoverPresentationController?.sourceView ?? viewController.view, animated: true, completion: nil)
    }
    
    private func dismiss() {
        self.dismiss(animated: true, completion: {
            self.didDismiss()
        })
    }
    
    override internal func didDismiss() {
        
    }
}

extension DashboardViewController {
    
    private func defaultViewColors() {
        self.view.backgroundColor = Palette.background
        self.bannerPaddingView.backgroundColor = Palette.banner
        self.bannerView.backgroundColor = Palette.banner
        self.titleLabel.textColor = Palette.bannerText
        if ScorecardUI.smallPhoneSize() {
            // Switch to cloud image rather than Sync text on shadowed button
            self.smallSyncButton.tintColor = Palette.bannerText
            self.smallSyncButton.isHidden = false
            self.syncButton.isHidden = true
        } else {
            self.syncButton.setTitleColor(Palette.bannerText, for: .normal)
            self.syncButton.setBackgroundColor(Palette.bannerShadow)
            self.smallSyncButton.isHidden = true
            self.syncButton.isHidden = false
        }
    }

    private func defaultCellColors(_ cell: DashboardCarouselCell) {
        cell.titleLabel.textColor = Palette.bannerText
        cell.backgroundImageView.tintColor = Palette.textTitle
    }
    
    private func defaultCellColors(_ cell: DashboardScrollCell) {
        cell.indicator.tintColor = Palette.banner
    }

}

class DashboardCarouselCell: UICollectionViewCell {
    @IBOutlet fileprivate weak var containerView: UIView!
    @IBOutlet fileprivate weak var backgroundImageView: UIImageView!
    @IBOutlet fileprivate weak var titleLabel: UILabel!
}

class DashboardScrollCell: UICollectionViewCell {
   @IBOutlet fileprivate weak var indicator: UIImageView!
}

class Dashboard {
    
    public class func color(detailView: DashboardDetailType) -> UIColor {
        switch detailView {
        case .history:
            return Palette.history
        case .statistics:
            return Palette.stats
        case .highScores:
            return Palette.highScores
        }
    }
    
    public class func image(detailView: DashboardDetailType) -> UIImage {
        switch detailView {
        case .history:
            return UIImage(systemName: "calendar.circle.fill")!
        case .statistics:
            return UIImage(systemName: "waveform.circle.fill")!
        case .highScores:
            return UIImage(systemName: "star.circle.fill")!
        }
    }
}
