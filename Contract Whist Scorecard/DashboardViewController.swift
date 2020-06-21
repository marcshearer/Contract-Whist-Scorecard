//
//  DashboardViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 21/06/2020.
//  Copyright © 2020 Marc Shearer. All rights reserved.
//

import UIKit

class DashboardViewController: ScorecardViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, CustomCollectionViewLayoutDelegate {

    private enum DashboardCollectionViews: Int {
        case carousel = 1
        case scroll = 2
    }
    
    private let pages = 3
    private let shieldsPage = 0
    private let personalPage = 1
    private let everyonePage = 2
    private var currentPage = -1
    
    private var firstTime = true
    
    @IBOutlet private weak var bannerPaddingView: InsetPaddingView!
    @IBOutlet private weak var bannerView: UIView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var carouselCollectionView: UICollectionView!
    @IBOutlet private weak var carouselCollectionViewFlowLayout: CustomCollectionViewLayout!
    @IBOutlet private weak var scrollCollectionView: UICollectionView!
    @IBOutlet private weak var finishButton: ClearButton!
    
    @IBAction func finishButtonPressed(_ sender: UIButton) {
        self.dismiss()
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()
        self.defaultViewColors()

        // Configure flow and set initial value
        self.carouselCollectionViewFlowLayout.delegate = self
        
        self.carouselCollectionView.contentInset = UIEdgeInsets(top: 0.0, left: 93.75, bottom: 0.0, right: 93.75)
        self.carouselCollectionView.decelerationRate = UIScrollView.DecelerationRate.fast
        
        self.currentPage = self.personalPage
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.carouselCollectionView.layoutIfNeeded()
        self.carouselCollectionView.reloadData()
        self.carouselCollectionView.layoutIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.carouselCollectionView.contentOffset = CGPoint(x: self.carouselCollectionView.bounds.width / 4.0, y: 0.0)
        self.changed(carouselCollectionView, itemAtCenter: self.personalPage, forceScroll: true)
        self.carouselCollectionView.reloadData()
        self.firstTime = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.carouselCollectionView.reloadData()
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
            carouselCell.containerView.backgroundColor = (indexPath.row == self.currentPage ? Palette.bannerShadow : Palette.bannerText)
            
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
            if self.currentPage != itemAtCenter || forceScroll == true {
                UIView.animate(withDuration: self.firstTime ? 0.0 : 0.5) {
                    // Unhighlight the cell leaving the center
                    if let cell = self.carouselCollectionView.cellForItem(at: IndexPath(item: self.currentPage, section: 0)) as? DashboardCarouselCell {
                        if self.currentPage != itemAtCenter {
                            cell.containerView.backgroundColor = Palette.bannerText
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
                        cell.titleLabel.alpha = 1.0
                    }
                    self.scrollCollectionView.reloadData()
                }
            }
        }
        
    }
    
    private func selectPage(_ page: Int) {
        
    }
    
    // MARK: - Function to present and dismiss this view ==============================================================
    
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
        self.bannerPaddingView.backgroundColor = Palette.banner
        self.bannerView.backgroundColor = Palette.banner
        self.titleLabel.textColor = Palette.bannerText
    }

    private func defaultCellColors(_ cell: DashboardCarouselCell) {
        cell.titleLabel.textColor = Palette.bannerText
        cell.backgroundImageView.tintColor = Palette.bannerTextContrast
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
