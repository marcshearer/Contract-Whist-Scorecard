//
//  PlayerDetailViewController.swift
//  Contract Whist Scorecard
//
//  Created by Marc Shearer on 13/12/2016.
//  Copyright © 2016 Marc Shearer. All rights reserved.
//

import UIKit

enum DetailMode {
    case create
    case amend
    case display
    case download
    case downloaded
    case none
}

class PlayerDetailViewController: CustomViewController, UITableViewDataSource, UITableViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, SyncDelegate {
    
    // MARK: - Class Properties ======================================================================== -
    // Main state properties
    private let scorecard = Scorecard.shared
    private var reconcile: Reconcile!
    private let sync = Sync()

    // Properties to control how view works
    private var playerDetail: PlayerDetail!
    private var mode: DetailMode!
    private var sourceView: UIView!
    private var callerCompletion: ((PlayerDetail?, Bool)->())?
    
    // Local class variables
    private var tableRows = 0
    private var baseRows = 0
    private var nameTitleRow = 1
    private var nameRow = 2
    private var emailTitleRow = 3
    private var emailRow = 4
    private var twosTitleRow = -1
    private var twosValueRow = -1
    private var imageRow = 6
    private var emailOnEntry = ""
    private var visibleOnEntry = false
    private var actionSheet: ActionSheet!
    private let grayColor = UIColor(white: 0.9, alpha: 1.0)
    private var showEmail = false
    private var changed = false

    // Alert controller while waiting for cloud download
    private var cloudAlertController: UIAlertController!
    private var cloudIndicatorView: UIActivityIndicatorView!

    // UI component pointers
    private var textFieldList = [UITextField?](repeating: nil, count: 23)
    private var nameErrorLabel: UILabel? = nil
    private var emailErrorLabel: UILabel? = nil
    private var imageView: UIImageView? = nil
    private var emailCell: PlayerDetailCell!

    // MARK: - IB Outlets ============================================================================== -
    @IBOutlet private weak var navigationBar: UINavigationBar!
    @IBOutlet private weak var footerPaddingView: UIView!
    @IBOutlet private weak var finishButton: UIButton!
    @IBOutlet private weak var actionButton: UIButton!
    @IBOutlet private weak var tableView: UITableView!

    // MARK: - IB Actions ============================================================================== -
    
    @IBAction func continueButtonPressed(_ sender: Any) {
        switch mode! {
        case .amend:
            // Update core data with any changes
            self.warnEmailChanged(completion: {
                if !CoreData.update(updateLogic: {
                    let playerMO = self.playerDetail.playerMO!
                    if playerMO.email != self.playerDetail.email {
                        // Need to rebuild as email changed
                        self.playerDetail.toManagedObject(playerMO: playerMO)
                        if Reconcile.rebuildLocalPlayer(playerMO: self.playerDetail.playerMO) {
                            self.playerDetail.fromManagedObject(playerMO: playerMO)
                        }
                    } else {
                        self.playerDetail.toManagedObject(playerMO: playerMO)
                    }
                }) {
                    self.alertMessage("Error saving player")
                }
            })
        case .create:
            // Player will be created in calling controller (selectPlayers)
            self.dismiss(animated: true, completion: { self.callerCompletion?(self.playerDetail, false) })
        case .download:
            self.getCloudPlayerDetails()
        case .downloaded:
            // No further action required
            self.dismiss(animated: true, completion: { self.callerCompletion?(self.playerDetail, false) })
        default:
            break
        }
    }
    
    @IBAction func backButtonPressed(_ sender: Any) {

        // Taking cancel option
        if self.mode != .display {
            playerDetail.name = ""
        }
        self.dismiss(animated: true, completion: { self.callerCompletion?(nil, false) })

    }

    @IBAction func allSwipe(recognizer:UISwipeGestureRecognizer) {
        backButtonPressed(finishButton!)
    }
    
    // MARK: - method to show this view controller ============================================================================== -
    
    static public func show(from sourceViewController: UIViewController, playerDetail: PlayerDetail, mode: DetailMode, sourceView: UIView, completion: ((PlayerDetail?,Bool)->())? = nil) {
        let storyboard = UIStoryboard(name: "PlayerDetailViewController", bundle: nil)
        let playerDetailViewController = storyboard.instantiateViewController(withIdentifier: "PlayerDetailViewController") as! PlayerDetailViewController
        playerDetailViewController.modalPresentationStyle = UIModalPresentationStyle.popover
        playerDetailViewController.isModalInPopover = true
        playerDetailViewController.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection()
        playerDetailViewController.popoverPresentationController?.sourceView = sourceView
        playerDetailViewController.preferredContentSize = CGSize(width: 400, height: 600)
        playerDetailViewController.playerDetail = playerDetail
        playerDetailViewController.mode = mode
        playerDetailViewController.sourceView = sourceView
        playerDetailViewController.callerCompletion = completion
        sourceViewController.present(playerDetailViewController, animated: true, completion: nil)
    }
    
    // MARK: - View Overrides ========================================================================== -

    override func viewDidLoad() {
        super.viewDidLoad()
        
        baseRows = 13
        if scorecard.settingBonus2 {
            twosTitleRow = baseRows
            twosValueRow = baseRows + 1
            baseRows += 2
        }
        tableRows = baseRows + (mode == .amend ? 10 : 8) // Exclude delete if not in amend mode
        navigationBar.topItem?.title = playerDetail.name
        
        switch self.mode! {
        case .create:
            // Smaller input
            tableRows = 7
            baseRows = 10
            navigationBar.topItem?.title = "New Player"
            
        case .download:
            // Switch name and email
            emailTitleRow = 1
            emailRow = 2
            nameTitleRow = 3
            nameRow = 4
            navigationBar.topItem?.title = "Download"
            footerPaddingView.backgroundColor = self.grayColor
            showEmail = true

        default:
            break
        }
        
        // Store email on entry
        emailOnEntry = playerDetail.email
        visibleOnEntry = playerDetail.visibleLocally
        
        enableButtons()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        scorecard.reCenterPopup(self)
        if actionSheet != nil {
            scorecard.reCenterPopup(actionSheet.alertController)
        }
    }

    // MARK: - TableView Overrides ===================================================================== -

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableRows
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return (indexPath.row == imageRow ? 80 :
               (indexPath.row == 0 ? 10 :
               (indexPath.row % 2 == 1 ? 20 : 44)))
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: PlayerDetailCell?
        
        switch indexPath.row {
        case 0:
            // blank row at the top
            cell = tableView.dequeueReusableCell(withIdentifier: "Player Detail Padding", for: indexPath) as? PlayerDetailCell
        case nameTitleRow, emailTitleRow, baseRows, baseRows+2, baseRows+4, baseRows+8:
            // Single input title
            cell = tableView.dequeueReusableCell(withIdentifier: "Player Detail Header Single", for: indexPath) as? PlayerDetailCell
        case 5:
            // Thumbnail title
            cell = tableView.dequeueReusableCell(withIdentifier: "Player Detail Header Single", for: indexPath) as? PlayerDetailCell
        case 7, 9, 11, twosTitleRow:
            // Triple title
            cell = tableView.dequeueReusableCell(withIdentifier: "Player Detail Header Triple", for: indexPath) as? PlayerDetailCell
        case nameRow, emailRow:
            // Single input value
            cell = tableView.dequeueReusableCell(withIdentifier: "Player Detail Body Single", for: indexPath) as? PlayerDetailCell
            cell?.playerDetailField.tag = indexPath.row
            cell?.playerDetailField.addTarget(self, action: #selector(PlayerDetailViewController.textFieldDidChange(_:)), for: UIControl.Event.editingChanged)
            cell?.playerDetailField.addTarget(self, action: #selector(PlayerDetailViewController.textFieldShouldReturn(_:)), for: UIControl.Event.editingDidEndOnExit)
            cell?.playerDetailField.returnKeyType = .next
            cell?.playerDetailField.isSecureTextEntry = false
            cell?.playerDetailSecure.isHidden = true
            cell?.playerDetailSecureInfo.isHidden = true
            textFieldList[indexPath.row] = cell!.playerDetailField
        case imageRow:
            // Image view
            cell = tableView.dequeueReusableCell(withIdentifier: "Player Detail Image", for: indexPath) as? PlayerDetailCell
            imageView = cell?.playerImage
            ScorecardUI.veryRoundCorners(imageView!)
        case 8, 10, 12, twosValueRow, baseRows+1, baseRows+3, baseRows+5, baseRows+6, baseRows+7:
            // Triple value
            cell = tableView.dequeueReusableCell(withIdentifier: "Player Detail Body Triple", for: indexPath) as? PlayerDetailCell
            cell?.playerDetailLabel1.textColor = (mode == .download ? .lightGray : .black)
            cell?.playerDetailLabel2.textColor = (mode == .download ? .lightGray : .black)
            cell?.playerDetailLabel3.textColor = (mode == .download ? .lightGray : .black)
        case baseRows+9:
            // Single action button
            cell = tableView.dequeueReusableCell(withIdentifier: "Player Detail Body Action Button", for: indexPath) as? PlayerDetailCell
            
        default:
            cell = nil
        }
        
        switch indexPath.row {
        case 0:
            // Blank row
            break
        case nameTitleRow:
            // Name title
            cell!.playerDetailLabel1.text = "Player name"
            nameErrorLabel = cell!.playerDetailLabel2
            ScorecardUI.errorStyle(nameErrorLabel!)
        case nameRow:
            // Name value
            cell!.playerDetailField.text = playerDetail.name
            switch mode! {
            case .create, .amend:
                cell!.playerDetailField.placeholder = "Player name - Must not be blank"
            default:
                cell!.playerDetailField.placeholder = "Player name"
            }
            cell!.playerDetailField.keyboardType = .default
            cell!.playerDetailField.autocapitalizationType = .words
            cell!.playerDetailField.returnKeyType = .next
            if mode == .create {
                cell!.playerDetailField.becomeFirstResponder()
            }
        case emailTitleRow:
            // Email title
            switch mode! {
            case .download:
                cell!.playerDetailLabel1.text = "Player to download"
            default:
                cell!.playerDetailLabel1.text = "Unique identifier - E.g. email address"
            }
            emailErrorLabel = cell!.playerDetailLabel2
            ScorecardUI.errorStyle(emailErrorLabel!)
        case emailRow:
            // Email value
            cell!.playerDetailField.text = "\(playerDetail.email)"
            switch mode! {
            case .download:
                cell!.playerDetailField.placeholder = "Unique identifier of player"
            default:
                cell!.playerDetailField.placeholder = "Unique identifier - Must not be blank"
            }
            cell!.playerDetailField.keyboardType = .emailAddress
            cell!.playerDetailField.autocapitalizationType = .none
            cell!.playerDetailField.returnKeyType = .done
            cell?.playerDetailSecure.addTarget(self, action: #selector(PlayerDetailViewController.secureButtonPressed(_:)), for: UIControl.Event.touchUpInside)
            cell?.playerDetailSecureInfo.addTarget(self, action: #selector(PlayerDetailViewController.secureInfoButtonPressed(_:)), for: UIControl.Event.touchUpInside)
            emailCell = cell
            // Hidden entry if value already filled in
            setEmailVisible(self.playerDetail.visibleLocally)
            if mode == .download {
                cell!.playerDetailField.becomeFirstResponder()
            }
            cell!.separator.isHidden = (mode == .download)
        case 5:
            // Thumbnail title
            cell!.playerDetailLabel1.text = "Thumbnail image"
        case imageRow:
            // Thumbnail Image
            Utility.setThumbnail(data: playerDetail.thumbnail,
                                 imageView: cell!.playerImage)
        case 7:
            // Played, Won titles
            cell!.playerDetailLabel1.text = "Games played"
            cell!.playerDetailLabel2.text = "Games won"
            cell!.playerDetailLabel3.text = "Games won %"
        case 8:
            // Played, Won values
            cell!.playerDetailLabel1.text = "\(playerDetail.gamesPlayed)"
            cell!.playerDetailLabel2.text = "\(playerDetail.gamesWon)"
            var ratio = (CGFloat(playerDetail.gamesWon) / CGFloat(playerDetail.gamesPlayed) * 100)
            ratio.round()
            cell!.playerDetailLabel3.text = (playerDetail.gamesPlayed == 0 ? "0 %" : "\(Int(ratio)) %")
        case 9:
            // Total score, Average score titles
            cell!.playerDetailLabel1.text = "Total score"
            cell!.playerDetailLabel2.text = "Average score"
            cell!.playerDetailLabel3.text = ""
        case 10:
            // Total score, Average score values
            cell!.playerDetailLabel1.text = "\(playerDetail.totalScore)"
            var ratio = CGFloat(playerDetail.totalScore) / CGFloat(playerDetail.gamesPlayed)
            ratio.round()
            cell!.playerDetailLabel2.text = (playerDetail.gamesPlayed == 0 ? "0" : "\(Int(ratio))")
            cell!.playerDetailLabel3.text = ""
        case 11:
            // Hands played, Hands Made titles
            cell!.playerDetailLabel1.text = "Hands played"
            cell!.playerDetailLabel2.text = "Hands made"
            cell!.playerDetailLabel3.text = "Hands made %"
        case 12:
            // Hands played, Hands Made values
            cell!.playerDetailLabel1.text = "\(playerDetail.handsPlayed)"
            cell!.playerDetailLabel2.text = "\(playerDetail.handsMade)"
            var ratio = (CGFloat(playerDetail.handsMade) / CGFloat(playerDetail.handsPlayed)) * 100
            ratio.round()
            cell!.playerDetailLabel3.text = (playerDetail.handsPlayed == 0 ? "0 %" : "\(Int(ratio)) %")
        case twosTitleRow:
            // Twos titles
            cell!.playerDetailLabel1.text = "Twos made"
            cell!.playerDetailLabel2.text = "Twos made %"
            cell!.playerDetailLabel3.text = ""
        case twosValueRow:
            // Twos values
            cell!.playerDetailLabel1.text = "\(playerDetail.twosMade)"
            var ratio = (CGFloat(playerDetail.twosMade) / CGFloat(playerDetail.handsPlayed)) * 100
            ratio.round()
            cell!.playerDetailLabel2.text = (playerDetail.handsPlayed == 0 ? "0 %" : "\(Int(ratio)) %")
            cell!.playerDetailLabel3.text = ""
        case baseRows:
            // Date last played title
            cell!.playerDetailLabel1.text = "Last played"
        case baseRows+1:
            // Date last played
            if playerDetail.datePlayed != nil {
                let formatter = DateFormatter()
                formatter.dateStyle = DateFormatter.Style.full
                cell!.playerDetailLabel1.text = formatter.string(from: playerDetail.datePlayed)
            } else {
                cell!.playerDetailLabel1.text="Not played"
            }
            cell!.playerDetailLabel1Width.constant = 300
            cell!.playerDetailLabel2Width.constant = 0
            cell!.playerDetailLabel3Width.constant = 0
            cell!.playerDetailLabel1.textAlignment = .left
            cell!.playerDetailLabel2.text = ""
            cell!.playerDetailLabel3.text = ""
        case baseRows+2:
            // Date last sync title
            cell!.playerDetailLabel1.text = "Last sync"
        case baseRows+3:
            // Date last sync
            if playerDetail.syncDate != nil {
                let formatter = DateFormatter()
                formatter.dateStyle = DateFormatter.Style.full
                cell!.playerDetailLabel1.text = formatter.string(from: playerDetail.syncDate)
            } else {
                cell!.playerDetailLabel1.text="Not synced"
            }
            cell!.playerDetailLabel1Width.constant = 300
            cell!.playerDetailLabel2Width.constant = 0
            cell!.playerDetailLabel3Width.constant = 0
            cell!.playerDetailLabel1.textAlignment = .left
            cell!.playerDetailLabel2.text = ""
            cell!.playerDetailLabel3.text = ""
        case baseRows+4:
            // Personal Records Title
                cell!.playerDetailLabel1.text = "Personal Records"
        case baseRows+5:
            cell!.playerDetailLabel1.textAlignment = .left
            cell!.playerDetailLabel1.text = "Score"
            cell!.playerDetailLabel2.text = "\(playerDetail.maxScore)"
            if playerDetail.maxScoreDate != nil {
                let formatter = DateFormatter()
                formatter.setLocalizedDateFormatFromTemplate("dd/MM/yyyy")
                cell!.playerDetailLabel3.text = formatter.string(from: playerDetail.maxScoreDate)
            } else {
                cell!.playerDetailLabel3.text=""
            }
            cell!.separator.isHidden = true
        case baseRows+6:
            cell!.playerDetailLabel1.textAlignment = .left
            cell!.playerDetailLabel1.text = "Bids made"
            cell!.playerDetailLabel2.text = "\(playerDetail.maxMade)"
            if playerDetail.maxMadeDate != nil {
                let formatter = DateFormatter()
                formatter.setLocalizedDateFormatFromTemplate("dd/MM/yyyy")                
                cell!.playerDetailLabel3.text = formatter.string(from: playerDetail.maxMadeDate)
            } else {
                cell!.playerDetailLabel3.text=""
            }
            cell!.separator.isHidden = true
        case baseRows+7:
            cell!.playerDetailLabel1.textAlignment = .left
            cell!.playerDetailLabel1.text = "Twos made"
            cell!.playerDetailLabel2.text = "\(playerDetail.maxTwos)"
            if playerDetail.maxTwosDate != nil {
                let formatter = DateFormatter()
                formatter.setLocalizedDateFormatFromTemplate("dd/MM/yyyy")
                cell!.playerDetailLabel3.text = formatter.string(from: playerDetail.maxTwosDate)
            } else {
                cell!.playerDetailLabel3.text=""
            }
        case baseRows+8:
            // Personal Records Title
            cell!.playerDetailLabel1.text = "Actions"
        case baseRows+9:
            cell!.playerDetailActionButton.setTitle("Delete Player", for: .normal)
            cell!.playerDetailActionButton.addTarget(self, action: #selector(PlayerDetailViewController.actionButtonPressed(_:)), for: UIControl.Event.touchUpInside)
            
        default:
            break
        }
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor.clear
        cell!.selectedBackgroundView = backgroundView
        
        if mode == .download {
            // Gray out and disable all but email row
            if indexPath.row == emailRow {
                cell?.isUserInteractionEnabled = true
                cell?.backgroundColor = .white
            } else {
                cell?.isUserInteractionEnabled = false
                if indexPath.row > emailRow {
                    cell?.backgroundColor = self.grayColor
                }
            }
        } else {
            cell?.backgroundColor = UIColor.white
        }

        if self.mode == .display || self.mode == .downloaded {
            cell?.isUserInteractionEnabled = false
        }
        
        return cell!
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath?{
        switch indexPath.row {
        case imageRow:
            return indexPath
        default:
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.row {
        case imageRow:
            
            tableView.deselectRow(at: indexPath, animated: false)
            
            actionSheet = ActionSheet("Thumbnail Image", message: "\(playerDetail.thumbnail == nil ? "Add a" : "Replace") thumbnail image for this player", view: sourceView)
            actionSheet.add("Take Photo", handler: {
                    self.getPicture(from: .camera)
                })
            actionSheet.add("Use Photo Library",handler: {
                    self.getPicture(from: .photoLibrary)
                })
            if playerDetail.thumbnail != nil {
                actionSheet.add("Remove Photo", handler: {
                    self.removeImage()

                })
            }
            actionSheet.add("Cancel", style: .cancel, handler:nil)
            actionSheet.present()
        default:
            break
        }
    }
    
    // MARK: - TextField and Button Control Overrides ======================================================== -
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        self.changed = true
        switch textField.tag {
        case nameRow:
            playerDetail.name = textField.text!
            playerDetail.nameDate = Date()
        case emailRow:
            playerDetail.email = textField.text!
            playerDetail.emailDate = Date()
        default:
            break
        }
        self.enableButtons()
    }
    
    @objc func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.tag == nameRow && textField.text == "" {
            // Don't allow blank name
            return false
        } else if mode == .download && textField.tag == emailRow && textField.text == "" {
            // Don't allow blank email in download mode
            return false
        } else {
            // Try to move to next text field - resign if none found
            var field = textField.tag
            var found = false
            while field < textFieldList.count - 1 {
                field += 1
                if textFieldList[field] != nil {
                    textFieldList[field]?.becomeFirstResponder()
                    found = true
                    break
                }
            }
            if !found {
                textField.resignFirstResponder()
            }
            return true
        }
    }

    @objc func secureButtonPressed(_ button: UIButton) {
        alertDecision("Note that by default Unique IDs are only visible on a device where they are created. Changing this setting will also make this Unique ID hidden on this device - i.e. you will not be able to see the value on this device although you will be able to change it. Once you select hidden mode, this is irreversible.\n\nYou can only make the Unique ID visible again by blanking it out and re-typing it.\n\nAre you sure you want to do this?", title: "Hidden Mode", okButtonText: "Confirm", okHandler: {
                self.setEmailVisible(false)
                self.changed = true
                self.enableButtons()
        })
    }
    
    @objc func secureInfoButtonPressed(_ button: UIButton) {
        alertMessage("Note that by default Unique IDs are only visible on a device where they are created. \n\nYou can only make the Unique ID visible again by blanking it out and re-typing it.", title: "Hidden Entry")
    }
    
    @objc func actionButtonPressed(_ button: UIButton) {
        switch button.tag {
        case 0:
            self.checkDeletePlayer()
        default:
            break
        }
    }

   // MARK: - Image Picker Routines / Overrides ============================================================ -

    func getPicture(from: UIImagePickerController.SourceType) {
       if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.allowsEditing = false
            imagePicker.sourceType = from
            
            present(imagePicker, animated: true, completion: nil)
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)
        
        if let selectedImage = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as? UIImage {
            var rotatedImage:UIImage
            
            imageView!.image = selectedImage
            
            if let rawImage = imageView!.image {
                rotatedImage = rotateImage(image: rawImage)
                if let imageData = rotatedImage.pngData() {
                    playerDetail.thumbnail  = Data(imageData)
                    playerDetail.thumbnailDate = Date()
                }
                imageView!.image = rotatedImage
            }
            imageView!.contentMode = .scaleAspectFill
            imageView!.clipsToBounds = true
            imageView!.alpha = 1.0
            imageView!.backgroundColor = UIColor.lightGray
            self.changed = true
            self.enableButtons()
            
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    func rotateImage(image: UIImage) -> UIImage {
        
        if (image.imageOrientation == UIImage.Orientation.up ) {
            return image
        }
        
        UIGraphicsBeginImageContext(image.size)
        
        image.draw(in: CGRect(origin: CGPoint.zero, size: image.size))
        let copy = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return copy!
    }
    
    func removeImage() {
        playerDetail.thumbnail = nil
        playerDetail.thumbnailDate = nil
        imageView!.image = UIImage(named: "camera")
        imageView!.contentMode = .center
        imageView!.clipsToBounds = false
        imageView!.alpha = 0.5
        self.changed = true
        self.enableButtons()
    }
    
    // MARK: - Sync routines including the delegate methods ======================================== -
    
    func getCloudPlayerDetails() {
        
        sync.initialise()
        
        self.cloudAlertController = UIAlertController(title: title, message: "Downloading player from Cloud\n\n\n\n", preferredStyle: .alert)
        
        self.sync.delegate = self
        if self.sync.connect() {
            
            //add the activity indicator as a subview of the alert controller's view
            self.cloudIndicatorView = UIActivityIndicatorView(frame: CGRect(x: 0, y: 100,
                                                                width: self.cloudAlertController.view.frame.width,
                                                                height: 100))
            self.cloudIndicatorView.style = .whiteLarge
            self.cloudIndicatorView.color = UIColor.black
            self.cloudIndicatorView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.cloudAlertController.view.addSubview(self.cloudIndicatorView)
            self.cloudIndicatorView.isUserInteractionEnabled = true
            self.cloudIndicatorView.startAnimating()
            
            self.present(self.cloudAlertController, animated: true, completion: nil)
            
            self.sync.synchronise(syncMode: .syncGetPlayerDetails, specificEmail: [playerDetail.email])
        } else {
            self.alertMessage("Error getting player details from iCloud")
            self.actionButton.isHidden = true
        }
    }
    
    func getImages(_ imageFromCloud: [PlayerMO]) {
        self.sync.fetchPlayerImagesFromCloud(imageFromCloud)
    }
    
    func syncMessage(_ message: String) {
    }
    
    func syncAlert(_ message: String, completion: @escaping ()->()) {
        Utility.mainThread {
            self.cloudAlertController.dismiss(animated: true, completion: {
                self.alertMessage(message, title: "Contract Whist Scorecard", okHandler: {
                    self.actionButton.isHidden = true
                    completion()
                })
            })
        }
    }
    
    func syncCompletion(_ errors: Int) {
    }
    
    func syncReturnPlayers(_ playerList: [PlayerDetail]!) {
        
        Utility.mainThread {
            self.cloudAlertController.dismiss(animated: true, completion: {
                if playerList != nil && playerList.count > 0 {
                    self.playerDetail = playerList[0]
                    self.mode = .downloaded
                    self.navigationBar.topItem?.title = self.playerDetail.name
                    self.footerPaddingView.backgroundColor = UIColor.white
                    self.tableView.isUserInteractionEnabled = false
                    self.enableButtons()
                    self.tableView.reloadData()
                    
                } else {
                    self.alertMessage("Unable to download player from Cloud", buttonText: "Continue", okHandler:
                        {
                            self.actionButton.isHidden = true
                    })
                }
            })
        }
    }
    
    // MARK: - Form Presentation / Handling Routines =================================================== -
    
    func enableButtons() {
        var finishTitle = ""
        var invalid: Bool
        
        let duplicateName = scorecard.isDuplicateName(playerDetail)
        let duplicateEmail = scorecard.isDuplicateEmail(playerDetail)
        
        switch mode! {
        case .amend, .create:
            invalid = duplicateName || duplicateEmail || playerDetail.name == "" || playerDetail.email == ""
        case .download:
            invalid = (playerDetail.email == "" || duplicateEmail)
        default:
            invalid = false
        }
        
        if invalid {
            finishTitle = "Cancel"
        } else if (mode == .amend && self.changed) || mode == .create {
            finishTitle = "Cancel"
        } else {
            finishTitle = "Back"
        }
        finishButton.setTitle(finishTitle, for: .normal)
        
        switch mode! {
        case .amend:
            actionButton.isHidden = (!self.changed || invalid)
            actionButton.setTitle("Save", for: .normal)
        case .create:
            actionButton.isHidden = invalid
            actionButton.setTitle("Create", for: .normal)
        case .download:
            actionButton.isHidden = invalid
            actionButton.setTitle("Check", for: .normal)
        case .downloaded:
            actionButton.isHidden = false
            actionButton.setTitle("Add", for: .normal)
        default:
            actionButton.isHidden = true
        }
        
        if nameErrorLabel != nil {
            nameErrorLabel!.text = (duplicateName ? "Duplicate not allowed" : "")
        }
        if emailErrorLabel != nil {
            emailErrorLabel!.text = (duplicateEmail ? (mode == .download ? "Already on device" : "Duplicate not allowed") : "")
        }
        
        if playerDetail.email == "" {
            // Reset to visible
            setEmailVisible(true)
            // Avoid undo to reveal previous content
            if self.emailCell != nil {
                self.emailCell.playerDetailField.undoManager?.removeAllActions()
            }
        }
    }
    
    // MARK: - Utility Routines ======================================================================== -

    func checkDeletePlayer() {
        var alertController: UIAlertController
        alertController = UIAlertController(title: "Warning", message: "This will remove the player \n'\(playerDetail.name)'\nfrom this device.\n\nIf you are synchronising with iCloud the player will still be available to download in future.\n Otherwise this will remove their details permanently.\n\n Are you sure you want to do this?", preferredStyle: UIAlertController.Style.alert)
        
        alertController.addAction(UIAlertAction(title: "Confirm", style: UIAlertAction.Style.default,
                                                handler: { (action:UIAlertAction!) -> Void in
            
            // Update core data with any changes
            self.playerDetail.deleteMO()

            // Remove this player from list of subscriptions
            Notifications.updateHighScoreSubscriptions()

            // Delete any detached games
            History.deleteDetachedGames()

            // Flag as deleted and return
            self.dismiss(animated: true, completion: { self.callerCompletion?(self.playerDetail, true) })
                                                    
        }))
        alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler:nil))
        present(alertController, animated: true, completion: nil)
    }
    
    func warnEmailChanged(completion: (()->())? = nil) {
        if self.playerDetail.name != "" && self.emailOnEntry != "" && self.emailOnEntry != self.playerDetail.email {
            self.alertDecision("If you change a player's unique ID this will separate them from their game history. Essentially this is the same as deleting the player and creating a new one.\n\nAre you sure you want to do this?", title: "Warning",
            okHandler: {
                completion?()
                self.dismiss(animated: true, completion: { self.callerCompletion?(self.playerDetail, false) })
            },
            cancelHandler: {
            })
        } else {
            completion?()
            self.dismiss(animated: true, completion: { self.callerCompletion?(self.playerDetail, false) })
        }
    }
    
    func setEmailVisible(_ visible: Bool) {
        self.playerDetail.visibleLocally = visible
        if self.emailCell != nil && !showEmail {
            self.emailCell.playerDetailField.isSecureTextEntry = !visible
            self.emailCell.playerDetailSecure.isHidden = !visible
            self.emailCell.playerDetailSecureInfo.isHidden = visible
        }
    }
}

// MARK: - Other UI Classes - e.g. Cells =========================================================== -

class PlayerDetailCell: UITableViewCell {
    @IBOutlet weak var playerDetailLabel1Width: NSLayoutConstraint!
    @IBOutlet weak var playerDetailLabel2Width: NSLayoutConstraint!
    @IBOutlet weak var playerDetailLabel3Width: NSLayoutConstraint!
    @IBOutlet weak var playerDetailLabel1: UILabel!
    @IBOutlet weak var playerDetailLabel2: UILabel!
    @IBOutlet weak var playerDetailLabel3: UILabel!
    @IBOutlet weak var playerDetailField: UITextField!
    @IBOutlet weak var playerDetailSecure: UIButton!
    @IBOutlet weak var playerDetailSecureInfo: UIButton!
    @IBOutlet weak var playerDetailActionButton: UIButton!
    @IBOutlet weak var playerImage: UIImageView!
    @IBOutlet weak var separator: UIView!
}



// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
	return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
	return input.rawValue
}
