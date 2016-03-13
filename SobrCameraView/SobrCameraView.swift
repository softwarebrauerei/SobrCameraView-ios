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
    case BlackAndWhite = 0
    case Normal = 1
}

/**
*  A simple UIView-Subclass which enables border detection of documents
*/
public class SobrCameraView: UIView, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    //MARK: Properties
    /// Enables realtime border detection.
    public var borderDetectionEnabled = true
    /// The color of the detection frame.
    public var borderDetectionFrameColor: UIColor = UIColor(red: 1, green: 0, blue: 0, alpha: 0.5)
    /// Sets the torch enabled or disabled.
    public var torchEnabled = false {
        didSet {
            if let device = self.captureDevice {
                if device.hasTorch && device.hasFlash {
                    try! device.lockForConfiguration()
                    device.torchMode = self.torchEnabled ? .On : .Off
                    device.unlockForConfiguration()
                }
            }
        }
    }
    
    /// Sets the imageFilter based on `SobrCameraViewImageFilter` Enum.
    public var imageFilter: SobrCameraViewImageFilter = .Normal {
        didSet {
            if let glkView = self.glkView {
                let effect = UIBlurEffect(style: .Dark)
                let effectView = UIVisualEffectView(effect: effect)
                effectView.frame = self.bounds
                self.insertSubview(effectView, aboveSubview: glkView)
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.25 * Double(NSEC_PER_SEC))), dispatch_get_main_queue(), { () -> Void in
                    effectView.removeFromSuperview()
                })
            }
        }
    }
    
    //MARK: Private Properties
    private var captureSession = AVCaptureSession()
    private var captureDevice: AVCaptureDevice?
    private var context: EAGLContext?
    private var stillImageOutput: AVCaptureStillImageOutput = AVCaptureStillImageOutput()
    private var forceStop: Bool = false
    private var coreImageContext: CIContext?
    private var renderBuffer: GLuint = 0
    private var glkView: GLKView?
    private var stopped: Bool = false
    private var imageDetectionConfidence = 0.0
    private var borderDetectFrame: Bool = false
    private var borderDetectLastRectangleFeature: CIRectangleFeature?
    private var capturing: Bool = false
    private var timeKeeper: NSTimer?
    
    private static let highAccuracyRectangleDetector = CIDetector(ofType: CIDetectorTypeRectangle, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
    
    //MARK: Lifecycle
    
    /**
    Adds observers to the NSNotificationCenter.
    */
    public override func awakeFromNib() {
        super.awakeFromNib()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("_backgroundMode"), name: UIApplicationWillResignActiveNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("_foregroundMode"), name: UIApplicationDidBecomeActiveNotification, object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    //MARK: Actions
    /**
    Set's up all needed Elements for Video and Border detection. Should be called in `viewDidLoad:` in the view controller.
    */
    public func setupCameraView() {
        self.setupGLKView()
        
        let allDevices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
        let aDevice: AnyObject? = allDevices.first
        
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
        dataOutput.setSampleBufferDelegate(self, queue: dispatch_get_main_queue())
        self.captureSession.addOutput(dataOutput)
        
        self.captureSession.addOutput(self.stillImageOutput)
        
        let connection = dataOutput.connections.first as! AVCaptureConnection
        connection.videoOrientation = .Portrait
        
        if self.captureDevice!.flashAvailable {
            try! self.captureDevice?.lockForConfiguration()
            self.captureDevice?.flashMode = .Off
            self.captureDevice?.unlockForConfiguration()
        }
        
        if self.captureDevice!.isFocusModeSupported(.ContinuousAutoFocus) {
            try! self.captureDevice?.lockForConfiguration()
            self.captureDevice?.focusMode = .ContinuousAutoFocus
            self.captureDevice?.unlockForConfiguration()
        }
        
        self.captureSession.commitConfiguration()
        
    }
    
    /**
    Starts the camera.
    */
    public func start() {
        self.stopped = false
        self.captureSession.startRunning()
        self.hideGlkView(false, completion: nil)
        self.timeKeeper = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: Selector("_enableBorderDetection"), userInfo: nil, repeats: true)
    }
    
    /**
    Stops the camera
    */
    public func stop() {
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
    public func focusAt(point: CGPoint, completion:((Void)-> Void)?) {
        if let device = self.captureDevice {
            let poi = CGPoint(x: point.y / self.bounds.height, y: 1.0 - (point.x / self.bounds.width))
            if device.focusPointOfInterestSupported && device.isFocusModeSupported(.AutoFocus) {
                try! device.lockForConfiguration()
                if device.isFocusModeSupported(.ContinuousAutoFocus) {
                    device.focusMode = .ContinuousAutoFocus
                    device.focusPointOfInterest = poi
                }
                
                if device.exposurePointOfInterestSupported && device.isExposureModeSupported(.ContinuousAutoExposure) {
                    device.exposurePointOfInterest = poi
                    device.exposureMode = .ContinuousAutoExposure
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
    public func captureImage(completion: (image: UIImage, feature: CIRectangleFeature?) -> Void) {
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
        
        self.stillImageOutput.captureStillImageAsynchronouslyFromConnection(videoConnection!, completionHandler: { (imageSampleBuffer, error) -> Void in
            let jpg = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageSampleBuffer)
            
            var enhancedImage: CIImage = CIImage(data: jpg)!
            switch self.imageFilter {
            case .BlackAndWhite:
                enhancedImage = self.contrastFilter(enhancedImage)
            default:
                enhancedImage = self.enhanceFilter(enhancedImage)
            }
            
            if self.borderDetectionEnabled && self.detectionConfidenceValid() {
                if let rectangleFeature = self.biggestRectangle(SobrCameraView.highAccuracyRectangleDetector.featuresInImage(enhancedImage) as! [CIRectangleFeature]) {
                    enhancedImage = self.perspectiveCorrectedImage(enhancedImage, feature: rectangleFeature)
                }
            }
            
            UIGraphicsBeginImageContext(CGSize(width: enhancedImage.extent.size.height, height: enhancedImage.extent.size.width))
            
            UIImage(CIImage: enhancedImage, scale: 1.0, orientation: UIImageOrientation.Right).drawInRect(CGRect(x: 0, y: 0, width: enhancedImage.extent.size.height, height: enhancedImage.extent.size.width))
            
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            completion(image: image, feature: self.biggestRectangle(SobrCameraView.highAccuracyRectangleDetector.featuresInImage(enhancedImage) as! [CIRectangleFeature]))
        })
        self.capturing = false
    }
    
    //MARK: Private Actions
    /**
    This method is for internal use only. But it must be public to subscribe to `NSNotificationCenter` events.
    */
    public func _backgroundMode() {
        self.forceStop = true
    }
    /**
    This method is for internal use only. But it must be public to subscribe to `NSNotificationCenter` events.
    */
    public func _foregroundMode() {
        self.forceStop = false
    }
    /**
    This method is for internal use only. But it must be public to subscribe to `NSNotificationCenter` events.
    */
    public func _enableBorderDetection() {
        self.borderDetectFrame = true
    }
    
    private func setupGLKView() {
        if let _ = self.context {
            return
        }
        
        self.context = EAGLContext(API: .OpenGLES2)
        self.glkView = GLKView(frame: self.bounds, context: self.context!)
        self.glkView!.autoresizingMask = ([UIViewAutoresizing.FlexibleWidth, UIViewAutoresizing.FlexibleHeight])
        self.glkView!.translatesAutoresizingMaskIntoConstraints = true
        self.glkView!.contentScaleFactor = 1.0
        self.glkView!.drawableDepthFormat = .Format24
        self.insertSubview(self.glkView!, atIndex: 0)
        glGenRenderbuffers(1, &self.renderBuffer)
        glBindRenderbuffer(GLenum(GL_RENDERBUFFER), self.renderBuffer)
        
        self.coreImageContext = CIContext(EAGLContext: self.context!, options: [kCIContextUseSoftwareRenderer: true])
        EAGLContext.setCurrentContext(self.context!)
    }
    
    private func contrastFilter(image: CIImage) -> CIImage {
        return CIFilter(name: "CIColorControls", withInputParameters: ["inputContrast":1.1, kCIInputImageKey: image])!.outputImage!
    }
    
    private func enhanceFilter(image: CIImage) -> CIImage {
        return CIFilter(name: "CIColorControls", withInputParameters: ["inputBrightness":0.0, "inputContrast":1.14, "inputSaturation":0.0, kCIInputImageKey: image])!.outputImage!
    }
    
    private func biggestRectangle(rectangles: [CIRectangleFeature]) -> CIRectangleFeature? {
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
    
    private func overlayImageForFeatureInImage(image: CIImage, feature: CIRectangleFeature) -> CIImage! {
        var overlay = CIImage(color: CIColor(color: self.borderDetectionFrameColor))
        overlay = overlay.imageByCroppingToRect(image.extent)
        overlay = overlay.imageByApplyingFilter("CIPerspectiveTransformWithExtent", withInputParameters: ["inputExtent":     CIVector(CGRect: image.extent),
            "inputTopLeft":    CIVector(CGPoint: feature.topLeft),
            "inputTopRight":   CIVector(CGPoint: feature.topRight),
            "inputBottomLeft": CIVector(CGPoint: feature.bottomLeft),
            "inputBottomRight": CIVector(CGPoint: feature.bottomRight)])
        return overlay.imageByCompositingOverImage(image)
    }
    
    private func hideGlkView(hide: Bool, completion:( () -> Void)?) {
        UIView.animateWithDuration(0.1, animations: { () -> Void in
            self.glkView?.alpha = (hide) ? 0.0 : 1.0
            }) { (finished) -> Void in
                completion?()
        }
    }
    
    private func detectionConfidenceValid() -> Bool {
        return (self.imageDetectionConfidence > 1.0)
    }
    
    private func perspectiveCorrectedImage(image: CIImage, feature: CIRectangleFeature) -> CIImage {
        return image.imageByApplyingFilter("CIPerspectiveCorrection", withInputParameters: [
            "inputTopLeft":    CIVector(CGPoint: feature.topLeft),
            "inputTopRight":   CIVector(CGPoint: feature.topRight),
            "inputBottomLeft": CIVector(CGPoint: feature.bottomLeft),
            "inputBottomRight":CIVector(CGPoint: feature.bottomRight)])
    }
    
    //MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    /**
    This method is for internal use only. But must be declared public because it matches a requirement in public protocol `AVCaptureVideoDataOutputSampleBufferDelegate`.
    */
    public func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        if self.forceStop {
            return
        }
        let sampleBufferValid: Bool = CMSampleBufferIsValid(sampleBuffer)
        if self.stopped || self.capturing || !sampleBufferValid {
            return
        }
        
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        var image = CIImage(CVPixelBuffer: pixelBuffer!)
        
        switch self.imageFilter {
        case .BlackAndWhite:
            image = self.contrastFilter(image)
        default:
            image = self.enhanceFilter(image)
        }
        
        if self.borderDetectionEnabled {
            if self.borderDetectFrame {
                self.borderDetectLastRectangleFeature = self.biggestRectangle(SobrCameraView.highAccuracyRectangleDetector.featuresInImage(image) as! [CIRectangleFeature])
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
            ciContext.drawImage(image, inRect: self.bounds, fromRect: image.extent)
            context.presentRenderbuffer(Int(GL_RENDERBUFFER))
            glkView.setNeedsDisplay()
        }
    }
}
