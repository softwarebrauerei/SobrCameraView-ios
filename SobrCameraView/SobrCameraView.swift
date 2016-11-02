//
//  SobrCameraView.swift
//  SobrCameraView-Example
//
//  Created by Silas Knobel on 16/06/15.
//  Copyright (c) 2015 Software Brauerei AG. All rights reserved.
//

import UIKit
import AVFoundation
import CoreVideo
import CoreMedia
import CoreImage
import ImageIO
import GLKit

/**
Available Image Filters

- `.BlackAndWhite`: A black and white filter to increase the contrast.
- `.Normal`: Increases the contrast on colored pictures.
*/
public enum SobrCameraViewImageFilter: Int {
    case blackAndWhite = 0
    case normal = 1
}

/**
*  A simple UIView-Subclass which enables border detection of documents
*/
open class SobrCameraView: UIView, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    //MARK: Properties
    /// Enables realtime border detection.
    open var borderDetectionEnabled = true
    /// The color of the detection frame.
    open var borderDetectionFrameColor: UIColor = UIColor(red: 1, green: 0, blue: 0, alpha: 0.5)
    /// Sets the torch enabled or disabled.
    open var torchEnabled = false {
        didSet {
            if let device = self.captureDevice {
                if device.hasTorch && device.hasFlash {
                    try! device.lockForConfiguration()
                    device.torchMode = self.torchEnabled ? .on : .off
                    device.unlockForConfiguration()
                }
            }
        }
    }
    
    /// Sets the imageFilter based on `SobrCameraViewImageFilter` Enum.
    open var imageFilter: SobrCameraViewImageFilter = .normal {
        didSet {
            if let glkView = self.glkView {
                let effect = UIBlurEffect(style: .dark)
                let effectView = UIVisualEffectView(effect: effect)
                effectView.frame = self.bounds
                self.insertSubview(effectView, aboveSubview: glkView)
                
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.25 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: { () -> Void in
                    effectView.removeFromSuperview()
                })
            }
        }
    }
    
    //MARK: Private Properties
    fileprivate var captureSession = AVCaptureSession()
    fileprivate var captureDevice: AVCaptureDevice?
    fileprivate var context: EAGLContext?
    fileprivate var stillImageOutput: AVCaptureStillImageOutput = AVCaptureStillImageOutput()
    fileprivate var forceStop: Bool = false
    fileprivate var coreImageContext: CIContext?
    fileprivate var renderBuffer: GLuint = 0
    fileprivate var glkView: GLKView?
    fileprivate var stopped: Bool = false
    fileprivate var imageDetectionConfidence = 0.0
    fileprivate var borderDetectFrame: Bool = false
    fileprivate var borderDetectLastRectangleFeature: CIRectangleFeature?
    fileprivate var capturing: Bool = false
    fileprivate var timeKeeper: Timer?
    
    fileprivate static let highAccuracyRectangleDetector = CIDetector(ofType: CIDetectorTypeRectangle, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
    
    //MARK: Lifecycle
    
    /**
    Adds observers to the NSNotificationCenter.
    */
    open override func awakeFromNib() {
        super.awakeFromNib()
        NotificationCenter.default.addObserver(self, selector: #selector(SobrCameraView._backgroundMode), name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SobrCameraView._foregroundMode), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    //MARK: Actions
    /**
    Set's up all needed Elements for Video and Border detection. Should be called in `viewDidLoad:` in the view controller.
    */
    open func setupCameraView() {
        self.setupGLKView()
        
        let allDevices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo)
        let aDevice: AnyObject? = allDevices?.first as AnyObject?
        
        if aDevice == nil {
            return
        }
        
        self.captureSession.beginConfiguration()
        self.captureDevice = (aDevice as! AVCaptureDevice)
        
        let input = try! AVCaptureDeviceInput(device: self.captureDevice)
        self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        self.captureSession.addInput(input)
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.alwaysDiscardsLateVideoFrames = true
//        dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA]
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
        self.captureSession.addOutput(dataOutput)
        
        self.captureSession.addOutput(self.stillImageOutput)
        
        let connection = dataOutput.connections.first as! AVCaptureConnection
        connection.videoOrientation = .portrait
        
        if self.captureDevice!.isFlashAvailable {
            try! self.captureDevice?.lockForConfiguration()
            self.captureDevice?.flashMode = .off
            self.captureDevice?.unlockForConfiguration()
        }
        
        if self.captureDevice!.isFocusModeSupported(.continuousAutoFocus) {
            try! self.captureDevice?.lockForConfiguration()
            self.captureDevice?.focusMode = .continuousAutoFocus
            self.captureDevice?.unlockForConfiguration()
        }
        
        self.captureSession.commitConfiguration()
        
    }
    
    /**
    Starts the camera.
    */
    open func start() {
        self.stopped = false
        self.captureSession.startRunning()
        self.hideGlkView(false, completion: nil)
        self.timeKeeper = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(SobrCameraView._enableBorderDetection), userInfo: nil, repeats: true)
    }
    
    /**
    Stops the camera
    */
    open func stop() {
        self.stopped = true
        self.captureSession.stopRunning()
        self.hideGlkView(true, completion: nil)
        self.timeKeeper?.invalidate()
    }
    
    /**
    Sets the focus of the camera to a given point if supported.
    
    :param: point      The point to focus.
    :param: completion The completion handler will be called everytime. Even if the camera does not support focus.
    */
    open func focusAt(_ point: CGPoint, completion:((Void)-> Void)?) {
        if let device = self.captureDevice {
            let poi = CGPoint(x: point.y / self.bounds.height, y: 1.0 - (point.x / self.bounds.width))
            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                try! device.lockForConfiguration()
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                    device.focusPointOfInterest = poi
                }
                
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposurePointOfInterest = poi
                    device.exposureMode = .continuousAutoExposure
                }
                
                device.unlockForConfiguration()
                completion?()
            }
        }
        else {
            completion?()
        }
    }
    
    /**
    Captures the image. If `borderDetectionEnabled` is `true`, a perspective correction will be applied to the image.
    The selected `imageFilter` will also be applied to the image.
    
    :param: completion Returns the image as `UIImage`.
    */
    open func captureImage(_ completion: @escaping (_ image: UIImage, _ feature: CIRectangleFeature?) -> Void) {
        if self.capturing {
            return
        }
        
        self.hideGlkView(true, completion: { () -> Void in
            self.hideGlkView(false, completion: nil)
        })
        
        self.capturing = true
        
        var videoConnection: AVCaptureConnection?
        for connection in self.stillImageOutput.connections as! [AVCaptureConnection] {
            for port in connection.inputPorts as! [AVCaptureInputPort] {
                if port.mediaType == AVMediaTypeVideo {
                    videoConnection = connection
                    break
                }
            }
            if let _ = videoConnection {
                break
            }
        }
        
        self.stillImageOutput.captureStillImageAsynchronously(from: videoConnection!, completionHandler: { (imageSampleBuffer, error) -> Void in
            let jpg = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageSampleBuffer)
            
            var enhancedImage: CIImage = CIImage(data: jpg!)!
            switch self.imageFilter {
            case .blackAndWhite:
                enhancedImage = self.contrastFilter(enhancedImage)
            default:
                enhancedImage = self.enhanceFilter(enhancedImage)
            }
            
            if self.borderDetectionEnabled && self.detectionConfidenceValid() {
                if let rectangleFeature = self.biggestRectangle(SobrCameraView.highAccuracyRectangleDetector?.features(in: enhancedImage) as! [CIRectangleFeature]) {
                    enhancedImage = self.perspectiveCorrectedImage(enhancedImage, feature: rectangleFeature)
                }
            }
            
            UIGraphicsBeginImageContext(CGSize(width: enhancedImage.extent.size.height, height: enhancedImage.extent.size.width))
            
            UIImage(ciImage: enhancedImage, scale: 1.0, orientation: UIImageOrientation.right).draw(in: CGRect(x: 0, y: 0, width: enhancedImage.extent.size.height, height: enhancedImage.extent.size.width))
            
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            completion(image!, self.biggestRectangle(SobrCameraView.highAccuracyRectangleDetector?.features(in: enhancedImage) as! [CIRectangleFeature]))
        })
        self.capturing = false
    }
    
    //MARK: Private Actions
    /**
    This method is for internal use only. But it must be public to subscribe to `NSNotificationCenter` events.
    */
    open func _backgroundMode() {
        self.forceStop = true
    }
    /**
    This method is for internal use only. But it must be public to subscribe to `NSNotificationCenter` events.
    */
    open func _foregroundMode() {
        self.forceStop = false
    }
    /**
    This method is for internal use only. But it must be public to subscribe to `NSNotificationCenter` events.
    */
    open func _enableBorderDetection() {
        self.borderDetectFrame = true
    }
    
    fileprivate func setupGLKView() {
        if let _ = self.context {
            return
        }
        
        self.context = EAGLContext(api: .openGLES2)
        self.glkView = GLKView(frame: self.bounds, context: self.context!)
        self.glkView!.autoresizingMask = ([UIViewAutoresizing.flexibleWidth, UIViewAutoresizing.flexibleHeight])
        self.glkView!.translatesAutoresizingMaskIntoConstraints = true
        self.glkView!.contentScaleFactor = 1.0
        self.glkView!.drawableDepthFormat = .format24
        self.insertSubview(self.glkView!, at: 0)
        glGenRenderbuffers(1, &self.renderBuffer)
        glBindRenderbuffer(GLenum(GL_RENDERBUFFER), self.renderBuffer)
        
        self.coreImageContext = CIContext(eaglContext: self.context!, options: [kCIContextUseSoftwareRenderer: true])
        EAGLContext.setCurrent(self.context!)
    }
    
    fileprivate func contrastFilter(_ image: CIImage) -> CIImage {
        return CIFilter(name: "CIColorControls", withInputParameters: ["inputContrast":1.1, kCIInputImageKey: image])!.outputImage!
    }
    
    fileprivate func enhanceFilter(_ image: CIImage) -> CIImage {
        return CIFilter(name: "CIColorControls", withInputParameters: ["inputBrightness":0.0, "inputContrast":1.14, "inputSaturation":0.0, kCIInputImageKey: image])!.outputImage!
    }
    
    fileprivate func biggestRectangle(_ rectangles: [CIRectangleFeature]) -> CIRectangleFeature? {
        if rectangles.count == 0 {
            return nil
        }
        
        var biggestRectangle = rectangles.first!
        
        var halfPerimeterValue = 0.0
        
        for rectangle in rectangles {
            let p1 = rectangle.topLeft
            let p2 = rectangle.topRight
            let width = hypotf(Float(p1.x - p2.x), Float(p1.y - p2.y))
            
            let p3 = rectangle.bottomLeft
            let height = hypotf(Float(p1.x - p3.x), Float(p1.y - p3.y))
            
            let currentHalfPermiterValue = Double(height + width)
            if halfPerimeterValue < currentHalfPermiterValue {
                halfPerimeterValue = currentHalfPermiterValue
                biggestRectangle = rectangle
            }
        }
        return biggestRectangle
    }
    
    fileprivate func overlayImageForFeatureInImage(_ image: CIImage, feature: CIRectangleFeature) -> CIImage! {
        var overlay = CIImage(color: CIColor(color: self.borderDetectionFrameColor))
        overlay = overlay.cropping(to: image.extent)
        overlay = overlay.applyingFilter("CIPerspectiveTransformWithExtent", withInputParameters: ["inputExtent":     CIVector(cgRect: image.extent),
            "inputTopLeft":    CIVector(cgPoint: feature.topLeft),
            "inputTopRight":   CIVector(cgPoint: feature.topRight),
            "inputBottomLeft": CIVector(cgPoint: feature.bottomLeft),
            "inputBottomRight": CIVector(cgPoint: feature.bottomRight)])
        return overlay.compositingOverImage(image)
    }
    
    fileprivate func hideGlkView(_ hide: Bool, completion:( () -> Void)?) {
        UIView.animate(withDuration: 0.1, animations: { () -> Void in
            self.glkView?.alpha = (hide) ? 0.0 : 1.0
            }, completion: { (finished) -> Void in
                completion?()
        }) 
    }
    
    fileprivate func detectionConfidenceValid() -> Bool {
        return (self.imageDetectionConfidence > 1.0)
    }
    
    fileprivate func perspectiveCorrectedImage(_ image: CIImage, feature: CIRectangleFeature) -> CIImage {
        return image.applyingFilter("CIPerspectiveCorrection", withInputParameters: [
            "inputTopLeft":    CIVector(cgPoint: feature.topLeft),
            "inputTopRight":   CIVector(cgPoint: feature.topRight),
            "inputBottomLeft": CIVector(cgPoint: feature.bottomLeft),
            "inputBottomRight":CIVector(cgPoint: feature.bottomRight)])
    }
    
    //MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    /**
    This method is for internal use only. But must be declared public because it matches a requirement in public protocol `AVCaptureVideoDataOutputSampleBufferDelegate`.
    */
    open func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        if self.forceStop {
            return
        }
        let sampleBufferValid: Bool = CMSampleBufferIsValid(sampleBuffer)
        if self.stopped || self.capturing || !sampleBufferValid {
            return
        }
        
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        var image = CIImage(cvPixelBuffer: pixelBuffer!)
        
        switch self.imageFilter {
        case .blackAndWhite:
            image = self.contrastFilter(image)
        default:
            image = self.enhanceFilter(image)
        }
        
        if self.borderDetectionEnabled {
            if self.borderDetectFrame {
                self.borderDetectLastRectangleFeature = self.biggestRectangle(SobrCameraView.highAccuracyRectangleDetector?.features(in: image) as! [CIRectangleFeature])
                self.borderDetectFrame = false
            }
            
            if let lastRectFeature = self.borderDetectLastRectangleFeature {
                self.imageDetectionConfidence += 0.5
                image = self.overlayImageForFeatureInImage(image, feature: lastRectFeature)
            }
            else {
                self.imageDetectionConfidence = 0.0
            }
        }
        
        if let context = self.context, let ciContext = self.coreImageContext, let glkView = self.glkView {
            ciContext.draw(image, in: self.bounds, from: image.extent)
            context.presentRenderbuffer(Int(GL_RENDERBUFFER))
            glkView.setNeedsDisplay()
        }
    }
}
