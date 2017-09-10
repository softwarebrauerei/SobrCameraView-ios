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
        self.sourceImageView.contentMode = .scaleAspectFit
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.sourceImageView.image = self.sourceImage
    }
    
    
    @IBAction func back(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }
}
