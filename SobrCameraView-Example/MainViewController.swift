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
    
    fileprivate var _image: UIImage?
    fileprivate var _feature: CIRectangleFeature?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.cameraView.setupCameraView()
        self.cameraView.borderDetectionEnabled = true
        self.cameraView.borderDetectionFrameColor = UIColor(red:0.2, green:0.6, blue:0.86, alpha:0.5)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.isNavigationBarHidden = true
        self.cameraView.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.cameraView.stop()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showImage" {
            (segue.destination as! ImageViewController).sourceImage = self._image
        }
    }
    
    //MARK: Actions
    @IBAction func captureImage(_ sender: AnyObject?) {
        self.cameraView.captureImage { (image, feature) -> Void in
            self._image = image
            self._feature = feature
            self.performSegue(withIdentifier: "showImage", sender: nil)
        }
    }
    
    @IBAction func toggleTorch(_ sender: AnyObject?) {
        self.cameraView.torchEnabled = !self.cameraView.torchEnabled
    }

}

