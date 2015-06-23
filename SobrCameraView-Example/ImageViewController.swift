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
    @IBOutlet weak var borderView: EditBorderView!
    
    var sourceImage: UIImage?
    var rectangleFeature: CIRectangleFeature?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.sourceImageView.image = self.sourceImage
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        self.transformRectangleFeature()
    }

    
    private func transformRectangleFeature() {
        if let feature = self.rectangleFeature {
            let contentScale = self.sourceImageView.contentScale()
            
            debugPrintln("image scale: \(contentScale)")

            var transform = CGAffineTransformMakeScale(1, -1)
            transform = CGAffineTransformTranslate(transform, 0, -self.sourceImageView.frame.size.height)
            transform = CGAffineTransformRotate(transform, CGFloat(-M_PI_2))
            
            var points = CornerPoints()
            points.topLeft = CGPointApplyAffineTransform(feature.topLeft, transform)
            points.topRight = CGPointApplyAffineTransform(feature.topRight, transform)
            points.bottomLeft = CGPointApplyAffineTransform(feature.bottomLeft, transform)
            points.bottomRight = CGPointApplyAffineTransform(feature.bottomRight, transform)
            debugPrintln("points before: \(points)")
            
            points.topLeft = self.transformPoint(points.topLeft, withScale: contentScale)
            points.topRight = self.transformPoint(points.topRight, withScale: contentScale)
            points.bottomLeft = self.transformPoint(points.bottomLeft, withScale: contentScale)
            points.bottomRight = self.transformPoint(points.bottomRight, withScale: contentScale)
            debugPrintln("points after: \(points)")
            
            self.borderView.cornerPoints = points
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func transformPoint(point: CGPoint, withScale scale: CGFloat) -> CGPoint {
        return CGPoint(x: point.x * scale, y: point.y * scale)
    }
}
