//
//  UIKitExtensions.swift
//  SobrCameraView-Example
//
//  Created by Silas Knobel on 22/06/15.
//  Copyright (c) 2015 Software Brauerei AG. All rights reserved.
//

import UIKit

extension UIImageView {
    func contentScale() -> CGFloat {
        return CGFloat(fminf(Float(self.bounds.width/self.image!.size.width), Float(self.bounds.height/self.image!.size.height)))
    }
    
    func contentSize() -> CGSize {
        let imageSize = self.image!.size
        let scale = self.contentScale()
        return CGSize(width: imageSize.width*scale, height: imageSize.height*scale)
    }
    
    func contentFrame() -> CGRect {
        let scaledImageSize = self.contentSize()
        return CGRect(x: 0.5*(self.bounds.width - scaledImageSize.width), y: 0.5 * (self.bounds.height - scaledImageSize.height), width: scaledImageSize.width, height: scaledImageSize.height)
    }
}
