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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.cameraView.setupCameraView()
        self.cameraView.borderDetectionEnabled = true
        
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBarHidden = true
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
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
            (segue.destinationViewController as! ImageViewController).image = self._image
        }
    }
    
    //MARK: Actions
    @IBAction func captureImage(sender: AnyObject?) {
        self.cameraView.captureImage { (image) -> Void in
            self._image = image
            self.performSegueWithIdentifier("showImage", sender: nil)
        }
    }
    
    @IBAction func toggleTorch(sender: AnyObject?) {
        self.cameraView.torchEnabled = !self.cameraView.torchEnabled
    }

}

