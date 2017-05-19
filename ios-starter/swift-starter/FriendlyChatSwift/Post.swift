import UIKit
import Firebase

class Post {
    
    private var text: String?
    private var image: UIImage?
    private var imageURL: String?
    private var addedByUser: String?
    private var date: String?
    
    let storageRef = Storage.storage()
    
    
    init(text: String, image: UIImage, imageURL: String, addedByUser: String) {
        self.text = text
        self.image = image
        self.imageURL = imageURL
        self.addedByUser = addedByUser
        self.date = String(describing: NSDate())
        
    }
    
    init(text: String, addedByUser: String) {
        self.text = text
        self.addedByUser = addedByUser
        self.date = String(describing: NSDate())
    }
    
    
    // constructor for data received from Firebase
    init(snapshot: DataSnapshot) {
        let snapshotValue = snapshot.value as! [String: Any]
        self.text = snapshotValue["text"] as? String
        print("Text: ", text!)
        self.imageURL = snapshotValue["imageURL"] as? String
        print("ImageURL: ", imageURL!)
        self.addedByUser = snapshotValue["addedByUser"] as? String
        print("Added by user: ", addedByUser!)
        self.date = snapshotValue["date"] as? String
        print("Date: ", date!)
        // self.image = downloadImage2(url: imageURL!)
        // downloadImage2(url: imageURL!)
    }
    
    func hasImage() -> Bool {
        if self.image != nil {
            return true
        }
        else {
            return false
        }
    }
    
    func getImage() -> UIImage {
        return image!
    }
    
    
    func getText() -> String {
        return text!
    }
    
    func getImageURL() -> String {
        return imageURL!
    }
    
    func setImageURL(url: String) {
        self.imageURL = url
    }
    
    func setImage(newImage: UIImage) {
        self.image = newImage
    }
    
    func getDate() -> String {
        return self.date!
    }
    
    
    // firebase database expects a dirctionary for uploads
    
    func toAnyObject() -> Any {
        return [
            "text": text,
            "imageURL": imageURL,
            "addedByUser": addedByUser,
            "date": date
        ]
    }
    
    // use the image url in the database to download the correct image from storage
    func downloadImage(url: String) {
        print("download image called")
        storageRef.reference(forURL: url).downloadURL(completion: { (url, error) in
            if error != nil {
                print(error?.localizedDescription ?? "Error getting image from url")
                return
            }
            
            URLSession.shared.dataTask(with: url!, completionHandler: { (data, response, error) in
                if error != nil {
                    print(error ?? "Error in url session")
                    return
                }
                guard let imageData = UIImage(data: data!) else { return }
                print("ImageData......")
                
                DispatchQueue.main.async {
                    self.image = imageData
                }
            })
        })
    }
}
