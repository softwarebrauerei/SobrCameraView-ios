//
//  ImageViewController.swift
//  SobrCameraView-Example
//
//  Created by Silas Knobel on 16/06/15.
//  Copyright (c) 2015 Software Brauerei AG. All rights reserved.
//

import UIKit
import CoreImage

class ImageViewController: UIViewController {
    
    //MARK: Outlets
    @IBOutlet weak var sourceImageView: UIImageView!
    
    var sourceImage: UIImage?
    var rectangleFeature: CIRectangleFeature?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.sourceImageView.contentMode = .ScaleAspectFit
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.sourceImageView.image = self.sourceImage
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        self.transformRectangleFeature()
    }
    
    @IBAction func back(sender: UIButton) {
        self.navigationController?.popViewControllerAnimated(true)
    }
}
