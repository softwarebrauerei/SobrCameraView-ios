//
//  ViewController.swift
//  SobrCameraView-Example
//
//  Created by Silas Knobel on 16/06/15.
//  Copyright (c) 2015 Software Brauerei AG. All rights reserved.
//

import UIKit

class MainViewController: UIViewController {
    
    //MARK: Outlets
    @IBOutlet weak var cameraView: SobrCameraView!
    
    private var _image: UIImage?
    private var _feature: CIRectangleFeature?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.cameraView.setupCameraView()
        self.cameraView.borderDetectionEnabled = true
        self.cameraView.borderDetectionFrameColor = UIColor(red:0.2, green:0.6, blue:0.86, alpha:0.5)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBarHidden = true
        self.cameraView.start()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        self.cameraView.stop()
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showImage" {
            (segue.destinationViewController as! ImageViewController).sourceImage = self._image
        }
    }
    
    //MARK: Actions
    @IBAction func captureImage(sender: AnyObject?) {
        self.cameraView.captureImage { (image, feature) -> Void in
            self._image = image
            self._feature = feature
            self.performSegueWithIdentifier("showImage", sender: nil)
        }
    }
    
    @IBAction func toggleTorch(sender: AnyObject?) {
        self.cameraView.torchEnabled = !self.cameraView.torchEnabled
    }

}

