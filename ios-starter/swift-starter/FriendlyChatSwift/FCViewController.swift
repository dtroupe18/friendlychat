//
//  Copyright (c) 2015 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Photos
import UIKit

import Firebase
import GoogleMobileAds

/**
 * AdMob ad unit IDs are not currently stored inside the google-services.plist file. Developers
 * using AdMob can store them as custom values in another plist, or simply use constants. Note that
 * these ad units are configured to return only test ads, and should not be used outside this sample.
 */
let kBannerAdUnitID = "ca-app-pub-3940256099942544/2934735716"

@objc(FCViewController)
class FCViewController: UIViewController, UITableViewDataSource, UITableViewDelegate,
    UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate,
        InviteDelegate {

  // Instance variables
  @IBOutlet weak var textField: UITextField!
  @IBOutlet weak var sendButton: UIButton!
  var ref: DatabaseReference!
  var messages: [DataSnapshot]! = []
    let posts = [Post]()
    
  var msglength: NSNumber = 10
  fileprivate var _refHandle: DatabaseHandle!

  var storageRef: StorageReference!
  var remoteConfig: RemoteConfig!

  @IBOutlet weak var banner: GADBannerView!
  @IBOutlet weak var clientTable: UITableView!

  override func viewDidLoad() {
    super.viewDidLoad()

    self.clientTable.register(UITableViewCell.self, forCellReuseIdentifier: "tableViewCell")

    configureDatabase()
    configureStorage()
    configureRemoteConfig()
    fetchConfig()
    loadAd()
    logViewLoaded()
  }

    deinit {
        
        // NOT REALLY SURE WHAT THIS DOES
        if let refHandle = _refHandle {
            self.ref.child("messages").removeObserver(withHandle: _refHandle)
        }
    }
    
    
    func configureDatabase() {
        ref = Database.database().reference()
        // Listen for new messages in the Firebase database
        _refHandle = self.ref.child("messages").observe(.childAdded, with: { [weak self] (snapshot) -> Void in
            guard let strongSelf = self else { return }
            
            // EACH SNAPSHOT IS PLACED IN THE MESSAGES ARRAY
            strongSelf.messages.append(snapshot)
            
            // MAKE THE NUMBER OF ROWS IN THE FEED == THE NUMBER OF SNAPSHOTS
            strongSelf.clientTable.insertRows(at: [IndexPath(row: strongSelf.messages.count-1, section: 0)], with: .automatic)
        })
    }
    
    func configureStorage() {
        
        // REGULAR STORAGE REF - NOTE IT'S NOW STORAGE.STORAGE()
        storageRef = Storage.storage().reference()
    }

  func configureRemoteConfig() {
  }

  func fetchConfig() {
  }
    
    
    // FIREBASE CONFIG
  @IBAction func didPressFreshConfig(_ sender: AnyObject) {
    fetchConfig()
  }

    //
  @IBAction func didSendMessage(_ sender: UIButton) {
    _ = textFieldShouldReturn(textField)
  }

    @IBAction func didPressCrash(_ sender: AnyObject) {
        FirebaseCrashMessage("Cause Crash button clicked")
        fatalError()
    }


    func logViewLoaded() {
        FirebaseCrashMessage("View loaded")
    }

  func loadAd() {
  }

  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    guard let text = textField.text else { return true }

    let newLength = text.characters.count + string.characters.count - range.length
    return newLength <= self.msglength.intValue // Bool
  }

  // UITableViewDataSource protocol methods
    
    // RETURN THE NUMBER OF SNAPSHOTS
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return messages.count
  }
    
    
    //
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        // Dequeue cell - CLIENT TABLE = UITABLEVIEW
        let cell = self.clientTable .dequeueReusableCell(withIdentifier: "tableViewCell", for: indexPath)
        
        // Unpack message from Firebase DataSnapshot
        let messageSnapshot: DataSnapshot! = self.messages[indexPath.row]
        
        // CONVERT EACH SNAPSHOT TO A DICTIONARY 
        guard let message = messageSnapshot.value as? [String:String] else { return cell }
        
        //                  MESSAGE["NAME"]
        let name = message[Constants.MessageFields.name] ?? ""
        
                                // MESSAGE["IMAGEURL"]
        if let imageURL = message[Constants.MessageFields.imageURL] {
            if imageURL.hasPrefix("gs://") {
                Storage.storage().reference(forURL: imageURL).getData(maxSize: INT64_MAX) {(data, error) in
                    if let error = error {
                        print("Error downloading: \(error)")
                        return
                    }
                    
                    // THREADING.... DISPATCH SOMETHING IN THE MAIN THREAD
                    DispatchQueue.main.async {
                        
                        // USE OF REGULAR TABLEVIEW CELL NOT A CUSTOM CELL
                        cell.imageView?.image = UIImage.init(data: data!)
                        cell.setNeedsLayout()
                    }
                }
                // TRY URL DOESN'T HAVE "GS://" PREFIX
            } else if let URL = URL(string: imageURL), let data = try? Data(contentsOf: URL) {
                cell.imageView?.image = UIImage.init(data: data)
            }
            cell.textLabel?.text = "sent by: \(name)"
        }
            
        // NO IMAGE!
        else {
            let text = message[Constants.MessageFields.text] ?? ""
            cell.textLabel?.text = name + ": " + text
            
            // DEFAULT IMAGE
            cell.imageView?.image = UIImage(named: "ic_account_circle")
            
            // CHECK AGAIN FOR PHOTO URL    MESSAGE["PHOTOURL"]
            if let photoURL = message[Constants.MessageFields.photoURL], let URL = URL(string: photoURL),
                let data = try? Data(contentsOf: URL) {
                cell.imageView?.image = UIImage(data: data)
            }
        }
        return cell
    }
    

  // UITextViewDelegate protocol methods
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    guard let text = textField.text else { return true }
    textField.text = ""
    view.endEditing(true)
    
            // DATA = ["TEXT": TEXT]
    let data = [Constants.MessageFields.text: text]
    sendMessage(withData: data)
    return true
  }

    // SENDS MESSAGE REQUIRES THE USE OF A DICTIONARY
    func sendMessage(withData data: [String: String]) {
        var mdata = data
        
        // ADD ["NAME": CURRENT USER NAME] TO THE DICTIONARY
        mdata[Constants.MessageFields.name] = Auth.auth().currentUser?.displayName
        
        // *** NOT SURE ABOUT THIS BECAUSE DATA CAN ALREADY HAVE AN IMAGE URL ***
        if let photoURL = Auth.auth().currentUser?.photoURL {
            mdata[Constants.MessageFields.photoURL] = photoURL.absoluteString
        }
        
        // PUSH DATA TO FIREBASE DATABASE UNDER "MESSAGES"
        self.ref.child("messages").childByAutoId().setValue(mdata)
    }

 
    // BASIC IMAGE PICKER CONTROLLER, CAN USE EITHER THE CAMERA OR THE PHOTO LIBRARY
  @IBAction func didTapAddPhoto(_ sender: AnyObject) {
    let picker = UIImagePickerController()
    picker.delegate = self
    if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.camera) {
      picker.sourceType = UIImagePickerControllerSourceType.camera
    } else {
      picker.sourceType = UIImagePickerControllerSourceType.photoLibrary
    }

    present(picker, animated: true, completion:nil)
  }
    

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true, completion:nil)
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // if it's a photo from the library, not an image from the camera
        if #available(iOS 8.0, *), let referenceURL = info[UIImagePickerControllerReferenceURL] as? URL {
            let assets = PHAsset.fetchAssets(withALAssetURLs: [referenceURL], options: nil)
            let asset = assets.firstObject
            asset?.requestContentEditingInput(with: nil, completionHandler: { [weak self] (contentEditingInput, info) in
                let imageFile = contentEditingInput?.fullSizeImageURL
                let filePath = "\(uid)/\(Int(Date.timeIntervalSinceReferenceDate * 1000))/\((referenceURL as AnyObject).lastPathComponent!)"
                guard let strongSelf = self else { return }
                
                // UPLOADING PHOTO FROM LIBRARY TO FIREBASE STORAGE
                strongSelf.storageRef.child(filePath)
                    .putFile(from: imageFile!, metadata: nil) { (metadata, error) in
                        if let error = error {
                            let nsError = error as NSError
                            print("Error uploading: \(nsError.localizedDescription)")
                            return
                        }
                        
                        // SEND MESSAGE WITH IMAGE
                        strongSelf.sendMessage(withData: [Constants.MessageFields.imageURL: strongSelf.storageRef.child((metadata?.path)!).description])
                }
            })
        }
        // USE THE CAMERA TO GET A PHOTO
        else {
            guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else { return }
            
            // 80% COMPRESSION
            let imageData = UIImageJPEGRepresentation(image, 0.8)
            // USER ID + CURRENT TIME
            let imagePath = "\(uid)/\(Int(Date.timeIntervalSinceReferenceDate * 1000)).jpg"
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            // UPLOAD IMAGE TO FIREBASE STORAGE
            self.storageRef.child(imagePath)
                .putData(imageData!, metadata: metadata) { [weak self] (metadata, error) in
                    if let error = error {
                        print("Error uploading: \(error)")
                        return
                    }
                    guard let strongSelf = self else { return }
                    // SEND A MESSAGE WITH AN IMAGE
                    strongSelf.sendMessage(withData: [Constants.MessageFields.imageURL: strongSelf.storageRef.child((metadata?.path)!).description])
            }
        }
    }
    
    
    
    // CANCEL IMAGE PICKER
  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true, completion:nil)
  }

    // BASIC SIGN OUT OF APPLICATION
    @IBAction func signOut(_ sender: UIButton) {
        let firebaseAuth = Auth.auth()
        do {
            try firebaseAuth.signOut()
            dismiss(animated: true, completion: nil)
        } catch let signOutError as NSError {
            print ("Error signing out: \(signOutError.localizedDescription)")
        }
    }
    
    // SHOW ALERT FUNCTION, TAKES IN TWO STRINGS
  func showAlert(withTitle title: String, message: String) {
    DispatchQueue.main.async {
        let alert = UIAlertController(title: title,
            message: message, preferredStyle: .alert)
        let dismissAction = UIAlertAction(title: "Dismiss", style: .destructive, handler: nil)
        alert.addAction(dismissAction)
        self.present(alert, animated: true, completion: nil)
    }
  }
    
    // INVITE PEOPLE TO USE THIS APPLICATION
    @IBAction func inviteTapped(_ sender: AnyObject) {
        if let invite = Invites.inviteDialog() {
            invite.setInviteDelegate(self)
            
            // NOTE: You must have the App Store ID set in your developer console project
            // in order for invitations to successfully be sent.
            
            // A message hint for the dialog. Note this manifests differently depending on the
            // received invitation type. For example, in an email invite this appears as the subject.
            invite.setMessage("Try this out!\n -\(Auth.auth().currentUser?.displayName ?? "")")
            // Title for the dialog, this is what the user sees before sending the invites.
            invite.setTitle("FriendlyChat")
            invite.setDeepLink("app_url")
            invite.setCallToActionText("Install!")
            invite.setCustomImage("https://www.google.com/images/branding/googlelogo/2x/googlelogo_color_272x92dp.png")
            invite.open()
        }
    }
    
    // FINISH APPLICATION INVITE
    func inviteFinished(withInvitations invitationIds: [Any], error: Error?) {
        if let error = error {
            print("Failed: \(error.localizedDescription)")
        } else {
            print("Invitations sent")
        }
    }

}
