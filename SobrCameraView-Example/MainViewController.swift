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
        
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBarHidden = true
        self.cameraView.start()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        self.cameraView.stop()
        self.navigationController?.navigationBarHidden = false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showImage" {
            var points = CornerPoints()
            points.topLeft = CGPoint(x: 20, y: 100)
            points.topRight = CGPoint(x: 120, y: 100)
            points.bottomLeft = CGPoint(x: 20, y: 300)
            points.bottomRight = CGPoint(x: 120, y: 300)
            
            (segue.destinationViewController as! ImageViewController).sourceImage = self._image
            (segue.destinationViewController as! ImageViewController).rectangleFeature = self._feature
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

